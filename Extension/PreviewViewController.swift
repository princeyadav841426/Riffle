// Riffle — folder preview for macOS Quick Look
// Copyright © 2026 Aignix. MIT License.
// Portions Copyright © 2025 ALTIC (PeekX, MIT License) — see LICENSE.

import Cocoa
import Quartz
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing
import ImageIO
import WebKit
import QuartzCore  // For CATransaction

// MARK: - Debug Logger
/// Writes a small rolling log to the extension's temp folder. Compiled out of release builds.
final class DebugLogger {
    static let shared = DebugLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.aignix.riffle.logger", qos: .utility)
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let maxSize: UInt64 = 256 * 1024 // 256 KB
    
    private init() {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        fileURL = temp.appendingPathComponent("RiffleExt.log")
    }

    func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        let message = message()
        let timestamp = formatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        queue.async {
            if let data = entry.data(using: .utf8) {
                self.append(data)
            }
            NSLog("%@", message)
        }
        #endif
    }
    
    func locationDescription() -> String { fileURL.path }
    
    private func append(_ data: Data) {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) == false {
                try data.write(to: fileURL, options: .atomic)
            } else {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            }
            pruneIfNeeded()
        } catch {
            NSLog("Riffle logger error: \(error.localizedDescription)")
        }
    }
    
    private func pruneIfNeeded() {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? UInt64,
            size > maxSize
        else { return }
        
        if let data = try? Data(contentsOf: fileURL) {
            let trimmed = data.suffix(Int(maxSize / 2))
            try? trimmed.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Custom Outline View

/// Protocol for handling keyboard events in the outline view
protocol FinderOutlineViewKeyboardDelegate: AnyObject {
    func outlineView(_ outlineView: FinderOutlineView, handle event: NSEvent) -> Bool
}

/// Custom outline view that intercepts keyboard events for QuickLook-specific shortcuts
final class FinderOutlineView: NSOutlineView {
    weak var keyboardDelegate: FinderOutlineViewKeyboardDelegate?
    
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
    
    override func keyDown(with event: NSEvent) {
        if keyboardDelegate?.outlineView(self, handle: event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Recursive Folder Size Calculator

/// Measures folder sizes recursively on background threads, with an in-memory cache
/// so a folder is only ever walked once per preview session.
final class FolderSizeCalculator {
    static let shared = FolderSizeCalculator()

    private let queue = DispatchQueue(label: "com.aignix.riffle.foldersize",
                                      qos: .utility,
                                      attributes: .concurrent)
    private let lock = NSLock()
    private var cache: [String: Int64] = [:]
    private var inFlight: Set<String> = []

    /// Hard ceiling so a runaway folder (e.g. a whole drive) can never hang the preview.
    private let maxEntries = 200_000

    func cachedSize(for url: URL) -> Int64? {
        lock.lock(); defer { lock.unlock() }
        return cache[url.path]
    }

    func size(for url: URL, completion: @escaping (Int64) -> Void) {
        let key = url.path

        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            DispatchQueue.main.async { completion(hit) }
            return
        }
        if inFlight.contains(key) {
            lock.unlock()
            return
        }
        inFlight.insert(key)
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            let total = self.walk(url)

            self.lock.lock()
            self.cache[key] = total
            self.inFlight.remove(key)
            self.lock.unlock()

            DispatchQueue.main.async { completion(total) }
        }
    }

    private func walk(_ url: URL) -> Int64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(at: url,
                                             includingPropertiesForKeys: keys,
                                             options: [],
                                             errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        var seen = 0
        for case let entry as URL in enumerator {
            seen += 1
            if seen > maxEntries { break }
            guard let values = try? entry.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.isRegularFile == true else { continue }
            // Prefer allocated size so the number matches what Finder reports on disk.
            if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                total += Int64(allocated)
            } else if let logical = values.fileSize {
                total += Int64(logical)
            }
        }
        return total
    }
}

// MARK: - Pane Divider

/// Draggable divider between the file list and the preview pane.
/// (NSSplitView ignores repositioning inside a Quick Look remote view, so the layout is ours.)
final class PaneDivider: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastX: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: floor(bounds.midX), y: 0, width: 1, height: bounds.height).fill()
    }

    override func mouseDown(with event: NSEvent) {
        lastX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        let x = event.locationInWindow.x
        onDrag?(x - lastX)
        lastX = x
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded?()
    }
}

/// Rounded backdrop behind thumbnails that follows light/dark mode.
final class BackdropView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.06)
                                           : NSColor.black.withAlphaComponent(0.04)).cgColor
        }
    }
}

// MARK: - File Item Model

/// Represents a file or folder in the preview hierarchy
final class FileItem: NSObject, QLPreviewItem {
    let url: URL
    let name: String
    let isFolder: Bool
    let size: Int64
    let modificationDate: Date
    let contentType: UTType?
    weak var parent: FileItem?
    var icon: NSImage?
    var children: [FileItem]?
    var childrenLoaded = false

    // Recursive folder size (computed lazily on a background queue)
    var computedFolderSize: Int64?
    var folderSizeRequested = false

    // Details shown in the preview pane, filled in lazily when the item is selected
    var itemCount: Int?
    var creationDate: Date?
    var pixelSize: CGSize?

    /// Size used for display and sorting: real bytes for files, recursive total for folders.
    var effectiveSize: Int64 {
        if isFolder { return computedFolderSize ?? -1 }
        return size
    }
    
    // Cached formatted strings to avoid repeated formatting
    private var _formattedSize: String?
    private var _formattedDate: String?
    private var _kindDescription: String?
    
    // Cached type checks for fast preview decisions
    lazy var isImage: Bool = contentType?.conforms(to: .image) ?? false
    lazy var isText: Bool = contentType?.conforms(to: .text) ?? false || url.pathExtension.lowercased() == "md"
    lazy var isMedia: Bool = contentType?.conforms(to: .audiovisualContent) ?? false
    
    init(url: URL, resourceValues: URLResourceValues, parent: FileItem? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isFolder = resourceValues.isDirectory ?? false
        self.size = Int64(resourceValues.fileSize ?? 0)
        self.modificationDate = resourceValues.contentModificationDate ?? Date()
        self.contentType = resourceValues.contentType
        self.parent = parent
        super.init()
    }
    
    var kindDescription: String {
        if let cached = _kindDescription {
            return cached
        }
        let desc = isFolder ? "Folder" : (contentType?.localizedDescription ?? "File")
        _kindDescription = desc
        return desc
    }
    
    // Lazy formatted size - computed once and cached
    func formattedSize(using formatter: ByteCountFormatter) -> String {
        if let cached = _formattedSize {
            return cached
        }
        if isFolder {
            // Still being measured - show a placeholder and do NOT cache it.
            guard let computed = computedFolderSize else { return "––" }
            let formatted = formatter.string(fromByteCount: computed)
            _formattedSize = formatted
            return formatted
        }
        let formatted = formatter.string(fromByteCount: size)
        _formattedSize = formatted
        return formatted
    }
    
    // Lazy formatted date - computed once and cached
    func formattedDate(using formatter: DateFormatter) -> String {
        if let cached = _formattedDate {
            return cached
        }
        let formatted = formatter.string(from: modificationDate)
        _formattedDate = formatted
        return formatted
    }
    
    /// Label/value rows for the preview pane's details list.
    func detailRows(sizeFormatter: ByteCountFormatter, dateFormatter: DateFormatter, root: URL?) -> [(String, String)] {
        var rows: [(String, String)] = [("Kind", kindDescription)]
        if isFolder {
            rows.append(("Size", computedFolderSize.map { sizeFormatter.string(fromByteCount: $0) } ?? "Calculating…"))
            if let itemCount {
                rows.append(("Items", NumberFormatter.localizedString(from: NSNumber(value: itemCount), number: .decimal)))
            }
        } else {
            rows.append(("Size", formattedSize(using: sizeFormatter)))
        }
        if let pixelSize {
            rows.append(("Dimensions", "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"))
        }
        rows.append(("Modified", formattedDate(using: dateFormatter)))
        if let creationDate {
            rows.append(("Created", dateFormatter.string(from: creationDate)))
        }
        if parent != nil, let root {
            // Nested item: show where it sits relative to the previewed folder.
            let parts = url.deletingLastPathComponent().pathComponents
            let rootParts = root.deletingLastPathComponent().pathComponents
            rows.append(("Where", parts.dropFirst(rootParts.count).joined(separator: " › ")))
        }
        return rows
    }

    /// Clears the memoised size string so the recursive total can replace the placeholder.
    func invalidateFormattedSize() {
        _formattedSize = nil
    }

    func setChildren(_ children: [FileItem]) {
        self.children = children
        self.childrenLoaded = true
        for child in children {
            child.parent = self
        }
    }
    
    func resetChildren() {
        children = nil
        childrenLoaded = false
    }
    
    var previewItemURL: URL? { url }
    var previewItemTitle: String { name }
}

// MARK: - Preview View Controller

/// Main view controller for the QuickLook folder preview extension
@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController {
    
    // MARK: - Filter Types
    
    private enum FilterType: Int {
        case all, folders, images, documents, media
        
        func matches(_ item: FileItem) -> Bool {
            switch self {
            case .all:
                return true
            case .folders:
                return item.isFolder
            case .images:
                return item.isImage
            case .documents:
                if item.isFolder { return false }
                // Document = not image and not media
                return !item.isImage && !item.isMedia
            case .media:
                return item.isMedia
            }
        }
    }
    
    // MARK: - UI Components
    
    private var mainStack: NSStackView!
    private var scrollView: NSScrollView!
    private var contentRow: NSView!
    private var paneDivider: PaneDivider!
    private var previewWidthConstraint: NSLayoutConstraint!
    private var outlineView: FinderOutlineView!
    private var headerView: NSView!
    private var iconImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var infoLabel: NSTextField!
    private var controlsStack: NSStackView!
    private var filterControl: NSSegmentedControl!
    private var previewPane: NSView!
    private var pathBarView: NSView!
    private var pathControl: NSPathControl!
    private var previewImageView: NSImageView!
    private var webView: WKWebView!
    private var singleFileWebView: WKWebView!  // Separate WebView for single file mode
    private var previewSpinner: NSProgressIndicator!
    private var previewContentStack: NSStackView!
    private var previewTitleLabel: NSTextField!
    private var previewDetailsStack: NSStackView!
    private var previewMessageLabel: NSTextField!
    private var previewThumbnailRequest: QLThumbnailGenerator.Request?

    /// Inset of the preview pane's content from the divider (left) and window edge (right).
    private let previewInsetLeading: CGFloat = 16
    private let previewInsetTrailing: CGFloat = 4
    /// Width of the label column ("Kind", "Size"…) in the details list.
    private let detailKeyWidth: CGFloat = 74
    private let detailColumnSpacing: CGFloat = 8

    // MARK: - Performance Caches

    private let iconCache = NSCache<NSString, NSImage>()
    private let iconLoadQueue = DispatchQueue(label: "com.aignix.riffle.iconloader", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Data State
    
    private var rootItems: [FileItem] = []
    private var filterType: FilterType = .all
    private var currentSortDescriptor: NSSortDescriptor? = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    private var visibleRootItems: [FileItem] = []
    private var previewedItem: FileItem?
    private var previewImageLoadTask: DispatchWorkItem?
    private var previewRootURL: URL?
    private var lastRowWidth: CGFloat = 0
    /// Share of the row given to the preview pane; remembered after the user drags the divider.
    private var previewFraction: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "previewPaneFraction")
        return saved > 0.1 && saved < 0.8 ? CGFloat(saved) : 0.36
    }()
    private var singleFileMode = false
    private var previewUpdateWorkItem: DispatchWorkItem?
    
    // MARK: - Formatters
    
    private lazy var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Main Vertical Stack
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.distribution = .fill
        self.mainStack = stack
        
        headerView = createHeaderView()
        controlsStack = createControlsStack()
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false  // columns are fitted to the width instead
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        outlineView = FinderOutlineView()
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.headerView = NSTableHeaderView()
        outlineView.focusRingType = .none
        outlineView.selectionHighlightStyle = .regular
        outlineView.rowSizeStyle = .default
        outlineView.allowsColumnReordering = false
        outlineView.allowsColumnResizing = true
        // Columns are fitted by fitColumnsToList(); AppKit's own autoresizing would undo that.
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        // Same look in every host; the inset style adds side padding the column fit can't see.
        outlineView.style = .fullWidth
        outlineView.intercellSpacing = NSSize(width: 4, height: 2)
        outlineView.keyboardDelegate = self
        outlineView.menu = contextMenu
        outlineView.menu?.delegate = self
        
        scrollView.documentView = outlineView
        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(listFrameChanged(_:)),
                                               name: NSView.frameDidChangeNotification,
                                               object: scrollView.contentView)
        
        previewPane = createPreviewPane()
        paneDivider = PaneDivider()
        paneDivider.translatesAutoresizingMaskIntoConstraints = false
        paneDivider.onDrag = { [weak self] delta in self?.dragDivider(by: delta) }
        paneDivider.onDragEnded = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(Double(self.previewFraction), forKey: "previewPaneFraction")
        }
        
        contentRow = NSView()
        contentRow.translatesAutoresizingMaskIntoConstraints = false
        contentRow.addSubview(scrollView)
        contentRow.addSubview(paneDivider)
        contentRow.addSubview(previewPane)
        // Preferred width sits below window-resize priority (500), so resizing the Quick Look
        // window is never blocked; the hard floors below decide the window's minimum width.
        previewWidthConstraint = previewPane.widthAnchor.constraint(equalToConstant: 280)
        previewWidthConstraint.priority = .init(490)
        let listMin = scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.outlineMinWidth)
        listMin.priority = .init(998)
        let paneMin = previewPane.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.previewFloorWidth)
        paneMin.priority = .init(997)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentRow.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentRow.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentRow.bottomAnchor),
            paneDivider.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            paneDivider.topAnchor.constraint(equalTo: contentRow.topAnchor),
            paneDivider.bottomAnchor.constraint(equalTo: contentRow.bottomAnchor),
            paneDivider.widthAnchor.constraint(equalToConstant: Self.dividerWidth),
            previewPane.leadingAnchor.constraint(equalTo: paneDivider.trailingAnchor),
            previewPane.trailingAnchor.constraint(equalTo: contentRow.trailingAnchor),
            previewPane.topAnchor.constraint(equalTo: contentRow.topAnchor),
            previewPane.bottomAnchor.constraint(equalTo: contentRow.bottomAnchor),
            previewWidthConstraint,
            listMin,
            paneMin
        ])
        
        mainStack.addArrangedSubview(headerView)
        mainStack.addArrangedSubview(controlsStack)
        mainStack.addArrangedSubview(contentRow)

        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            
            headerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            controlsStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            contentRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])
        
        // Content priorities to ensure SplitView fills space
        headerView.setContentHuggingPriority(.required, for: .vertical)
        controlsStack.setContentHuggingPriority(.required, for: .vertical)
        contentRow.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Create standalone WebView for single-file mode
        singleFileWebView = WKWebView(frame: .zero, configuration: makeDocumentWebConfiguration())
        singleFileWebView.navigationDelegate = self
        singleFileWebView.translatesAutoresizingMaskIntoConstraints = false
        singleFileWebView.isHidden = true
        singleFileWebView.setValue(false, forKey: "drawsBackground")
        container.addSubview(singleFileWebView)
        
        NSLayoutConstraint.activate([
            singleFileWebView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            singleFileWebView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            singleFileWebView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            singleFileWebView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        createColumns()
        updatePreview(for: nil)
        self.view = container
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        fitColumnsToList()
        outlineView.window?.makeFirstResponder(outlineView)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        let width = contentRow.bounds.width
        guard width > 1 else { return }
        if abs(width - lastRowWidth) > 0.5 {
            lastRowWidth = width
            applyPreviewWidth()
        }
        fitColumnsToList()
        updatePreviewWrapWidths()
    }

    /// Multi-line labels need an explicit wrap width, otherwise AppKit sizes them to their
    /// one-line width and the split view clips the overflow (the old right-edge cropping bug).
    private func updatePreviewWrapWidths() {
        let contentWidth = floor(previewContentStack.bounds.width)
        guard contentWidth > 1 else { return }
        var changed = false
        func apply(_ field: NSTextField, _ width: CGFloat) {
            let width = max(1, width)
            if abs(field.preferredMaxLayoutWidth - width) > 0.5 {
                field.preferredMaxLayoutWidth = width
                field.invalidateIntrinsicContentSize()
                changed = true
            }
        }
        apply(previewTitleLabel, contentWidth)
        apply(previewMessageLabel, contentWidth)
        for case let row as NSStackView in previewDetailsStack.arrangedSubviews {
            if let value = row.arrangedSubviews.last as? NSTextField {
                apply(value, contentWidth - detailKeyWidth - detailColumnSpacing)
            }
        }
        if changed {
            previewPane.needsLayout = true
        }
    }
    
    // MARK: - UI Builders
    private func createHeaderView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        iconImageView = NSImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown
        
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = NSFont.systemFont(ofSize: 13)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            iconImageView.topAnchor.constraint(equalTo: view.topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            infoLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])
        
        return view
    }
    
    private func createControlsStack() -> NSStackView {
        filterControl = NSSegmentedControl(labels: ["All", "Folders", "Images", "Docs", "Media"], trackingMode: .selectOne, target: self, action: #selector(filterChanged(_:)))
        filterControl.selectedSegment = FilterType.all.rawValue
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView(views: [filterControl])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        
        // Ensure the stack itself doesn't force a specific width if not needed, 
        // but we can center the filter control inside it.
        
        NSLayoutConstraint.activate([
            filterControl.widthAnchor.constraint(equalToConstant: 320)
        ])
        
        return stack
    }
    
    private static let outlineMinWidth: CGFloat = 340
    private static let previewMinWidth: CGFloat = 230
    private static let previewFloorWidth: CGFloat = 180
    private static let previewMaxWidth: CGFloat = 520

    private static let dividerWidth: CGFloat = 9

    /// Preview pane width for the current row width: the remembered share, clamped so both
    /// sides stay usable. The file list keeps its minimum first; the preview yields.
    private func previewWidth(forFraction fraction: CGFloat) -> CGFloat {
        let available = contentRow.bounds.width - Self.dividerWidth
        var width = min(Self.previewMaxWidth, max(Self.previewMinWidth, (available * fraction).rounded()))
        width = min(width, max(Self.previewFloorWidth, available - Self.outlineMinWidth))
        return max(0, width)
    }

    private func applyPreviewWidth() {
        let width = previewWidth(forFraction: previewFraction)
        guard abs(previewWidthConstraint.constant - width) > 0.5 else { return }
        DebugLogger.shared.log("Pane layout: row=\(Int(contentRow.bounds.width)) preview=\(Int(width))")
        previewWidthConstraint.constant = width
    }

    /// Name takes whatever the other columns leave, so Kind never falls off the right edge.
    /// In a narrow list, Kind, Date and Size give up width (down to their minimums) first.
    private func fitColumnsToList() {
        let clipWidth = scrollView.contentView.bounds.width
        let columns = outlineView.tableColumns
        guard clipWidth > 0, let nameColumn = columns.first else { return }
        let spacing = outlineView.intercellSpacing.width * CGFloat(columns.count)
        var widths = columns.map { Self.defaultColumnWidths[$0.identifier.rawValue] ?? $0.width }
        var deficit = nameColumn.minWidth + widths.dropFirst().reduce(0, +) + spacing - clipWidth
        for index in [3, 1, 2] where deficit > 0 && index < columns.count {
            let give = min(deficit, widths[index] - columns[index].minWidth)
            widths[index] -= give
            deficit -= give
        }
        // In a roomy list, let Size and Kind breathe before Name takes the rest.
        var spare = clipWidth - spacing - widths.reduce(0, +)
        for (index, cap) in [(2, CGFloat(86)), (3, CGFloat(132))] where spare > 0 && index < columns.count {
            let give = min(spare / 2, max(0, cap - widths[index]))
            widths[index] += give
            spare -= give
        }
        widths[0] = max(nameColumn.minWidth, floor(clipWidth - widths.dropFirst().reduce(0, +) - spacing) - 1)
        for (column, width) in zip(columns, widths) where abs(column.width - width) > 0.5 {
            column.width = width
        }
    }

    @objc private func listFrameChanged(_ notification: Notification) {
        fitColumnsToList()
    }

    private func dragDivider(by delta: CGFloat) {
        let available = contentRow.bounds.width - Self.dividerWidth
        guard available > 0 else { return }
        let proposed = previewWidthConstraint.constant - delta
        let maxWidth = max(Self.previewMinWidth, available - Self.outlineMinWidth)
        let width = min(max(proposed, Self.previewMinWidth), min(maxWidth, available * 0.7))
        previewFraction = width / available
        previewWidthConstraint.constant = width.rounded()
        view.layoutSubtreeIfNeeded()
    }
    
    private static let defaultColumnWidths: [String: CGFloat] = ["name": 200, "date": 132, "size": 74, "kind": 90]

    private func createColumns() {
        outlineView.tableColumns.forEach { outlineView.removeTableColumn($0) }

        // Name absorbs any extra width; the other columns keep a compact, readable size.
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.minWidth = 120
        nameColumn.width = 200
        nameColumn.resizingMask = [.autoresizingMask, .userResizingMask]
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Date Modified"
        dateColumn.minWidth = 96
        dateColumn.width = 132
        dateColumn.resizingMask = .userResizingMask
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: "date", ascending: false)
        outlineView.addTableColumn(dateColumn)

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.minWidth = 60
        sizeColumn.width = 74
        sizeColumn.resizingMask = .userResizingMask
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: false)
        outlineView.addTableColumn(sizeColumn)

        let kindColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind"))
        kindColumn.title = "Kind"
        kindColumn.minWidth = 64
        kindColumn.width = 90
        kindColumn.resizingMask = .userResizingMask
        kindColumn.sortDescriptorPrototype = NSSortDescriptor(key: "kind", ascending: true)
        outlineView.addTableColumn(kindColumn)
    }

    /// A full-width, multi-line label. Wrap width is kept in sync by `updatePreviewWrapWidths()`.
    private func makeWrappingLabel(_ text: String, font: NSFont, color: NSColor, maxLines: Int) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isSelectable = false
        label.maximumNumberOfLines = maxLines
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.truncatesLastVisibleLine = true
        label.translatesAutoresizingMaskIntoConstraints = false
        // Let the pane decide the width; the label only decides its height.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func createPreviewPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.detachesHiddenViews = true
        previewContentStack = stack

        let imageContainer = BackdropView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        previewImageView = NSImageView()
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.imageAlignment = .alignCenter
        // The image must never size the pane: a 3000px photo would otherwise push the details off-screen.
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            previewImageView.setContentCompressionResistancePriority(.init(1), for: orientation)
            previewImageView.setContentHuggingPriority(.init(1), for: orientation)
        }
        
        webView = WKWebView(frame: .zero, configuration: makeDocumentWebConfiguration())
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.setValue(false, forKey: "drawsBackground")
        
        previewSpinner = NSProgressIndicator()
        previewSpinner.translatesAutoresizingMaskIntoConstraints = false
        previewSpinner.style = .spinning
        previewSpinner.controlSize = .large
        previewSpinner.isDisplayedWhenStopped = false
        
        imageContainer.addSubview(previewImageView)
        imageContainer.addSubview(webView)
        imageContainer.addSubview(previewSpinner)
        
        // Thumbnail area: 4:3 of the pane width, capped so the details always stay visible.
        let proportionalHeight = imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: 0.75)
        proportionalHeight.priority = .init(740)
        NSLayoutConstraint.activate([
            previewImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            webView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            webView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            webView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            previewSpinner.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            previewSpinner.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            
            imageContainer.heightAnchor.constraint(lessThanOrEqualToConstant: 320),
            imageContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            proportionalHeight
        ])

        previewTitleLabel = makeWrappingLabel("No Selection",
                                              font: .systemFont(ofSize: 17, weight: .semibold),
                                              color: .labelColor,
                                              maxLines: 3)

        previewDetailsStack = NSStackView()
        previewDetailsStack.translatesAutoresizingMaskIntoConstraints = false
        previewDetailsStack.orientation = .vertical
        previewDetailsStack.alignment = .leading
        previewDetailsStack.spacing = 5

        previewMessageLabel = makeWrappingLabel("",
                                                font: .systemFont(ofSize: 12),
                                                color: .tertiaryLabelColor,
                                                maxLines: 4)
        previewMessageLabel.isHidden = true

        stack.addArrangedSubview(imageContainer)
        stack.addArrangedSubview(previewTitleLabel)
        stack.addArrangedSubview(previewDetailsStack)
        stack.addArrangedSubview(previewMessageLabel)
        stack.setCustomSpacing(8, after: previewTitleLabel)
        stack.setCustomSpacing(14, after: previewDetailsStack)

        // Every row spans the full content width so nothing can run past the pane's edge.
        for view in [imageContainer, previewTitleLabel!, previewDetailsStack!, previewMessageLabel!] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: pane.topAnchor),
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: previewInsetLeading),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -previewInsetTrailing),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: pane.bottomAnchor)
        ])

        return pane
    }

    /// Replaces the details list with label/value rows (Kind, Size, Modified…).
    private func setDetailRows(_ rows: [(String, String)]) {
        previewDetailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let valueWidth = max(1, floor(previewContentStack.bounds.width) - detailKeyWidth - detailColumnSpacing)
        for (key, value) in rows {
            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = .systemFont(ofSize: 12)
            keyLabel.textColor = .secondaryLabelColor
            keyLabel.lineBreakMode = .byTruncatingTail
            keyLabel.translatesAutoresizingMaskIntoConstraints = false
            keyLabel.widthAnchor.constraint(equalToConstant: detailKeyWidth).isActive = true

            let valueLabel = makeWrappingLabel(value, font: .systemFont(ofSize: 12), color: .labelColor, maxLines: 3)
            valueLabel.lineBreakMode = key == "Where" ? .byCharWrapping : .byWordWrapping
            valueLabel.isSelectable = true
            valueLabel.preferredMaxLayoutWidth = valueWidth

            let row = NSStackView(views: [keyLabel, valueLabel])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = detailColumnSpacing
            row.translatesAutoresizingMaskIntoConstraints = false
            previewDetailsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: previewDetailsStack.widthAnchor).isActive = true
        }
        previewDetailsStack.isHidden = rows.isEmpty
        previewPane.needsLayout = true
    }
    
    private func createPathBar() -> NSView {
        let bar = NSVisualEffectView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.material = .underPageBackground
        bar.blendingMode = .withinWindow
        bar.state = .active
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 6
        bar.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        
        pathControl = NSPathControl()
        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.pathStyle = .standard
        pathControl.focusRingType = .none
        pathControl.font = NSFont.systemFont(ofSize: 12)
        pathControl.isEnabled = true
        pathControl.isEditable = false
        bar.addSubview(pathControl)
        
        NSLayoutConstraint.activate([
            pathControl.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            pathControl.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            pathControl.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        
        return bar
    }
    
    
    // MARK: - Preview Loading
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check if directory
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                if values.isDirectory == false {
                    // Single file mode: a markdown / text file opened directly with Space.
                    DebugLogger.shared.log("Single file preview: \(url.lastPathComponent)")
                    let html = DocumentRenderer.html(forFileAt: url, style: .fullPage)
                    DispatchQueue.main.async {
                        self.applySingleFileLayout(true)
                        self.singleFileWebView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
                        handler(nil)
                    }
                    return
                }

                let start = CFAbsoluteTimeGetCurrent()
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                DebugLogger.shared.log("Enumerated \(contents.count) entries for \(url.lastPathComponent) in \(String(format: "%.1f", elapsed)) ms")
                
                let sortedContents = self.sortURLs(contents)
                var rootItems: [FileItem] = []
                var totalSize: Int64 = 0
                var folderCount = 0
                var fileCount = 0
                
                for entry in sortedContents.prefix(5000) {
                    let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey, .contentModificationDateKey])
                    let item = FileItem(url: entry, resourceValues: values)
                    if item.isFolder {
                        folderCount += 1
                    } else {
                        fileCount += 1
                        totalSize += item.size
                    }
                    rootItems.append(item)
                }
                self.sortFileItems(&rootItems)
                
                let infoText = "Measuring… · " + Self.countSummary(folders: folderCount, files: fileCount)
                
                DispatchQueue.main.async {
                    self.applySingleFileLayout(false)
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = NSSize(width: 48, height: 48)
                    DebugLogger.shared.log("Applying preview data for \(url.lastPathComponent). Diagnostics log: \(DebugLogger.shared.locationDescription())")
                    self.rootItems = rootItems
                    self.previewRootURL = url
                    self.rebuildVisibleRootItems()
                    self.iconImageView.image = icon
                    self.titleLabel.stringValue = url.lastPathComponent
                    self.infoLabel.stringValue = infoText
                    self.updateHeaderTotal(for: url, folderCount: folderCount, fileCount: fileCount)
                    self.outlineView.reloadData()
                    self.syncPreviewWithSelection()
                    handler(nil)
                }
            } catch {
                DebugLogger.shared.log("Failed to build preview for \(url.lastPathComponent): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    handler(error)
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func filterChanged(_ sender: NSSegmentedControl) {
        guard let type = FilterType(rawValue: sender.selectedSegment) else { return }
        
        // Early return if filter hasn't changed - avoid unnecessary work
        guard type != filterType else { return }
        
        DebugLogger.shared.log("Filter switched to \(type)")
        filterType = type
        rebuildVisibleRootItems()
        
        // Use targeted reload instead of full reloadData() - significantly faster
        // This reloads only the root level items rather than the entire table structure
        outlineView.reloadItem(nil, reloadChildren: true)
        
        syncPreviewWithSelection()
    }
    
    // MARK: - Helpers
    /// Kicks off (or reuses) a recursive size measurement for a folder row and
    /// refreshes just that row when the number lands.
    fileprivate func requestFolderSize(for item: FileItem) {
        guard item.isFolder, item.computedFolderSize == nil else { return }

        if let hit = FolderSizeCalculator.shared.cachedSize(for: item.url) {
            item.computedFolderSize = hit
            item.invalidateFormattedSize()
            reloadSizeCell(for: item)
            refreshDetails(for: item)
            return
        }

        guard !item.folderSizeRequested else { return }
        item.folderSizeRequested = true

        FolderSizeCalculator.shared.size(for: item.url) { [weak self, weak item] total in
            guard let self, let item else { return }
            item.computedFolderSize = total
            item.invalidateFormattedSize()
            self.reloadSizeCell(for: item)
            self.refreshDetails(for: item)
        }
    }

    private func reloadSizeCell(for item: FileItem) {
        let row = outlineView.row(forItem: item)
        guard row >= 0 else { return }
        let sizeColumn = outlineView.column(withIdentifier: NSUserInterfaceItemIdentifier("size"))
        guard sizeColumn >= 0 else { return }
        outlineView.reloadData(forRowIndexes: IndexSet(integer: row),
                               columnIndexes: IndexSet(integer: sizeColumn))
    }

    /// Recursively measures the previewed folder itself so the header shows a real total.
    fileprivate func updateHeaderTotal(for url: URL, folderCount: Int, fileCount: Int) {
        FolderSizeCalculator.shared.size(for: url) { [weak self] total in
            guard let self, self.previewRootURL == url else { return }
            self.infoLabel.stringValue = "\(self.byteFormatter.string(fromByteCount: total)) · " + Self.countSummary(folders: folderCount, files: fileCount)
        }
    }

    static func countSummary(folders: Int, files: Int) -> String {
        "\(folders) \(folders == 1 ? "folder" : "folders"), \(files) \(files == 1 ? "file" : "files")"
    }

    private func sortURLs(_ urls: [URL]) -> [URL] {
        let sorted = urls.sorted { lhs, rhs in
            let lhsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let rhsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if lhsDir != rhsDir {
                return lhsDir
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
        if let descriptor = currentSortDescriptor {
            return sorted.sorted { lhs, rhs in
                compareURLs(lhs, rhs, with: descriptor)
            }
        }
        return sorted
    }
    
    private func sortFileItems(_ items: inout [FileItem]) {
        guard !items.isEmpty else { return }
        let comparator = makeItemComparator()
        items.sort(by: comparator)
    }
    
    private func makeItemComparator() -> (FileItem, FileItem) -> Bool {
        if let descriptor = currentSortDescriptor {
            return { lhs, rhs in
                self.compareFileItems(lhs, rhs, with: descriptor)
            }
        }
        return { lhs, rhs in
            self.defaultItemComparator(lhs, rhs)
        }
    }
    
    private func compareFileItems(_ lhs: FileItem, _ rhs: FileItem, with descriptor: NSSortDescriptor) -> Bool {
        let ascending = descriptor.ascending
        switch descriptor.key ?? "name" {
        case "date":
            if lhs.modificationDate == rhs.modificationDate {
                return defaultItemComparator(lhs, rhs)
            }
            return ascending ? lhs.modificationDate < rhs.modificationDate : lhs.modificationDate > rhs.modificationDate
        case "size":
            if lhs.effectiveSize == rhs.effectiveSize {
                return defaultItemComparator(lhs, rhs)
            }
            return ascending ? lhs.effectiveSize < rhs.effectiveSize : lhs.effectiveSize > rhs.effectiveSize
        case "kind":
            if lhs.kindDescription == rhs.kindDescription {
                return defaultItemComparator(lhs, rhs)
            }
            return ascending ? lhs.kindDescription < rhs.kindDescription : lhs.kindDescription > rhs.kindDescription
        case "name":
            fallthrough
        default:
            if lhs.name == rhs.name {
                return defaultItemComparator(lhs, rhs)
            }
            if ascending {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            } else {
                return rhs.name.localizedStandardCompare(lhs.name) == .orderedAscending
            }
        }
    }
    
    private func defaultItemComparator(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        if lhs.isFolder != rhs.isFolder {
            return lhs.isFolder && !rhs.isFolder
        }
        return lhs.name.localizedStandardCompare(rhs.name) != .orderedDescending
    }
    
    private func resortDescendants(from items: [FileItem]) {
        guard !items.isEmpty else { return }
        let comparator = makeItemComparator()
        resortDescendants(items, comparator: comparator)
    }
    
    private func resortDescendants(_ items: [FileItem], comparator: @escaping (FileItem, FileItem) -> Bool) {
        for item in items {
            if var children = item.children {
                children.sort(by: comparator)
                item.children = children
                resortDescendants(children, comparator: comparator)
            }
        }
    }
    
    private func compareURLs(_ lhs: URL, _ rhs: URL, with descriptor: NSSortDescriptor) -> Bool {
        let key = descriptor.key ?? "name"
        let ascending = descriptor.ascending
        switch key {
        case "name":
            return ascending ?
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending :
                rhs.lastPathComponent.localizedStandardCompare(lhs.lastPathComponent) == .orderedAscending
        case "date":
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        case "size":
            let lhsSize = Int64((try? lhs.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            let rhsSize = Int64((try? rhs.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            return ascending ? lhsSize < rhsSize : lhsSize > rhsSize
        case "kind":
            let lhsType = (try? lhs.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.localizedDescription ?? ""
            let rhsType = (try? rhs.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.localizedDescription ?? ""
            return ascending ? lhsType < rhsType : lhsType > rhsType
        default:
            return true
        }
    }
    
    private func rebuildVisibleRootItems() {
        if filterType == .all {
            visibleRootItems = rootItems
            return
        }
        visibleRootItems = filterItems(rootItems)
    }
    
    private func children(of item: FileItem?) -> [FileItem] {
        if let item {
            guard let children = item.children else { return [] }
            return filterItems(children)
        }
        return visibleRootItems
    }
    
    private func filterItems(_ items: [FileItem]) -> [FileItem] {
        items.filter { item in
            filterType.matches(item)
        }
    }
    
    // Path bar update (commented out - path bar not displayed)
    // private func updatePreviewPath(for item: FileItem?) {
    //     guard let referenceRoot = previewRootURL ?? item?.url else {
    //         pathControl.url = nil
    //         return
    //     }
    //     let target = item?.url ?? referenceRoot
    //     pathControl.url = target
    // }
    
    private func syncPreviewWithSelection() {
        // Cancel any pending preview update
        previewUpdateWorkItem?.cancel()
        
        // Minimal debounce (10ms) - just enough to prevent rapid-fire updates
        // but imperceptible to users for single clicks
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.updatePreview(for: self.selectedItems.last)
        }
        previewUpdateWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: workItem)
    }
    
    private func updatePreview(for item: FileItem?) {
        previewImageLoadTask?.cancel()
        previewImageLoadTask = nil
        if let request = previewThumbnailRequest {
            QLThumbnailGenerator.shared.cancel(request)
            previewThumbnailRequest = nil
        }
        previewSpinner.stopAnimation(nil)
        
        previewImageView.image = nil
        previewedItem = item
        
        guard let item else {
            previewImageView.superview?.isHidden = true
            previewTitleLabel.stringValue = "No Selection"
            setDetailRows([])
            previewMessageLabel.stringValue = "Select a file or folder to see its preview and details."
            previewMessageLabel.isHidden = false
            return
        }
        
        previewImageView.superview?.isHidden = false
        previewTitleLabel.stringValue = item.name
        refreshDetails(for: item)
        previewMessageLabel.isHidden = true
        loadExtraDetails(for: item)
        
        if item.isImage {
            webView.isHidden = true
            previewImageView.isHidden = false
            loadPreviewImage(for: item)
        } else if item.isText {
            previewImageView.isHidden = true
            webView.isHidden = false
            loadMarkdownPreview(for: item)
        } else {
            webView.isHidden = true
            previewImageView.isHidden = false
            if item.isFolder {
                requestFolderSize(for: item)
                loadLargeIcon(for: item) { [weak self] icon in
                    guard let self, self.previewedItem === item else { return }
                    self.showPreviewIcon(icon)
                }
            } else {
                loadThumbnail(for: item)
            }
        }
    }

    /// Rebuilds the details list from what the item currently knows.
    private func refreshDetails(for item: FileItem) {
        guard previewedItem === item else { return }
        setDetailRows(item.detailRows(sizeFormatter: byteFormatter, dateFormatter: dateFormatter, root: previewRootURL))
        updatePreviewWrapWidths()
    }

    /// Fetches the details that cost a disk read (created date, folder item count) off the main thread.
    private func loadExtraDetails(for item: FileItem) {
        let needsCount = item.isFolder && item.itemCount == nil
        guard item.creationDate == nil || needsCount else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let created = (try? item.url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            var count: Int?
            if needsCount {
                if item.childrenLoaded, let children = item.children {
                    count = children.count
                } else {
                    count = (try? FileManager.default.contentsOfDirectory(atPath: item.url.path))?
                        .filter { !$0.hasPrefix(".") }.count
                }
            }
            DispatchQueue.main.async {
                if let created { item.creationDate = created }
                if let count { item.itemCount = count }
                self?.refreshDetails(for: item)
            }
        }
    }

    /// Real Quick Look thumbnail for videos, PDFs, documents…; falls back to the file icon.
    private func loadThumbnail(for item: FileItem) {
        previewSpinner.startAnimation(nil)
        let size = previewImageView.bounds.size
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: max(size.width, 160), height: max(size.height, 120)),
            scale: view.window?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        previewThumbnailRequest = request
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                guard let self, self.previewedItem === item else { return }
                self.previewThumbnailRequest = nil
                self.previewSpinner.stopAnimation(nil)
                if let image = representation?.nsImage {
                    self.previewImageView.imageScaling = .scaleProportionallyUpOrDown
                    self.previewImageView.image = image
                } else {
                    self.loadLargeIcon(for: item) { [weak self] icon in
                        guard let self, self.previewedItem === item else { return }
                        self.showPreviewIcon(icon)
                    }
                }
            }
        }
    }

    /// File/folder icons sit at a fixed, comfortable size instead of filling the backdrop.
    private func showPreviewIcon(_ icon: NSImage) {
        previewImageView.imageScaling = .scaleProportionallyDown
        icon.size = NSSize(width: 128, height: 128)
        previewImageView.image = icon
    }

    private func applySingleFileLayout(_ enabled: Bool) {
        singleFileMode = enabled
        mainStack.isHidden = enabled
        singleFileWebView.isHidden = !enabled
    }
    
    private func loadMarkdownPreview(for item: FileItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            let html = DocumentRenderer.html(forFileAt: item.url, style: .pane)
            DispatchQueue.main.async {
                guard self.previewedItem === item else { return }
                self.webView.loadHTMLString(html, baseURL: item.url.deletingLastPathComponent())
            }
        }
    }

    /// Web views only ever show rendered markdown/text, never run scripts from the file.
    private func makeDocumentWebConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return config
    }
    
    private func loadPreviewImage(for item: FileItem) {
        previewSpinner.startAnimation(nil)
        let fileURL = item.url as NSURL
        // Decode a screen-sized version instead of the full image, so a 50 MP photo stays instant.
        let maxPixel = max(previewImageView.bounds.width, previewImageView.bounds.height) * (view.window?.backingScaleFactor ?? 2)
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let source = CGImageSourceCreateWithURL(fileURL, nil)
            var pixelSize: CGSize?
            if let source,
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let width = props[kCGImagePropertyPixelWidth] as? Int,
               let height = props[kCGImagePropertyPixelHeight] as? Int {
                let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
                pixelSize = orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(Int(maxPixel), 512)
            ]
            let cgImage = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.previewedItem === item else { return }
                self.previewSpinner.stopAnimation(nil)
                if let pixelSize, item.pixelSize == nil {
                    item.pixelSize = pixelSize
                    self.refreshDetails(for: item)
                }
                if let cgImage {
                    self.previewImageView.imageScaling = .scaleProportionallyUpOrDown
                    self.previewImageView.image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                } else {
                    DebugLogger.shared.log("Image decode failed for \(item.url.path)")
                    self.previewMessageLabel.stringValue = "Could not load this image."
                    self.previewMessageLabel.isHidden = false
                    self.loadLargeIcon(for: item) { [weak self] icon in
                        guard let self, self.previewedItem === item else { return }
                        self.showPreviewIcon(icon)
                    }
                }
                self.previewImageLoadTask = nil
            }
        }
        previewImageLoadTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }
    
    private var selectedItems: [FileItem] {
        outlineView.selectedRowIndexes.compactMap { outlineView.item(atRow: $0) as? FileItem }
    }
    
    private func actionURLs() -> [URL] {
        let selection = selectedItems.map { $0.url }
        if !selection.isEmpty { return selection }
        if let previewedItem {
            return [previewedItem.url]
        }
        return []
    }
    
    @objc private func copyPathAction() {
        let urls = actionURLs().map { $0.path }
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSString])
    }
    
    private func showQuickLook() {
        guard QLPreviewPanel.shared()?.isVisible == false else {
            QLPreviewPanel.shared()?.reloadData()
            return
        }
        guard let panel = QLPreviewPanel.shared(), !selectedItems.isEmpty else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(self)
    }
    
    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu(title: "Actions")
        menu.addItem(withTitle: "Copy Path", action: #selector(copyPathAction), keyEquivalent: "")
        return menu
    }()
    
    
    private func loadChildren(for item: FileItem, completion: @escaping () -> Void) {
        if item.childrenLoaded {
            completion()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()
                let contents = try FileManager.default.contentsOfDirectory(
                    at: item.url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                let sorted = self.sortURLs(contents)
                var children: [FileItem] = []
                for entry in sorted.prefix(5000) {
                    let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey, .contentModificationDateKey])
                    children.append(FileItem(url: entry, resourceValues: values, parent: item))
                }
                self.sortFileItems(&children)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                DispatchQueue.main.async {
                    DebugLogger.shared.log("Loaded \(children.count) children for \(item.name) in \(String(format: "%.1f", elapsed)) ms")
                    item.setChildren(children)
                    completion()
                }
            } catch {
                DispatchQueue.main.async {
                    DebugLogger.shared.log("Failed to load children for \(item.name): \(error.localizedDescription)")
                    item.setChildren([])
                    completion()
                }
            }
        }
    }
    
    private func loadIcon(for item: FileItem, completion: @escaping (NSImage) -> Void) {
        // First check if item already has icon cached
        if let icon = item.icon {
            completion(icon)
            return
        }
        
        let path = item.url.path
        let cacheKey = path as NSString
        
        // Check NSCache
        if let cached = iconCache.object(forKey: cacheKey) {
            item.icon = cached
            completion(cached)
            return
        }
        
        // Load icon on background thread to avoid blocking UI
        iconLoadQueue.async { [weak self] in
            guard let self = self else { return }
            
            // NSWorkspace.shared.icon is thread-safe and can be called from background
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            
            // Cache the icon
            self.iconCache.setObject(icon, forKey: cacheKey)
            item.icon = icon
            
            // Update UI on main thread
            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }
    
    private func loadLargeIcon(for item: FileItem, completion: @escaping (NSImage) -> Void) {
        let path = item.url.path
        let cacheKey = "\(path)-large" as NSString
        
        // Check cache for large icon
        if let cached = iconCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }
        
        // Load large icon on background thread
        iconLoadQueue.async { [weak self] in
            guard let self = self else { return }
            
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 128, height: 128)
            
            // Cache the large icon
            self.iconCache.setObject(icon, forKey: cacheKey)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }
}

// MARK: - NSOutlineViewDataSource
extension PreviewViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return children(of: item as? FileItem).count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return children(of: item as? FileItem)[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fileItem = item as? FileItem else { return false }
        return fileItem.isFolder
    }
}

// MARK: - NSOutlineViewDelegate
extension PreviewViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem,
              let identifier = tableColumn?.identifier else { return nil }
        let reuseIdentifier = NSUserInterfaceItemIdentifier("cell-\(identifier.rawValue)")
        let cellView: NSTableCellView
        
        if let existing = outlineView.makeView(withIdentifier: reuseIdentifier, owner: self) as? NSTableCellView {
            cellView = existing
        } else {
            cellView = NSTableCellView()
            cellView.identifier = reuseIdentifier
            let stackView = NSStackView()
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.orientation = .horizontal
            stackView.alignment = .centerY
            stackView.spacing = 6
            cellView.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 6),
                stackView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -6),
                stackView.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 2),
                stackView.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -2)
            ])
            if identifier.rawValue == "name" {
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyDown
                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16)
                ])
                stackView.addArrangedSubview(imageView)
                cellView.imageView = imageView
            }
            let alignment: NSTextAlignment = identifier.rawValue == "size" ? .right : .left
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = .labelColor
            textField.lineBreakMode = .byTruncatingTail
            textField.alignment = alignment
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            textField.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(textField)
            cellView.textField = textField
        }
        
        switch identifier.rawValue {
        case "name":
            cellView.textField?.stringValue = fileItem.name
            loadIcon(for: fileItem) { icon in
                cellView.imageView?.image = icon
            }
        case "date":
            // Use cached formatted date to avoid repeated formatting
            cellView.textField?.stringValue = fileItem.formattedDate(using: dateFormatter)
        case "size":
            // Use cached formatted size to avoid repeated formatting
            cellView.textField?.stringValue = fileItem.formattedSize(using: byteFormatter)
            requestFolderSize(for: fileItem)
        case "kind":
            cellView.textField?.stringValue = fileItem.kindDescription
        default:
            cellView.textField?.stringValue = ""
        }
        return cellView
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        currentSortDescriptor = outlineView.sortDescriptors.first
        
        // Move sorting to background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.sortFileItems(&self.rootItems)
            self.resortDescendants(from: self.rootItems)
            
            DispatchQueue.main.async {
                self.rebuildVisibleRootItems()
                // Use targeted reload instead of full reloadData()
                self.outlineView.reloadItem(nil, reloadChildren: true)
            }
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        guard let fileItem = item as? FileItem else { return false }
        loadChildren(for: fileItem) {
            outlineView.reloadItem(fileItem, reloadChildren: true)
        }
        return true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard notification.object as? NSOutlineView === outlineView else { return }
        // Removed logging here to reduce overhead on every selection change
        syncPreviewWithSelection()
    }
}

// MARK: - Keyboard & Menu Handling
extension PreviewViewController {
}

extension PreviewViewController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let location = outlineView.convert(outlineView.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        let row = outlineView.row(at: location)
        if row >= 0 && !outlineView.isRowSelected(row) {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        let hasSelection = !selectedItems.isEmpty
        menu.items.forEach { $0.isEnabled = hasSelection }
    }
}

// MARK: - Quick Look Panel
extension PreviewViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        selectedItems.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        selectedItems[index]
    }
}

// MARK: - Web Navigation
extension PreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DebugLogger.shared.log("Web: finished loading (single=\(webView === singleFileWebView)) frame=\(webView.frame) hidden=\(webView.isHidden)")
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.takeSnapshot(with: nil) { image, error in
                guard let image, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                    DebugLogger.shared.log("Web: snapshot failed \(String(describing: error))")
                    return
                }
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("web-snapshot.png")
                try? png.write(to: url)
                DebugLogger.shared.log("Web: snapshot saved \(url.path)")
            }
        }
        #endif
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DebugLogger.shared.log("Web: failed \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DebugLogger.shared.log("Web: failed provisional \(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DebugLogger.shared.log("Web: content process terminated, reloading")
        webView.reload()
    }
}

// MARK: - Outline Keyboard Delegate
extension PreviewViewController: FinderOutlineViewKeyboardDelegate {
    func outlineView(_ outlineView: FinderOutlineView, handle event: NSEvent) -> Bool {
        let commandPressed = event.modifierFlags.contains(.command)
        switch (event.keyCode, commandPressed) {
        case (49, false): // Space
            showQuickLook()
            return true
        case (_, true) where event.charactersIgnoringModifiers == "c":
            copyPathAction()
            return true
        default:
            return false
        }
    }
}

#if RIFFLE_HARNESS
// Hooks for scripts/harness — renders the real view controller offscreen for layout checks.
extension PreviewViewController {
    var harnessRowCount: Int { outlineView.numberOfRows }
    func harnessRowName(_ row: Int) -> String { (outlineView.item(atRow: row) as? FileItem)?.name ?? "" }
    func harnessSelect(row: Int) { outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
    func harnessFrames() -> String {
        "row=\(contentRow.frame.width) list=\(scrollView.frame.width) pane=\(previewPane.frame.width) " +
        "content=\(previewContentStack.frame) title=\(previewTitleLabel.frame) details=\(previewDetailsStack.frame) " +
        "columns=\(outlineView.tableColumns.map { "\($0.title):\(Int($0.width))" })"
    }
    func harnessDrag(_ delta: CGFloat) -> String {
        dragDivider(by: delta)
        return "after drag(\(delta)): list=\(scrollView.frame.width) pane=\(previewPane.frame.width)"
    }
}
#endif

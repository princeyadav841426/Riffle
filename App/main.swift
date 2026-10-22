// Riffle — folder preview for macOS Quick Look
// Copyright © 2026 Aignix. MIT License.
//
// The app itself is only a welcome window: it registers the Quick Look extension that ships
// inside it, tells the user whether the extension is on, and explains how to use it.

import Cocoa

private let extensionID = "com.aignix.riffle.preview"
private let legacyExtensionIDs = ["altic.PeekX.PeekXExt", "local.peekxplus.Ext"]
private let repoURL = URL(string: "https://github.com/princeyadav841426/Riffle")!

@discardableResult
private func run(_ tool: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do { try process.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

/// pluginkit marks a user-disabled extension with a leading "-".
private func extensionState(_ identifier: String) -> (installed: Bool, enabled: Bool) {
    let line = run("/usr/bin/pluginkit", ["-m", "-i", identifier])
        .split(separator: "\n")
        .first { $0.contains(identifier) }
    guard let line else { return (false, false) }
    return (true, !line.trimmingCharacters(in: .whitespaces).hasPrefix("-"))
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Setting up Quick Look…")
    private let conflictLabel = NSTextField(wrappingLabelWithString: "")
    private var conflictRow: NSStackView!
    private var conflictAppURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        #if RIFFLE_SNAPSHOT
        // scripts: render the welcome window to a PNG and exit (layout check without screen capture).
        showStatus(ok: true, "Riffle is on. Select any folder in Finder and press Space.")
        conflictLabel.stringValue = "PeekX is also installed and may answer folder previews instead of Riffle. Move PeekX to the Trash."
        conflictRow.isHidden = CommandLine.arguments.count < 3
        window.appearance = NSAppearance(named: .darkAqua)
        window.layoutIfNeeded()
        if let view = window.contentView?.superview, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        exit(0)
        #endif
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setUpExtension()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Extension registration

    private var isRunningFromDiskImage: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
    }

    private func setUpExtension() {
        if isRunningFromDiskImage {
            showStatus(ok: false, "Drag Riffle into your Applications folder first, then open it from there.")
            return
        }
        let appexPath = Bundle.main.builtInPlugInsURL?.appendingPathComponent("RiffleExt.appex").path
        DispatchQueue.global(qos: .userInitiated).async {
            if let appexPath { run("/usr/bin/pluginkit", ["-a", appexPath]) }
            run("/usr/bin/pluginkit", ["-e", "use", "-i", extensionID])
            run("/usr/bin/qlmanage", ["-r"])
            run("/usr/bin/qlmanage", ["-r", "cache"])
            Thread.sleep(forTimeInterval: 1.0)
            DispatchQueue.main.async { self.refreshStatus() }
        }
    }

    private func refreshStatus() {
        let state = extensionState(extensionID)
        if state.installed && state.enabled {
            showStatus(ok: true, "Riffle is on. Select any folder in Finder and press Space.")
        } else if state.installed {
            showStatus(ok: false, "Riffle is turned off. Open Extension Settings and switch on Riffle under Quick Look.")
        } else {
            showStatus(ok: false, "macOS hasn't picked up Riffle yet. Quit and reopen Riffle, or log out and back in.")
        }

        let legacy = legacyExtensionIDs.first { extensionState($0).enabled }
        conflictAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "altic.PeekX")
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "local.peekxplus")
        if legacy != nil {
            conflictLabel.stringValue = "PeekX is also installed and may answer folder previews instead of Riffle. Move PeekX to the Trash."
            conflictRow.isHidden = false
        }
    }

    private func showStatus(ok: Bool, _ text: String) {
        let symbol = ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        statusIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        statusIcon.contentTintColor = ok ? .systemGreen : .systemOrange
        statusLabel.stringValue = text
    }

    // MARK: Actions

    @objc private func openExtensionSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    @objc private func revealConflictingApp() {
        guard let url = conflictAppURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(repoURL)
    }

    @objc private func done() {
        NSApp.terminate(nil)
    }

    // MARK: Window

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        field.isSelectable = false
        return field
    }

    private func step(_ number: Int, _ text: String) -> NSView {
        let badge = NSImageView(image: NSImage(systemSymbolName: "\(number).circle.fill", accessibilityDescription: "Step \(number)") ?? NSImage())
        badge.symbolConfiguration = .init(pointSize: 18, weight: .semibold)
        badge.contentTintColor = .controlAccentColor
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let body = NSTextField(wrappingLabelWithString: text)
        body.font = .systemFont(ofSize: 13)
        body.isSelectable = false
        let row = NSStackView(views: [badge, body])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                          styleMask: [.titled, .closable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalToConstant: 96)
        ])

        let title = label("Riffle", size: 26, weight: .bold)
        let subtitle = label("See what's inside any folder without opening it.", size: 13, color: .secondaryLabelColor)

        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        statusIcon.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)
        statusIcon.contentTintColor = .secondaryLabelColor
        statusIcon.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.isSelectable = false
        let statusRow = NSStackView(views: [statusIcon, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .firstBaseline
        statusRow.spacing = 8

        let steps = NSStackView(views: [
            step(1, "Select any folder in Finder."),
            step(2, "Press Space — the whole folder opens in Quick Look."),
            step(3, "Click a file for its preview and details. Drag the divider to resize.")
        ])
        steps.orientation = .vertical
        steps.alignment = .leading
        steps.spacing = 10

        conflictLabel.font = .systemFont(ofSize: 12)
        conflictLabel.textColor = .secondaryLabelColor
        conflictLabel.isSelectable = false
        let revealButton = NSButton(title: "Show PeekX", target: self, action: #selector(revealConflictingApp))
        revealButton.controlSize = .small
        conflictLabel.alignment = .center
        conflictRow = NSStackView(views: [conflictLabel, revealButton])
        conflictRow.orientation = .vertical
        conflictRow.alignment = .centerX
        conflictRow.spacing = 8
        conflictRow.isHidden = true

        let settingsButton = NSButton(title: "Extension Settings…", target: self, action: #selector(openExtensionSettings))
        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [settingsButton, doneButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let footer = NSButton(title: "Free & open source — made by Aignix", target: self, action: #selector(openRepository))
        footer.isBordered = false
        footer.font = .systemFont(ofSize: 11)
        footer.contentTintColor = .tertiaryLabelColor

        let stack = NSStackView(views: [icon, title, subtitle, statusRow, steps, conflictRow, buttons, footer])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.detachesHiddenViews = true
        stack.setCustomSpacing(6, after: title)
        stack.setCustomSpacing(22, after: subtitle)
        stack.setCustomSpacing(22, after: statusRow)
        stack.setCustomSpacing(22, after: steps)
        stack.edgeInsets = NSEdgeInsets(top: 44, left: 36, bottom: 22, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 460)
        ])
        for view in [subtitle, statusRow, steps, conflictRow!] {
            view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -72).isActive = true
        }
        for field in [subtitle, statusLabel, conflictLabel] {
            field.preferredMaxLayoutWidth = 360
        }
        for case let row as NSStackView in steps.arrangedSubviews {
            (row.arrangedSubviews.last as? NSTextField)?.preferredMaxLayoutWidth = 330
        }
        window.contentView = content
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.regular)

// Minimal main menu so ⌘Q and ⌘W work.
let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "About Riffle", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
appMenu.addItem(.separator())
appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
appMenu.addItem(withTitle: "Quit Riffle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
NSApplication.shared.mainMenu = mainMenu

NSApplication.shared.run()

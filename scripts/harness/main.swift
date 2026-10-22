// Offscreen layout check: renders the real PreviewViewController for a folder at a given
// window size, selects rows, and writes PNG snapshots. Built by scripts/harness.sh.
import Cocoa

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: harness <folder> <out-prefix> [width] [height] [rows,comma,separated]")
    exit(2)
}
let folder = URL(fileURLWithPath: args[1])
let outPrefix = args[2]
let width = args.count > 3 ? Double(args[3]) ?? 808 : 808
let height = args.count > 4 ? Double(args[4]) ?? 560 : 560
let rows = args.count > 5 ? args[5].split(separator: ",").compactMap { Int($0) } : [-1]

let light = ProcessInfo.processInfo.environment["HARNESS_LIGHT"] != nil
_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

func pump(_ seconds: Double) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
}

func snapshot(_ view: NSView, to path: String) {
    // cacheDisplay skips the window's own background, so paint one under the content.
    view.wantsLayer = true
    view.layer?.backgroundColor = light ? NSColor(calibratedWhite: 0.955, alpha: 1).cgColor
                                        : NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}

let controller = PreviewViewController()
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                      styleMask: [.titled, .resizable], backing: .buffered, defer: false)
window.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
window.contentViewController = controller
window.setContentSize(NSSize(width: width, height: height))
if ProcessInfo.processInfo.environment["HARNESS_ONSCREEN"] != nil { window.setFrameOrigin(NSPoint(x: -4000, y: 0)); window.orderFrontRegardless() }

var loaded = false
controller.preparePreviewOfFile(at: folder) { error in
    if let error { print("prepare error: \(error)") }
    loaded = true
}
while !loaded { pump(0.05) }
pump(1.0)

if ProcessInfo.processInfo.environment["HARNESS_DRAG"] != nil { print(controller.harnessDrag(-120)); print(controller.harnessDrag(400)) }
print("rows: \((0..<min(controller.harnessRowCount, 30)).map { "\($0)=\(controller.harnessRowName($0))" }.joined(separator: " | "))")
for row in rows {
    if row >= 0 { controller.harnessSelect(row: row) }
    pump(2.0)
    let path = "\(outPrefix)_\(row < 0 ? "none" : String(row)).png"
    snapshot(window.contentView!, to: path)
    print("row \(row) -> \(path)\n  \(controller.harnessFrames())")
}

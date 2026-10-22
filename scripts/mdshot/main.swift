// Renders a markdown file through DocumentRenderer into an offscreen WKWebView and saves a 2x PNG.
// Usage (built by scripts/mdshot.sh): mdshot <file.md> <out.png> [width] [height]
import Cocoa
import WebKit

let args = CommandLine.arguments
let file = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let width = args.count > 3 ? Double(args[3]) ?? 820 : 820
let height = args.count > 4 ? Double(args[4]) ?? 560 : 560

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)
let window = NSWindow(contentRect: NSRect(x: -4000, y: 0, width: width, height: height),
                      styleMask: [.borderless], backing: .buffered, defer: false)
let appearance = NSAppearance(named: ProcessInfo.processInfo.environment["MDSHOT_DARK"] != nil ? .darkAqua : .aqua)
window.appearance = appearance
let config = WKWebViewConfiguration()
config.defaultWebpagePreferences.allowsContentJavaScript = false
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
web.appearance = appearance
window.contentView = web
window.orderFrontRegardless()
web.loadHTMLString(DocumentRenderer.html(forFileAt: file, style: .fullPage), baseURL: nil)

var done = false
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    let snap = WKSnapshotConfiguration()
    snap.snapshotWidth = NSNumber(value: width * 2)
    web.takeSnapshot(with: snap) { image, _ in
        if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: out)
        }
        done = true
    }
}
while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

// Draws the README poster (1280×640, also the right size for GitHub's social preview).
// Usage: swift make_banner.swift <light|dark> <icon.png> <screenshot.png> <out.png>
import AppKit

let a = CommandLine.arguments
let dark = a[1] == "dark"
let W: CGFloat = 1280, H: CGFloat = 640

func rgb(_ h: UInt32, _ al: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: al)
}
// Light = Moodwall's canvas and ink; dark = GitHub's dark theme, so the poster sits flush on either.
let ground = dark ? rgb(0x0D1117) : rgb(0xF6F6F6)
let ink = dark ? rgb(0xE6EDF3) : rgb(0x1D1D1C)
let muted = dark ? rgb(0x8B949E) : rgb(0x8C8C86)
let accent = dark ? rgb(0x58A6FF) : rgb(0x2F6FE4)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
ground.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

// Product screenshot on the right, running off the edge.
if let shot = NSImage(contentsOfFile: a[3]) {
    let width: CGFloat = 800
    let frame = NSRect(x: 590, y: (H - width * shot.size.height / shot.size.width) / 2, width: width, height: width * shot.size.height / shot.size.width)
    let clip = NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0x000000, dark ? 0.5 : 0.14)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set(); ground.setFill(); clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState(); clip.addClip(); shot.draw(in: frame); NSGraphicsContext.restoreGraphicsState()
    (dark ? rgb(0xFFFFFF, 0.1) : rgb(0x000000, 0.08)).setStroke(); clip.lineWidth = 1.5; clip.stroke()
}

if let icon = NSImage(contentsOfFile: a[2]) { icon.draw(in: NSRect(x: 66, y: 418, width: 132, height: 132)) }
func text(_ s: String, _ f: NSFont, _ c: NSColor, _ x: CGFloat, _ y: CGFloat, kern: CGFloat = 0) {
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern])
        .draw(with: NSRect(x: x, y: y, width: 520, height: 0), options: [.usesLineFragmentOrigin])
}
text("Riffle", .systemFont(ofSize: 82, weight: .bold), ink, 70, 318, kern: -2.5)
text("See what's inside any folder", .systemFont(ofSize: 32, weight: .semibold), ink, 74, 252, kern: -0.6)
text("without opening it.", .systemFont(ofSize: 32, weight: .semibold), muted, 74, 210, kern: -0.6)
text("Press Space on a folder in Finder.", .systemFont(ofSize: 21, weight: .regular), muted, 74, 150)
text("Free  ·  Open source  ·  macOS 14+", .systemFont(ofSize: 21, weight: .semibold), accent, 74, 76)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[4]))
print("wrote \(a[4])")

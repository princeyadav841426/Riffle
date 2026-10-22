// Draws the 1200×630 social share image. Usage: swift tools-og.swift <icon.png> <screenshot.png> <out.png>
import AppKit
let a = CommandLine.arguments
let W: CGFloat = 1200, H: CGFloat = 630
func rgb(_ h: UInt32, _ al: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: al)
}
func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont(name: "Inter", size: size) ?? .systemFont(ofSize: size, weight: weight)
    let d = base.fontDescriptor.addingAttributes([.traits: [NSFontDescriptor.TraitKey.weight: weight]])
    return NSFont(descriptor: d, size: size) ?? base
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
rgb(0xF6F6F6).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

// Screenshot, bleeding off the right edge.
if let shot = NSImage(contentsOfFile: a[2]) {
    let frame = NSRect(x: 600, y: 70, width: 760, height: 760 * shot.size.height / shot.size.width)
    let clip = NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = rgb(0x000000, 0.14); shadow.shadowBlurRadius = 40; shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set(); rgb(0xFFFFFF).setFill(); clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState(); clip.addClip(); shot.draw(in: frame); NSGraphicsContext.restoreGraphicsState()
    rgb(0x000000, 0.08).setStroke(); clip.lineWidth = 1.5; clip.stroke()
}

if let icon = NSImage(contentsOfFile: a[1]) { icon.draw(in: NSRect(x: 58, y: 420, width: 140, height: 140)) }
func text(_ s: String, _ f: NSFont, _ c: NSColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, kern: CGFloat = 0) {
    let p = NSMutableParagraphStyle(); p.lineSpacing = 4
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern, .paragraphStyle: p])
        .draw(with: NSRect(x: x, y: y, width: w, height: 0), options: [.usesLineFragmentOrigin])
}
// With height 0 the string draws upward from y (its first baseline sits near y).
text("Riffle", .systemFont(ofSize: 80, weight: .bold), rgb(0x1D1D1C), 70, 330, 520, kern: -2.5)
text("See what's inside any folder", .systemFont(ofSize: 34, weight: .semibold), rgb(0x1D1D1C), 72, 262, 520, kern: -0.6)
text("without opening it.", .systemFont(ofSize: 34, weight: .semibold), rgb(0x8C8C86), 72, 218, 520, kern: -0.6)
text("Free for Mac  ·  riffle.aignix.online", .systemFont(ofSize: 22, weight: .medium), rgb(0x2F6FE4), 72, 78, 560, kern: 0)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))

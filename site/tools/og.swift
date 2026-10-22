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
rgb(0x05070D).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
let glow = NSGradient(colors: [rgb(0x208ADF, 0.28), rgb(0x208ADF, 0)])!
glow.draw(fromCenter: NSPoint(x: 880, y: 300), radius: 0, toCenter: NSPoint(x: 880, y: 300), radius: 520, options: [])

// Screenshot, bleeding off the right edge.
if let shot = NSImage(contentsOfFile: a[2]) {
    let frame = NSRect(x: 600, y: 70, width: 760, height: 760 * shot.size.height / shot.size.width)
    let clip = NSBezierPath(roundedRect: frame, xRadius: 18, yRadius: 18)
    NSGraphicsContext.saveGraphicsState(); clip.addClip(); shot.draw(in: frame); NSGraphicsContext.restoreGraphicsState()
    rgb(0x208ADF, 0.45).setStroke(); clip.lineWidth = 2; clip.stroke()
}
// Fade the screenshot into the ground on its left edge.
NSGradient(colors: [rgb(0x05070D), rgb(0x05070D, 0)])!.draw(in: NSRect(x: 560, y: 0, width: 120, height: H), angle: 0)

if let icon = NSImage(contentsOfFile: a[1]) { icon.draw(in: NSRect(x: 58, y: 420, width: 140, height: 140)) }
func text(_ s: String, _ f: NSFont, _ c: NSColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, kern: CGFloat = 0) {
    let p = NSMutableParagraphStyle(); p.lineSpacing = 4
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern, .paragraphStyle: p])
        .draw(with: NSRect(x: x, y: y, width: w, height: 0), options: [.usesLineFragmentOrigin])
}
// With height 0 the string draws upward from y (its first baseline sits near y).
text("Riffle", .systemFont(ofSize: 80, weight: .bold), rgb(0xF8FAFC), 70, 330, 520, kern: -2.5)
text("See what's inside any folder", .systemFont(ofSize: 34, weight: .semibold), rgb(0xF8FAFC), 72, 262, 520, kern: -0.6)
text("without opening it.", .systemFont(ofSize: 34, weight: .semibold), rgb(0x94A3B8), 72, 218, 520, kern: -0.6)
text("FREE FOR MAC  ·  RIFFLE.AIGNIX.ONLINE", NSFont.monospacedSystemFont(ofSize: 17, weight: .medium), rgb(0x55A9F0), 72, 74, 560, kern: 2.5)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))

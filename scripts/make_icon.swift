// Draws Riffle's app icon (1024×1024 PNG): a stack of cards fanned out like a riffled deck,
// the front card showing a folder tab and a short file list. Usage: swift make_icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Squircle tile on Apple's icon grid (824pt tile inside a 1024 canvas).
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(color(0x1B1E3C))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let background = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                            colors: [color(0x2A2F6B), color(0x14162F)] as CFArray,
                            locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
// Soft warm glow behind the cards.
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                      colors: [color(0xFF7A45, 0.42), color(0xFF7A45, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 470), endRadius: 420, options: [])
ctx.restoreGState()

// Cards fan out from a pivot below the tile, like a riffled deck.
let pivot = CGPoint(x: 512, y: 150)
let card = CGRect(x: -165, y: 150, width: 330, height: 420)

func drawCard(angle: CGFloat, fill: CGColor, shadow: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: pivot.x, y: pivot.y)
    ctx.rotate(by: angle * .pi / 180)
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: color(0x000000, shadow))
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.restoreGState()
}

drawCard(angle: 22, fill: color(0x8F96D8), shadow: 0.25)
drawCard(angle: -22, fill: color(0x8F96D8), shadow: 0.25)
drawCard(angle: 11, fill: color(0xC3C8F2), shadow: 0.3)
drawCard(angle: -11, fill: color(0xC3C8F2), shadow: 0.3)

// Front card.
ctx.saveGState()
ctx.translateBy(x: pivot.x, y: pivot.y)
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.4))
ctx.addPath(CGPath(roundedRect: card, cornerWidth: 34, cornerHeight: 34, transform: nil))
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Folder on the front card: tab + body in warm orange.
let folderBody = CGRect(x: -112, y: 380, width: 224, height: 140)
let tab = CGMutablePath()
tab.move(to: CGPoint(x: -112, y: 500))
tab.addLine(to: CGPoint(x: -112, y: 540))
tab.addQuadCurve(to: CGPoint(x: -96, y: 556), control: CGPoint(x: -112, y: 556))
tab.addLine(to: CGPoint(x: -30, y: 556))
tab.addQuadCurve(to: CGPoint(x: -12, y: 544), control: CGPoint(x: -20, y: 556))
tab.addLine(to: CGPoint(x: 0, y: 530))
tab.addLine(to: CGPoint(x: 0, y: 500))
tab.closeSubpath()
ctx.addPath(tab)
ctx.setFillColor(color(0xF0602E))
ctx.fillPath()
ctx.addPath(CGPath(roundedRect: folderBody, cornerWidth: 18, cornerHeight: 18, transform: nil))
let folderGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [color(0xFF9A5C), color(0xF2643A)] as CFArray,
                                locations: [0, 1])!
ctx.saveGState()
ctx.clip()
ctx.drawLinearGradient(folderGradient, start: CGPoint(x: 0, y: 520), end: CGPoint(x: 0, y: 380), options: [])
ctx.restoreGState()

// File-list rows under the folder.
let rowColor = color(0x2A2F6B, 0.22)
for (index, width) in [176.0, 136.0, 156.0].enumerated() {
    let y = 318 - CGFloat(index) * 52
    ctx.addPath(CGPath(roundedRect: CGRect(x: -112, y: y, width: 28, height: 28), cornerWidth: 7, cornerHeight: 7, transform: nil))
    ctx.setFillColor(color(0xF2643A, index == 0 ? 0.9 : 0.45))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: -70, y: y + 6, width: CGFloat(width), height: 16), cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.setFillColor(rowColor)
    ctx.fillPath()
}
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")

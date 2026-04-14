import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? ""
guard !outputPath.isEmpty else {
    fputs("Usage: render_dmg_background.swift <output.png>\n", stderr)
    exit(1)
}

let size = NSSize(width: 780, height: 440)
let image = NSImage(size: size)

image.lockFocusFlipped(false)

let rect = NSRect(origin: .zero, size: size)

// Base background
let base = NSGradient(colors: [
    NSColor(calibratedRed: 0.85, green: 0.90, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.93, green: 0.95, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.88, green: 0.92, blue: 1.0, alpha: 1.0),
])!
base.draw(in: rect, angle: -18)

func drawSoftGlow(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, alpha: CGFloat) {
    let glowRect = NSRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
    let path = NSBezierPath(ovalIn: glowRect)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let gradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(alpha),
        NSColor.white.withAlphaComponent(0.0),
    ])!
    gradient.draw(in: glowRect, relativeCenterPosition: .zero)
    NSGraphicsContext.restoreGraphicsState()
}

drawSoftGlow(center: CGPoint(x: 110, y: 95), radiusX: 250, radiusY: 120, alpha: 0.46)
drawSoftGlow(center: CGPoint(x: 675, y: 95), radiusX: 260, radiusY: 135, alpha: 0.32)
drawSoftGlow(center: CGPoint(x: 390, y: 405), radiusX: 360, radiusY: 90, alpha: 0.22)

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: 0.2,
    ]
    NSString(string: text).draw(in: rect, withAttributes: attrs)
}

drawText(
    "PasteGo for Mac",
    in: NSRect(x: 90, y: 312, width: 600, height: 76),
    font: .systemFont(ofSize: 58, weight: .medium),
    color: NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.19, alpha: 1.0)
)

drawText(
    "拖动应用到文件夹，即可安装",
    in: NSRect(x: 170, y: 258, width: 440, height: 40),
    font: .systemFont(ofSize: 24, weight: .regular),
    color: NSColor(calibratedRed: 0.46, green: 0.53, blue: 0.69, alpha: 1.0)
)

// Arrow
NSGraphicsContext.saveGraphicsState()
let arrowColor = NSColor.white.withAlphaComponent(0.92)
arrowColor.setStroke()
let shadow = NSShadow()
shadow.shadowBlurRadius = 8
shadow.shadowOffset = .zero
shadow.shadowColor = NSColor.white.withAlphaComponent(0.28)
shadow.set()

let line = NSBezierPath()
line.move(to: CGPoint(x: 340, y: 144))
line.line(to: CGPoint(x: 384, y: 144))
line.lineWidth = 9
line.lineCapStyle = .round
line.stroke()

let head = NSBezierPath()
head.move(to: CGPoint(x: 370, y: 130))
head.line(to: CGPoint(x: 392, y: 144))
head.line(to: CGPoint(x: 370, y: 158))
head.lineWidth = 9
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to render PNG background\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))

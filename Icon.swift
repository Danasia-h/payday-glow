import AppKit
let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 206, yRadius: 206).fill()
        let green = NSColor(calibratedRed: 0.79, green: 0.94, blue: 0.48, alpha: 1)
        green.setStroke()
        let clock = NSBezierPath(ovalIn: NSRect(x: 214, y: 214, width: 596, height: 596)); clock.lineWidth = 38; clock.stroke()
        let hand = NSBezierPath(); hand.lineWidth = 43; hand.lineCapStyle = .round
        hand.move(to: NSPoint(x: 512, y: 718)); hand.line(to: NSPoint(x: 512, y: 512)); hand.line(to: NSPoint(x: 642, y: 438)); hand.stroke()
        green.setFill(); NSBezierPath(ovalIn: NSRect(x: 481, y: 481, width: 62, height: 62)).fill()
        NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 670, y: 150, width: 220, height: 220)).fill()
        green.setFill(); NSBezierPath(ovalIn: NSRect(x: 686, y: 166, width: 188, height: 188)).fill()
        let text = "¥" as NSString
        text.draw(at: NSPoint(x: 739, y: 177), withAttributes: [.font: NSFont.systemFont(ofSize: 130, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.25, blue: 0.20, alpha: 1)])
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name))
    }
}

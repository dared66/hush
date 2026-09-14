import AppKit

// Original Hush artwork. All coordinates scale from a 1024-point canvas.
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
do {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 208, yRadius: 208)
    NSGradient(starting: color(0.10, 0.24, 0.28), ending: color(0.025, 0.08, 0.12))!.draw(in: tile, angle: -90)
    color(0.22, 0.40, 0.42).setStroke()
    tile.lineWidth = 3
    tile.stroke()
    // Two tall stems connected by a quiet wave: Hush's H and audio in one mark.
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 344, y: 302)); mark.line(to: NSPoint(x: 344, y: 722))
    mark.move(to: NSPoint(x: 680, y: 302)); mark.line(to: NSPoint(x: 680, y: 722))
    mark.move(to: NSPoint(x: 344, y: 512))
    mark.curve(to: NSPoint(x: 512, y: 512), controlPoint1: NSPoint(x: 412, y: 646), controlPoint2: NSPoint(x: 450, y: 646))
    mark.curve(to: NSPoint(x: 680, y: 512), controlPoint1: NSPoint(x: 574, y: 378), controlPoint2: NSPoint(x: 612, y: 378))
    mark.lineWidth = 78; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
    color(0.65, 0.98, 0.84).setStroke(); mark.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let name = "Hush"
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/\(name).png"))
}

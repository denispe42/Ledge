import AppKit
let W = 1280, H = 640
let shot = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSGradient(colors: [NSColor(red: 0.20, green: 0.12, blue: 0.40, alpha: 1), NSColor(red: 0.10, green: 0.28, blue: 0.55, alpha: 1), NSColor(red: 0.05, green: 0.45, blue: 0.55, alpha: 1)])!
bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)
// The island hangs from the very top edge (flat top, rounded bottom), and the black notch lies over its top centre.
let cut: CGFloat = 27   // points of the source below the island (backdrop), dropped
let source = NSRect(x: 0, y: cut, width: shot.size.width, height: shot.size.height - cut)
let width: CGFloat = 820, height = width * source.height / source.width
let frame = NSRect(x: (CGFloat(W) - width) / 2, y: CGFloat(H) - height, width: width, height: height)
NSGraphicsContext.current?.saveGraphicsState()
// A rounded rect taller than the frame, so only the bottom corners are visible below the canvas top.
NSBezierPath(roundedRect: NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + 60), xRadius: 40, yRadius: 40).addClip()
shot.draw(in: frame, from: source, operation: .sourceOver, fraction: 1)
NSGraphicsContext.current?.restoreGraphicsState()
NSColor.black.setFill()
NSBezierPath(roundedRect: NSRect(x: 490, y: CGFloat(H) - 38, width: 300, height: 68), xRadius: 22, yRadius: 22).fill()
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, alpha: CGFloat = 1) {
    let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor.white.withAlphaComponent(alpha)])
    a.draw(at: NSPoint(x: (CGFloat(W) - a.size().width) / 2, y: y))
}
text("Ledge", size: 64, weight: .bold, y: 118)
text("A native island around the MacBook notch. Zero network.", size: 28, weight: .medium, y: 66, alpha: 0.92)
text("Keep Awake · Cleaning · Calculator · Timer · Shelf · AirDrop · Mirror · Monitor", size: 19, weight: .regular, y: 28, alpha: 0.7)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))

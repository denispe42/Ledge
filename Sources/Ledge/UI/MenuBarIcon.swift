import AppKit

/// The menu-bar mark: a plain round smiley, drawn in code (no image file). It is a template image, so the menu bar
/// colours it white or black by itself to match the wallpaper and appearance.
@MainActor
enum MenuBarIcon {
    static let size = NSSize(width: 18, height: 18)

    static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.black.set()
            let face = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.25, dy: 1.25))
            face.lineWidth = 1.5
            face.stroke()

            let c = NSPoint(x: bounds.midX, y: bounds.midY)
            for dx in [-2.8, 2.8] {
                NSBezierPath(ovalIn: NSRect(x: c.x + dx - 1.15, y: c.y + 1.6, width: 2.3, height: 2.3)).fill()
            }
            let smile = NSBezierPath()
            smile.appendArc(withCenter: NSPoint(x: c.x, y: c.y + 0.4), radius: 4.4, startAngle: 205, endAngle: 335)
            smile.lineWidth = 1.5
            smile.lineCapStyle = .round
            smile.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

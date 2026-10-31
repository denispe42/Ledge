import AppKit
// A neutral gradient window behind the island, so screenshots and GIFs show the glass over a clean picture instead
// of whatever is on the desktop: backdrop <x> <y> <w> <h>  (screen points, origin top-left). Kill it when done.
let a = CommandLine.arguments.dropFirst().compactMap { Double($0) }
guard a.count == 4, let screen = NSScreen.screens.first else { exit(1) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let frame = NSRect(x: a[0], y: screen.frame.height - a[1] - a[3], width: a[2], height: a[3])
let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
// Below the menu bar and the island panels (the collapsed pill sits at the status bar level), so the island still
// opens on a click and its glass lies over this picture.
window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
window.ignoresMouseEvents = true
window.isOpaque = true
window.hasShadow = false
let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
view.wantsLayer = true
let gradient = CAGradientLayer()
gradient.frame = view.bounds
gradient.colors = [NSColor(red: 0.20, green: 0.12, blue: 0.40, alpha: 1).cgColor,
                   NSColor(red: 0.10, green: 0.28, blue: 0.55, alpha: 1).cgColor,
                   NSColor(red: 0.05, green: 0.45, blue: 0.55, alpha: 1).cgColor]
gradient.startPoint = CGPoint(x: 0, y: 1)
gradient.endPoint = CGPoint(x: 1, y: 0)
view.layer?.addSublayer(gradient)
window.contentView = view
window.orderFrontRegardless()
app.run()

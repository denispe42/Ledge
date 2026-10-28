import AppKit

// Menu-bar-less agent app (no Dock icon); see Resources/Info.plist LSUIElement.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

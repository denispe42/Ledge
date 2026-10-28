import AppKit

/// Menu-bar icon with Settings and Quit. The app has no Dock icon, so this is the way in.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onSettings: () -> Void

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: L10n.statusItemTip)
        item.button?.toolTip = L10n.statusItemTip
        let menu = NSMenu()
        let settings = NSMenuItem(title: L10n.settings, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)
        item.menu = menu
    }

    @objc private func openSettings() { onSettings() }
}

import AppKit

/// Menu-bar icon with Settings and Quit. The app has no Dock icon, so this is the way in.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onSettings: () -> Void
    /// Settings and Quit. Also offered on a right click on the notch, because a crowded menu bar can leave no room for
    /// the icon and the app must stay reachable.
    let menu = NSMenu()

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        super.init()
        item.button?.image = MenuBarIcon.image()
        item.button?.image?.accessibilityDescription = L10n.statusItemTip
        item.button?.toolTip = L10n.statusItemTip
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

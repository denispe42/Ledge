import AppKit

/// Borderless, non-activating floating panel: never steals focus from the frontmost app.
@MainActor
final class IslandPanel: NSPanel {
    let islandView = IslandView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // One level above the collapsed pill, so the glass is always drawn over it.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        contentView = islandView
    }

    /// The opened glass extends a corner radius above the screen top so only its bottom corners are visible;
    /// by default AppKit would push such a frame back below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// System Liquid Glass only renders in its full "active" look in a key window, so the panel is key while the
    /// island is open (see IslandController, which hands the focus back on close).
    var keyAllowed = false
    override var canBecomeKey: Bool { keyAllowed }

    /// Keys go to the open page if it wants them (the calculator); otherwise they are swallowed quietly instead of beeping.
    override func keyDown(with event: NSEvent) { _ = islandView.handleKey(event) }
    override var canBecomeMain: Bool { false }
}

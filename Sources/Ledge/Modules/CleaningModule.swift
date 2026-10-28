import AppKit
import LedgeCore

/// Tile that starts cleaning mode (see `CleaningSession`). The session is created on the first press, so an enabled
/// module that is never used holds no windows and no observers.
@MainActor
final class CleaningModule: UIModule {
    let id = "cleaning"
    var title: String { L10n.cleaning }

    private var session: CleaningSession?
    private var closeIsland: ((@escaping (NSRunningApplication?) -> Void) -> Void)?

    func start() throws {}

    func stop() {
        session?.end()
        session = nil
    }

    func setCloseHandler(_ close: @escaping (@escaping (NSRunningApplication?) -> Void) -> Void) { closeIsland = close }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "sparkles", title: title)
        tile.statusText = KeyboardBlocker.hasPermission ? L10n.start : L10n.allowAccess
        tile.onPress = { [weak self] in self?.begin() }
        return tile
    }

    /// The island closes first and does not hand the focus back (a late activation of the previous app would take it
    /// from the mode and end it at once); the mode returns the focus itself when it ends.
    private func begin() {
        Haptics.tick(.generic)
        guard KeyboardBlocker.hasPermission else {
            KeyboardBlocker.requestPermission()
            return
        }
        closeIsland? { [weak self] previous in
            guard let self else { return }
            let session = self.session ?? CleaningSession()
            self.session = session
            session.start(returningFocusTo: previous)
        }
    }
}

import AppKit
import LedgeCore

private struct AirDropUnavailable: LocalizedError {
    var errorDescription: String? { L10n.airDropUnavailable }
}

/// Files dropped on the AirDrop zone go to the system's AirDrop window (pick the device there). The module holds
/// nothing while idle; during a send it keeps the island open so the window it belongs to does not vanish.
@MainActor
final class AirDropModule: UIModule {
    let id = "airdrop"
    var title: String { L10n.airDrop }
    private static let symbol = "dot.radiowaves.left.and.right"

    private let sharer: FileSharing
    private var hold: ((Bool) -> Void)?
    private var isSending = false
    private var isChoosing = false
    private var chooser: NSOpenPanel?
    private var resignObserver: NSObjectProtocol?
    private var failed = false
    private var tiles: [TileView] = []

    init(sharer: FileSharing = AirDropSharer()) { self.sharer = sharer }

    var dropZone: DropZone? {
        DropZone(symbol: Self.symbol, title: title, showsPageAfterDrop: false) { [weak self] urls, anchor in
            self?.send(urls, from: anchor)
        }
    }

    func start() throws {
        guard sharer.isAvailable else { throw AirDropUnavailable() }
    }

    func stop() {
        chooser?.cancel(nil)
        if isSending || isChoosing { hold?(false) }
        isSending = false
        endChoosing()
        failed = false
        tiles.removeAll()
    }

    func setHoldHandler(_ hold: @escaping (Bool) -> Void) { self.hold = hold }

    /// The tile is a button: it asks for files and hands them to AirDrop. Dropping files works on the drop screen.
    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: Self.symbol, title: title)
        tile.onPress = { [weak self, weak tile] in
            Haptics.tick(.generic)
            self?.chooseFiles(anchor: tile)
        }
        tiles.append(tile)
        apply(to: tile)
        return tile
    }

    /// The standard open panel, placed below the island (the island's glass lies above ordinary windows and would hide
    /// the panel's top). The island is held open meanwhile: the pointer leaves it on its way to the panel.
    /// The system hides the panel without calling back when the user activates another app (a click on a Dock icon),
    /// so losing the focus cancels it: otherwise the hold would never end and the island could not close any more.
    private func chooseFiles(anchor: NSView?) {
        // A second press closes the panel; the island stays open (the pointer is still over it when the hold ends).
        if isChoosing { chooser?.cancel(nil); return }
        isChoosing = true
        hold?(true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = L10n.send
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        chooser = panel
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak panel] _ in
            MainActor.assumeIsolated { panel?.cancel(nil) }
        }
        // Activate the app without raising all its windows: `NSApp.activate(ignoringOtherApps:)` would also bring an open
        // Settings window over the other apps. The key window (this island) comes forward, nothing else.
        NSRunningApplication.current.activate(options: [])
        panel.begin { [weak self] response in
            guard let self else { return }
            self.endChoosing()
            if response == .OK, !panel.urls.isEmpty {
                self.send(panel.urls, from: anchor)
            } else {
                self.hold?(false)
            }
        }
        if let island = anchor?.window?.frame {
            panel.setFrameTopLeftPoint(NSPoint(x: island.midX - panel.frame.width / 2, y: island.minY - 8))
        }
    }

    private func endChoosing() {
        isChoosing = false
        chooser = nil
        if let observer = resignObserver { NotificationCenter.default.removeObserver(observer) }
        resignObserver = nil
    }

    private func send(_ urls: [URL], from anchor: NSView?) {
        guard !urls.isEmpty else { return }
        isSending = true
        hold?(true)
        sharer.share(urls, from: anchor) { [weak self] outcome in
            guard let self else { return }
            self.isSending = false
            self.failed = outcome == .failed
            self.tiles.forEach(self.apply)
            self.hold?(false)
        }
    }

    private func apply(to tile: TileView) {
        tile.statusText = failed ? L10n.airDropUnavailable : L10n.chooseFiles
    }
}

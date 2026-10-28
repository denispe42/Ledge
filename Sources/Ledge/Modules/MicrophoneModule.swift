import AppKit
import LedgeCore

private struct NoMicrophone: LocalizedError {
    var errorDescription: String? { L10n.noMicrophone }
}

/// One press mutes or unmutes the system's default microphone. Nothing listens while the island is closed: the
/// listeners are installed on opening (after a fresh reading, since another app may have changed the mute) and
/// removed on closing.
@MainActor
final class MicrophoneModule: UIModule {
    let id = "microphone"
    var title: String { L10n.microphone }

    private let control: MicrophoneControl
    private var tiles: [TileView] = []
    /// The volume to restore after a mute done by volume (devices without a mute property).
    private var rememberedVolume: Float?

    init(control: MicrophoneControl = CoreAudioMicrophone()) {
        self.control = control
    }

    func start() throws {
        guard control.reading() != nil else { throw NoMicrophone() }
        control.onChange = { [weak self] in self?.refresh() }
    }

    func stop() {
        control.stop()
        control.onChange = nil
        tiles.removeAll()
        rememberedVolume = nil
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "mic.fill", title: title)
        tile.onPress = { [weak self] in self?.toggle() }
        tiles.append(tile)
        apply(to: tile)
        return tile
    }

    func islandVisibilityChanged(_ open: Bool) {
        if open {
            control.start()
            refresh()
        } else {
            control.stop()
        }
    }

    private func toggle() {
        guard let reading = control.reading(),
              let action = MicrophoneMute.toggle(reading, remembered: rememberedVolume) else { return }
        Haptics.tick(.generic)
        if case .volume = action.change { rememberedVolume = action.remember }
        control.apply(action.change)
        refresh()
    }

    private func refresh() { tiles.forEach(apply) }

    private func apply(to tile: TileView) {
        let state = control.reading().map(MicrophoneMute.state) ?? .unavailable
        tile.isOn = state == .muted
        tile.setSymbol(state == .muted ? "mic.slash.fill" : "mic.fill")
        switch state {
        case .live: tile.statusText = L10n.on
        case .muted: tile.statusText = L10n.muted
        case .unavailable: tile.statusText = L10n.unavailable
        }
    }
}

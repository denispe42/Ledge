import AppKit
import AVFoundation
import LedgeCore

/// Tile that opens the mirror window (see `MirrorPanel`). The camera runs only while that window is open; an enabled
/// module that is never used holds nothing.
@MainActor
final class MirrorModule: UIModule {
    let id = "mirror"
    var title: String { L10n.mirror }

    private var panel: MirrorPanel?
    private var camera: MirrorCamera?
    private var tiles: [TileView] = []

    func start() throws {}

    func stop() {
        closeMirror()
        tiles.removeAll()
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "camera.fill", title: title)
        tile.statusText = L10n.open
        tile.isOn = panel != nil
        tile.onPress = { [weak self] in self?.toggle() }
        tiles.append(tile)
        return tile
    }

    private func toggle() {
        Haptics.tick(.generic)
        if panel != nil { return closeMirror() }
        switch MirrorPolicy.action(for: MirrorCamera.authorization) {
        case .start: openMirror()
        case .askPermission:
            Task { @MainActor in
                if await AVCaptureDevice.requestAccess(for: .video) { openMirror() } else { showNoAccess() }
            }
        case .showNoAccess: showNoAccess()
        }
    }

    private func openMirror() {
        let camera = MirrorCamera()
        guard camera.configure() else { return showNoCamera() }
        self.camera = camera
        show(MirrorPanel(camera: camera, note: nil))
        camera.start()
    }

    private func showNoAccess() { show(MirrorPanel(camera: nil, note: L10n.noCameraAccess)) }
    private func showNoCamera() { show(MirrorPanel(camera: nil, note: L10n.noCamera)) }

    private func show(_ panel: MirrorPanel) {
        panel.onClose = { [weak self] in self?.closeMirror() }
        self.panel = panel
        panel.present()
        refreshTiles()
    }

    private func closeMirror() {
        camera?.stop()
        camera = nil
        panel?.orderOut(nil)
        panel = nil
        refreshTiles()
    }

    private func refreshTiles() { tiles.forEach { $0.isOn = panel != nil } }
}

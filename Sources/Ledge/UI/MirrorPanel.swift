import AppKit
import AVFoundation

/// The mirror window: a small rounded picture of the camera, mirrored left to right, floating above other windows.
/// Drag it anywhere; ✕ or Esc closes it. Black and white apart from the camera picture itself.
@MainActor
final class MirrorPanel: NSPanel {
    static let size = NSSize(width: 400, height: 300)
    var onClose: (() -> Void)?

    private let preview: AVCaptureVideoPreviewLayer?
    private let note = NSTextField(labelWithString: "")

    /// `camera` nil shows only the "no access" note.
    init(camera: MirrorCamera?, note text: String?) {
        preview = camera.map { AVCaptureVideoPreviewLayer(session: $0.session) }
        super.init(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        contentView = makeContent(text)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onClose?() }

    /// Centred on the screen under the pointer, a little above the middle.
    func present() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2, y: frame.midY - Self.size.height / 2 + 40))
        }
        orderFrontRegardless()
        makeKey()
    }

    private func makeContent(_ text: String?) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: Self.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.cornerRadius = 22
        view.layer?.masksToBounds = true
        if let preview {
            preview.frame = view.bounds
            preview.videoGravity = .resizeAspectFill
            if let connection = preview.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            view.layer?.addSublayer(preview)
        }
        if let text {
            note.stringValue = text
            note.font = .systemFont(ofSize: 15, weight: .medium)
            note.textColor = .white
            note.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(note)
            NSLayoutConstraint.activate([note.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                         note.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        }
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: L10n.close) ?? NSImage(),
                             target: self, action: #selector(closePressed))
        close.isBordered = false
        close.contentTintColor = .black
        close.wantsLayer = true
        close.layer?.backgroundColor = NSColor.white.cgColor
        close.layer?.cornerRadius = 13
        close.frame = NSRect(x: Self.size.width - 40, y: Self.size.height - 40, width: 26, height: 26)
        view.addSubview(close)
        return view
    }

    @objc private func closePressed() { onClose?() }
}

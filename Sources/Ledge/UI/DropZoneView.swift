import AppKit


/// A glass target for files: icon and name, inverted (white disc look, black ink) while a file hovers over it.
/// Two colours only, like the tiles.
@MainActor
final class DropZoneView: NSView {
    static let size = NSSize(width: 190, height: 100)

    /// Called with the dropped files.
    var onDrop: (([URL]) -> Void)?

    private let fill = NSView()
    private let symbol = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var isTargeted = false { didSet { updateAppearance() } }

    init(symbol name: String, title: String) {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        registerForDraggedTypes(FileDrop.types)
        setAccessibilityLabel(title)

        fill.wantsLayer = true
        fill.layer?.cornerRadius = 24
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 28, weight: .semibold))
        // An image view takes drags itself (it is editable by default) and would steal them from the zone
        // whenever the pointer is over the icon, which is the centre of the zone.
        symbol.isEditable = false
        symbol.unregisterDraggedTypes()
        label.stringValue = title
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        let stack = NSStackView(views: [symbol, label])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        fill.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: fill.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            widthAnchor.constraint(equalToConstant: Self.size.width),
            heightAnchor.constraint(equalToConstant: Self.size.height),
        ])
        let host = Glass.make(around: fill, cornerRadius: 24)
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
        updateAppearance()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { updateAppearance() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard FileDrop.hasFiles(sender) else { return [] }
        isTargeted = true
        Haptics.tick(.alignment)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { isTargeted = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        let urls = FileDrop.fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            fill.layer?.backgroundColor = (isTargeted ? Glass.ink : Glass.ink.withAlphaComponent(0.12)).cgColor
        }
        let ink = isTargeted ? Glass.inverseInk : Glass.ink
        symbol.contentTintColor = ink
        label.textColor = ink
    }
}

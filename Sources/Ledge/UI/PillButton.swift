import AppKit

/// A small glass capsule button (text and/or symbol). A prominent one is inverted (the main action).
@MainActor
final class PillButton: NSView {
    /// Transparent margin around the capsule so the press animation is never clipped.
    static let pad: CGFloat = 8

    var onPress: (() -> Void)?
    var isProminent = false { didSet { updateAppearance() } }

    private let content = NSView()
    private let symbolView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(title: String? = nil, symbol: String? = nil, width: CGFloat = 76, height: CGFloat = 34) {
        super.init(frame: NSRect(x: 0, y: 0, width: width + 2 * Self.pad, height: height + 2 * Self.pad))
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.stringValue = title ?? ""
        label.isHidden = title == nil
        if let symbol {
            symbolView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        }
        symbolView.isHidden = symbol == nil
        setAccessibilityLabel(title ?? symbol)
        setAccessibilityRole(.button)

        let row = NSStackView(views: [symbolView, label])
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        content.wantsLayer = true
        content.layer?.cornerRadius = height / 2
        content.addSubview(row)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width + 2 * Self.pad),
            heightAnchor.constraint(equalToConstant: height + 2 * Self.pad),
            row.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
        let host = Glass.make(around: content, cornerRadius: height / 2, interactive: true)
        host.frame = bounds.insetBy(dx: Self.pad, dy: Self.pad)
        addSubview(host)
        updateAppearance()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ title: String) {
        label.isHidden = false
        label.stringValue = title
        setAccessibilityLabel(title)
    }

    override func viewDidChangeEffectiveAppearance() { updateAppearance() }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.insetBy(dx: Self.pad, dy: Self.pad).contains(local) ? super.hitTest(point) : nil
    }

    override func mouseDown(with event: NSEvent) { onPress?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            content.layer?.backgroundColor = isProminent ? Glass.ink.cgColor : NSColor.clear.cgColor
        }
        let color = isProminent ? Glass.inverseInk : Glass.ink
        label.textColor = color
        symbolView.contentTintColor = color
    }
}

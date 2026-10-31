import AppKit

/// What every screen shows in cleaning mode: black, a ring that fills while an exit hold is going, one line of
/// instructions and an "Exit" button that works only when held. Strictly black and white.
@MainActor
final class CleaningView: NSView {
    /// The button was pressed or let go; the session counts the hold.
    var onButtonHold: ((Bool) -> Void)?

    private let ring = CAShapeLayer()
    private let hint = NSTextField(labelWithString: L10n.cleaningHint)
    private let exitButton = ExitHoldButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        ring.fillColor = nil
        ring.strokeColor = NSColor.white.cgColor
        ring.lineWidth = 4
        ring.lineCap = .round
        ring.strokeEnd = 0
        layer?.addSublayer(ring)

        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textColor = .white
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)

        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.onHold = { [weak self] in self?.onButtonHold?($0) }
        addSubview(exitButton)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 64),
            exitButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            exitButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -48),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let radius: CGFloat = 36
        let centre = CGPoint(x: bounds.midX, y: bounds.midY + 8)
        // The arc starts at the top (angle π/2 in the layer's y-up space) and runs clockwise as the stroke grows.
        ring.frame = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: ring.bounds.midX, y: ring.bounds.midY), radius: radius - 2,
                    startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        ring.path = path
    }

    /// Fills the ring over `duration`; the session ends the mode when the hold completes.
    func startRing(duration: Double) {
        let fill = CABasicAnimation(keyPath: "strokeEnd")
        fill.fromValue = 0
        fill.toValue = 1
        fill.duration = duration
        fill.timingFunction = CAMediaTimingFunction(name: .linear)
        ring.strokeEnd = 1
        ring.add(fill, forKey: "fill")
    }

    func resetRing() {
        ring.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeEnd = 0
        CATransaction.commit()
    }
}

/// White outline pill. A plain click does nothing: it reports press and release so the hold can be timed.
@MainActor
private final class ExitHoldButton: NSView {
    var onHold: ((Bool) -> Void)?
    private let label = NSTextField(labelWithString: L10n.exit)

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.white.cgColor
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 96),
            heightAnchor.constraint(equalToConstant: 30),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { onHold?(true) }
    override func mouseUp(with event: NSEvent) { onHold?(false) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

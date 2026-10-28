import AppKit
import LedgeCore

/// One scrollable column of digits: the current value large, its neighbours small above and below.
/// Two-finger scroll (or a mouse wheel) changes the value; every step slides the digits and gives a light trackpad tick.
@MainActor
final class WheelColumnView: NSView {
    static let columnSize = NSSize(width: 70, height: 84)
    private static let slide: CGFloat = 30

    var onChange: (() -> Void)?
    var value: Int { wheel.value }

    private var wheel: WheelValue
    private var scroll = ScrollAccumulator()
    private let strip = NSView()
    private let previous = NSTextField(labelWithString: "")
    private let current = NSTextField(labelWithString: "")
    private let next = NSTextField(labelWithString: "")

    init(maximum: Int, value: Int = 0) {
        wheel = WheelValue(maximum: maximum, value: value)
        super.init(frame: NSRect(origin: .zero, size: Self.columnSize))
        wantsLayer = true
        layer?.masksToBounds = true
        strip.wantsLayer = true
        strip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(strip)

        previous.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        next.font = previous.font
        current.font = .monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        let stack = NSStackView(views: [previous, current, next])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        for label in [previous, current, next] { label.textColor = Glass.ink; label.alignment = .center }
        // The neighbours are fainter so the chosen value stands out (an explicit exception to the two-colour rule).
        previous.textColor = Glass.ink.withAlphaComponent(0.4)
        next.textColor = Glass.ink.withAlphaComponent(0.4)
        strip.addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.columnSize.width),
            heightAnchor.constraint(equalToConstant: Self.columnSize.height),
            strip.leadingAnchor.constraint(equalTo: leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: trailingAnchor),
            strip.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: strip.centerXAnchor),
            stack.topAnchor.constraint(equalTo: strip.topAnchor),
            stack.bottomAnchor.constraint(equalTo: strip.bottomAnchor),
        ])
        setAccessibilityRole(.incrementor)
        refreshDigits()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Sets the value without sound, haptics or animation (used to show the remembered duration).
    func setValue(_ newValue: Int) {
        wheel.set(newValue)
        refreshDigits()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { scroll.reset() }
        let precise = event.hasPreciseScrollingDeltas
        // With natural scrolling the content follows the fingers: finger down = digits move down = smaller value.
        let contentMovesDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY > 0 : event.scrollingDeltaY < 0
        let magnitude = abs(event.scrollingDeltaY)
        let steps = scroll.add(contentMovesDown ? magnitude : -magnitude, threshold: precise ? 14 : 0.5)
        guard steps != 0 else { return }
        let moved = wheel.move(by: -steps)
        guard moved != 0 else { return }
        refreshDigits()
        slide(from: moved > 0 ? Self.slide : -Self.slide)
        Haptics.tick(.alignment)
        onChange?()
    }

    private func refreshDigits() {
        previous.stringValue = wheel.value > 0 ? String(format: "%02d", wheel.value - 1) : ""
        current.stringValue = String(format: "%02d", wheel.value)
        next.stringValue = wheel.value < wheel.maximum ? String(format: "%02d", wheel.value + 1) : ""
        setAccessibilityValue(current.stringValue)
    }

    /// The digits glide into place from the direction they came from.
    private func slide(from offset: CGFloat) {
        let a = CABasicAnimation(keyPath: "transform.translation.y")
        a.fromValue = offset
        a.toValue = 0
        a.duration = 0.12
        a.timingFunction = CAMediaTimingFunction(name: .easeOut)
        strip.layer?.add(a, forKey: "slide")
    }
}

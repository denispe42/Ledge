import AppKit
import LedgeCore

/// The page that opens on a long press of the Keep Awake tile: two wheels (hours and minutes, scroll them like the
/// timer's), "Start" for that time and "Always" for no end at all.
@MainActor
final class KeepAwakePage: NSView {
    private let hours = WheelColumnView(maximum: 23)
    private let minutes = WheelColumnView(maximum: 59)

    /// `initial` is the time chosen last time; `changed` reports every turn of a wheel (so it is remembered);
    /// `choose` gets the seconds to keep awake, or nil for "until switched off".
    init(initial: TimeInterval, changed: @escaping (TimeInterval) -> Void, choose: @escaping (TimeInterval?) -> Void) {
        super.init(frame: .zero)
        let total = Int(initial)
        hours.setValue(total / 3600)
        minutes.setValue((total % 3600) / 60)
        let current = { [weak self] () -> TimeInterval in
            guard let self else { return 0 }
            return TimeInterval(self.hours.value * 3600 + self.minutes.value * 60)
        }
        [hours, minutes].forEach { $0.onChange = { changed(current()) } }

        func unit(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.textColor = Glass.ink
            return label
        }
        let wheels = NSStackView(views: [hours, unit(L10n.hoursUnit), minutes, unit(L10n.minutesUnit)])
        wheels.orientation = .horizontal
        wheels.spacing = 6
        wheels.setCustomSpacing(22, after: wheels.arrangedSubviews[1])

        let start = PillButton(title: L10n.start, width: 110)
        start.isProminent = true
        start.onPress = {
            let seconds = current()
            guard seconds > 0 else { return Haptics.tick(.generic) }
            Haptics.tick(.generic)
            choose(seconds)
        }
        let always = PillButton(title: L10n.always, width: 110)
        always.onPress = { Haptics.tick(.generic); choose(nil) }
        let buttons = NSStackView(views: [start, always])
        buttons.orientation = .horizontal
        buttons.spacing = 8 - 2 * PillButton.pad

        let column = NSStackView(views: [wheels, buttons])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 10 - PillButton.pad
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 400),
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

import AppKit
import LedgeCore

/// Shared layout of a clock page: the big time on top, one row of buttons below.
@MainActor
class ClockPageView: NSView {
    let timeLabel = NSTextField(labelWithString: "0:00")
    let column = NSStackView()

    /// The page fills the island below the notch; its content is centred in that area.
    init() {
        super.init(frame: .zero)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .semibold)
        timeLabel.textColor = Glass.ink
        timeLabel.alignment = .center
        column.orientation = .vertical
        column.spacing = 10 - PillButton.pad
        column.alignment = .centerX
        column.addArrangedSubview(timeLabel)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 400),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// The "pin the time next to the notch" button shared by the clock pages; inverted while pinned.
    static func makePinButton(toggle: @escaping () -> Void) -> PillButton {
        let button = PillButton(symbol: "pin.fill", width: 44)
        button.toolTip = L10n.pinTime
        button.onPress = toggle
        return button
    }

    static func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 8 - 2 * PillButton.pad
        return row
    }
}

/// Timer page. Idle: three wheels (hours, minutes, seconds) to scroll plus Start. Running: the countdown with
/// pause/resume and reset.
@MainActor
final class TimerPageView: ClockPageView {
    private let hours = WheelColumnView(maximum: 23)
    private let minutes = WheelColumnView(maximum: 59)
    private let seconds = WheelColumnView(maximum: 59)
    private let wheelsRow: NSStackView
    private let controls = ClockPageView.row([])
    private let primary = PillButton(width: 110)
    private let reset = PillButton(title: L10n.reset)
    private let pin: PillButton

    init(begin: @escaping (TimeInterval) -> Void, togglePause: @escaping () -> Void, resetTimer: @escaping () -> Void,
         togglePin: @escaping () -> Void, durationChanged: @escaping (TimeInterval) -> Void, initialDuration: TimeInterval) {
        pin = ClockPageView.makePinButton(toggle: togglePin)
        func colon() -> NSTextField {
            let label = NSTextField(labelWithString: ":")
            label.font = .monospacedDigitSystemFont(ofSize: 36, weight: .semibold)
            label.textColor = Glass.ink
            return label
        }
        wheelsRow = ClockPageView.row([hours, colon(), minutes, colon(), seconds])
        wheelsRow.spacing = 4
        super.init()
        setDuration(initialDuration)
        // The chosen time goes to the model at once, so a redraw of the page (the pin button, the end of a timer) shows it again.
        [hours, minutes, seconds].forEach { $0.onChange = { [weak self] in
            guard let self else { return }
            durationChanged(self.duration)
        } }
        primary.isProminent = true
        primary.onPress = { [weak self] in
            guard let self else { return }
            if self.wheelsRow.isHidden { togglePause() } else { begin(self.duration) }
        }
        reset.onPress = resetTimer
        controls.addArrangedSubview(primary)
        controls.addArrangedSubview(reset)
        controls.addArrangedSubview(pin)
        column.addArrangedSubview(wheelsRow)
        column.addArrangedSubview(controls)
    }

    private var duration: TimeInterval { TimeInterval(hours.value * 3600 + minutes.value * 60 + seconds.value) }

    private func setDuration(_ total: TimeInterval) {
        let t = Int(total)
        hours.setValue(t / 3600)
        minutes.setValue((t % 3600) / 60)
        seconds.setValue(t % 60)
    }

    /// A swell of the digits, played once per beat of the end sound.
    func pulse() { timeLabel.pulse() }

    func update(_ timer: CountdownTimer, now: Date, pinned: Bool) {
        pin.isProminent = pinned
        let idle = timer.state == .idle
        wheelsRow.isHidden = !idle
        timeLabel.isHidden = idle
        reset.isHidden = idle
        timeLabel.stringValue = ClockFormat.string(timer.remaining(at: now), roundUp: true)
        switch timer.state {
        case .idle: primary.setTitle(L10n.start); setDuration(timer.duration)
        case .running: primary.setTitle(L10n.pause)
        case .paused: primary.setTitle(L10n.resume)
        case .finished: primary.setTitle(L10n.start)
        }
        // After the end only Reset makes sense.
        primary.isHidden = timer.state == .finished
    }
}

/// Stopwatch page: start/stop and reset.
@MainActor
final class StopwatchPageView: ClockPageView {
    private let primary = PillButton(width: 110)
    private let reset = PillButton(title: L10n.reset)
    private let pin: PillButton

    init(toggle: @escaping () -> Void, resetWatch: @escaping () -> Void, togglePin: @escaping () -> Void) {
        pin = ClockPageView.makePinButton(toggle: togglePin)
        super.init()
        primary.isProminent = true
        primary.onPress = toggle
        reset.onPress = resetWatch
        column.addArrangedSubview(ClockPageView.row([primary, reset, pin]))
    }

    func update(_ watch: Stopwatch, now: Date, pinned: Bool) {
        pin.isProminent = pinned
        timeLabel.stringValue = ClockFormat.string(watch.elapsed(at: now), roundUp: false)
        primary.setTitle(watch.isRunning ? L10n.pause : (watch.state == .idle ? L10n.start : L10n.resume))
    }
}

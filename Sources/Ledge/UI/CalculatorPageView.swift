import AppKit

/// One key of the calculator keypad. `span` is how many columns it covers.
struct KeyCell {
    var title: String
    var prominent = false
    var span = 1
    var dimmed = false
    var isClear = false
    var action: () -> Void
}

/// One line of the history list: the calculation in small dimmed text, the result under it. Pressing it takes the result.
@MainActor
private final class HistoryRowView: NSView {
    var onPress: (() -> Void)?

    init(expression: String, result: String) {
        super.init(frame: .zero)
        let top = NSTextField(labelWithString: expression)
        top.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        top.textColor = Glass.ink.withAlphaComponent(0.45)
        let bottom = NSTextField(labelWithString: result)
        bottom.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        bottom.textColor = Glass.ink
        let column = NSStackView(views: [top, bottom])
        column.orientation = .vertical
        column.spacing = 0
        column.translatesAutoresizingMaskIntoConstraints = false
        for label in [top, bottom] {
            label.alignment = .center
            label.lineBreakMode = .byTruncatingHead
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 36),
        ])
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(expression) = \(result)")
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.5
        onPress?()
    }

    override func mouseUp(with event: NSEvent) { alphaValue = 1 }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Document view with its origin at the top, so a short list sits at the top of the scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Calculator page: the number (with the finished calculation in dimmed text above it) on the left, the keypad on the
/// right. The module supplies the keys, so the same page shows the basic keypad and the wider programmer one.
@MainActor
final class CalculatorPageView: NSView, KeyHandling {
    private static let keyHeight: CGFloat = 22
    private static let gap: CGFloat = 4
    private static let displaySize: CGFloat = 44
    private static let historySize: CGFloat = 15

    var onKeyEvent: ((NSEvent) -> Bool)?
    private let pickHistory: (Int) -> Void

    private let displayLabel = NSTextField(labelWithString: "0")
    private let historyLabel = NSTextField(labelWithString: " ")
    private let keypad = NSStackView()
    private let programmerButton = PillButton(symbol: "chevron.left.forwardslash.chevron.right", width: 36, height: 22)
    private let extendedButton = PillButton(symbol: "parentheses", width: 36, height: 22)
    private let baseButton = PillButton(title: "DEC", width: 46, height: 22)
    private let historyButton = PillButton(symbol: "clock.arrow.circlepath", width: 32, height: 22)
    private let clearHistoryButton = PillButton(symbol: "trash", width: 32, height: 22)
    private let historyScroll = NSScrollView()
    private let historyStack = NSStackView()
    private let historyEmpty = NSTextField(labelWithString: L10n.noCalculations)
    private let readout = NSStackView()
    private var keypadWidth: NSLayoutConstraint!
    private var clearButtons: [PillButton] = []
    private var smallestDisplaySize: CGFloat = 18

    /// The mode switches under the number; the active one is shown inverted.
    enum Tool { case extended, programmer }

    init(toggleExtended: @escaping () -> Void, toggleProgrammer: @escaping () -> Void, cycleBase: @escaping () -> Void,
         toggleHistory: @escaping () -> Void, clearHistory: @escaping () -> Void, pickHistory: @escaping (Int) -> Void) {
        self.pickHistory = pickHistory
        super.init(frame: .zero)
        displayLabel.textColor = Glass.ink
        displayLabel.font = .monospacedDigitSystemFont(ofSize: Self.displaySize, weight: .semibold)
        // The finished calculation above the answer: the same ink, dimmed (like the neighbours on the timer wheels).
        historyLabel.textColor = Glass.ink.withAlphaComponent(0.45)
        historyLabel.font = .monospacedDigitSystemFont(ofSize: Self.historySize, weight: .medium)
        readout.setViews([historyLabel, displayLabel], in: .center)
        readout.orientation = .vertical
        readout.spacing = 2
        readout.translatesAutoresizingMaskIntoConstraints = false
        for label in [displayLabel, historyLabel] {
            label.alignment = .center
            label.lineBreakMode = .byClipping
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalTo: readout.widthAnchor).isActive = true
        }

        keypad.orientation = .vertical
        keypad.spacing = 3 - 2 * PillButton.pad
        keypad.translatesAutoresizingMaskIntoConstraints = false

        programmerButton.onPress = { toggleProgrammer() }
        programmerButton.toolTip = L10n.programmerKeys
        extendedButton.onPress = { toggleExtended() }
        extendedButton.toolTip = L10n.extendedKeys
        baseButton.onPress = { cycleBase() }
        baseButton.isHidden = true
        let tools = NSStackView(views: [extendedButton, programmerButton, baseButton])
        tools.orientation = .horizontal
        tools.spacing = 4 - 2 * PillButton.pad
        tools.translatesAutoresizingMaskIntoConstraints = false

        historyButton.onPress = { toggleHistory() }
        historyButton.toolTip = L10n.history
        clearHistoryButton.onPress = { clearHistory() }
        clearHistoryButton.toolTip = L10n.clearHistory
        clearHistoryButton.isHidden = true
        let historyTools = NSStackView(views: [clearHistoryButton, historyButton])
        historyTools.orientation = .horizontal
        historyTools.spacing = 4 - 2 * PillButton.pad
        historyTools.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        historyStack.orientation = .vertical
        historyStack.spacing = 2
        historyStack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(historyStack)
        document.translatesAutoresizingMaskIntoConstraints = false
        historyScroll.documentView = document
        historyScroll.drawsBackground = false
        historyScroll.hasVerticalScroller = false
        historyScroll.isHidden = true
        historyScroll.translatesAutoresizingMaskIntoConstraints = false
        historyEmpty.font = .systemFont(ofSize: 12, weight: .medium)
        historyEmpty.textColor = Glass.ink.withAlphaComponent(0.45)
        historyEmpty.alignment = .center
        historyEmpty.isHidden = true
        historyEmpty.translatesAutoresizingMaskIntoConstraints = false

        addSubview(readout)
        addSubview(keypad)
        addSubview(tools)
        addSubview(historyScroll)
        addSubview(historyEmpty)
        addSubview(historyTools)
        keypadWidth = keypad.widthAnchor.constraint(equalToConstant: 200)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 400),
            keypad.trailingAnchor.constraint(equalTo: trailingAnchor, constant: PillButton.pad - 4),
            keypad.centerYAnchor.constraint(equalTo: centerYAnchor),
            keypadWidth,
            // The readout is centred in the free area left of the keypad.
            readout.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            readout.trailingAnchor.constraint(equalTo: keypad.leadingAnchor, constant: PillButton.pad - 8),
            readout.centerYAnchor.constraint(equalTo: centerYAnchor),
            historyStack.topAnchor.constraint(equalTo: document.topAnchor),
            historyStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            historyStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            historyStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.topAnchor.constraint(equalTo: historyScroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: historyScroll.contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: historyScroll.contentView.widthAnchor),
            historyScroll.leadingAnchor.constraint(equalTo: readout.leadingAnchor),
            historyScroll.trailingAnchor.constraint(equalTo: readout.trailingAnchor),
            historyScroll.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            historyScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26),
            historyEmpty.centerXAnchor.constraint(equalTo: readout.centerXAnchor),
            historyEmpty.centerYAnchor.constraint(equalTo: historyScroll.centerYAnchor),
            historyTools.trailingAnchor.constraint(equalTo: readout.trailingAnchor, constant: PillButton.pad),
            historyTools.topAnchor.constraint(equalTo: topAnchor, constant: -PillButton.pad + 1),
            tools.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tools.bottomAnchor.constraint(equalTo: bottomAnchor, constant: PillButton.pad - 4),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Replaces the keypad: `columns` columns of `keyWidth` wide keys, one stack row per entry of `rows`.
    func setKeypad(_ rows: [[KeyCell]], columns: Int, keyWidth: CGFloat, tool: Tool?, smallestDisplaySize: CGFloat) {
        keypad.arrangedSubviews.forEach { keypad.removeArrangedSubview($0); $0.removeFromSuperview() }
        clearButtons = []
        for cells in rows {
            let buttons = cells.map { cell -> PillButton in
                let width = CGFloat(cell.span) * keyWidth + CGFloat(cell.span - 1) * Self.gap
                let b = PillButton(title: cell.title, width: width, height: Self.keyHeight)
                b.isProminent = cell.prominent
                b.alphaValue = cell.dimmed ? 0.3 : 1
                b.onPress = { cell.action() }
                if cell.isClear { clearButtons.append(b) }
                return b
            }
            let stack = NSStackView(views: buttons)
            stack.orientation = .horizontal
            stack.spacing = Self.gap - 2 * PillButton.pad
            keypad.addArrangedSubview(stack)
        }
        keypadWidth.constant = CGFloat(columns) * keyWidth + CGFloat(columns - 1) * Self.gap + 2 * PillButton.pad
        extendedButton.isProminent = tool == .extended
        programmerButton.isProminent = tool == .programmer
        baseButton.isHidden = tool != .programmer
        self.smallestDisplaySize = smallestDisplaySize
        needsLayout = true
    }

    /// Shows the list of finished calculations instead of the number, or the number again.
    func setHistory(_ entries: [(expression: String, result: String)], visible: Bool) {
        historyStack.arrangedSubviews.forEach { historyStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (index, entry) in entries.enumerated() {
            let row = HistoryRowView(expression: entry.expression, result: entry.result)
            row.onPress = { [weak self] in self?.pickHistory(index) }
            historyStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true
        }
        historyScroll.isHidden = !visible || entries.isEmpty
        historyEmpty.isHidden = !visible || !entries.isEmpty
        readout.isHidden = visible
        clearHistoryButton.isHidden = !visible || entries.isEmpty
        historyButton.isProminent = visible
        historyScroll.documentView?.scroll(.zero)
    }

    func update(display: String, history: String, clearTitle: String, baseTitle: String) {
        displayLabel.stringValue = display
        historyLabel.stringValue = history.isEmpty ? " " : history
        clearButtons.forEach { $0.setTitle(clearTitle) }
        baseButton.setTitle(baseTitle)
        fitTexts()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        fitTexts()
    }

    /// Texts are as big as the free width allows, so long numbers shrink instead of being cut.
    private func fitTexts() {
        fit(displayLabel, baseSize: Self.displaySize, smallest: smallestDisplaySize, weight: .semibold)
        fit(historyLabel, baseSize: Self.historySize, smallest: 9, weight: .medium)
    }

    private func fit(_ label: NSTextField, baseSize: CGFloat, smallest: CGFloat, weight: NSFont.Weight) {
        let available = label.bounds.width
        guard available > 0 else { return }
        let base = NSFont.monospacedDigitSystemFont(ofSize: baseSize, weight: weight)
        let width = (label.stringValue as NSString).size(withAttributes: [.font: base]).width
        let size = max(smallest, min(baseSize, baseSize * (available - 16) / max(width, 1)))
        if abs(size - (label.font?.pointSize ?? 0)) > 0.25 {
            label.font = .monospacedDigitSystemFont(ofSize: size, weight: weight)
        }
    }

    func handleKey(_ event: NSEvent) -> Bool { onKeyEvent?(event) ?? false }
}

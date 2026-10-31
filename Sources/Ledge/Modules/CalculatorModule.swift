import AppKit
import LedgeCore

/// Calculator in three forms: the basic one, the extended one (parentheses, powers, fractions) and the programmer's
/// one (number bases, bitwise keys). The last two have a wider keypad behind a switch under the number.
/// Pure state and a page: nothing runs in the background and nothing is observed.
@MainActor
final class CalculatorModule: UIModule {
    let id = "calculator"
    var title: String { L10n.calculator }

    private enum Mode: Hashable { case basic, extended, programmer }

    private var basic = Calculator()
    private var extended = ExpressionCalculator()
    private var programmer = ProgrammerCalculator()
    private var mode = Mode.basic
    private var histories: [Mode: CalculationHistory] = [:]   // in memory only, one list per form
    private var showsHistory = false
    private var tiles: [TileView] = []
    private weak var page: CalculatorPageView?

    func start() throws {
        reset()
    }

    func stop() {
        tiles.removeAll()
        reset()
    }

    private func reset() {
        let separator = Locale.current.decimalSeparator?.first ?? "."
        basic = Calculator()
        basic.decimalSeparator = separator
        extended = ExpressionCalculator()
        extended.decimalSeparator = separator
        programmer = ProgrammerCalculator()
        mode = .basic
        histories = [:]
        showsHistory = false
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "plus.forwardslash.minus", title: title)
        tile.onPress = { Haptics.tick(.generic); open() }
        tiles.append(tile)
        apply(to: tile)
        return tile
    }

    func makePage() -> NSView? {
        let page = CalculatorPageView(
            toggleExtended: { [weak self] in self?.switchMode(to: .extended) },
            toggleProgrammer: { [weak self] in self?.switchMode(to: .programmer) },
            cycleBase: { [weak self] in self?.pressProgrammer(.setBase(self?.programmer.base.next ?? .decimal)) },
            toggleHistory: { [weak self] in self?.toggleHistory() },
            clearHistory: { [weak self] in self?.clearHistory() },
            pickHistory: { [weak self] in self?.pickHistory($0) })
        page.onKeyEvent = { [weak self] in self?.handle($0) ?? false }
        self.page = page
        installKeypad()
        refresh()
        return page
    }

    // MARK: Input

    /// The switch of the active mode returns to the basic one.
    private func switchMode(to new: Mode) {
        mode = mode == new ? .basic : new
        showsHistory = false
        installKeypad()
        refresh()
    }

    private func pressBasic(_ key: CalcKey) {
        showsHistory = false   // typing brings the number back
        let before = basic.history
        basic.press(key)
        recordIfFinished(before: before, history: basic.history, result: basic.display, value: basic.valueText)
        refresh()
    }

    private func pressExtended(_ key: ExprKey) {
        showsHistory = false
        let before = extended.history
        extended.press(key)
        recordIfFinished(before: before, history: extended.history, result: extended.display, value: extended.valueText)
        if key == .toggleFraction { installKeypad() }   // the a/b key shows whether fractions are on
        refresh()
    }

    private func pressProgrammer(_ key: ProgKey) {
        let before = programmer.base
        showsHistory = false
        let beforeHistory = programmer.history
        programmer.press(key)
        recordIfFinished(before: beforeHistory, history: programmer.history, result: programmer.display,
                         value: programmer.valueText)
        if programmer.base != before { installKeypad() }   // digits that do not exist in the base are dimmed
        refresh()
    }

    // MARK: History

    /// A calculation is finished when the small line changes to "… =".
    private func recordIfFinished(before: String, history: String, result: String, value: String) {
        guard history != before, history.hasSuffix(" ="), !isErrorShown else { return }
        histories[mode, default: CalculationHistory()]
            .add(expression: String(history.dropLast(2)), result: result, value: value)
    }

    private var isErrorShown: Bool {
        switch mode {
        case .basic: return basic.isError
        case .extended: return extended.isError
        case .programmer: return programmer.isError
        }
    }

    private func toggleHistory() {
        showsHistory.toggle()
        refresh()
    }

    private func clearHistory() {
        histories[mode]?.clear()
        refresh()
    }

    /// Takes the result of a past calculation over as the number on the display and goes back to the calculator.
    private func pickHistory(_ index: Int) {
        guard let entries = histories[mode]?.entries, entries.indices.contains(index) else { return }
        let value = entries[index].value
        showsHistory = false
        switch mode {
        case .basic:
            if let d = Decimal(string: value) { pressBasic(.value(d)) }
        case .extended:
            if let d = Decimal(string: value) { pressExtended(.value(d)) }
        case .programmer:
            if let i = Int64(value) { pressProgrammer(.value(i)) }
        }
        refresh()
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch mode {
        case .basic:
            guard let key = CalculatorKeyMap.basic(keyCode: event.keyCode, characters: event.characters) else { return false }
            pressBasic(key)
        case .extended:
            guard let key = CalculatorKeyMap.extended(keyCode: event.keyCode, characters: event.characters) else { return false }
            pressExtended(key)
        case .programmer:
            guard let key = CalculatorKeyMap.programmer(keyCode: event.keyCode, characters: event.characters) else { return false }
            pressProgrammer(key)
        }
        return true
    }

    // MARK: Keypads

    private func installKeypad() {
        switch mode {
        case .basic:
            page?.setKeypad(basicRows(), columns: 4, keyWidth: 44, tool: nil, smallestDisplaySize: 18)
        case .extended:
            page?.setKeypad(extendedRows(), columns: 6, keyWidth: 38, tool: .extended, smallestDisplaySize: 14)
        case .programmer:
            page?.setKeypad(programmerRows(), columns: 6, keyWidth: 38, tool: .programmer, smallestDisplaySize: 11)
        }
    }

    private func basicRows() -> [[KeyCell]] {
        func key(_ title: String, _ k: CalcKey, prominent: Bool = false, span: Int = 1) -> KeyCell {
            KeyCell(title: title, prominent: prominent, span: span, action: { [weak self] in self?.pressBasic(k) })
        }
        func digit(_ n: Int) -> KeyCell { key(String(n), .digit(n)) }
        func op(_ title: String, _ o: CalcOp) -> KeyCell { key(title, .op(o), prominent: true) }
        var clear = key("AC", .clear)
        clear.isClear = true
        return [
            [clear, key("±", .negate), key("%", .percent), op("÷", .divide)],
            [digit(7), digit(8), digit(9), op("×", .multiply)],
            [digit(4), digit(5), digit(6), op("−", .subtract)],
            [digit(1), digit(2), digit(3), op("+", .add)],
            [key("0", .digit(0), span: 2), key(Locale.current.decimalSeparator ?? ".", .decimalPoint),
             key("=", .equals, prominent: true)],
        ]
    }

    /// The basic grid plus two columns: parentheses, square, root, power, reciprocal, π, e, fractions and backspace.
    private func extendedRows() -> [[KeyCell]] {
        func key(_ title: String, _ k: ExprKey, prominent: Bool = false, span: Int = 1) -> KeyCell {
            KeyCell(title: title, prominent: prominent, span: span, action: { [weak self] in self?.pressExtended(k) })
        }
        func digit(_ n: Int) -> KeyCell { key(String(n), .digit(n)) }
        func op(_ title: String, _ o: CalcOp) -> KeyCell { key(title, .op(o), prominent: true) }
        var clear = key("AC", .clear)
        clear.isClear = true
        return [
            [clear, key("±", .negate), key("%", .percent), op("÷", .divide), key("(", .openParen), key(")", .closeParen)],
            [digit(7), digit(8), digit(9), op("×", .multiply), key("x²", .square), key("√", .squareRoot)],
            [digit(4), digit(5), digit(6), op("−", .subtract), key("xʸ", .power), key("1/x", .reciprocal)],
            [digit(1), digit(2), digit(3), op("+", .add), key("π", .pi), key("e", .euler)],
            [key("0", .digit(0), span: 2), key(Locale.current.decimalSeparator ?? ".", .decimalPoint),
             key("=", .equals, prominent: true), key("a/b", .toggleFraction, prominent: extended.showsFraction),
             key("⌫", .backspace)],
        ]
    }

    /// The basic grid (without ± and %, which the programmer's calculator does not need) plus two columns with
    /// the hexadecimal digits and the bitwise keys.
    private func programmerRows() -> [[KeyCell]] {
        let base = programmer.base
        func key(_ title: String, _ k: ProgKey, prominent: Bool = false, span: Int = 1) -> KeyCell {
            KeyCell(title: title, prominent: prominent, span: span, action: { [weak self] in self?.pressProgrammer(k) })
        }
        func digit(_ n: Int) -> KeyCell {
            var cell = key(String(n, radix: 16, uppercase: true), .digit(n))
            cell.dimmed = !base.allows(n)
            return cell
        }
        func op(_ title: String, _ o: ProgOp) -> KeyCell { key(title, .op(o), prominent: true) }
        var clear = key("AC", .clear)
        clear.isClear = true
        return [
            [clear, key("<<", .op(.shiftLeft)), key(">>", .op(.shiftRight)), op("÷", .divide), digit(10), digit(11)],
            [digit(7), digit(8), digit(9), op("×", .multiply), digit(12), digit(13)],
            [digit(4), digit(5), digit(6), op("−", .subtract), digit(14), digit(15)],
            [digit(1), digit(2), digit(3), op("+", .add), key("AND", .op(.and)), key("OR", .op(.or))],
            [key("0", .digit(0), span: 2), key("mod", .op(.modulo)), key("=", .equals, prominent: true),
             key("XOR", .op(.xor)), key("NOT", .not)],
        ]
    }

    // MARK: Display

    private var shownText: String {
        switch mode {
        case .basic: return basic.isError ? L10n.error : basic.display
        case .extended: return extended.isError ? L10n.error : extended.display
        case .programmer: return programmer.isError ? L10n.error : programmer.display
        }
    }

    private func refresh() {
        tiles.forEach(apply)
        let history: String
        let clearsEverything: Bool
        switch mode {
        case .basic: (history, clearsEverything) = (basic.history, basic.clearsEverything)
        case .extended: (history, clearsEverything) = (extended.history, extended.clearsEverything)
        case .programmer: (history, clearsEverything) = (programmer.history, programmer.clearsEverything)
        }
        page?.setHistory((histories[mode]?.entries ?? []).map { ($0.expression, $0.result) }, visible: showsHistory)
        page?.update(display: shownText, history: history, clearTitle: clearsEverything ? "AC" : "C",
                     baseTitle: programmer.base.label)
    }

    private func apply(to tile: TileView) {
        tile.statusText = basic.isError ? L10n.error : basic.display
    }
}

import Foundation

public enum ExprKey: Equatable, Sendable {
    case digit(Int)
    case decimalPoint
    case op(CalcOp)
    case power, openParen, closeParen
    case equals, negate, percent
    case square, squareRoot, reciprocal
    case pi, euler
    case toggleFraction
    case backspace, clear
    /// A number put on the display as if it was typed (a result taken from the history).
    case value(Decimal)
}

/// The extended calculator: a whole expression with parentheses, usual operator precedence, powers, roots and
/// reciprocals, and results that can be shown as common fractions. Arithmetic is decimal (0.1 + 0.2 is 0.3).
public struct ExpressionCalculator: Equatable, Sendable {
    public var decimalSeparator: Character = "."
    public private(set) var isError = false
    public private(set) var showsFraction = false

    private enum Token: Equatable, Sendable {
        case number(Decimal)
        case op(CalcOp)
        case power
        case open, close
    }

    private var tokens: [Token] = []
    private var entry: String?
    private var current: Decimal = 0
    private var resultShown = false
    private var historyText = ""

    public init() {}

    public var display: String {
        if isError { return "Error" }
        if let entry { return Self.localised(entry, decimalSeparator) }
        if showsFraction, let fraction = FractionFormat.string(for: current) { return fraction }
        return Self.localised(Calculator.format(current), decimalSeparator)
    }

    /// The expression so far in small text, for example "( 2 + 3 ) ×" or "( 2 + 3 ) × 4 =".
    public var history: String {
        if !historyText.isEmpty { return Self.localised(historyText, decimalSeparator) }
        return Self.localised(tokens.map(Self.text).joined(separator: " "), decimalSeparator)
    }

    public var clearsEverything: Bool { entry == nil || entry == "0" }

    /// The number on the display with a decimal point, whatever the separator.
    public var valueText: String { entry.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 } ?? Calculator.format(current) }

    public mutating func press(_ key: ExprKey) {
        if key == .clear { clear(); return }
        if isError { return }
        switch key {
        case .digit(let d): typeDigit(d)
        case .decimalPoint: typePoint()
        case .op(let o): chooseOperator(.op(o))
        case .power: chooseOperator(.power)
        case .openParen: openGroup()
        case .closeParen: closeGroup()
        case .equals: evaluate()
        case .negate: negate()
        case .percent: percent()
        case .square: unary { $0 * $0 }
        case .squareRoot: unary { $0 < 0 ? nil : Self.decimal(sqrt(NSDecimalNumber(decimal: $0).doubleValue)) }
        case .reciprocal: unary { $0 == 0 ? nil : 1 / $0 }
        case .pi: constant("3.14159265358979")
        case .euler: constant("2.71828182845905")
        case .toggleFraction: showsFraction.toggle()
        case .backspace: backspace()
        case .value(let v): beginNumber(); entry = Calculator.format(v)
        case .clear: break
        }
    }

    // MARK: Entry

    private mutating func startFreshIfResultShown() {
        if resultShown { tokens = []; resultShown = false; historyText = "" }
    }

    /// A number or "(" typed right after a number or ")" means a multiplication.
    private mutating func insertImplicitMultiplication() {
        if let last = tokens.last, last == .close { tokens.append(.op(.multiply)) }
    }

    private mutating func typeDigit(_ d: Int) {
        guard (0...9).contains(d) else { return }
        beginNumber()
        var text = entry ?? ""
        if text == "0" || text == "-0" { text.removeLast() }
        guard text.filter(\.isNumber).count < Calculator.maxDigits else { return }
        entry = text + String(d)
    }

    private mutating func typePoint() {
        beginNumber()
        let text = entry ?? "0"
        if !text.contains(".") { entry = text + "." }
    }

    private mutating func beginNumber() {
        startFreshIfResultShown()
        if entry == nil { insertImplicitMultiplication() }
    }

    private var typedValue: Decimal? {
        guard let text = entry else { return nil }
        return Decimal(string: text.hasSuffix(".") ? String(text.dropLast()) : text)
    }

    /// Moves the typed number into the expression.
    private mutating func commitEntry() {
        if let value = typedValue { tokens.append(.number(value)) }
        entry = nil
    }

    private mutating func negate() {
        if let text = entry {
            entry = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
        } else if resultShown || tokens.isEmpty {
            current = -current
        } else if let last = tokens.last, last != .close {
            entry = "-0"
        }
    }

    private mutating func percent() {
        if let value = typedValue {
            entry = Calculator.format(value / 100)
        } else if resultShown {
            current /= 100
        }
    }

    private mutating func constant(_ text: String) {
        beginNumber()
        entry = text
    }

    /// A function of the number on the display (the typed one or the last result).
    private mutating func unary(_ transform: (Decimal) -> Decimal?) {
        if let value = typedValue {
            guard let r = transform(value), !r.isNaN else { fail(); return }
            entry = Calculator.format(r)
        } else if resultShown || tokens.isEmpty {
            guard let r = transform(current), !r.isNaN else { fail(); return }
            current = r
            resultShown = true
            tokens = []
            historyText = ""
        }
    }

    private mutating func backspace() {
        if var text = entry {
            text.removeLast()
            entry = (text.isEmpty || text == "-") ? nil : text
        } else if !resultShown, !tokens.isEmpty {
            tokens.removeLast()
            // Deleting an operator reopens the number before it for editing.
            if case .number(let value)? = tokens.last {
                tokens.removeLast()
                entry = Calculator.format(value)
            }
        }
    }

    private mutating func clear() {
        if let text = entry, text != "0" { entry = "0"; return }
        let separator = decimalSeparator
        self = ExpressionCalculator()
        decimalSeparator = separator
    }

    // MARK: Structure

    private mutating func chooseOperator(_ token: Token) {
        if resultShown {
            tokens = [.number(current)]
            resultShown = false
            historyText = ""
        } else {
            commitEntry()
        }
        if tokens.isEmpty { tokens.append(.number(current)) }
        switch tokens.last {
        case .number, .close: tokens.append(token)
        case .op, .power: tokens[tokens.count - 1] = token
        case .open, .none: break
        }
    }

    private var depth: Int {
        tokens.reduce(0) { $0 + ($1 == .open ? 1 : $1 == .close ? -1 : 0) }
    }

    private mutating func openGroup() {
        startFreshIfResultShown()
        commitEntry()
        insertImplicitMultiplicationBeforeGroup()
        tokens.append(.open)
    }

    private mutating func insertImplicitMultiplicationBeforeGroup() {
        switch tokens.last {
        case .number, .close: tokens.append(.op(.multiply))
        default: break
        }
    }

    private mutating func closeGroup() {
        guard !resultShown, depth > 0 else { return }
        commitEntry()
        switch tokens.last {
        case .number, .close: tokens.append(.close)
        default: break
        }
    }

    // MARK: Evaluation

    private mutating func evaluate() {
        if resultShown { return }
        commitEntry()
        while let last = tokens.last, last != .close, !isNumber(last) { tokens.removeLast() }
        if tokens.isEmpty {
            historyText = "\(Calculator.format(current)) ="
            resultShown = true
            return
        }
        tokens += Array(repeating: .close, count: depth)
        var parser = Parser(tokens: tokens.map(Self.parserToken))
        guard let value = parser.parse(), !value.isNaN else { fail(); return }
        historyText = tokens.map(Self.text).joined(separator: " ") + " ="
        current = value
        tokens = []
        resultShown = true
    }

    private func isNumber(_ token: Token) -> Bool {
        if case .number = token { return true }
        return false
    }

    private mutating func fail() {
        isError = true
        tokens = []
        entry = nil
        historyText = ""
    }

    // MARK: Helpers

    private static func localised(_ text: String, _ separator: Character) -> String {
        separator == "." ? text : text.replacingOccurrences(of: ".", with: String(separator))
    }

    private static func text(_ token: Token) -> String {
        switch token {
        case .number(let v): return Calculator.format(v)
        case .op(.add): return "+"
        case .op(.subtract): return "−"
        case .op(.multiply): return "×"
        case .op(.divide): return "÷"
        case .power: return "^"
        case .open: return "("
        case .close: return ")"
        }
    }

    private static func parserToken(_ token: Token) -> Parser.Item {
        switch token {
        case .number(let v): return .number(v)
        case .op(let o): return .op(o)
        case .power: return .power
        case .open: return .open
        case .close: return .close
        }
    }

    fileprivate static func decimal(_ d: Double) -> Decimal? {
        d.isFinite ? Decimal(string: "\(d)") : nil
    }

    /// Recursive descent: sum → product → power → primary.
    private struct Parser {
        enum Item: Equatable { case number(Decimal), op(CalcOp), power, open, close }

        let tokens: [Item]
        var index = 0

        init(tokens: [Item]) { self.tokens = tokens }

        mutating func parse() -> Decimal? {
            guard let value = sum(), index == tokens.count else { return nil }
            return value
        }

        private var next: Item? { index < tokens.count ? tokens[index] : nil }

        private mutating func sum() -> Decimal? {
            guard var left = product() else { return nil }
            while case .op(let o)? = next, o == .add || o == .subtract {
                index += 1
                guard let right = product() else { return nil }
                left = o == .add ? left + right : left - right
            }
            return left
        }

        private mutating func product() -> Decimal? {
            guard var left = powered() else { return nil }
            while case .op(let o)? = next, o == .multiply || o == .divide {
                index += 1
                guard let right = powered() else { return nil }
                if o == .multiply { left *= right } else {
                    if right == 0 { return nil }
                    left /= right
                }
            }
            return left
        }

        private mutating func powered() -> Decimal? {
            guard let base = primary() else { return nil }
            guard case .power? = next else { return base }
            index += 1
            guard let exponent = powered() else { return nil }   // right-associative
            return Self.raise(base, to: exponent)
        }

        private mutating func primary() -> Decimal? {
            switch next {
            case .number(let v)?:
                index += 1
                return v
            case .open?:
                index += 1
                guard let inner = sum(), case .close? = next else { return nil }
                index += 1
                return inner
            default:
                return nil
            }
        }

        private static func raise(_ base: Decimal, to exponent: Decimal) -> Decimal? {
            let e = NSDecimalNumber(decimal: exponent).doubleValue
            if e == e.rounded(), abs(e) <= 1000 {
                let n = Int(e)
                if n == 0 { return 1 }
                if base == 0 { return n < 0 ? nil : 0 }
                let p = pow(base, abs(n))
                return n < 0 ? 1 / p : p
            }
            if base < 0 { return nil }
            return ExpressionCalculator.decimal(pow(NSDecimalNumber(decimal: base).doubleValue, e))
        }
    }
}

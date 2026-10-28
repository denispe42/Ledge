import Foundation

public enum CalcOp: Equatable, Sendable { case add, subtract, multiply, divide }

public enum CalcKey: Equatable, Sendable {
    case digit(Int)
    case decimalPoint
    case op(CalcOp)
    case equals, percent, negate, backspace, clear
    /// A whole number put on the display as if it was typed (a result taken from the history).
    case value(Decimal)
}

/// A four-function calculator with the behaviour of the system one: chained operations run left to right, `=` repeats
/// the last operation, `%` is a share of the first number after + and −. Arithmetic is decimal, so 0.1 + 0.2 is 0.3.
public struct Calculator: Equatable, Sendable {
    public static let maxDigits = 15

    /// Shown instead of a decimal point (the UI sets the locale's one). Internally the point is always ".".
    public var decimalSeparator: Character = "."
    public private(set) var isError = false

    private var historyText = ""
    private var entry: String?            // the number being typed; nil when `current` is a result
    private var current: Decimal = 0
    private var accumulator: Decimal?
    private var pending: CalcOp?
    private var lastOp: CalcOp?
    private var lastOperand: Decimal = 0
    private var resultShown = false
    private var operandSupplied = false   // `current` was produced by % and counts as the second operand

    public init() {}

    /// Text for the display; "Error" while `isError` (the UI shows its own localised word).
    public var display: String {
        if isError { return "Error" }
        let text = entry ?? Self.format(current)
        return Self.localised(text, separator: decimalSeparator)
    }

    private static func localised(_ text: String, separator: Character) -> String {
        separator == "." ? text : text.replacingOccurrences(of: ".", with: String(separator))
    }

    /// The calculation so far in small text above the number: "7 ×" while an operation waits, "7 × 8 =" after `=`.
    public var history: String { Self.localised(historyText, separator: decimalSeparator) }

    /// True when the next `clear` wipes everything (the key reads "AC"); otherwise it clears only the typed number ("C").
    public var clearsEverything: Bool { entry == nil || entry == "0" }

    public mutating func press(_ key: CalcKey) {
        if key == .clear { clear(); return }
        if isError { return }
        switch key {
        case .digit(let d): typeDigit(d)
        case .decimalPoint: typePoint()
        case .op(let o): choose(o)
        case .equals: evaluate()
        case .percent: percent()
        case .negate: negate()
        case .backspace: backspace()
        case .value(let v): insert(v)
        case .clear: break
        }
    }

    /// The number on the display with a decimal point, whatever the separator: the value to take over or store.
    public var valueText: String { entry.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 } ?? Self.format(current) }

    // MARK: Entry

    private mutating func startNumberIfResultShown() {
        if resultShown { accumulator = nil; pending = nil; resultShown = false; historyText = "" }
        operandSupplied = false
    }

    private mutating func typeDigit(_ d: Int) {
        guard (0...9).contains(d) else { return }
        startNumberIfResultShown()
        var text = entry ?? ""
        if text == "0" || text == "-0" { text.removeLast() }
        guard text.filter(\.isNumber).count < Self.maxDigits else { return }
        entry = text + String(d)
    }

    private mutating func insert(_ value: Decimal) {
        startNumberIfResultShown()
        entry = Self.format(value)
    }

    private mutating func typePoint() {
        startNumberIfResultShown()
        let text = entry ?? "0"
        if !text.contains(".") { entry = text + "." }
    }

    private mutating func negate() {
        if let text = entry {
            entry = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
        } else if pending != nil && !operandSupplied {
            entry = "-0"
        } else {
            current = -current
        }
    }

    private mutating func backspace() {
        guard var text = entry else { return }
        text.removeLast()
        entry = (text.isEmpty || text == "-") ? "0" : text
    }

    private mutating func clear() {
        if let text = entry, text != "0" { entry = "0"; return }
        self = Calculator(keepingSeparator: decimalSeparator)
    }

    private init(keepingSeparator: Character) { decimalSeparator = keepingSeparator }

    // MARK: Arithmetic

    private var typedValue: Decimal? {
        guard let text = entry else { return nil }
        return Decimal(string: text.hasSuffix(".") ? String(text.dropLast()) : text)
    }

    private mutating func choose(_ op: CalcOp) {
        let supplied = entry != nil || operandSupplied
        if let p = pending, let a = accumulator, supplied {
            guard let r = Self.apply(p, a, typedValue ?? current) else { fail(); return }
            accumulator = r
            current = r
        } else if pending == nil {
            accumulator = typedValue ?? current
            current = accumulator ?? 0
        }
        pending = op
        historyText = "\(Self.format(accumulator ?? current)) \(Self.symbol(op))"
        entry = nil
        resultShown = false
        operandSupplied = false
    }

    private mutating func evaluate() {
        let operand = typedValue ?? current
        if let p = pending, let a = accumulator {
            guard let r = Self.apply(p, a, operand) else { fail(); return }
            lastOp = p
            lastOperand = operand
            historyText = "\(Self.format(a)) \(Self.symbol(p)) \(Self.format(operand)) ="
            current = r
        } else if resultShown, let op = lastOp {
            guard let r = Self.apply(op, current, lastOperand) else { fail(); return }
            historyText = "\(Self.format(current)) \(Self.symbol(op)) \(Self.format(lastOperand)) ="
            current = r
        } else {
            historyText = "\(Self.format(operand)) ="
            current = operand
        }
        accumulator = nil
        pending = nil
        entry = nil
        resultShown = true
        operandSupplied = false
    }

    private mutating func percent() {
        let value = typedValue ?? current
        if let p = pending, let a = accumulator, p == .add || p == .subtract {
            current = a * value / 100
        } else {
            current = value / 100
        }
        entry = nil
        operandSupplied = true
    }

    private mutating func fail() {
        isError = true
        historyText = ""
        entry = nil
        accumulator = nil
        pending = nil
    }

    private static func symbol(_ op: CalcOp) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }

    private static func apply(_ op: CalcOp, _ a: Decimal, _ b: Decimal) -> Decimal? {
        let r: Decimal
        switch op {
        case .add: r = a + b
        case .subtract: r = a - b
        case .multiply: r = a * b
        case .divide:
            if b == 0 { return nil }
            r = a / b
        }
        return r.isNaN ? nil : r
    }

    /// Up to `maxDigits` significant digits, no exponent, no trailing zeros.
    static func format(_ value: Decimal) -> String {
        if value == 0 { return "0" }
        var v = value
        let magnitude = NSDecimalNumber(decimal: value).doubleValue.magnitude
        let integerDigits = Int(log10(magnitude).rounded(.down)) + 1
        let scale = min(max(maxDigits - integerDigits, 0), maxDigits)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &v, scale, .plain)
        return "\(rounded)"
    }
}

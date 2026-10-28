import Foundation

public enum ProgBase: Int, CaseIterable, Sendable {
    case binary = 2, octal = 8, decimal = 10, hexadecimal = 16

    /// Whether a digit key with this value works in the base.
    public func allows(_ digit: Int) -> Bool { digit >= 0 && digit < rawValue }

    public var label: String {
        switch self {
        case .binary: return "BIN"
        case .octal: return "OCT"
        case .decimal: return "DEC"
        case .hexadecimal: return "HEX"
        }
    }

    /// The base after this one when the base key is pressed repeatedly.
    public var next: ProgBase {
        switch self {
        case .decimal: return .hexadecimal
        case .hexadecimal: return .binary
        case .binary: return .octal
        case .octal: return .decimal
        }
    }
}

public enum ProgOp: Equatable, Sendable {
    case add, subtract, multiply, divide, modulo, and, or, xor, shiftLeft, shiftRight
}

public enum ProgKey: Equatable, Sendable {
    case digit(Int)        // 0...15
    case op(ProgOp)
    case equals, not, backspace, clear
    case setBase(ProgBase)
    /// A number put on the display as if it was typed (a result taken from the history).
    case value(Int64)
}

/// The programmer's calculator: 64-bit signed integers, entry and display in binary, octal, decimal or hexadecimal,
/// bitwise operations and shifts. Arithmetic wraps around on overflow. Outside decimal a negative number is shown as
/// its 64-bit two's complement. Chains, `=` repeat and the history line work as in `Calculator`.
public struct ProgrammerCalculator: Equatable, Sendable {
    public private(set) var base: ProgBase = .decimal
    public private(set) var isError = false

    private var entry: String?
    private var current: Int64 = 0
    private var accumulator: Int64?
    private var pending: ProgOp?
    private var lastOp: ProgOp?
    private var lastOperand: Int64 = 0
    private var resultShown = false
    private var operandSupplied = false
    private var historyText = ""

    public init() {}

    public var display: String { isError ? "Error" : (entry ?? format(current)) }
    public var history: String { historyText }
    public var clearsEverything: Bool { entry == nil || entry == "0" }

    /// The number on the display as a signed decimal, whatever the base.
    public var valueText: String { String(typedValue ?? current) }

    public mutating func press(_ key: ProgKey) {
        if key == .clear { clear(); return }
        if isError { return }
        switch key {
        case .digit(let d): typeDigit(d)
        case .op(let o): choose(o)
        case .equals: evaluate()
        case .not: invert()
        case .backspace: backspace()
        case .setBase(let b): changeBase(to: b)
        case .value(let v): insert(v)
        case .clear: break
        }
    }

    // MARK: Entry

    private func parse(_ text: String) -> Int64? {
        guard let bits = UInt64(text, radix: base.rawValue) else { return nil }
        if base == .decimal && bits > UInt64(Int64.max) { return nil }
        return Int64(bitPattern: bits)
    }

    private func format(_ value: Int64) -> String {
        base == .decimal ? String(value) : String(UInt64(bitPattern: value), radix: base.rawValue, uppercase: true)
    }

    private var typedValue: Int64? { entry.flatMap(parse) }

    private mutating func typeDigit(_ d: Int) {
        guard base.allows(d) else { return }
        if resultShown { accumulator = nil; pending = nil; resultShown = false; historyText = "" }
        operandSupplied = false
        var text = entry ?? ""
        if text == "0" { text = "" }
        text += String(d, radix: 16, uppercase: true)
        if parse(text) != nil { entry = text }
    }

    private mutating func insert(_ value: Int64) {
        if resultShown { accumulator = nil; pending = nil; resultShown = false; historyText = "" }
        if value >= 0 || base != .decimal {
            entry = format(value)
            operandSupplied = false
        } else {
            // A negative decimal cannot be typed (there is no sign key): keep it as a finished operand.
            entry = nil
            current = value
            operandSupplied = true
        }
    }

    private mutating func backspace() {
        guard var text = entry else { return }
        text.removeLast()
        entry = text.isEmpty ? "0" : text
    }

    private mutating func clear() {
        if let text = entry, text != "0" { entry = "0"; return }
        var fresh = ProgrammerCalculator()
        fresh.base = base
        self = fresh
    }

    private mutating func changeBase(to newBase: ProgBase) {
        if let v = typedValue {
            current = v
            entry = nil
            operandSupplied = true
        }
        base = newBase
    }

    private mutating func invert() {
        if entry == nil && pending != nil && !operandSupplied { return }
        current = ~(typedValue ?? current)
        entry = nil
        operandSupplied = true
    }

    // MARK: Arithmetic

    private mutating func choose(_ op: ProgOp) {
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
        historyText = "\(format(accumulator ?? current)) \(Self.symbol(op))"
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
            historyText = "\(format(a)) \(Self.symbol(p)) \(format(operand)) ="
            current = r
        } else if resultShown, let op = lastOp {
            guard let r = Self.apply(op, current, lastOperand) else { fail(); return }
            historyText = "\(format(current)) \(Self.symbol(op)) \(format(lastOperand)) ="
            current = r
        } else {
            historyText = "\(format(operand)) ="
            current = operand
        }
        accumulator = nil
        pending = nil
        entry = nil
        resultShown = true
        operandSupplied = false
    }

    private mutating func fail() {
        isError = true
        historyText = ""
        entry = nil
        accumulator = nil
        pending = nil
    }

    private static func symbol(_ op: ProgOp) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .modulo: return "mod"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .shiftLeft: return "<<"
        case .shiftRight: return ">>"
        }
    }

    private static func apply(_ op: ProgOp, _ a: Int64, _ b: Int64) -> Int64? {
        switch op {
        case .add: return a &+ b
        case .subtract: return a &- b
        case .multiply: return a &* b
        case .divide: return b == 0 ? nil : a.dividedReportingOverflow(by: b).partialValue
        case .modulo: return b == 0 ? nil : a.remainderReportingOverflow(dividingBy: b).partialValue
        case .and: return a & b
        case .or: return a | b
        case .xor: return a ^ b
        case .shiftLeft: return (0..<64).contains(b) ? a << b : 0
        case .shiftRight: return (0..<64).contains(b) ? a >> b : (a < 0 ? -1 : 0)
        }
    }
}

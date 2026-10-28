import LedgeCore

/// Keyboard to calculator keys. Keypad key codes first (they do not depend on the keyboard layout), then the typed
/// character.
enum CalculatorKeyMap {
    static func basic(keyCode: UInt16, characters: String?) -> CalcKey? {
        if let key = fromKeyCode(keyCode) { return key }
        guard let c = characters?.first else { return nil }
        if let n = c.wholeNumberValue, c.isASCII { return .digit(n) }
        switch c {
        case ".", ",": return .decimalPoint
        case "+": return .op(.add)
        case "-": return .op(.subtract)
        case "*", "x", "×": return .op(.multiply)
        case "/", "÷": return .op(.divide)
        case "=": return .equals
        case "%": return .percent
        default: return nil
        }
    }

    static func extended(keyCode: UInt16, characters: String?) -> ExprKey? {
        if let key = fromKeyCode(keyCode) { return exprKey(key) }
        guard let c = characters?.first else { return nil }
        if let n = c.wholeNumberValue, c.isASCII { return .digit(n) }
        switch c {
        case ".", ",": return .decimalPoint
        case "+": return .op(.add)
        case "-": return .op(.subtract)
        case "*", "x", "×": return .op(.multiply)
        case "/", "÷": return .op(.divide)
        case "^": return .power
        case "(": return .openParen
        case ")": return .closeParen
        case "=": return .equals
        case "%": return .percent
        default: return nil
        }
    }

    static func programmer(keyCode: UInt16, characters: String?) -> ProgKey? {
        if let key = fromKeyCode(keyCode) { return progKey(key) }
        // Letters by the physical key (A B C D E F on a US keyboard), so a Russian layout does not matter.
        if let digit = hexLetterKeyCodes[keyCode] { return .digit(digit) }
        guard let c = characters?.first else { return nil }
        if let n = c.hexDigitValue, c.isASCII { return .digit(n) }
        switch c {
        case "+": return .op(.add)
        case "-": return .op(.subtract)
        case "*", "×": return .op(.multiply)
        case "/", "÷": return .op(.divide)
        case "%": return .op(.modulo)
        case "&": return .op(.and)
        case "|": return .op(.or)
        case "^": return .op(.xor)
        case "<": return .op(.shiftLeft)
        case ">": return .op(.shiftRight)
        case "~": return .not
        case "=": return .equals
        default: return nil
        }
    }

    private static func exprKey(_ key: CalcKey) -> ExprKey? {
        switch key {
        case .digit(let d): return .digit(d)
        case .decimalPoint: return .decimalPoint
        case .op(let o): return .op(o)
        case .equals: return .equals
        case .backspace: return .backspace
        case .clear: return .clear
        case .percent: return .percent
        case .negate: return .negate
        case .value: return nil
        }
    }

    private static let hexLetterKeyCodes: [UInt16: Int] = [0: 10, 11: 11, 8: 12, 2: 13, 14: 14, 3: 15]

    private static func progKey(_ key: CalcKey) -> ProgKey? {
        switch key {
        case .digit(let d): return .digit(d)
        case .op(.add): return .op(.add)
        case .op(.subtract): return .op(.subtract)
        case .op(.multiply): return .op(.multiply)
        case .op(.divide): return .op(.divide)
        case .equals: return .equals
        case .backspace: return .backspace
        case .clear: return .clear
        case .decimalPoint, .percent, .negate, .value: return nil
        }
    }

    private static func fromKeyCode(_ code: UInt16) -> CalcKey? {
        switch code {
        case 82: return .digit(0)
        case 83: return .digit(1)
        case 84: return .digit(2)
        case 85: return .digit(3)
        case 86: return .digit(4)
        case 87: return .digit(5)
        case 88: return .digit(6)
        case 89: return .digit(7)
        case 91: return .digit(8)
        case 92: return .digit(9)
        case 65: return .decimalPoint
        case 67: return .op(.multiply)
        case 69: return .op(.add)
        case 75: return .op(.divide)
        case 78: return .op(.subtract)
        case 81, 76, 36: return .equals          // keypad =, Enter, Return
        case 51: return .backspace
        case 117, 71: return .clear              // forward delete, keypad Clear
        default: return nil
        }
    }
}

import Testing
@testable import LedgeCore

private func run(_ keys: [ProgKey], base: ProgBase = .decimal) -> ProgrammerCalculator {
    var c = ProgrammerCalculator()
    c.press(.setBase(base))
    keys.forEach { c.press($0) }
    return c
}

private func digits(_ s: String) -> [ProgKey] {
    s.map { .digit(Int(String($0), radix: 16)!) }
}

@Test func programmerStartsAtZeroInDecimal() {
    let c = ProgrammerCalculator()
    #expect(c.display == "0")
    #expect(c.base == .decimal)
}

@Test func digitsAreLimitedByTheBase() {
    #expect(run(digits("19"), base: .binary).display == "1")
    #expect(run(digits("789"), base: .octal).display == "7")
    #expect(run(digits("FF"), base: .decimal).display == "0")
    #expect(run(digits("FF"), base: .hexadecimal).display == "FF")
    #expect(run(digits("1010"), base: .binary).display == "1010")
}

@Test func enabledDigitsFollowTheBase() {
    #expect(ProgBase.binary.allows(1) && !ProgBase.binary.allows(2))
    #expect(ProgBase.decimal.allows(9) && !ProgBase.decimal.allows(10))
    #expect(ProgBase.hexadecimal.allows(15))
}

@Test func switchingBaseKeepsTheValue() {
    var c = run(digits("255"))
    c.press(.setBase(.hexadecimal))
    #expect(c.display == "FF")
    c.press(.setBase(.binary))
    #expect(c.display == "11111111")
    c.press(.setBase(.octal))
    #expect(c.display == "377")
    c.press(.setBase(.decimal))
    #expect(c.display == "255")
}

@Test func integerArithmetic() {
    #expect(run(digits("12") + [.op(.add)] + digits("30") + [.equals]).display == "42")
    #expect(run(digits("7") + [.op(.divide)] + digits("2") + [.equals]).display == "3")
    #expect(run(digits("7") + [.op(.modulo)] + digits("4") + [.equals]).display == "3")
    #expect(run(digits("3") + [.op(.subtract)] + digits("5") + [.equals]).display == "-2")
}

@Test func bitwiseOperations() {
    #expect(run(digits("F0") + [.op(.and)] + digits("3C") + [.equals], base: .hexadecimal).display == "30")
    #expect(run(digits("F0") + [.op(.or)] + digits("0F") + [.equals], base: .hexadecimal).display == "FF")
    #expect(run(digits("FF") + [.op(.xor)] + digits("0F") + [.equals], base: .hexadecimal).display == "F0")
    #expect(run(digits("1") + [.op(.shiftLeft)] + digits("4") + [.equals]).display == "16")
    #expect(run(digits("20") + [.op(.shiftRight)] + digits("2") + [.equals]).display == "5")
}

@Test func notFlipsAllBits() {
    #expect(run(digits("0") + [.not]).display == "-1")
    #expect(run(digits("0") + [.not], base: .hexadecimal).display == "FFFFFFFFFFFFFFFF")
    #expect(run(digits("F") + [.not, .not], base: .hexadecimal).display == "F")
}

@Test func negativeValuesAreTwosComplementOutsideDecimal() {
    var c = run(digits("1") + [.op(.subtract)] + digits("2") + [.equals])
    #expect(c.display == "-1")
    c.press(.setBase(.hexadecimal))
    #expect(c.display == "FFFFFFFFFFFFFFFF")
}

@Test func divisionByZeroIsAnError() {
    var c = run(digits("5") + [.op(.divide)] + digits("0") + [.equals])
    #expect(c.isError)
    c.press(.clear)
    #expect(!c.isError)
    #expect(run(digits("5") + [.op(.modulo)] + digits("0") + [.equals]).isError)
}

@Test func overflowWrapsAroundInsteadOfCrashing() {
    let c = run(digits("9223372036854775807") + [.op(.add)] + digits("1") + [.equals])
    #expect(c.display == "-9223372036854775808")
}

@Test func tooLongEntryIsIgnored() {
    #expect(run(digits("9223372036854775808")).display == "922337203685477580")   // would exceed Int64.max
    #expect(run(digits("FFFFFFFFFFFFFFFFF"), base: .hexadecimal).display == "FFFFFFFFFFFFFFFF")
}

@Test func hugeShiftGivesZero() {
    #expect(run(digits("1") + [.op(.shiftLeft)] + digits("64") + [.equals]).display == "0")
}

@Test func programmerHistoryUsesTheCurrentBase() {
    let c = run(digits("F0") + [.op(.and)] + digits("3C") + [.equals], base: .hexadecimal)
    #expect(c.history == "F0 AND 3C =")
    #expect(run(digits("7") + [.op(.add)]).history == "7 +")
}

@Test func chainsEqualsRepeatAndBackspace() {
    #expect(run(digits("2") + [.op(.add)] + digits("3") + [.op(.multiply)] + digits("4") + [.equals]).display == "20")
    #expect(run(digits("5") + [.op(.add)] + digits("2") + [.equals, .equals]).display == "9")
    #expect(run(digits("123") + [.backspace]).display == "12")
    #expect(run(digits("7") + [.op(.add)] + digits("1") + [.clear, .digit(2), .equals]).display == "9")
}

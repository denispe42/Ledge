import Testing
@testable import LedgeCore

private func run(_ keys: [CalcKey]) -> Calculator {
    var c = Calculator()
    keys.forEach { c.press($0) }
    return c
}

private func digits(_ s: String) -> [CalcKey] {
    s.map { $0 == "." ? .decimalPoint : .digit(Int(String($0))!) }
}

@Test func startsAtZero() {
    #expect(Calculator().display == "0")
}

@Test func digitsAppendAndLeadingZeroIsReplaced() {
    #expect(run(digits("007")).display == "7")
    #expect(run(digits("120")).display == "120")
}

@Test func decimalPointIsAddedOnce() {
    #expect(run(digits("1.2.3")).display == "1.23")
    #expect(run([.decimalPoint, .digit(5)]).display == "0.5")
}

@Test func basicOperations() {
    #expect(run(digits("12") + [.op(.add)] + digits("30") + [.equals]).display == "42")
    #expect(run(digits("9") + [.op(.subtract)] + digits("12") + [.equals]).display == "-3")
    #expect(run(digits("6") + [.op(.multiply)] + digits("7") + [.equals]).display == "42")
    #expect(run(digits("1") + [.op(.divide)] + digits("4") + [.equals]).display == "0.25")
}

@Test func chainedOperationsEvaluateLeftToRight() {
    let c = run(digits("2") + [.op(.add)] + digits("3") + [.op(.multiply)] + digits("4") + [.equals])
    #expect(c.display == "20")
}

@Test func operatorShownAfterChainIsPartialResult() {
    let c = run(digits("2") + [.op(.add)] + digits("3") + [.op(.multiply)])
    #expect(c.display == "5")
}

@Test func pressingAnotherOperatorReplacesThePending() {
    let c = run(digits("8") + [.op(.add), .op(.subtract)] + digits("3") + [.equals])
    #expect(c.display == "5")
}

@Test func equalsRepeatsLastOperation() {
    let c = run(digits("5") + [.op(.add)] + digits("2") + [.equals, .equals, .equals])
    #expect(c.display == "11")
}

@Test func typingAfterResultStartsANewNumber() {
    let c = run(digits("1") + [.op(.add)] + digits("1") + [.equals] + digits("7"))
    #expect(c.display == "7")
}

@Test func operatorAfterResultContinuesFromIt() {
    let c = run(digits("1") + [.op(.add)] + digits("1") + [.equals, .op(.multiply)] + digits("5") + [.equals])
    #expect(c.display == "10")
}

@Test func decimalArithmeticIsExact() {
    let c = run(digits("0.1") + [.op(.add)] + digits("0.2") + [.equals])
    #expect(c.display == "0.3")
}

@Test func divisionByZeroIsAnErrorUntilCleared() {
    var c = run(digits("5") + [.op(.divide)] + digits("0") + [.equals])
    #expect(c.isError)
    c.press(.digit(3))
    #expect(c.isError)
    c.press(.clear)
    #expect(!c.isError)
    #expect(c.display == "0")
}

@Test func negateTogglesTheSign() {
    #expect(run(digits("5") + [.negate]).display == "-5")
    #expect(run(digits("5") + [.negate, .negate]).display == "5")
    #expect(run([.negate]).display == "0")
}

@Test func negateWorksOnAResult() {
    let c = run(digits("2") + [.op(.add)] + digits("3") + [.equals, .negate])
    #expect(c.display == "-5")
}

@Test func percentAloneDividesByHundred() {
    #expect(run(digits("50") + [.percent]).display == "0.5")
}

@Test func percentAfterAddIsAPercentageOfTheFirstNumber() {
    let c = run(digits("200") + [.op(.add)] + digits("10") + [.percent, .equals])
    #expect(c.display == "220")
}

@Test func percentAfterMultiplyIsAPlainFraction() {
    let c = run(digits("200") + [.op(.multiply)] + digits("10") + [.percent, .equals])
    #expect(c.display == "20")
}

@Test func backspaceRemovesTheLastCharacter() {
    #expect(run(digits("123") + [.backspace]).display == "12")
    #expect(run(digits("5") + [.backspace]).display == "0")
    #expect(run(digits("-5".replacingOccurrences(of: "-", with: "")) + [.negate, .backspace]).display == "0")
}

@Test func clearEntryThenAll() {
    var c = run(digits("5") + [.op(.add)] + digits("7"))
    #expect(c.clearsEverything == false)
    c.press(.clear)
    #expect(c.display == "0")
    #expect(c.clearsEverything)
    c.press(.digit(2))
    c.press(.equals)
    #expect(c.display == "7")   // pending "5 +" survived the first clear: 5 + 2
    c.press(.clear)
    c.press(.clear)
    #expect(c.display == "0")
    c.press(.equals)
    #expect(c.display == "0")
}

@Test func entryLengthIsLimited() {
    let c = run(digits(String(repeating: "9", count: 30)))
    #expect(c.display.count == 15)
}

@Test func longResultsAreRounded() {
    let c = run(digits("1") + [.op(.divide)] + digits("3") + [.equals])
    #expect(c.display == "0.333333333333333")
}

@Test func hugeResultsDoNotCrash() {
    var c = run(digits("9999999999") + [.op(.multiply)] + digits("9999999999") + [.equals])
    #expect(!c.display.isEmpty)
    c.press(.clear)
    #expect(c.display == "0")
}

@Test func decimalSeparatorCanBeLocalised() {
    var c = Calculator()
    c.decimalSeparator = ","
    [.digit(1), .decimalPoint, .digit(5)].forEach { c.press($0) }
    #expect(c.display == "1,5")
}

@Test func historyShowsThePendingOperation() {
    #expect(Calculator().history == "")
    #expect(run(digits("7") + [.op(.multiply)]).history == "7 ×")
    #expect(run(digits("7") + [.op(.multiply)] + digits("8")).history == "7 ×")
}

@Test func historyShowsTheFinishedExpression() {
    #expect(run(digits("7") + [.op(.multiply)] + digits("8") + [.equals]).history == "7 × 8 =")
    #expect(run(digits("9") + [.op(.subtract)] + digits("12") + [.equals]).history == "9 − 12 =")
    #expect(run(digits("1") + [.op(.divide)] + digits("4") + [.equals]).history == "1 ÷ 4 =")
}

@Test func historyFollowsChainsAndRepeatedEquals() {
    #expect(run(digits("2") + [.op(.add)] + digits("3") + [.op(.multiply)]).history == "5 ×")
    #expect(run(digits("5") + [.op(.add)] + digits("2") + [.equals, .equals]).history == "7 + 2 =")
}

@Test func historyIsClearedByNewEntryAndClear() {
    #expect(run(digits("7") + [.op(.multiply)] + digits("8") + [.equals] + digits("3")).history == "")
    #expect(run(digits("7") + [.op(.multiply)] + digits("8") + [.equals, .clear]).history == "")
}

@Test func historyUsesTheDecimalSeparator() {
    var c = Calculator()
    c.decimalSeparator = ","
    digits("1.5").forEach { c.press($0) }
    c.press(.op(.add))
    digits("2").forEach { c.press($0) }
    c.press(.equals)
    #expect(c.history == "1,5 + 2 =")
}

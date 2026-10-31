import Foundation
import Testing
@testable import LedgeCore

@Test func historyStartsEmptyAndKeepsNewestFirst() {
    var h = CalculationHistory()
    #expect(h.entries.isEmpty)
    h.add(expression: "1 + 1", result: "2", value: "2")
    h.add(expression: "2 × 3", result: "6", value: "6")
    #expect(h.entries.map(\.result) == ["6", "2"])
    #expect(h.entries[0].expression == "2 × 3")
    #expect(h.entries[0].value == "6")
}

@Test func historyIgnoresAnImmediateRepeat() {
    var h = CalculationHistory()
    h.add(expression: "1 + 1", result: "2", value: "2")
    h.add(expression: "1 + 1", result: "2", value: "2")
    #expect(h.entries.count == 1)
    h.add(expression: "3", result: "3", value: "3")
    h.add(expression: "1 + 1", result: "2", value: "2")
    #expect(h.entries.count == 3)
}

@Test func historyIsLimited() {
    var h = CalculationHistory()
    for i in 0..<(CalculationHistory.limit + 20) { h.add(expression: "\(i) + 0", result: "\(i)", value: "\(i)") }
    #expect(h.entries.count == CalculationHistory.limit)
    #expect(h.entries[0].result == "\(CalculationHistory.limit + 19)")
}

@Test func historyCanBeCleared() {
    var h = CalculationHistory()
    h.add(expression: "1 + 1", result: "2", value: "2")
    h.clear()
    #expect(h.entries.isEmpty)
}

@Test func insertedValueActsAsATypedNumber() {
    var c = Calculator()
    c.press(.value(5))
    c.press(.op(.add))
    c.press(.digit(3))
    c.press(.equals)
    #expect(c.display == "8")
    c.press(.value(Decimal(string: "-2.5")!))
    #expect(c.display == "-2.5")
    c.press(.op(.multiply))
    c.press(.digit(2))
    c.press(.equals)
    #expect(c.display == "-5")
}

@Test func insertedValueStartsANewCalculationAfterAResult() {
    var c = Calculator()
    [CalcKey.digit(2), .op(.add), .digit(2), .equals, .value(9)].forEach { c.press($0) }
    #expect(c.display == "9")
    #expect(c.history == "")
}

@Test func valueTextIsTheCanonicalNumber() {
    var c = Calculator()
    c.decimalSeparator = ","
    [CalcKey.digit(1), .decimalPoint, .digit(5), .op(.add), .digit(1), .equals].forEach { c.press($0) }
    #expect(c.valueText == "2.5")
    #expect(c.display == "2,5")
}

@Test func extendedInsertedValueAndValueText() {
    var c = ExpressionCalculator()
    c.press(.value(4))
    c.press(.op(.multiply))
    c.press(.value(Decimal(string: "0.5")!))
    c.press(.equals)
    #expect(c.display == "2")
    #expect(c.valueText == "2")
    c.press(.value(7))
    #expect(c.history == "")
}

@Test func programmerInsertedValues() {
    var c = ProgrammerCalculator()
    c.press(.value(255))
    c.press(.setBase(.hexadecimal))
    #expect(c.display == "FF")
    c.press(.clear)
    c.press(.clear)
    c.press(.value(-5))                    // decimal: kept as a result-like operand
    c.press(.op(.add))
    c.press(.digit(8))
    c.press(.equals)
    #expect(c.display == "3")
    #expect(c.valueText == "3")
}

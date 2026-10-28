import Foundation
import Testing
@testable import LedgeCore

private func run(_ keys: [ExprKey]) -> ExpressionCalculator {
    var c = ExpressionCalculator()
    keys.forEach { c.press($0) }
    return c
}

private func k(_ s: String) -> [ExprKey] {
    s.compactMap { ch -> ExprKey? in
        switch ch {
        case "0"..."9": return .digit(Int(String(ch))!)
        case ".": return .decimalPoint
        case "+": return .op(.add)
        case "-": return .op(.subtract)
        case "*": return .op(.multiply)
        case "/": return .op(.divide)
        case "^": return .power
        case "(": return .openParen
        case ")": return .closeParen
        case "=": return .equals
        default: return nil
        }
    }
}

@Test func multiplicationBindsTighterThanAddition() {
    #expect(run(k("2+3*4=")).display == "14")
    #expect(run(k("2*3+4=")).display == "10")
    #expect(run(k("10-4/2=")).display == "8")
}

@Test func parenthesesChangeTheOrder() {
    #expect(run(k("(2+3)*4=")).display == "20")
    #expect(run(k("2*(3+4)=")).display == "14")
    #expect(run(k("((1+2)*(3+4))=")).display == "21")
}

@Test func openParenthesesAreClosedByEquals() {
    #expect(run(k("(2+3=")).display == "5")
    #expect(run(k("2*(3+4=")).display == "14")
}

@Test func strayClosingParenthesisIsIgnored() {
    #expect(run(k("2+3)=")).display == "5")
}

@Test func trailingOperatorIsDropped() {
    #expect(run(k("5+=")).display == "5")
}

@Test func anotherOperatorReplacesThePrevious() {
    #expect(run(k("8+-3=")).display == "5")
}

@Test func implicitMultiplicationAroundParentheses() {
    #expect(run(k("2(3+4)=")).display == "14")
    #expect(run(k("(2+3)4=")).display == "20")
    #expect(run(k("(1+1)(2+2)=")).display == "8")
}

@Test func powerIsRightAssociativeAndBeatsMultiplication() {
    #expect(run(k("2^3=")).display == "8")
    #expect(run(k("2^3^2=")).display == "512")
    #expect(run(k("2*3^2=")).display == "18")
    #expect(run(k("2^0=")).display == "1")
    #expect(run(k("2^")+[.negate]+k("1=")).display == "0.5")
}

@Test func divisionByZeroAndInvalidPowerAreErrors() {
    #expect(run(k("5/0=")).isError)
    #expect(run(k("5/(2-2)=")).isError)
    #expect(run(k("0^")+[.negate]+k("1=")).isError)
}

@Test func decimalFractionsAreExact() {
    #expect(run(k("0.1+0.2=")).display == "0.3")
    #expect(run(k("1/4+1/4=")).display == "0.5")
}

@Test func unaryFunctionsActOnTheTypedNumber() {
    #expect(run(k("9") + [.squareRoot]).display == "3")
    #expect(run(k("7") + [.square]).display == "49")
    #expect(run(k("8") + [.reciprocal]).display == "0.125")
    #expect(run(k("3+") + k("4") + [.square] + k("=")).display == "19")
}

@Test func unaryErrors() {
    #expect(run(k("0") + [.reciprocal]).isError)
    #expect(run([.digit(4), .negate, .squareRoot]).isError)
}

@Test func unaryFunctionsActOnAResult() {
    #expect(run(k("3+6=") + [.squareRoot]).display == "3")
}

@Test func constants() {
    #expect(run([.pi]).display == "3.14159265358979")
    #expect(run([.euler]).display == "2.71828182845905")
}

@Test func negateAndPercent() {
    #expect(run(k("5") + [.negate]).display == "-5")
    #expect(run(k("2*") + [.negate] + k("3=")).display == "-6")
    #expect(run(k("50") + [.percent]).display == "0.5")
}

@Test func historyShowsTheExpression() {
    #expect(ExpressionCalculator().history == "")
    #expect(run(k("(2+3)*")).history == "( 2 + 3 ) ×")
    #expect(run(k("(2+3)*4=")).history == "( 2 + 3 ) × 4 =")
    #expect(run(k("2+3=") + k("7")).history == "")
}

@Test func expressionContinuesFromAResult() {
    #expect(run(k("2+3=") + k("*4=")).display == "20")
}

@Test func backspaceEditsTheNumberThenTheExpression() {
    #expect(run(k("123") + [.backspace]).display == "12")
    #expect(run(k("2+") + [.backspace] + k("3=")).display == "23")   // the operator is gone, the 2 is editable again
}

@Test func expressionClearEntryThenAll() {
    var c = run(k("2+7"))
    c.press(.clear)
    #expect(c.display == "0")
    #expect(c.clearsEverything)
    c.press(.clear)
    #expect(c.history == "")
}

@Test func fractionModeShowsExactFractions() {
    var c = run(k("1/3+1/4="))
    #expect(c.display == "0.583333333333333")
    c.press(.toggleFraction)
    #expect(c.display == "7/12")
    c.press(.toggleFraction)
    #expect(c.display == "0.583333333333333")
}

@Test func fractionApproximation() {
    #expect(FractionFormat.string(for: 0.5) == "1/2")
    #expect(FractionFormat.string(for: Decimal(string: "0.333333333333333")!) == "1/3")
    #expect(FractionFormat.string(for: Decimal(string: "-0.75")!) == "-3/4")
    #expect(FractionFormat.string(for: Decimal(string: "2.5")!) == "5/2")
    #expect(FractionFormat.string(for: 2) == nil)
    #expect(FractionFormat.string(for: Decimal(string: "3.14159265358979")!) == nil)
}

@Test func decimalSeparatorIsLocalisedInDisplayAndHistory() {
    var c = ExpressionCalculator()
    c.decimalSeparator = ","
    k("1.5+2=").forEach { c.press($0) }
    #expect(c.display == "3,5")
    #expect(c.history == "1,5 + 2 =")
}

@Test func errorsLastUntilClear() {
    var c = run(k("5/0="))
    c.press(.digit(3))
    #expect(c.isError)
    c.press(.clear)
    #expect(!c.isError && c.display == "0")
}

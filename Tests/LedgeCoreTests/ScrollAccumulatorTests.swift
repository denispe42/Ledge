import CoreGraphics
import Testing
@testable import LedgeCore

@Test func smallDeltasAddUpToOneStep() {
    var a = ScrollAccumulator()
    #expect(a.add(5, threshold: 12) == 0)
    #expect(a.add(5, threshold: 12) == 0)
    #expect(a.add(5, threshold: 12) == 1)
    #expect(a.add(9, threshold: 12) == 1)   // remainder 3 + 9 = 12
}

@Test func largeDeltaGivesSeveralStepsAndKeepsRemainder() {
    var a = ScrollAccumulator()
    #expect(a.add(30, threshold: 12) == 2)
    #expect(a.add(6, threshold: 12) == 1)   // 6 + 6 left over
}

@Test func oppositeDirectionAndReset() {
    var a = ScrollAccumulator()
    #expect(a.add(-25, threshold: 12) == -2)
    a.reset()
    #expect(a.add(-5, threshold: 12) == 0)
    #expect(a.add(5, threshold: 12) == 0)
}

@Test func nonPositiveThresholdNeverSteps() {
    var a = ScrollAccumulator()
    #expect(a.add(100, threshold: 0) == 0)
}

@Test func wheelValueStopsAtTheEnds() {
    var w = WheelValue(maximum: 59, value: 58)
    #expect(w.move(by: 5) == 1 && w.value == 59)
    #expect(w.move(by: 1) == 0)
    #expect(w.move(by: -100) == -59 && w.value == 0)
    #expect(w.move(by: -1) == 0)
}

@Test func wheelValueClampsItsInitialValue() {
    #expect(WheelValue(maximum: 23, value: 99).value == 23)
    #expect(WheelValue(maximum: 23, value: -4).value == 0)
}

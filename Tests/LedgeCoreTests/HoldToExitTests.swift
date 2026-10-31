import Testing
@testable import LedgeCore

@Test func holdCompletesOnlyAfterTheFullDuration() {
    var hold = HoldToExit(duration: 3)
    let began = hold.press(at: 10)
    #expect(began)
    #expect(!hold.isComplete(at: 12.9))
    #expect(hold.isComplete(at: 13))
}

@Test func keyRepeatDoesNotRestartTheHold() {
    var hold = HoldToExit(duration: 3)
    let first = hold.press(at: 10)
    let repeated = hold.press(at: 11)
    #expect(first)
    #expect(!repeated)
    #expect(hold.isComplete(at: 13))
}

@Test func releasingResetsTheHold() {
    var hold = HoldToExit(duration: 3)
    _ = hold.press(at: 10)
    hold.release()
    #expect(!hold.isComplete(at: 14))
    let again = hold.press(at: 20)
    #expect(again)
    #expect(!hold.isComplete(at: 22))
}

@Test func progressGrowsFromZeroToOne() {
    var hold = HoldToExit(duration: 4)
    #expect(hold.progress(at: 0) == 0)
    _ = hold.press(at: 0)
    #expect(hold.progress(at: 1) == 0.25)
    #expect(hold.progress(at: 99) == 1)
}

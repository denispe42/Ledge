import Foundation
import Testing
@testable import LedgeCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)
private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

@Test func idleTimerShowsItsDuration() {
    #expect(CountdownTimer(duration: 300).remaining(at: t0) == 300)
}

@Test func runningTimerCountsDownAndFinishesOnce() {
    var t = CountdownTimer(duration: 60)
    t.start(now: t0)
    #expect(t.remaining(at: at(20)) == 40)
    #expect(t.updateFinished(at: at(59)) == false)
    #expect(t.updateFinished(at: at(60)) == true)
    #expect(t.state == .finished)
    #expect(t.updateFinished(at: at(61)) == false)
    #expect(t.remaining(at: at(100)) == 0)
}

@Test func pauseKeepsRemainingAndResumeContinues() {
    var t = CountdownTimer(duration: 60)
    t.start(now: t0)
    t.pause(now: at(15))
    #expect(t.remaining(at: at(500)) == 45)
    t.resume(now: at(500))
    #expect(t.remaining(at: at(510)) == 35)
}

@Test func startWithNewDurationRemembersIt() {
    var t = CountdownTimer(duration: 60)
    t.start(duration: 600, now: t0)
    t.reset()
    #expect(t.state == .idle && t.remaining(at: t0) == 600)
}

@Test func zeroDurationNeverStarts() {
    var t = CountdownTimer(duration: 0)
    t.start(now: t0)
    #expect(t.state == .idle)
}

@Test func pauseOrResumeInWrongStateDoNothing() {
    var t = CountdownTimer(duration: 60)
    t.pause(now: t0); t.resume(now: t0)
    #expect(t.state == .idle)
}

@Test func timerPassedWhileAsleepFinishesLazily() {
    var t = CountdownTimer(duration: 60)
    t.start(now: t0)
    #expect(t.updateFinished(at: at(3600)) == true)
}

@Test func stopwatchAccumulatesAcrossPauses() {
    var s = Stopwatch()
    s.start(now: t0)
    s.pause(now: at(10))
    #expect(s.elapsed(at: at(100)) == 10)
    s.start(now: at(100))
    #expect(s.elapsed(at: at(105)) == 15)
    s.reset()
    #expect(s.elapsed(at: at(200)) == 0 && s.state == .idle)
}

@Test func clockFormatting() {
    #expect(ClockFormat.string(59.2, roundUp: true) == "1:00")
    #expect(ClockFormat.string(59.9, roundUp: false) == "0:59")
    #expect(ClockFormat.string(3661, roundUp: false) == "1:01:01")
    #expect(ClockFormat.string(-5, roundUp: true) == "0:00")
}

@Test func redrawDelaysLandJustAfterTheNextSecondChange() {
    #expect(abs(ClockFormat.delayToNextChange(of: 4.25, countingDown: true) - 0.26) < 1e-9)
    #expect(abs(ClockFormat.delayToNextChange(of: 4.25, countingDown: false) - 0.76) < 1e-9)
    #expect(abs(ClockFormat.delayToNextChange(of: 5, countingDown: true) - 1.01) < 1e-9)
}

import Foundation
import Testing
@testable import LedgeCore

@Test func aSessionWithoutADurationNeverEnds() {
    let session = KeepAwakeSession.start(at: Date(timeIntervalSince1970: 1000), for: nil)
    #expect(session.until == nil)
    #expect(session.remaining(at: Date(timeIntervalSince1970: 1_000_000)) == nil)
    #expect(!session.isOver(at: Date(timeIntervalSince1970: 1_000_000)))
}

@Test func aTimedSessionCountsDown() {
    let start = Date(timeIntervalSince1970: 1000)
    let session = KeepAwakeSession.start(at: start, for: 300)
    #expect(session.until == Date(timeIntervalSince1970: 1300))
    #expect(session.remaining(at: Date(timeIntervalSince1970: 1100)) == 200)
    #expect(!session.isOver(at: Date(timeIntervalSince1970: 1299)))
    #expect(session.isOver(at: Date(timeIntervalSince1970: 1300)))
    #expect(session.remaining(at: Date(timeIntervalSince1970: 5000)) == 0)
}

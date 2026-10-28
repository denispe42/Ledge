import Testing
@testable import LedgeCore

@MainActor
private final class FakeProvider: PowerAssertionProvider {
    var refuse = false
    private(set) var acquired = 0, released: [UInt32] = []
    func acquire(reason: String) -> UInt32? {
        guard !refuse else { return nil }
        acquired += 1
        return UInt32(acquired)
    }
    func release(_ token: UInt32) { released.append(token) }
}

@MainActor @Test func togglingHoldsAndReleasesTheAssertion() {
    let p = FakeProvider(); let k = KeepAwake(provider: p)
    k.toggle()
    #expect(k.isActive && p.acquired == 1)
    k.toggle()
    #expect(!k.isActive && p.released == [1])
}

@MainActor @Test func activatingTwiceDoesNotAcquireTwice() {
    let p = FakeProvider(); let k = KeepAwake(provider: p)
    k.setActive(true); k.setActive(true)
    #expect(p.acquired == 1)
}

@MainActor @Test func refusedAssertionLeavesItInactive() {
    let p = FakeProvider(); p.refuse = true
    let k = KeepAwake(provider: p)
    #expect(k.setActive(true) == false)
    #expect(!k.isActive)
}

@MainActor @Test func shutdownReleasesWhenActiveAndIsHarmlessOtherwise() {
    let p = FakeProvider(); let k = KeepAwake(provider: p)
    k.shutdown()
    #expect(p.released.isEmpty)
    k.setActive(true); k.shutdown()
    #expect(p.released == [1])
}

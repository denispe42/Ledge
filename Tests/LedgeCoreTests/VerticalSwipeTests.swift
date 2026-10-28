import Testing
@testable import LedgeCore

@Test func downwardTravelFiresOnceAtThreshold() {
    var s = VerticalSwipe()
    s.begin()
    #expect(s.add(fingerDown: 15, fingerAcross: 0, threshold: 30) == nil)
    #expect(s.add(fingerDown: 20, fingerAcross: 1, threshold: 30) == .down)
    #expect(s.add(fingerDown: 50, fingerAcross: 0, threshold: 30) == nil)   // same gesture: already spent
}

@Test func upwardTravelFiresUp() {
    var s = VerticalSwipe()
    s.begin()
    #expect(s.add(fingerDown: -40, fingerAcross: 0, threshold: 30) == .up)
}

@Test func newGestureFiresAgain() {
    var s = VerticalSwipe()
    s.begin()
    #expect(s.add(fingerDown: 40, fingerAcross: 0, threshold: 30) == .down)
    s.begin()
    #expect(s.add(fingerDown: -40, fingerAcross: 0, threshold: 30) == .up)
}

@Test func horizontalSwipeIsIgnored() {
    var s = VerticalSwipe()
    s.begin()
    #expect(s.add(fingerDown: 10, fingerAcross: 60, threshold: 30) == nil)
    #expect(s.add(fingerDown: 25, fingerAcross: 60, threshold: 30) == nil)
}

@Test func backAndForthCancelsOut() {
    var s = VerticalSwipe()
    s.begin()
    #expect(s.add(fingerDown: 20, fingerAcross: 0, threshold: 30) == nil)
    #expect(s.add(fingerDown: -20, fingerAcross: 0, threshold: 30) == nil)
}

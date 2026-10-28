import CoreGraphics
import Testing
@testable import LedgeCore

private func run(_ events: [IslandEvent]) -> IslandState {
    var m = IslandStateMachine()
    events.forEach { m.handle($0) }
    return m.state
}

@Test func clickOpensAndClicksOnAnOpenIslandChangeNothing() {
    #expect(run([.clicked]) == .open)
    #expect(run([.clicked, .clicked, .clicked]) == .open)
}

@Test func leavingClosesOnlyWhenOpen() {
    #expect(run([.clicked, .pointerLeft]) == .collapsed)
    #expect(run([.pointerLeft]) == .collapsed)
}

@Test func canReopenAfterClosing() {
    #expect(run([.clicked, .pointerLeft, .clicked]) == .open)
}

@Test func expandedFrameKeepsTopEdgeAndCentre() {
    let c = CGRect(x: 663, y: 944, width: 186, height: 38)
    let e = IslandGeometry.expandedFrame(from: c)
    #expect(e.maxY == c.maxY)
    #expect(e.midX == c.midX)
    #expect(e.size == IslandGeometry.expandedSize)
}

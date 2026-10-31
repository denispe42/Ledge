import Testing
@testable import LedgeCore

@Test func onlyPinnedClocksAreVisible() {
    #expect(CompactPolicy.isVisible(pinned: true, hideInFullscreen: true, isFullscreen: false))
    #expect(!CompactPolicy.isVisible(pinned: false, hideInFullscreen: true, isFullscreen: false))
}

@Test func fullScreenHidesPinnedClocksOnlyWhenTheSettingSaysSo() {
    #expect(!CompactPolicy.isVisible(pinned: true, hideInFullscreen: true, isFullscreen: true))
    #expect(CompactPolicy.isVisible(pinned: true, hideInFullscreen: false, isFullscreen: true))
}

@Test func tickingNeedsARunningClockAndAnAudience() {
    #expect(CompactPolicy.shouldTick(running: true, islandOpen: true, pinned: false))
    #expect(CompactPolicy.shouldTick(running: true, islandOpen: false, pinned: true))
    #expect(!CompactPolicy.shouldTick(running: true, islandOpen: false, pinned: false))
    #expect(!CompactPolicy.shouldTick(running: false, islandOpen: true, pinned: true))
}

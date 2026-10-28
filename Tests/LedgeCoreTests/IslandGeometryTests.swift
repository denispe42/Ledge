import CoreGraphics
import Testing
@testable import LedgeCore

private let notched = ScreenInfo(
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
    safeAreaTop: 38, leftAreaWidth: 663, rightAreaWidth: 663)
private let plain = ScreenInfo(
    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055))

@Test func notchFrameHugsTheNotch() {
    let f = IslandGeometry.collapsedFrame(on: notched)
    #expect(f == CGRect(x: 663, y: 944, width: 186, height: 38))
    #expect(f.maxY == notched.frame.maxY)
}

@Test func notchWithoutSideAreasFallsBackToCentred() {
    var s = notched; s.leftAreaWidth = nil; s.rightAreaWidth = nil
    let f = IslandGeometry.collapsedFrame(on: s)
    #expect(f.width == IslandGeometry.fallbackNotchWidth)
    #expect(f.midX == s.frame.midX)
}

@Test func secondaryNotchedDisplayOffsetIsRespected() {
    var s = notched
    s.frame.origin = CGPoint(x: 1512, y: 0)
    #expect(IslandGeometry.collapsedFrame(on: s).minX == CGFloat(1512 + 663))
}

@Test func onlyNotchedScreenIsChosen() {
    #expect(IslandGeometry.notchedScreenIndex([plain, notched]) == 1)
    #expect(IslandGeometry.notchedScreenIndex([plain, plain]) == nil)
    #expect(IslandGeometry.notchedScreenIndex([]) == nil)
}

@Test func earWidthHasAMinimumAndGrowsWithText() {
    #expect(IslandGeometry.earWidth(forTextWidth: nil) == 0)
    #expect(IslandGeometry.earWidth(forTextWidth: 20) == IslandGeometry.minimumEar)
    #expect(IslandGeometry.earWidth(forTextWidth: 60.2) == CGFloat(85))
}

@Test func wideningKeepsTheTopEdgeAndTheNotchInPlace() {
    let notch = CGRect(x: 663, y: 944, width: 186, height: 38)
    let wide = IslandGeometry.widened(notch, left: 60, right: 0)
    #expect(wide == CGRect(x: 603, y: 944, width: 246, height: 38))
    #expect(IslandGeometry.widened(notch, left: 0, right: 0) == notch)
}

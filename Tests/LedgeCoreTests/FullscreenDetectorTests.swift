import CoreGraphics
import Testing
@testable import LedgeCore

private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
private let me: Int32 = 100

private func win(_ r: CGRect, owner: String = "TextEdit", pid: Int32 = 5, layer: Int = 0,
                 alpha: Double = 1) -> WindowSnapshot {
    WindowSnapshot(ownerPID: pid, ownerName: owner, layer: layer, bounds: r, alpha: alpha)
}

private let dock = win(screen, owner: "Dock", pid: 1, layer: 20)
private let fullscreenWindow = win(CGRect(x: 0, y: 33, width: 1470, height: 923))

private func check(_ w: [WindowSnapshot]) -> Bool {
    FullscreenDetector.isFullscreen(windows: w, screen: screen, safeTop: 33, ownPID: me)
}

@Test func fullWindowWithoutDockIsFullscreen() {
    #expect(check([fullscreenWindow]))
}

@Test func maximisedWindowWithDockIsNotFullscreen() {
    #expect(!check([dock, win(CGRect(x: 0, y: 33, width: 1470, height: 849))]))
}

@Test func maximisedWindowWithAutoHiddenDockStillHasDockWindow() {
    #expect(!check([dock, fullscreenWindow]))
}

@Test func smallWindowsAreNotFullscreen() {
    #expect(!check([win(CGRect(x: 50, y: 312, width: 1247, height: 436))]))
}

@Test func invisibleHelperWindowsAreIgnored() {
    #expect(!check([win(CGRect(x: 0, y: 33, width: 1470, height: 923), alpha: 0)]))
}

@Test func ownWindowsNeverCount() {
    #expect(!check([win(CGRect(x: 0, y: 0, width: 1470, height: 956), owner: "Ledge", pid: me)]))
}

@Test func menuBarAndOtherLayersAreIgnored() {
    #expect(!check([win(CGRect(x: 0, y: 0, width: 1470, height: 33), owner: "Window Server", pid: 2, layer: 24)]))
}

@Test func nothingOnScreenIsNotFullscreen() {
    #expect(!check([]))
}

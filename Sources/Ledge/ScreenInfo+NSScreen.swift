import AppKit
import LedgeCore

extension ScreenInfo {
    /// Bridges a live display into the testable snapshot used by `IslandGeometry`.
    @MainActor
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame,
                  safeAreaTop: screen.safeAreaInsets.top,
                  leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
                  rightAreaWidth: screen.auxiliaryTopRightArea?.width)
    }
}

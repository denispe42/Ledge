import CoreGraphics

/// One on-screen window as reported by the window server (CG coordinates: origin top-left).
public struct WindowSnapshot: Equatable, Sendable {
    public var ownerPID: Int32
    public var ownerName: String
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double

    public init(ownerPID: Int32, ownerName: String, layer: Int, bounds: CGRect, alpha: Double = 1) {
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
    }
}

/// Decides whether another app is in native full screen (this also covers full-screen video in browsers and players).
///
/// A maximised window looks alike but differs in two ways: it leaves room for the Dock (or the Dock's own window is
/// still on screen), while a full-screen window reaches the bottom edge and the Dock window disappears.
public enum FullscreenDetector {
    static let tolerance: CGFloat = 1
    static let dockLayer = 20

    /// - Parameters:
    ///   - screen: the notched display's frame in CG coordinates (origin top-left).
    ///   - safeTop: height of the notch band; full-screen windows may start below it.
    public static func isFullscreen(windows: [WindowSnapshot], screen: CGRect, safeTop: CGFloat, ownPID: Int32) -> Bool {
        let dockVisible = windows.contains {
            $0.ownerName == "Dock" && $0.layer == dockLayer && covers($0.bounds, screen: screen)
        }
        guard !dockVisible else { return false }
        return windows.contains { w in
            w.ownerPID != ownPID && w.layer == 0 && w.alpha > 0
                && w.bounds.width >= screen.width - tolerance
                && abs(w.bounds.minX - screen.minX) <= tolerance
                && w.bounds.minY <= screen.minY + safeTop + tolerance
                && w.bounds.maxY >= screen.maxY - tolerance
        }
    }

    private static func covers(_ bounds: CGRect, screen: CGRect) -> Bool {
        bounds.width >= screen.width - tolerance && bounds.height >= screen.height - tolerance
            && abs(bounds.minX - screen.minX) <= tolerance && abs(bounds.minY - screen.minY) <= tolerance
    }
}

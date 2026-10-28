import CoreGraphics

/// Plain-data snapshot of one display, so placement logic can be tested without AppKit.
public struct ScreenInfo: Equatable, Sendable {
    public var frame: CGRect
    /// Frame minus menu bar and Dock.
    public var visibleFrame: CGRect
    /// Height of the camera housing (0 on Macs without a notch).
    public var safeAreaTop: CGFloat
    /// Widths of the usable menu-bar areas left and right of the notch, if the system reports them.
    public var leftAreaWidth: CGFloat?
    public var rightAreaWidth: CGFloat?

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat = 0,
                leftAreaWidth: CGFloat? = nil, rightAreaWidth: CGFloat? = nil) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.leftAreaWidth = leftAreaWidth
        self.rightAreaWidth = rightAreaWidth
    }

    public var hasNotch: Bool { safeAreaTop > 0 }
}

/// Where the collapsed island sits: exactly over the notch. Macs without a notch are not supported.
public enum IslandGeometry {
    /// Used only if the system reports a notch but not its side areas.
    static let fallbackNotchWidth: CGFloat = 190

    /// The first display that has a notch, or nil (then the island stays hidden).
    public static func notchedScreenIndex(_ screens: [ScreenInfo]) -> Int? {
        screens.firstIndex(where: \.hasNotch)
    }

    public static func collapsedFrame(on screen: ScreenInfo) -> CGRect {
        let height = screen.safeAreaTop
        if let left = screen.leftAreaWidth, let right = screen.rightAreaWidth {
            let width = screen.frame.width - left - right
            if width > 0 {
                return CGRect(x: screen.frame.minX + left, y: screen.frame.maxY - height,
                              width: width, height: height)
            }
        }
        let width = fallbackNotchWidth
        return CGRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height,
                      width: width, height: height)
    }
}

extension IslandGeometry {
    /// Size of the opened island.
    public static let expandedSize = CGSize(width: 440, height: 176)

    /// Opened frame: same top edge and horizontal centre as the collapsed one.
    public static func expandedFrame(from collapsed: CGRect, size: CGSize = expandedSize) -> CGRect {
        CGRect(x: collapsed.midX - size.width / 2, y: collapsed.maxY - size.height,
               width: size.width, height: size.height)
    }
}

extension IslandGeometry {
    /// Smallest width of the strip beside the notch that shows a running clock.
    public static let minimumEar: CGFloat = 52
    static let earPadding: CGFloat = 12

    /// Width of the strip beside the notch for text of the given width (0 when there is nothing to show).
    public static func earWidth(forTextWidth width: CGFloat?) -> CGFloat {
        guard let width else { return 0 }
        return max(minimumEar, ceil(width) + 2 * earPadding)
    }

    /// The collapsed island frame widened on the left and right to make room for text beside the notch.
    public static func widened(_ notch: CGRect, left: CGFloat, right: CGFloat) -> CGRect {
        CGRect(x: notch.minX - left, y: notch.minY, width: notch.width + left + right, height: notch.height)
    }
}

/// Rules for the clocks beside the notch while the island is closed.
public enum CompactPolicy {
    /// A clock is shown only if the user pinned it, and not in full screen when that is switched off.
    public static func isVisible(pinned: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool {
        pinned && !(hideInFullscreen && isFullscreen)
    }

    /// A running clock needs a redraw every second only if someone can see it: the island is open or it is pinned.
    /// Otherwise nothing ticks at all.
    public static func shouldTick(running: Bool, islandOpen: Bool, pinned: Bool) -> Bool {
        running && (islandOpen || pinned)
    }
}

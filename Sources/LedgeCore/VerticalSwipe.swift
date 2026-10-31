import CoreGraphics

public enum SwipeDirection: Equatable, Sendable { case down, up }

/// Turns the scroll deltas of one two-finger gesture into a single "swipe down" or "swipe up": it fires once the
/// finger travel along y passes `threshold` and stays silent until the next gesture begins (or the deltas stop being
/// mostly vertical, which is a horizontal swipe or a diagonal drift).
public struct VerticalSwipe: Equatable, Sendable {
    private var travel = ScrollAccumulator()
    private var spent = false

    public init() {}

    /// A new gesture starts counting again.
    public mutating func begin() {
        travel.reset()
        spent = false
    }

    /// `fingerDown` is the finger travel in points, positive downward (the caller undoes the natural-scrolling flip).
    public mutating func add(fingerDown: CGFloat, fingerAcross: CGFloat, threshold: CGFloat) -> SwipeDirection? {
        guard !spent, abs(fingerDown) > abs(fingerAcross) else { return nil }
        let steps = travel.add(fingerDown, threshold: threshold)
        guard steps != 0 else { return nil }
        spent = true
        return steps > 0 ? .down : .up
    }
}

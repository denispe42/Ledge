import CoreGraphics

/// Turns a stream of scroll deltas into whole steps, keeping the remainder, so a wheel picker advances once per
/// `threshold` points of finger travel regardless of how the deltas are chunked.
public struct ScrollAccumulator: Equatable, Sendable {
    private var remainder: CGFloat = 0

    public init() {}

    /// Returns the number of whole steps (negative for the opposite direction) that `delta` completes.
    public mutating func add(_ delta: CGFloat, threshold: CGFloat) -> Int {
        guard threshold > 0 else { return 0 }
        remainder += delta
        let steps = Int((remainder / threshold).rounded(.towardZero))
        remainder -= CGFloat(steps) * threshold
        return steps
    }

    public mutating func reset() { remainder = 0 }
}

/// One wheel of a picker: a value clamped to 0...maximum.
public struct WheelValue: Equatable, Sendable {
    public let maximum: Int
    public private(set) var value: Int

    public init(maximum: Int, value: Int = 0) {
        self.maximum = max(0, maximum)
        self.value = min(max(0, value), self.maximum)
    }

    /// Moves by `steps`, stopping at the ends. Returns how far it actually moved (0 at an end).
    @discardableResult
    public mutating func move(by steps: Int) -> Int {
        let target = min(max(0, value + steps), maximum)
        let moved = target - value
        value = target
        return moved
    }

    public mutating func set(_ newValue: Int) { value = min(max(0, newValue), maximum) }
}

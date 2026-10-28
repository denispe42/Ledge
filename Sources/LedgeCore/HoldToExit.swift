/// "Hold for N seconds" gesture that ends cleaning mode. Plain taps must do nothing, because wiping a trackpad or a
/// keyboard produces random presses. Time is passed in, so the rule is testable; the app schedules one delayed call
/// for the moment the hold would complete and checks `isComplete` there.
public struct HoldToExit {
    public let duration: Double
    private var startedAt: Double?

    public init(duration: Double) { self.duration = duration }

    /// True if this press began a new hold (the caller then schedules the check); false for key repeats.
    public mutating func press(at now: Double) -> Bool {
        guard startedAt == nil else { return false }
        startedAt = now
        return true
    }

    public mutating func release() { startedAt = nil }

    public func isComplete(at now: Double) -> Bool {
        guard let startedAt else { return false }
        return now - startedAt >= duration
    }

    /// 0 when not held, up to 1 when complete.
    public func progress(at now: Double) -> Double {
        guard let startedAt else { return 0 }
        return min(1, max(0, (now - startedAt) / duration))
    }
}

import Foundation

/// One run of Keep Awake (a press on the tile, or a time chosen on the wheel page): forever (`until == nil`) or until a moment. Times are passed in, so it is testable; the app
/// schedules a single delayed call for `until` (no polling).
public struct KeepAwakeSession: Equatable, Sendable {
    public let until: Date?

    public static func start(at now: Date, for duration: TimeInterval?) -> KeepAwakeSession {
        KeepAwakeSession(until: duration.map { now.addingTimeInterval($0) })
    }

    /// Seconds left (never negative); nil for a session without an end.
    public func remaining(at now: Date) -> TimeInterval? {
        until.map { max(0, $0.timeIntervalSince(now)) }
    }

    public func isOver(at now: Date) -> Bool {
        until.map { now >= $0 } ?? false
    }
}

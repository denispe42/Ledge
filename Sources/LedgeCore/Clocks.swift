import Foundation

/// Countdown timer state, driven by explicit `now` values so it can be tested without real time.
public struct CountdownTimer: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case running(deadline: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    public private(set) var state: State = .idle
    /// The length that `start` uses and that an idle timer shows.
    public var duration: TimeInterval

    public init(duration: TimeInterval = 300) { self.duration = duration }

    public var isRunning: Bool { if case .running = state { return true } else { return false } }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle: return duration
        case .running(let deadline): return max(0, deadline.timeIntervalSince(now))
        case .paused(let remaining): return remaining
        case .finished: return 0
        }
    }

    public mutating func start(duration: TimeInterval? = nil, now: Date) {
        if let duration { self.duration = duration }
        guard self.duration > 0 else { return }
        state = .running(deadline: now.addingTimeInterval(self.duration))
    }

    public mutating func pause(now: Date) {
        guard case .running = state else { return }
        state = .paused(remaining: remaining(at: now))
    }

    public mutating func resume(now: Date) {
        guard case .paused(let remaining) = state else { return }
        state = .running(deadline: now.addingTimeInterval(remaining))
    }

    public mutating func reset() { state = .idle }

    /// Moves a running timer whose deadline has passed to `.finished`. Returns true exactly once, when it does.
    @discardableResult
    public mutating func updateFinished(at now: Date) -> Bool {
        guard case .running(let deadline) = state, deadline <= now else { return false }
        state = .finished
        return true
    }
}

/// Stopwatch state, also driven by explicit `now` values.
public struct Stopwatch: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case running(since: Date, accumulated: TimeInterval)
        case paused(accumulated: TimeInterval)
    }

    public private(set) var state: State = .idle

    public init() {}

    public var isRunning: Bool { if case .running = state { return true } else { return false } }

    public func elapsed(at now: Date) -> TimeInterval {
        switch state {
        case .idle: return 0
        case .running(let since, let accumulated): return accumulated + max(0, now.timeIntervalSince(since))
        case .paused(let accumulated): return accumulated
        }
    }

    public mutating func start(now: Date) {
        switch state {
        case .idle: state = .running(since: now, accumulated: 0)
        case .paused(let accumulated): state = .running(since: now, accumulated: accumulated)
        case .running: break
        }
    }

    public mutating func pause(now: Date) {
        guard case .running = state else { return }
        state = .paused(accumulated: elapsed(at: now))
    }

    public mutating func reset() { state = .idle }
}

/// "m:ss", or "h:mm:ss" from one hour up.
public enum ClockFormat {
    /// Countdowns round up (a timer shows 0:01 until it is really done); stopwatches round down.
    public static func string(_ seconds: TimeInterval, roundUp: Bool) -> String {
        let total = Int(max(0, roundUp ? seconds.rounded(.up) : seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// Delay until the displayed second changes next, for event-driven redraws (never polling).
    public static func delayToNextChange(of seconds: TimeInterval, countingDown: Bool) -> TimeInterval {
        let fraction = seconds - seconds.rounded(.down)
        let delay = countingDown ? (fraction == 0 ? 1 : fraction) : 1 - fraction
        return delay + 0.01
    }
}

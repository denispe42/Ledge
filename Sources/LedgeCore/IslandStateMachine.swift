/// How open the island is.
public enum IslandState: Equatable, Sendable {
    case collapsed
    /// Open until the pointer leaves. Clicks on an open island never close it (empty space, buttons).
    case open
}

public enum IslandEvent: Equatable, Sendable {
    /// Click on the island itself.
    case clicked
    /// The pointer left the island: it closes at once.
    case pointerLeft
}

/// Pure state transitions for the island. No UI, no timers: the shell feeds events in.
/// Hovering deliberately does nothing here: the island opens only on a click.
public struct IslandStateMachine: Equatable, Sendable {
    public private(set) var state: IslandState = .collapsed

    public init() {}

    public var isExpanded: Bool { state == .open }

    public mutating func handle(_ event: IslandEvent) {
        switch (state, event) {
        case (.collapsed, .clicked): state = .open
        case (.open, .pointerLeft): state = .collapsed
        case (.open, .clicked), (.collapsed, .pointerLeft): break
        }
    }
}

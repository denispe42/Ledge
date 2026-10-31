/// Which drop zone receives dropped files. The zone under the pointer wins; a drop on the closed notch or on empty
/// island space goes to the first zone (the shelf, unless it is switched off).
public enum DropRouting {
    public static func zone(hit: Int?, zoneCount: Int) -> Int? {
        guard zoneCount > 0 else { return nil }
        if let hit, (0..<zoneCount).contains(hit) { return hit }
        return 0
    }
}

/// Keeps the island open while a system window that belongs to it is up (AirDrop's device picker): the pointer
/// leaves the island on its way to that window, which must not close it. A close that was skipped is made up for when
/// the hold ends. Pure state, no UI.
public struct IslandHold: Equatable, Sendable {
    public private(set) var isHeld = false
    private var closeSkipped = false

    public init() {}

    /// Starts or ends the hold. Returns true when ending it should close the island now.
    @discardableResult
    public mutating func setHeld(_ held: Bool) -> Bool {
        isHeld = held
        guard !held else { closeSkipped = false; return false }
        defer { closeSkipped = false }
        return closeSkipped
    }

    /// The pointer left the island. Returns true when the island may close now.
    public mutating func pointerLeft() -> Bool {
        guard isHeld else { return true }
        closeSkipped = true
        return false
    }

    /// The pointer is back over the island: the skipped close is no longer wanted.
    public mutating func pointerEntered() { closeSkipped = false }
}

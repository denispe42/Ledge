import AppKit

/// A page that wants the keyboard while the island is open (the panel is key but otherwise swallows keys).
@MainActor
protocol KeyHandling {
    /// Returns true if the key was used.
    func handleKey(_ event: NSEvent) -> Bool
}

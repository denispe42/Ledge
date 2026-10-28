import AppKit
import LedgeCore

/// Which side of the notch a module's closed-state text goes on.
enum CompactSide { case left, right }

/// Text a module shows beside the notch while the island is closed (for example a running timer).
struct CompactItem {
    let side: CompactSide
    let text: String
}

/// A place on the drop screen where a module takes files dragged to the notch.
struct DropZone {
    let symbol: String
    let title: String
    /// Whether the island switches to the module's page after a drop (the shelf shows its new file; AirDrop stays put).
    let showsPageAfterDrop: Bool
    /// `anchor` is the zone view that received the drop, nil for a drop on the closed notch.
    let handle: @MainActor ([URL], NSView?) -> Void
}

/// A module that shows a tile in the opened island and, optionally, a page of its own.
@MainActor
protocol UIModule: ModuleLifecycle {
    var title: String { get }
    /// A fresh tile; the island rebuilds tiles whenever modules start or stop.
    /// `open` shows this module's page (modules without a page ignore it).
    func makeTile(open: @escaping () -> Void) -> NSView
    /// The module's page inside the island, or nil if it has none.
    func makePage() -> NSView?
    /// The island opened or closed. Modules use it to redraw only while someone can see them.
    func islandVisibilityChanged(_ open: Bool)
    /// What to show beside the notch while the island is closed; nil for nothing.
    var compactItem: CompactItem? { get }
    /// Where this module takes files dragged to the notch; nil if it does not take files.
    var dropZone: DropZone? { get }
    /// The island calls this once; the module calls `hold(true)` while a system window of its own is up (the island
    /// then stays open though the pointer leaves it) and `hold(false)` when that window is gone.
    func setHoldHandler(_ hold: @escaping (Bool) -> Void)
    /// The island calls this once; the module calls `close(then)` to close the island and run `then` after it is gone, with the app that had the focus before (the island then does not return the focus itself).
    func setCloseHandler(_ close: @escaping (@escaping (NSRunningApplication?) -> Void) -> Void)
    /// The island calls this once; the module calls `home` to return to the main screen (after a choice on its page).
    func setHomeHandler(_ home: @escaping () -> Void)
    /// The island calls this once; the module calls `observer` whenever `compactItem` may have changed.
    func setCompactObserver(_ observer: @escaping () -> Void)
}

extension UIModule {
    func makePage() -> NSView? { nil }
    func islandVisibilityChanged(_ open: Bool) {}
    var compactItem: CompactItem? { nil }
    var dropZone: DropZone? { nil }
    func setHoldHandler(_ hold: @escaping (Bool) -> Void) {}
    func setCloseHandler(_ close: @escaping (@escaping (NSRunningApplication?) -> Void) -> Void) {}
    func setCompactObserver(_ observer: @escaping () -> Void) {}
    func setHomeHandler(_ home: @escaping () -> Void) {}
}

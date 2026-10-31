import AppKit

/// Notices a file being dragged towards the notch, so the island can open before the pointer reaches the very top edge
/// of the screen (where macOS itself starts Mission Control). Event-driven: it only looks at mouse events that
/// arrive, and installed only while a module that takes files is running.
@MainActor
final class FileDragWatcher {
    /// Screen area (bottom-left origin) that counts as "near the notch".
    var zone: CGRect = .zero
    var onEnterZone: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var monitors: [Any] = []
    private var baseline = 0
    private var fired = false
    private var dragging = false

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        let board = NSPasteboard(name: .drag)
        baseline = board.changeCount
        func add(_ mask: NSEvent.EventTypeMask, _ handler: @escaping @MainActor (FileDragWatcher) -> Void) {
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated { handler(self) }
            }) { monitors.append(monitor) }
        }
        add(.leftMouseDown) { watcher in
            watcher.baseline = NSPasteboard(name: .drag).changeCount
            watcher.fired = false
            watcher.dragging = false
        }
        add(.leftMouseDragged) { watcher in watcher.dragMoved() }
        add(.leftMouseUp) { watcher in
            let wasFileDrag = watcher.dragging
            watcher.fired = false
            watcher.dragging = false
            if wasFileDrag { watcher.onDragEnded?() }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        fired = false
        dragging = false
    }

    private func dragMoved() {
        let board = NSPasteboard(name: .drag)
        // A drag session has started when the drag pasteboard was written after the mouse went down.
        guard board.changeCount != baseline,
              board.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return }
        dragging = true
        guard !fired, zone.contains(NSEvent.mouseLocation) else { return }
        fired = true
        onEnterZone?()
    }
}

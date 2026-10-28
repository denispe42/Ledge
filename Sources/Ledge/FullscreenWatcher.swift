import AppKit
import LedgeCore

/// Tells the island when another app enters or leaves full screen.
/// Event-driven: reacts to space and app-activation notifications and re-checks twice shortly after,
/// because the window server needs a moment to finish the full-screen animation. No periodic polling.
@MainActor
final class FullscreenWatcher {
    var onChange: ((Bool) -> Void)?
    private(set) var isFullscreen = false
    private var recheck: [DispatchWorkItem] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleChecks() }
            }
        }
        evaluate()
    }

    /// Public so the controller can re-check after display changes.
    func evaluate() {
        let value = Self.currentlyFullscreen()
        guard value != isFullscreen else { return }
        isFullscreen = value
        onChange?(value)
    }

    private func scheduleChecks() {
        recheck.forEach { $0.cancel() }
        evaluate()
        recheck = [0.6, 1.5].map { delay in
            let item = DispatchWorkItem { [weak self] in self?.evaluate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    private static func currentlyFullscreen() -> Bool {
        let infos = NSScreen.screens.map(ScreenInfo.init)
        guard let index = IslandGeometry.notchedScreenIndex(infos) else { return false }
        let screen = NSScreen.screens[index]
        // AppKit frames have a bottom-left origin relative to the primary screen; CG windows use top-left.
        let primaryHeight = NSScreen.screens[0].frame.height
        let f = screen.frame
        let cgFrame = CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)

        let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let windows: [WindowSnapshot] = raw.compactMap { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32,
                  let layer = w[kCGWindowLayer as String] as? Int,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict) else { return nil }
            return WindowSnapshot(ownerPID: pid, ownerName: w[kCGWindowOwnerName as String] as? String ?? "",
                                  layer: layer, bounds: bounds, alpha: w[kCGWindowAlpha as String] as? Double ?? 1)
        }
        return FullscreenDetector.isFullscreen(windows: windows, screen: cgFrame, safeTop: screen.safeAreaInsets.top,
                                               ownPID: ProcessInfo.processInfo.processIdentifier)
    }
}

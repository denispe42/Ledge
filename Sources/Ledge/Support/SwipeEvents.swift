import AppKit
import LedgeCore

extension VerticalSwipe {
    /// Finger travel needed for one swipe, in points.
    static let threshold: CGFloat = 30

    /// Feeds one scroll event of a trackpad gesture; returns the direction once the swipe is complete.
    mutating func feed(_ event: NSEvent) -> SwipeDirection? {
        // A new gesture (or a device without gesture phases, like a wheel) starts counting again.
        if event.phase == .began || event.phase == .mayBegin || (event.phase.isEmpty && event.momentumPhase.isEmpty) {
            begin()
        }
        // Momentum after the fingers lift is not a new swipe.
        guard event.momentumPhase.isEmpty else { return nil }
        // With natural scrolling the content follows the fingers, so the delta already points the way they move.
        let down = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        return add(fingerDown: down, fingerAcross: event.scrollingDeltaX, threshold: Self.threshold)
    }
}

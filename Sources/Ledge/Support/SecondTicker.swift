import Foundation

/// Redraw ticks for a visible clock, scheduled one at a time for the moment the displayed second changes.
/// It is event-driven in spirit: it runs only while a clock is running AND the island is open; otherwise nothing is
/// scheduled at all (the end of a timer is a separate single deadline).
@MainActor
final class SecondTicker {
    var nextDelay: (() -> TimeInterval)?
    var onTick: (() -> Void)?

    private var active = false
    private var item: DispatchWorkItem?

    func start() {
        guard !active else { return }
        active = true
        schedule()
    }

    func stop() {
        active = false
        item?.cancel()
        item = nil
    }

    private func schedule() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.item = nil
            self.onTick?()
            if self.active, self.item == nil { self.schedule() }
        }
        item = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (nextDelay?() ?? 1), execute: work)
    }
}

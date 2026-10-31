import AppKit
import LedgeCore

/// Countdown timer. Closed island: nothing ticks, only one deadline callback and one system notification are pending.
@MainActor
final class TimerModule: UIModule {
    let id = "timer"
    var title: String { L10n.timer }

    private var model = CountdownTimer(duration: 300)
    private let notifier = TimerNotifier()
    private let ticker = SecondTicker()
    private var deadlineItem: DispatchWorkItem?
    private var tiles: [TileView] = []
    private weak var page: TimerPageView?
    private var islandOpen = false
    private var compactObserver: (() -> Void)?

    func start() throws {
        ticker.nextDelay = { [weak self] in
            guard let self else { return 1 }
            return ClockFormat.delayToNextChange(of: self.model.remaining(at: Date()), countingDown: true)
        }
        ticker.onTick = { [weak self] in self?.refresh() }
    }

    func stop() {
        ticker.stop()
        deadlineItem?.cancel()
        notifier.cancel()
        model.reset()
        Chime.shared.stop()
        tiles.removeAll()
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "timer", title: title)
        tile.onPress = { Haptics.tick(.generic); open() }
        tiles.append(tile)
        apply(to: tile, now: Date())
        return tile
    }

    func makePage() -> NSView? {
        let page = TimerPageView(
            begin: { [weak self] in self?.begin(duration: $0) },
            togglePause: { [weak self] in self?.togglePause() },
            resetTimer: { [weak self] in self?.resetTimer() },
            togglePin: { [weak self] in self?.togglePin() },
            durationChanged: { [weak self] in self?.setDuration($0) },
            initialDuration: model.duration)
        page.update(model, now: Date(), pinned: CompactSettings.isPinned(id))
        self.page = page
        return page
    }

    var compactItem: CompactItem? {
        model.state == .idle ? nil
            : CompactItem(side: .left, text: ClockFormat.string(model.remaining(at: Date()), roundUp: true))
    }

    func setCompactObserver(_ observer: @escaping () -> Void) { compactObserver = observer }

    func islandVisibilityChanged(_ open: Bool) {
        islandOpen = open
        refresh()
    }

    /// The wheels were turned: remember the time (only an idle timer shows the wheels) and show it on the tile.
    private func setDuration(_ duration: TimeInterval) {
        guard model.state == .idle else { return }
        model.duration = duration
        tiles.forEach { apply(to: $0, now: Date()) }
    }

    private func begin(duration: TimeInterval) {
        guard duration > 0 else { Haptics.tick(.generic); return }
        Haptics.tick(.generic)
        Chime.shared.stop()
        model.start(duration: duration, now: Date())
        notifier.schedule(after: model.duration)
        scheduleDeadline()
        refresh()
    }

    private func togglePause() {
        Haptics.tick(.generic)
        let now = Date()
        if model.isRunning {
            model.pause(now: now)
            deadlineItem?.cancel()
            notifier.cancel()
        } else {
            model.resume(now: now)
            notifier.schedule(after: model.remaining(at: now))
            scheduleDeadline()
        }
        refresh()
    }

    private func togglePin() {
        Haptics.tick(.generic)
        CompactSettings.setPinned(id, !CompactSettings.isPinned(id))   // posts `changed`: refresh runs below
        refresh()
    }

    private func resetTimer() {
        Haptics.tick(.generic)
        model.reset()
        deadlineItem?.cancel()
        notifier.cancel()
        refresh()
    }

    private func autoReset() {
        guard model.state == .finished else { return }
        model.reset()
        refresh()
    }

    /// One callback at the end time so the state flips to "finished" even if nobody looks.
    private func scheduleDeadline() {
        deadlineItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        deadlineItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + model.remaining(at: Date()) + 0.05, execute: item)
    }

    private func refresh() {
        let now = Date()
        if model.updateFinished(at: now) {
            // Once the sound has finished on its own, the timer returns to idle by itself.
            Chime.shared.play(
                named: TimerSettings.soundName,
                onBeat: { [weak self] in
                    self?.page?.pulse()
                    NotificationCenter.default.post(name: CompactSettings.beat, object: CompactSide.left)
                },
                completion: { [weak self] in self?.autoReset() })
        }
        tiles.forEach { apply(to: $0, now: now) }
        page?.update(model, now: now, pinned: CompactSettings.isPinned(id))
        // Ticks only while someone can see the time: the island is open, or the clock is pinned beside the notch.
        if CompactPolicy.shouldTick(running: model.isRunning, islandOpen: islandOpen, pinned: CompactSettings.isPinned(id)) {
            ticker.start()
        } else {
            ticker.stop()
        }
        compactObserver?()
    }

    private func apply(to tile: TileView, now: Date) {
        tile.isOn = model.isRunning
        tile.statusText = ClockFormat.string(model.remaining(at: now), roundUp: true)
    }
}

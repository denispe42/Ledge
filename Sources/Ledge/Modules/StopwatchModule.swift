import AppKit
import LedgeCore

/// Stopwatch. Ticks only while it runs and the island is open.
@MainActor
final class StopwatchModule: UIModule {
    let id = "stopwatch"
    var title: String { L10n.stopwatch }

    private var model = Stopwatch()
    private let ticker = SecondTicker()
    private var tiles: [TileView] = []
    private weak var page: StopwatchPageView?
    private var islandOpen = false
    private var compactObserver: (() -> Void)?

    func start() throws {
        ticker.nextDelay = { [weak self] in
            guard let self else { return 1 }
            return ClockFormat.delayToNextChange(of: self.model.elapsed(at: Date()), countingDown: false)
        }
        ticker.onTick = { [weak self] in self?.refresh() }
    }

    func stop() {
        ticker.stop()
        model.reset()
        tiles.removeAll()
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "stopwatch", title: title)
        tile.onPress = { Haptics.tick(.generic); open() }
        tiles.append(tile)
        apply(to: tile, now: Date())
        return tile
    }

    func makePage() -> NSView? {
        let page = StopwatchPageView(
            toggle: { [weak self] in self?.toggle() },
            resetWatch: { [weak self] in self?.resetWatch() },
            togglePin: { [weak self] in self?.togglePin() })
        page.update(model, now: Date(), pinned: CompactSettings.isPinned(id))
        self.page = page
        return page
    }

    var compactItem: CompactItem? {
        model.state == .idle ? nil
            : CompactItem(side: .right, text: ClockFormat.string(model.elapsed(at: Date()), roundUp: false))
    }

    func setCompactObserver(_ observer: @escaping () -> Void) { compactObserver = observer }

    func islandVisibilityChanged(_ open: Bool) {
        islandOpen = open
        refresh()
    }

    private func toggle() {
        Haptics.tick(.generic)
        if model.isRunning { model.pause(now: Date()) } else { model.start(now: Date()) }
        refresh()
    }

    private func togglePin() {
        Haptics.tick(.generic)
        CompactSettings.setPinned(id, !CompactSettings.isPinned(id))
        refresh()
    }

    private func resetWatch() {
        Haptics.tick(.generic)
        model.reset()
        refresh()
    }

    private func refresh() {
        let now = Date()
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
        tile.statusText = ClockFormat.string(model.elapsed(at: now), roundUp: false)
    }
}

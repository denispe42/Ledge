import AppKit
import IOKit.pwr_mgt
import LedgeCore

/// System side of Keep Awake: a public IOKit power assertion that stops idle sleep of Mac and display.
@MainActor
final class IOKitPowerAssertions: PowerAssertionProvider {
    func acquire(reason: String) -> UInt32? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 reason as CFString, &id)
        return result == kIOReturnSuccess ? id : nil
    }

    func release(_ token: UInt32) { IOPMAssertionRelease(token) }
}

/// Module wrapper: an enabled module costs nothing until the user switches Keep Awake on. A press keeps the Mac awake
/// until it is pressed again; a long press offers 5, 10, 30 minutes or an hour. A timed run uses one delayed call for
/// its end (wall-clock based, so time asleep counts); nothing is polled.
@MainActor
final class KeepAwakeModule: UIModule {
    let id = "keepAwake"
    var title: String { L10n.keepAwake }

    private var keepAwake: KeepAwake?
    private var tiles: [TileView] = []
    private var session: KeepAwakeSession?
    private var expiry: DispatchWorkItem?
    private var goHome: (() -> Void)?

    /// The time chosen on the wheels last time (30 minutes at first).
    private static var lastDuration: TimeInterval {
        get { UserDefaults.standard.object(forKey: "keepAwake.duration") as? Double ?? 1800 }
        set { UserDefaults.standard.set(newValue, forKey: "keepAwake.duration") }
    }

    func start() throws {
        let keepAwake = KeepAwake(provider: IOKitPowerAssertions())
        keepAwake.onChange = { [weak self] in self?.activityChanged() }
        self.keepAwake = keepAwake
    }

    func stop() {
        cancelExpiry()
        session = nil
        keepAwake?.shutdown()
        keepAwake = nil
        tiles.removeAll()
    }

    func setHomeHandler(_ home: @escaping () -> Void) { goHome = home }

    func makePage() -> NSView? {
        KeepAwakePage(initial: Self.lastDuration, changed: { Self.lastDuration = $0 }) { [weak self] duration in
            self?.begin(for: duration)
            self?.goHome?()
        }
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "cup.and.saucer.fill", title: title)
        apply(keepAwake?.isActive ?? false, to: tile)
        tile.onPress = { [weak self] in
            Haptics.tick(.generic)
            guard let self, let keepAwake = self.keepAwake else { return }
            if keepAwake.isActive { keepAwake.setActive(false) } else { self.begin(for: nil) }
        }
        tile.onLongPress = open
        tiles.append(tile)
        return tile
    }

    /// Starts (or restarts) Keep Awake for `duration` seconds, or until switched off when nil.
    private func begin(for duration: TimeInterval?) {
        guard let keepAwake, keepAwake.setActive(true) else { return }
        cancelExpiry()
        session = KeepAwakeSession.start(at: Date(), for: duration)
        if let duration {
            let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.expire() } }
            expiry = item
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + duration, execute: item)
        }
        refreshTiles()
    }

    private func expire() {
        guard session?.isOver(at: Date()) == true else { return }
        keepAwake?.setActive(false)
    }

    private func cancelExpiry() {
        expiry?.cancel()
        expiry = nil
    }

    /// Switched off by any route (tile, end of the time, module off): the run is over.
    private func activityChanged() {
        if keepAwake?.isActive != true {
            cancelExpiry()
            session = nil
        }
        refreshTiles()
    }

    private func refreshTiles() {
        let on = keepAwake?.isActive ?? false
        tiles.forEach { apply(on, to: $0) }
    }

    private func apply(_ on: Bool, to tile: TileView) {
        tile.isOn = on
        guard on else { tile.statusText = L10n.off; return }
        if let until = session?.until {
            tile.statusText = String(format: L10n.untilTime, Self.timeFormatter.string(from: until))
        } else {
            tile.statusText = L10n.on
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

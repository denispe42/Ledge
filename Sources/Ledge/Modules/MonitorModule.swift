import AppKit
import LedgeCore

/// System monitor: processor, memory, disk, network speed and battery on one page. Nothing is read while the island is
/// closed: the readings are taken once a second only while it is open (like the timer's display), and the battery level
/// comes from the system's own change notification.
@MainActor
final class MonitorModule: UIModule {
    let id = "monitor"
    var title: String { L10n.monitor }

    private let ticker = SecondTicker()
    private let batteryWatcher = BatteryWatcher()
    private var tiles: [TileView] = []
    private weak var page: MonitorPageView?
    private var lastTicks: CPUTicks?
    private var lastNet: (counters: NetCounters, at: Date)?
    private var cpu: Double?
    private var netRate = NetRate(bytesInPerSecond: 0, bytesOutPerSecond: 0)
    private var battery: BatteryState?

    func start() throws {
        ticker.nextDelay = { 1 }
        ticker.onTick = { [weak self] in self?.sample() }
        batteryWatcher.onChange = { [weak self] in
            self?.battery = SystemSampler.battery()
            self?.refresh()
        }
        batteryWatcher.start()
        battery = SystemSampler.battery()
    }

    func stop() {
        ticker.stop()
        batteryWatcher.stop()
        batteryWatcher.onChange = nil
        tiles.removeAll()
        lastTicks = nil
        lastNet = nil
        cpu = nil
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "gauge.with.dots.needle.50percent", title: title)
        tile.onPress = { Haptics.tick(.generic); open() }
        tiles.append(tile)
        apply(to: tile)
        return tile
    }

    func makePage() -> NSView? {
        let page = MonitorPageView()
        self.page = page
        refresh()
        return page
    }

    /// Opening starts a fresh pair of readings (a load figure needs two); closing stops everything.
    func islandVisibilityChanged(_ open: Bool) {
        if open {
            lastTicks = SystemSampler.cpuTicks()
            lastNet = (SystemSampler.network(), Date())
            cpu = nil
            battery = SystemSampler.battery()
            ticker.start()
        } else {
            ticker.stop()
        }
        refresh()
    }

    private func sample() {
        let now = Date()
        if let ticks = SystemSampler.cpuTicks() {
            if let last = lastTicks { cpu = CPUUsage.fraction(from: last, to: ticks) ?? cpu }
            lastTicks = ticks
        }
        let counters = SystemSampler.network()
        if let last = lastNet {
            netRate = NetRate.between(last.counters, counters, seconds: now.timeIntervalSince(last.at))
        }
        lastNet = (counters, now)
        refresh()
    }

    private func refresh() {
        tiles.forEach(apply)
        guard let page else { return }
        let memory = SystemSampler.memory()
        let disk = SystemSampler.disk()
        page.update(.init(
            cpu: cpu,
            memoryUsed: memory.map { MetricFormat.binaryBytes(Double($0.usedBytes)) } ?? "–",
            memoryTotal: memory.map { MetricFormat.binaryBytes(Double($0.total)) } ?? "–",
            memoryFraction: memory?.usedFraction ?? 0,
            diskFree: disk.map { MetricFormat.bytes(Double($0.available)) } ?? "–",
            diskFraction: disk?.usedFraction ?? 0,
            download: MetricFormat.rate(netRate.bytesInPerSecond),
            upload: MetricFormat.rate(netRate.bytesOutPerSecond),
            battery: battery?.text,
            batteryFraction: battery?.fraction,
            batteryDetail: battery.map { $0.showsCharging ? L10n.charging : L10n.onBattery },
            batteryCharging: battery?.showsCharging ?? false,
            cpuLevel: HealthLevel.forLoad(cpu ?? 0),
            memoryLevel: HealthLevel.forMemoryUse(memory?.usedFraction ?? 0),
            diskLevel: HealthLevel.forFreeShare(1 - (disk?.usedFraction ?? 0)),
            batteryLevel: battery?.level ?? .ok))
    }

    private func apply(to tile: TileView) {
        tile.statusText = cpu.map { "\(L10n.cpu) \(MetricFormat.percent($0))" } ?? L10n.cpu
    }
}

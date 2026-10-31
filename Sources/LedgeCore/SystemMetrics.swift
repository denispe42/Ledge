import Foundation

/// CPU tick counters as the kernel reports them (cumulative since boot, summed over all cores).
public struct CPUTicks: Equatable, Sendable {
    public var user, system, idle, nice: UInt64
    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
    var busy: UInt64 { user &+ system &+ nice }
    var total: UInt64 { busy &+ idle }
}

public enum CPUUsage {
    /// Share of the time the cores were busy between two readings, 0...1. nil without a usable difference.
    public static func fraction(from a: CPUTicks, to b: CPUTicks) -> Double? {
        guard b.user >= a.user, b.system >= a.system, b.idle >= a.idle, b.nice >= a.nice else { return nil }
        let total = b.total - a.total
        guard total > 0 else { return nil }
        return Double(b.busy - a.busy) / Double(total)
    }
}

/// Memory page counts from the kernel; "used" is counted like Activity Monitor's "Memory Used".
public struct MemoryPages: Equatable, Sendable {
    public var total: UInt64, pageSize: UInt64
    public var `internal`: UInt64, purgeable: UInt64, wired: UInt64, compressed: UInt64

    public init(total: UInt64, pageSize: UInt64, internal: UInt64, purgeable: UInt64, wired: UInt64, compressed: UInt64) {
        self.total = total; self.pageSize = pageSize
        self.internal = `internal`; self.purgeable = purgeable; self.wired = wired; self.compressed = compressed
    }

    public var usedBytes: UInt64 {
        let app = `internal` > purgeable ? `internal` - purgeable : 0
        return (app + wired + compressed) * pageSize
    }

    public var usedFraction: Double {
        total > 0 ? min(1, Double(usedBytes) / Double(total)) : 0
    }
}

public struct NetCounters: Equatable, Sendable {
    public var bytesIn: UInt64, bytesOut: UInt64
    public init(bytesIn: UInt64, bytesOut: UInt64) { self.bytesIn = bytesIn; self.bytesOut = bytesOut }
}

public struct NetRate: Equatable, Sendable {
    public var bytesInPerSecond: Double, bytesOutPerSecond: Double

    public init(bytesInPerSecond: Double, bytesOutPerSecond: Double) {
        self.bytesInPerSecond = bytesInPerSecond; self.bytesOutPerSecond = bytesOutPerSecond
    }

    /// Speed between two readings; a counter that went backwards (an interface came and went) counts as no traffic.
    public static func between(_ a: NetCounters, _ b: NetCounters, seconds: Double) -> NetRate {
        guard seconds > 0 else { return NetRate(bytesInPerSecond: 0, bytesOutPerSecond: 0) }
        func speed(_ old: UInt64, _ new: UInt64) -> Double { new >= old ? Double(new - old) / seconds : 0 }
        return NetRate(bytesInPerSecond: speed(a.bytesIn, b.bytesIn), bytesOutPerSecond: speed(a.bytesOut, b.bytesOut))
    }
}

public struct DiskSpace: Equatable, Sendable {
    public var total: UInt64, available: UInt64
    public init(total: UInt64, available: UInt64) { self.total = total; self.available = available }
    public var usedFraction: Double { total > 0 ? Double(total - min(available, total)) / Double(total) : 0 }
}

public struct BatteryState: Equatable, Sendable {
    public var percent: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public init(percent: Int, isCharging: Bool, isPluggedIn: Bool) {
        self.percent = percent; self.isCharging = isCharging; self.isPluggedIn = isPluggedIn
    }
    public var fraction: Double { Double(min(max(percent, 0), 100)) / 100 }

    /// Low charge matters only while the battery is the only source of power.
    public var level: HealthLevel {
        if isCharging || isPluggedIn { return .ok }
        if percent <= 10 { return .critical }
        return percent <= 20 ? .warning : .ok
    }

    /// Plugged in counts as charging: the system reports "plugged in" first and "charging" a moment later, and the
    /// label must not flip between the two.
    public var showsCharging: Bool { isCharging || isPluggedIn }

    public var text: String { "\(min(max(percent, 0), 100))%" }
}

/// How worried the user should be about a reading; the interface turns it into green, orange or red.
public enum HealthLevel: Equatable, Sendable {
    case ok, warning, critical

    /// A load (processor) as a share of the whole.
    public static func forLoad(_ fraction: Double) -> HealthLevel {
        fraction >= 0.9 ? .critical : (fraction >= 0.7 ? .warning : .ok)
    }

    /// Memory in use as a share of the physical memory: macOS fills it on purpose, so only a very full one is a worry.
    public static func forMemoryUse(_ fraction: Double) -> HealthLevel {
        fraction >= 0.95 ? .critical : (fraction >= 0.85 ? .warning : .ok)
    }

    /// Free space as a share of the whole.
    public static func forFreeShare(_ fraction: Double) -> HealthLevel {
        fraction <= 0.07 ? .critical : (fraction <= 0.15 ? .warning : .ok)
    }
}

/// Numbers for people: decimal units like Finder, one decimal place only when it helps.
public enum MetricFormat {
    public static func bytes(_ value: Double) -> String { format(value, base: 1000) }

    /// Memory is counted in powers of 1024 like Activity Monitor (a "24 GB" Mac shows 24 GB).
    public static func binaryBytes(_ value: Double) -> String { format(value, base: 1024) }

    public static func rate(_ bytesPerSecond: Double) -> String { bytes(bytesPerSecond) + "/s" }

    public static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    private static func format(_ value: Double, base: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(0, value)
        var unit = 0
        while v >= base, unit < units.count - 1 { v /= base; unit += 1 }
        let rounded = unit == 0 ? v.rounded() : (v * 10).rounded() / 10
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return "\(text) \(units[unit])"
    }
}

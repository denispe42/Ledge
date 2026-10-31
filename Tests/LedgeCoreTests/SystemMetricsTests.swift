import Foundation
import Testing
@testable import LedgeCore

@Test func cpuUsageIsTheBusyShareOfTheTicksBetweenTwoReadings() {
    let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
    let b = CPUTicks(user: 160, system: 70, idle: 870, nice: 0)   // +80 busy, +70 idle
    let usage = CPUUsage.fraction(from: a, to: b)
    #expect(usage != nil)
    #expect(abs((usage ?? 0) - 80.0 / 150.0) < 0.0001)
}

@Test func niceTicksCountAsBusy() {
    let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
    let b = CPUTicks(user: 0, system: 0, idle: 50, nice: 50)
    #expect(CPUUsage.fraction(from: a, to: b) == 0.5)
}

@Test func cpuUsageNeedsTwoDifferentReadings() {
    let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 0)
    #expect(CPUUsage.fraction(from: a, to: a) == nil)
}

@Test func cpuCounterThatWentBackwardsGivesNothing() {
    let a = CPUTicks(user: 100, system: 100, idle: 100, nice: 0)
    let b = CPUTicks(user: 50, system: 50, idle: 50, nice: 0)
    #expect(CPUUsage.fraction(from: a, to: b) == nil)
}

@Test func memoryUsedFollowsActivityMonitor() {
    // used = (internal − purgeable + wired + compressed) pages × page size
    let m = MemoryPages(total: 16 * 1024 * 1024 * 1024, pageSize: 16384, internal: 400_000, purgeable: 50_000,
                        wired: 100_000, compressed: 50_000)
    #expect(m.usedBytes == UInt64(500_000) * 16384)
    #expect(abs(m.usedFraction - Double(500_000 * 16384) / Double(16 * 1024 * 1024 * 1024)) < 0.0001)
}

@Test func memoryNeverReportsMoreThanTheTotal() {
    let m = MemoryPages(total: 1000, pageSize: 100, internal: 50, purgeable: 0, wired: 50, compressed: 50)
    #expect(m.usedFraction == 1)
    let none = MemoryPages(total: 0, pageSize: 100, internal: 1, purgeable: 0, wired: 0, compressed: 0)
    #expect(none.usedFraction == 0)
}

@Test func purgeableLargerThanInternalDoesNotUnderflow() {
    let m = MemoryPages(total: 1_000_000, pageSize: 1, internal: 10, purgeable: 50, wired: 5, compressed: 0)
    #expect(m.usedBytes == 5)
}

@Test func networkRateIsBytesPerSecond() {
    let a = NetCounters(bytesIn: 1_000, bytesOut: 5_000)
    let b = NetCounters(bytesIn: 3_000, bytesOut: 5_500)
    let rate = NetRate.between(a, b, seconds: 2)
    #expect(rate.bytesInPerSecond == 1_000)
    #expect(rate.bytesOutPerSecond == 250)
}

@Test func networkCounterReset() {
    let a = NetCounters(bytesIn: 9_000, bytesOut: 9_000)
    let b = NetCounters(bytesIn: 100, bytesOut: 100)   // interface went away and came back
    let rate = NetRate.between(a, b, seconds: 1)
    #expect(rate.bytesInPerSecond == 0 && rate.bytesOutPerSecond == 0)
    #expect(NetRate.between(a, a, seconds: 0).bytesInPerSecond == 0)
}

@Test func diskUsedFraction() {
    let d = DiskSpace(total: 1000, available: 250)
    #expect(d.usedFraction == 0.75)
    #expect(DiskSpace(total: 0, available: 0).usedFraction == 0)
}

@Test func sizesAreShownWithSensibleUnits() {
    #expect(MetricFormat.bytes(0) == "0 B")
    #expect(MetricFormat.bytes(999) == "999 B")
    #expect(MetricFormat.bytes(1_500) == "1.5 KB")
    #expect(MetricFormat.bytes(250_000_000) == "250 MB")
    #expect(MetricFormat.bytes(8_589_934_592) == "8.6 GB")
    #expect(MetricFormat.bytes(2_000_000_000_000) == "2 TB")
}

@Test func memorySizesUseBinaryUnitsLikeActivityMonitor() {
    #expect(MetricFormat.binaryBytes(Double(24 << 30)) == "24 GB")
    #expect(MetricFormat.binaryBytes(Double(1_536 << 20)) == "1.5 GB")
    #expect(MetricFormat.binaryBytes(0) == "0 B")
}

@Test func ratesAndPercents() {
    #expect(MetricFormat.rate(0) == "0 B/s")
    #expect(MetricFormat.rate(1_200_000) == "1.2 MB/s")
    #expect(MetricFormat.percent(0.374) == "37%")
    #expect(MetricFormat.percent(1.2) == "100%")
    #expect(MetricFormat.percent(-1) == "0%")
}

@Test func batteryText() {
    #expect(BatteryState(percent: 82, isCharging: false, isPluggedIn: false).text == "82%")
    #expect(BatteryState(percent: 100, isCharging: false, isPluggedIn: true).fraction == 1)
    #expect(BatteryState(percent: 150, isCharging: true, isPluggedIn: true).fraction == 1)
    #expect(BatteryState(percent: -5, isCharging: false, isPluggedIn: false).fraction == 0)
}

@Test func loadLevelsGoFromOkToCritical() {
    #expect(HealthLevel.forLoad(0.3) == .ok)
    #expect(HealthLevel.forLoad(0.699) == .ok)
    #expect(HealthLevel.forLoad(0.7) == .warning)
    #expect(HealthLevel.forLoad(0.89) == .warning)
    #expect(HealthLevel.forLoad(0.9) == .critical)
    #expect(HealthLevel.forLoad(2) == .critical)
}

@Test func memoryUseIsJudgedMoreLeniently() {
    // macOS keeps memory full on purpose (caches, compression), so 77 % is normal.
    #expect(HealthLevel.forMemoryUse(0.77) == .ok)
    #expect(HealthLevel.forMemoryUse(0.85) == .warning)
    #expect(HealthLevel.forMemoryUse(0.95) == .critical)
}

@Test func freeSpaceLevels() {
    #expect(HealthLevel.forFreeShare(0.5) == .ok)
    #expect(HealthLevel.forFreeShare(0.12) == .warning)
    #expect(HealthLevel.forFreeShare(0.05) == .critical)
}

@Test func batteryLevels() {
    #expect(BatteryState(percent: 80, isCharging: false, isPluggedIn: false).level == .ok)
    #expect(BatteryState(percent: 20, isCharging: false, isPluggedIn: false).level == .warning)
    #expect(BatteryState(percent: 10, isCharging: false, isPluggedIn: false).level == .critical)
    #expect(BatteryState(percent: 5, isCharging: true, isPluggedIn: true).level == .ok)   // charging: nothing to worry about
    #expect(BatteryState(percent: 5, isCharging: false, isPluggedIn: true).level == .ok)  // on the adapter
}

@Test func pluggedInBatteryAlwaysShowsAsCharging() {
    // Right after the cable goes in the system first reports "plugged in, not charging yet", then "charging":
    // the label must not change between the two.
    #expect(BatteryState(percent: 60, isCharging: false, isPluggedIn: true).showsCharging)
    #expect(BatteryState(percent: 60, isCharging: true, isPluggedIn: true).showsCharging)
    #expect(!BatteryState(percent: 60, isCharging: false, isPluggedIn: false).showsCharging)
}

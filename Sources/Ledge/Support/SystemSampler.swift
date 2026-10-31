import Foundation
import IOKit.ps
import LedgeCore

/// One-off readings of the system's own counters through public APIs (Mach host statistics, interface counters,
/// volume capacity, IOKit power sources). Nothing here runs by itself: the monitor asks, these functions answer.
enum SystemSampler {
    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // cpu_ticks is indexed by CPU_STATE_USER, SYSTEM, IDLE, NICE.
        return CPUTicks(user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
                        idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
    }

    static func memory() -> MemoryPages? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryPages(total: ProcessInfo.processInfo.physicalMemory, pageSize: UInt64(getpagesize()),
                           internal: UInt64(stats.internal_page_count), purgeable: UInt64(stats.purgeable_count),
                           wired: UInt64(stats.wire_count), compressed: UInt64(stats.compressor_page_count))
    }

    static func disk() -> DiskSpace? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskSpace(total: UInt64(max(0, total)), available: UInt64(max(0, free)))
    }

    static func battery() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = d[kIOPSCurrentCapacityKey] as? Int else { continue }
            let maximum = d[kIOPSMaxCapacityKey] as? Int ?? 100
            return BatteryState(percent: maximum > 0 ? current * 100 / maximum : current,
                                isCharging: d[kIOPSIsChargingKey] as? Bool ?? false,
                                isPluggedIn: (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
        }
        return nil
    }

    /// Network bytes since boot, 64-bit, over the physical interfaces (en0, en1, …; not loopback and not
    /// VPN tunnels, which would count the same traffic twice). Read per interface through the interface MIB: the
    /// route-socket interface list reports the byte counters cut to 32 bits on current macOS (checked against netstat).
    static func network() -> NetCounters {
        var total = NetCounters(bytesIn: 0, bytesOut: 0)
        guard let list = if_nameindex() else { return total }
        defer { if_freenameindex(list) }
        var item = list
        while item.pointee.if_index != 0, let namePointer = item.pointee.if_name {
            defer { item += 1 }
            guard String(cString: namePointer).hasPrefix("en") else { continue }
            var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, Int32(item.pointee.if_index), IFDATA_GENERAL]
            var data = ifmibdata()
            var size = MemoryLayout<ifmibdata>.size
            guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0,
                  data.ifmd_flags & UInt32(IFF_UP) != 0 else { continue }
            total.bytesIn &+= data.ifmd_data.ifi_ibytes
            total.bytesOut &+= data.ifmd_data.ifi_obytes
        }
        return total
    }
}

/// Tells when the battery level or the power source changes (the system posts it; nothing is polled).
@MainActor
final class BatteryWatcher {
    var onChange: (() -> Void)?
    private var source: CFRunLoopSource?

    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let address = UInt(bitPattern: context)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
                    Unmanaged<BatteryWatcher>.fromOpaque(pointer).takeUnretainedValue().onChange?()
                }
            }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
        source = created
    }

    func stop() {
        guard let source else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        CFRunLoopSourceInvalidate(source)
        self.source = nil
    }
}

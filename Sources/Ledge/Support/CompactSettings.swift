import Foundation

/// Settings for the clocks shown beside the notch while the island is closed.
@MainActor
enum CompactSettings {
    static let changed = Notification.Name("ledge.compact.settings.changed")
    /// Posted on each beat of an end sound; the object is the `CompactSide` whose clock should pulse.
    static let beat = Notification.Name("ledge.compact.beat")
    private static let hideKey = "compact.hideInFullscreen"

    /// Whether a module's clock is pinned beside the notch while the island is closed. Default: no.
    static func isPinned(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: "compact.pinned.\(id)")
    }

    static func setPinned(_ id: String, _ pinned: Bool) {
        UserDefaults.standard.set(pinned, forKey: "compact.pinned.\(id)")
        NotificationCenter.default.post(name: changed, object: nil)
    }

    /// Whether the clocks beside the notch disappear while another app is in full screen. Default: yes.
    static var hideInFullscreen: Bool {
        get { UserDefaults.standard.object(forKey: hideKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: hideKey)
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }
}

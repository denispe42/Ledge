import Foundation
import LedgeCore

/// The user's choice of how the opened island looks (glass or black); applied at once, kept in the preferences.
@MainActor
enum IslandLookSetting {
    static let changed = Notification.Name("ledge.island.look.changed")
    private static let key = "island.look"

    static var current: IslandLook {
        get { IslandLook.stored(UserDefaults.standard.string(forKey: key)) }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }
}

import Foundation
import LedgeCore

/// Module switches and the crash marker live in UserDefaults (local only).
@MainActor
final class UserDefaultsModuleStore: ModuleSettingsStore {
    private let defaults = UserDefaults.standard

    func isEnabled(_ id: ModuleID) -> Bool? {
        defaults.object(forKey: "module.\(id).enabled") as? Bool
    }

    func setEnabled(_ id: ModuleID, _ enabled: Bool) {
        defaults.set(enabled, forKey: "module.\(id).enabled")
    }

    var startingModule: ModuleID? {
        get { defaults.string(forKey: "startingModule") }
        set { defaults.set(newValue, forKey: "startingModule") }
    }
}

import Foundation
import LedgeCore
import ServiceManagement

/// Open at login through the public `SMAppService` API (no helper app, no extra permission; macOS lists Ledge under
/// System Settings → General → Login Items, where the user can also switch it off).
@MainActor
enum LaunchAtLoginSetting {
    private static let key = "launchAtLogin.choice"

    private static var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        default: .notRegistered
        }
    }

    static var isOn: Bool { LaunchAtLogin.isOn(status) }

    /// Called once at start: the very first run enrols the app (the default is "on").
    static func applyDefaultOnFirstRun() {
        let stored = UserDefaults.standard.object(forKey: key) as? Bool
        guard LaunchAtLogin.startupAction(stored: stored) == .register else { return }
        try? SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: key)
    }

    /// The Settings switch. Returns false if the system refused (the switch then shows the real state).
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        UserDefaults.standard.set(on, forKey: key)
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            return false
        }
        return true
    }
}

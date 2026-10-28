import AppKit
import LedgeCore

/// Switching the interface language: the choice is stored as the app's own `AppleLanguages` override (macOS reads it
/// when the app starts), then the app starts a fresh copy of itself and quits. Choosing "same as system" removes the
/// override, so the app follows the system language again, including when that changes later.
@MainActor
enum AppLanguageSetting {
    private static var bundleID: String { Bundle.main.bundleIdentifier ?? "app.ledge.Ledge" }

    /// The language the user picked in the app, or nil for "same as system".
    static var choice: String? {
        let stored = UserDefaults.standard.persistentDomain(forName: bundleID)?["AppleLanguages"] as? [String]
        return AppLanguage.override(stored: stored)
    }

    static func choose(_ code: String?) {
        guard code != choice else { return }
        if let stored = AppLanguage.valueToStore(for: code) {
            UserDefaults.standard.set(stored, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        relaunch()
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

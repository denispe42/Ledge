import AppKit

/// Trackpad haptics through the public NSHapticFeedbackManager. Silent on hardware without a Force Touch trackpad.
@MainActor
enum Haptics {
    static let defaultsKey = "haptics.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func tick(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

import Foundation
import UserNotifications

/// The standard macOS notification that announces the end of a timer (no custom windows or sounds).
/// It is scheduled with the system, so it also fires when the island is closed or the Mac was asleep.
@MainActor
final class TimerNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let requestID = "ledge.timer.finished"

    /// nil when running outside an app bundle (for example a plain `swift run`), where the API would crash.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func schedule(after seconds: TimeInterval) {
        guard let center, seconds > 0 else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = L10n.timerFinished
        content.sound = nil   // the sound is played by `Chime`, so there is no double sound
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }

    func cancel() {
        center?.removePendingNotificationRequests(withIdentifiers: [requestID])
        center?.removeDeliveredNotifications(withIdentifiers: [requestID])
    }

    /// Show the banner even though Ledge counts as the frontmost app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}

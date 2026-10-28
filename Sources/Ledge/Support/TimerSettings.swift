import Foundation
import LedgeCore

/// Timer preferences: which system sound announces the end.
@MainActor
enum TimerSettings {
    private static let soundKey = "timer.sound"
    static let soundDirectory = "/System/Library/Sounds"

    /// Names of the sounds installed with macOS (read when needed, so a changed system set is picked up).
    static var availableSounds: [String] {
        SoundCatalog.names(fromFileNames: (try? FileManager.default.contentsOfDirectory(atPath: soundDirectory)) ?? [])
    }

    static var soundName: String {
        get {
            SoundCatalog.resolve(selected: UserDefaults.standard.string(forKey: soundKey), available: availableSounds) ?? "Glass"
        }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }
}

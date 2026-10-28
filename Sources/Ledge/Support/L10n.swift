import Foundation

/// All user-visible strings. Keys are the English text, so a missing translation falls back to English.
/// Translations live in Resources/<lang>.lproj/Localizable.strings; the system language picks the file.
enum L10n {
    private static func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    static var keepAwake: String { tr("Keep Awake") }
    static var settings: String { tr("Settings…") }
    static var quit: String { tr("Quit Ledge") }
    static var on: String { tr("On") }
    static var off: String { tr("Off") }
    static var timer: String { tr("Timer") }
    static var stopwatch: String { tr("Stopwatch") }
    static var calculator: String { tr("Calculator") }
    static var programmerKeys: String { tr("Programmer keys") }
    static var extendedKeys: String { tr("Parentheses, powers and fractions") }
    static var history: String { tr("History") }
    static var clearHistory: String { tr("Clear history") }
    static var noCalculations: String { tr("No calculations yet") }
    static var shelf: String { tr("Shelf") }
    static var dropFilesHere: String { tr("Drop files here") }
    static var filesCount: String { tr("Files: %d") }
    static var empty: String { tr("Empty") }
    static var showInFinder: String { tr("Show in Finder") }
    static var removeFromShelf: String { tr("Remove from shelf") }
    static var clearShelf: String { tr("Clear shelf") }
    static var all: String { tr("All") }
    static var selectFiles: String { tr("Select files") }
    static var selectedCount: String { tr("Selected: %d") }
    static var removeSelected: String { tr("Remove selected from shelf") }
    static var airDrop: String { tr("AirDrop") }
    static var chooseFiles: String { tr("Choose files") }
    static var send: String { tr("Send") }
    static var airDropUnavailable: String { tr("AirDrop unavailable") }
    static var microphone: String { tr("Microphone") }
    static var muted: String { tr("Muted") }
    static var unavailable: String { tr("Unavailable") }
    static var noMicrophone: String { tr("No microphone found") }
    static var cleaning: String { tr("Cleaning") }
    static var cleaningHint: String { tr("Hold Esc or the button for 3 seconds to exit") }
    static var allowAccess: String { tr("Allow access") }
    static var mirror: String { tr("Mirror") }
    static var open: String { tr("Open") }
    static var close: String { tr("Close") }
    static var noCameraAccess: String { tr("No access to the camera") }
    static var noCamera: String { tr("No camera found") }
    static var rearrange: String { tr("Rearrange") }
    static var bringBackIcons: String { tr("Bring back icons") }
    static var bringBackAll: String { tr("Bring back all") }
    static var hoursUnit: String { tr("h") }
    static var minutesUnit: String { tr("min") }
    static var always: String { tr("Always") }
    static var untilTime: String { tr("until %@") }
    static var language: String { tr("Language") }
    static var sameAsSystem: String { tr("Same as system") }
    static var languageRestartNote: String { tr("Ledge restarts to apply the language.") }
    static var islandLook: String { tr("Island look") }
    static var lookGlass: String { tr("Glass") }
    static var lookBlack: String { tr("Black") }
    static var launchAtLogin: String { tr("Open at login") }
    static var exit: String { tr("Exit") }
    static var monitor: String { tr("Monitor") }
    static var cpu: String { tr("CPU") }
    static var memory: String { tr("Memory") }
    static var disk: String { tr("Disk") }
    static var download: String { tr("Download") }
    static var upload: String { tr("Upload") }
    static var battery: String { tr("Battery") }
    static var ofTotal: String { tr("of %@") }
    static var freeSpace: String { tr("free") }
    static var noBattery: String { tr("No battery") }
    static var charging: String { tr("Charging") }
    static var onBattery: String { tr("On battery") }
    /// A failure message from the module registry (its texts are English keys that live only in the strings files, e.g. "Crashed on the previous launch, switched off"; system error texts pass through).
    static func failure(_ message: String) -> String { tr(message) }
    static var error: String { tr("Error") }
    static var start: String { tr("Start") }
    static var pause: String { tr("Pause") }
    static var resume: String { tr("Resume") }
    static var reset: String { tr("Reset") }
    static var timerFinished: String { tr("Timer finished") }
    static var modules: String { tr("Modules") }
    static var general: String { tr("General") }
    static var hideTimeInFullscreen: String { tr("Hide the time beside the notch in full screen") }
    static var timerSound: String { tr("Sound at the end") }
    static var testSound: String { tr("Test sound") }
    static var pinTime: String { tr("Show the time next to the notch") }
    static var haptics: String { tr("Trackpad haptic feedback") }
    static var statusItemTip: String { tr("Ledge") }
}

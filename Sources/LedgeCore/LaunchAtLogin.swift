/// The system's view of a login item (a plain copy of `SMAppService.Status`, so the rules are testable).
public enum LoginItemStatus: Equatable, Sendable {
    case enabled, notRegistered, requiresApproval, notFound
}

public enum LoginItemAction: Equatable, Sendable {
    case register, nothing
}

/// Open at login: on by default, switchable in Settings or in System Settings → Login Items.
public enum LaunchAtLogin {
    /// What to do when the app starts. `stored` is the user's own choice made in Ledge's Settings (nil: never chosen).
    /// The first run switches the item on, as promised by the default; after that the app only reflects the system,
    /// so a user who removed Ledge from Login Items is not enrolled again at the next start.
    public static func startupAction(stored: Bool?) -> LoginItemAction { stored == nil ? .register : .nothing }

    /// Only a real app bundle may become a login item. A bare executable or a development build (Xcode's DerivedData,
    /// SwiftPM's .build) would be launched by macOS inside a Terminal window at every login.
    public static func canRegister(bundlePath: String) -> Bool {
        bundlePath.hasSuffix(".app") && !bundlePath.contains("/DerivedData/") && !bundlePath.contains("/.build/")
    }

    public static func isOn(_ status: LoginItemStatus) -> Bool { status == .enabled }
}

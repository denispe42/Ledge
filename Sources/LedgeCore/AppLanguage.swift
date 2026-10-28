/// The languages Ledge is translated into, and how the user's own choice is kept. With no choice the app follows the
/// system language (also when the system language changes later); a choice is stored as the app's own
/// `AppleLanguages` override, which macOS reads at launch.
public struct AppLanguage: Equatable, Sendable {
    public let code: String
    /// The name in the language itself, so a user can find their language whatever the interface says now.
    public let nativeName: String

    /// One per `Resources/<code>.lproj` folder (a test keeps the two in step).
    public static let all: [AppLanguage] = [
        .init(code: "en", nativeName: "English"),
        .init(code: "ru", nativeName: "Русский"),
        .init(code: "de", nativeName: "Deutsch"),
        .init(code: "fr", nativeName: "Français"),
        .init(code: "es", nativeName: "Español"),
        .init(code: "it", nativeName: "Italiano"),
        .init(code: "pt-BR", nativeName: "Português (Brasil)"),
        .init(code: "pl", nativeName: "Polski"),
        .init(code: "cs", nativeName: "Čeština"),
        .init(code: "uk", nativeName: "Українська"),
        .init(code: "tr", nativeName: "Türkçe"),
        .init(code: "ja", nativeName: "日本語"),
        .init(code: "ko", nativeName: "한국어"),
        .init(code: "zh-Hans", nativeName: "简体中文"),
    ]

    /// The user's choice from the app's stored `AppleLanguages`; nil means "same as the system".
    public static func override(stored: [String]?) -> String? {
        guard let first = stored?.first, all.contains(where: { $0.code == first }) else { return nil }
        return first
    }

    /// What to store for a choice (nil clears the override, so the system language applies again).
    public static func valueToStore(for code: String?) -> [String]? {
        guard let code, all.contains(where: { $0.code == code }) else { return nil }
        return [code]
    }
}

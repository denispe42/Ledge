/// How the opened island looks: the system glass, or solid black that melts into the notch like the closed island.
/// Both keep the project's two-colour rule for icons and text (white on dark, black on light glass; always white on black).
public enum IslandLook: String, CaseIterable, Sendable {
    case glass, black

    /// The look kept in the preferences; anything unknown or missing means glass.
    public static func stored(_ value: String?) -> IslandLook { value.flatMap(IslandLook.init(rawValue:)) ?? .glass }

    /// Black has no light variant, so everything on it is drawn as on a dark surface.
    public var forcesDarkAppearance: Bool { self == .black }
}

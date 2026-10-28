import Foundation

/// Picks the sound for the end of a timer from the system sounds (file names are supplied by the shell).
public enum SoundCatalog {
    private static let extensions: Set<String> = ["aiff", "aif", "caf", "wav", "m4a", "mp3"]

    /// Sound names (file names without the extension), sorted, skipping anything that is not an audio file.
    public static func names(fromFileNames files: [String]) -> [String] {
        files.compactMap { file -> String? in
            let url = URL(fileURLWithPath: file)
            guard extensions.contains(url.pathExtension.lowercased()) else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            return name.isEmpty ? nil : name
        }.sorted()
    }

    /// The selected sound if it still exists, otherwise `defaultName`, otherwise the first available one.
    public static func resolve(selected: String?, available: [String], defaultName: String = "Glass") -> String? {
        if let selected, available.contains(selected) { return selected }
        if available.contains(defaultName) { return defaultName }
        return available.first
    }
}

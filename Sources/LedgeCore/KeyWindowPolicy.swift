/// Whether the opened island takes the key window (needed for the full Liquid Glass look).
public enum KeyWindowPolicy {
    /// Over an app in full screen the panel must not become key: activating Ledge there pulls the opened island onto
    /// another desktop, so the click on the notch seems to do nothing.
    public static func opensAsKey(frontAppIsFullscreen: Bool) -> Bool {
        !frontAppIsFullscreen
    }
}

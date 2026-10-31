import Foundation

/// Where the user's tile order is kept (a list of module ids in UserDefaults; no files).
enum TileOrderStore {
    private static let key = "tiles.order"

    private static let hiddenKey = "tiles.hidden"

    /// Tiles the user put away from the home screen (the modules keep running).
    static var hidden: [String] {
        get { UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: hiddenKey) }
    }

    static var saved: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

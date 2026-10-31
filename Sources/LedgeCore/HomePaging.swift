import Foundation

/// The home screen of the island shows the module tiles ten at a time (two rows of five); more tiles make more pages.
public enum HomePaging {
    public static let tilesPerPage = 10

    public static func pageCount(tiles: Int) -> Int {
        max(1, (tiles + tilesPerPage - 1) / tilesPerPage)
    }

    public static func clamped(page: Int, tiles: Int) -> Int {
        min(max(page, 0), pageCount(tiles: tiles) - 1)
    }

    /// Indices of the tiles on `page` (the last page for a page beyond the end).
    public static func range(page: Int, tiles: Int) -> Range<Int> {
        let p = clamped(page: page, tiles: tiles)
        return (p * tilesPerPage)..<min(tiles, (p + 1) * tilesPerPage)
    }

    public static func stepped(from page: Int, by step: Int, tiles: Int) -> Int {
        clamped(page: page + step, tiles: tiles)
    }
}

import CoreGraphics

/// Where tiles sit in the home grid and in the "bring back" page: five to a row, rows centred.
@MainActor
enum TileGridLayout {
    static let columns = 5
    /// Distance between neighbouring cells: the tiles' circles are 14 pt apart across and 10 pt down.
    static let pitch = CGSize(width: TileView.fullSize.width - 2, height: TileView.fullSize.height - 6)
    /// Two full rows of five.
    static let size = CGSize(width: 4 * pitch.width + TileView.fullSize.width, height: pitch.height + TileView.fullSize.height)

    /// Bottom-left corner of cell `index` when `count` tiles are shown (view coordinates, y up, first row on top).
    static func origin(index: Int, count: Int) -> CGPoint {
        let row = index / columns
        let inRow = min(columns, count - row * columns)
        let indent = CGFloat(columns - inRow) * pitch.width / 2
        return CGPoint(x: indent + CGFloat(index % columns) * pitch.width,
                       y: size.height - TileView.fullSize.height - CGFloat(row) * pitch.height)
    }
}

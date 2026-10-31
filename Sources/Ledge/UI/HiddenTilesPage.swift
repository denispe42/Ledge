import AppKit
import LedgeCore

/// The page that lists the tiles the user put away: one row of up to five icons in the same rounded frame as the
/// rearranging screen, and under it a full "Bring back all" button. Press an icon to bring that one back. No hint
/// text: the page explains itself. At most five tiles can be put away (`TileArrangement.maxHidden`), so they all fit.
@MainActor
final class HiddenTilesPage: NSView {
    struct Item { let id: String, symbol: String, title: String }

    static let capacity = TileArrangement.maxHidden

    var onPick: ((String) -> Void)?
    var onBringBackAll: (() -> Void)?
    private let board = NSView()
    private let grid = NSView()
    private let bringBackAll = PillButton(title: L10n.bringBackAll, width: 132, height: 32)

    init(items: [Item]) {
        super.init(frame: .zero)
        let shown = Array(items.prefix(Self.capacity))
        // The frame lies outside nothing here, but it must never be clipped by the page area.
        wantsLayer = true
        layer?.masksToBounds = false
        grid.wantsLayer = true
        grid.layer?.masksToBounds = false
        grid.translatesAutoresizingMaskIntoConstraints = false
        bringBackAll.translatesAutoresizingMaskIntoConstraints = false
        bringBackAll.toolTip = L10n.bringBackAll
        bringBackAll.onPress = { [weak self] in self?.onBringBackAll?() }
        addSubview(grid)
        addSubview(bringBackAll)
        let frameSize = CGSize(width: TileGridLayout.size.width, height: TileView.fullSize.height)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 440),
            grid.centerXAnchor.constraint(equalTo: centerXAnchor),
            grid.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            grid.widthAnchor.constraint(equalToConstant: frameSize.width),
            grid.heightAnchor.constraint(equalToConstant: frameSize.height),
            bringBackAll.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Visual gap of 8 pt between the frame and the button (the button has its own 8 pt transparent margin).
            bringBackAll.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 8 - PillButton.pad),
            bringBackAll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // The same frame as on the rearranging screen (8 pt around the circles), one row high.
        board.wantsLayer = true
        board.layer?.cornerRadius = 22
        board.layer?.borderWidth = 1.5
        board.frame = NSRect(origin: .zero, size: frameSize)
        grid.addSubview(board)
        for (index, item) in shown.enumerated() {
            let tile = TileView(symbol: item.symbol, title: item.title)
            var origin = TileGridLayout.origin(index: index, count: shown.count)
            origin.y = 0
            tile.setFrameOrigin(origin)
            tile.onPress = { [weak self] in self?.onPick?(item.id) }
            grid.addSubview(tile)
        }
        updateBoardColor()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { updateBoardColor() }

    private func updateBoardColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            board.layer?.borderColor = Glass.ink.withAlphaComponent(0.25).cgColor
        }
    }
}

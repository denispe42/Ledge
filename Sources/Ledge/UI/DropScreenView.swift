import AppKit

/// What the island shows while files are dragged to the notch: one drop zone per module that takes files.
@MainActor
final class DropScreenView: NSView {
    /// The files, the index of the zone that received them and that zone's view (it anchors system windows).
    var onDrop: (([URL], Int, NSView) -> Void)?

    init(zones: [DropZone]) {
        super.init(frame: .zero)
        let views = zones.enumerated().map { index, zone -> DropZoneView in
            let view = DropZoneView(symbol: zone.symbol, title: zone.title)
            view.onDrop = { [weak self, weak view] urls in
                guard let view else { return }
                self?.onDrop?(urls, index, view)
            }
            return view
        }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// The page slot has no width of its own, so the screen brings its size (the island's content width).
    override var intrinsicContentSize: NSSize { NSSize(width: 416, height: 108) }
}

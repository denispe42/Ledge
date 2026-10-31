import AppKit
import LedgeCore

/// The collapsed island: a black shape that merges with the notch, with the clocks of pinned modules on the strips
/// beside it. It is its own window (see PillPanel), so closing the opened island can cross-fade into it with no gap.
@MainActor
final class PillView: NSView {
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

    var onPointerEntered: (() -> Void)?
    var onClicked: (() -> Void)?
    /// A two-finger swipe down over the closed island opens it, like a click.
    var onSwipedDown: (() -> Void)?
    /// Files are dragged over the closed island: it opens so they can be dropped on the shelf.
    var onFilesDragEntered: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?

    private let backdrop = NSView()
    private let leftLabel = NSTextField(labelWithString: "")
    private let rightLabel = NSTextField(labelWithString: "")
    private var leftEar: CGFloat = 0
    private var rightEar: CGFloat = 0
    private var swipe = VerticalSwipe()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        registerForDraggedTypes(FileDrop.types)
        backdrop.frame = bounds
        backdrop.autoresizingMask = [.width, .height]
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor.black.cgColor
        // Flat top merges with the screen edge; bottom corners are rounded (layer origin is bottom-left).
        backdrop.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backdrop.layer?.cornerRadius = 10
        for label in [leftLabel, rightLabel] {
            label.font = Self.font
            label.textColor = .white      // the collapsed island is always black
            label.alignment = .center
            label.isHidden = true
            backdrop.addSubview(label)
        }
        addSubview(backdrop)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Clock texts in strips of width `leftEar` / `rightEar` next to the notch (nil = nothing on that side).
    func setClocks(left: String?, right: String?, leftEar: CGFloat, rightEar: CGFloat) {
        leftLabel.stringValue = left ?? ""
        rightLabel.stringValue = right ?? ""
        leftLabel.isHidden = left == nil
        rightLabel.isHidden = right == nil
        self.leftEar = leftEar
        self.rightEar = rightEar
        needsLayout = true
    }

    func pulseClock(on side: CompactSide) {
        (side == .left ? leftLabel : rightLabel).pulse()
    }

    override func layout() {
        super.layout()
        let height = ceil(Self.font.boundingRectForFont.height)
        let y = (bounds.height - height) / 2
        leftLabel.frame = NSRect(x: 0, y: y, width: leftEar, height: height)
        rightLabel.frame = NSRect(x: bounds.width - rightEar, y: y, width: rightEar, height: height)
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
        super.updateTrackingAreas()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard FileDrop.hasFiles(sender) else { return [] }
        onFilesDragEntered?()
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDrop.fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }

    override func mouseEntered(with event: NSEvent) { onPointerEntered?() }
    override func mouseDown(with event: NSEvent) { onClicked?() }
    override func scrollWheel(with event: NSEvent) {
        if swipe.feed(event) == .down { onSwipedDown?() }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

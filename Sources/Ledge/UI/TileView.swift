import AppKit

/// A module tile: one round icon on system glass. Name and state are not drawn on the tile; the island shows them in
/// one line under the grid for the tile under the pointer (`onHover`, `title`, `statusText`). The glass uses the system
/// default style (no tint set), so it follows the user's Liquid Glass setting. Icons use only two colours (see
/// `Glass.ink`); when the feature is on, the whole circle is inverted.
@MainActor
final class TileView: NSView {
    /// The visible circle.
    static let diameter: CGFloat = 48
    /// Transparent margin around the circle: the glass grows and squashes when pressed and must not be clipped.
    static let pad: CGFloat = 8
    private static let discInset: CGFloat = 1
    static let fullSize = NSSize(width: diameter + 2 * pad, height: diameter + 2 * pad)

    enum DragPhase { case began, moved, ended }

    /// The module this tile belongs to (the island saves the user's tile order by it).
    var moduleID = ""
    var onPress: (() -> Void)?
    /// Held down for about half a second (then `onPress` is not called). A tile with this waits for the button to come
    /// up before it presses; without it a press acts at once on mouse down.
    var onLongPress: (() -> Void)?
    private var longPressWork: DispatchWorkItem?
    private var longPressFired = false
    /// While `isEditing`, presses become drags that rearrange the tiles.
    var onDrag: ((DragPhase, NSEvent) -> Void)?
    /// Rearranging mode: the tile wiggles and follows the pointer instead of acting.
    /// Dragged outside the frame: it will be put away when let go (shown red).
    var isDoomed = false { didSet { updateAppearance() } }
    var isEditing = false { didSet { if isEditing != oldValue { updateEditing() } } }
    /// The pointer entered (true) or left (false) the tile.
    var onHover: ((Bool) -> Void)?
    /// `statusText` changed; the island refreshes its line if this tile is the one under the pointer.
    var onTextChange: (() -> Void)?
    var isOn = false { didSet { updateAppearance() } }
    var statusText = "" {
        didSet {
            setAccessibilityValue(statusText)
            onTextChange?()
        }
    }

    let title: String
    /// The SF Symbol shown now (the "bring back" page draws the same icon).
    private(set) var symbolName = ""
    private var host: NSView?
    /// What the glass wraps; the disc sits 1 pt inside it so its edge never meets the glass edge (a bright speck
    /// used to wander along the rim of a white tile while it shook).
    private let content = NSView()
    private let disc = NSView()
    private let symbol = NSImageView()

    init(symbol name: String, title: String) {
        self.title = title
        super.init(frame: NSRect(origin: .zero, size: Self.fullSize))
        wantsLayer = true
        setAccessibilityLabel(title)
        setAccessibilityRole(.button)

        disc.wantsLayer = true
        disc.layer?.cornerRadius = Self.diameter / 2 - Self.discInset
        disc.translatesAutoresizingMaskIntoConstraints = false
        setSymbol(name)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(disc)
        disc.addSubview(symbol)
        NSLayoutConstraint.activate([
            disc.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.discInset),
            disc.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.discInset),
            disc.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.discInset),
            disc.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.discInset),
            symbol.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
        ])
        embed(content)
        updateAppearance()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Swaps the icon (a tile whose state is shown by its glyph, like the muted microphone).
    func setSymbol(_ name: String) {
        symbolName = name
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 19, weight: .semibold))
    }

    override func viewDidChangeEffectiveAppearance() { updateAppearance() }
    /// Only the circle itself is clickable, not the transparent margin. The tile answers for itself (not for an icon
    /// inside it), so `acceptsFirstMouse` below counts: a press on the island while another window of the app (the file
    /// chooser) is key must act at once instead of just taking the focus.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.insetBy(dx: Self.pad, dy: Self.pad).contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        if isEditing { return onDrag?(.began, event) ?? () }
        guard onLongPress != nil else { return onPress?() ?? () }
        longPressFired = false
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.longPressFired = true
                Haptics.tick(.levelChange)
                self.onLongPress?()
            }
        }
        longPressWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }
    override func mouseDragged(with event: NSEvent) { if isEditing { onDrag?(.moved, event) } }
    override func mouseUp(with event: NSEvent) {
        if isEditing { return onDrag?(.ended, event) ?? () }
        guard onLongPress != nil else { return }
        longPressWork?.cancel()
        longPressWork = nil
        if !longPressFired { onPress?() }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds.insetBy(dx: Self.pad, dy: Self.pad),
                                       options: [.mouseEnteredAndExited, .activeAlways], owner: self))
        super.updateTrackingAreas()
    }

    /// Hovering: the circle swells a little and the trackpad ticks (not while rearranging).
    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
        guard !isEditing else { return }
        Haptics.tick(.alignment)
        swell(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
        swell(false)
    }

    private func swell(_ on: Bool) {
        guard let layer = host?.layer else { return }
        let target = on ? layer.aboutCenter { CATransform3DScale($0, 1.1, 1.1, 1) } : CATransform3DIdentity
        let from = layer.presentation()?.transform ?? layer.transform
        layer.transform = target
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: from)
        animation.toValue = NSValue(caTransform3D: target)
        animation.duration = 0.14
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "swell")
    }

    /// Starts the wiggle again if the tile is in rearranging mode. A tile that was put away and brought back keeps
    /// `isEditing == true`, so setting it again does nothing, and taking a view out of the window stops its animations.
    func restartEditingAnimation() { updateEditing() }

    private func updateEditing() {
        swell(false)
        guard let layer else { return }
        layer.removeAnimation(forKey: "wiggle")
        guard isEditing, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        // The circle only shifts (no turning): turning the glass moves its lit rim, which showed as a wandering white speck.
        func shaken(_ side: CGFloat) -> NSValue {
            NSValue(caTransform3D: layer.aboutCenter {
                CATransform3DTranslate($0, side * 0.8, -side * 0.6, 0)
            })
        }
        let wiggle = CABasicAnimation(keyPath: "transform")
        wiggle.fromValue = shaken(-1)
        wiggle.toValue = shaken(1)
        wiggle.duration = 0.09 + Double.random(in: 0...0.04)
        wiggle.autoreverses = true
        wiggle.repeatCount = .infinity
        wiggle.timeOffset = Double.random(in: 0...0.1)
        layer.add(wiggle, forKey: "wiggle")
    }

    private func embed(_ content: NSView) {
        let host = Glass.make(around: content, cornerRadius: Self.diameter / 2, interactive: true)
        host.frame = bounds.insetBy(dx: Self.pad, dy: Self.pad)
        host.wantsLayer = true
        addSubview(host)
        self.host = host
    }

    private func updateAppearance() {
        // Dynamic colours are resolved for the view's current appearance.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            disc.layer?.backgroundColor = isOn ? Glass.ink.cgColor : NSColor.clear.cgColor
        }
        symbol.contentTintColor = isDoomed ? .systemRed : (isOn ? Glass.inverseInk : Glass.ink)
    }
}

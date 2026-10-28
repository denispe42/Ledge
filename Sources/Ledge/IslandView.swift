import AppKit
import LedgeCore

/// The opened island: system Liquid Glass with either the home grid of tiles or a module's page.
/// It opens and closes as ONE object: the whole panel (glass and content together) fades and scales in and out
/// (see IslandController). The collapsed island is a separate window (PillPanel).
@MainActor
final class IslandView: NSView {
    /// How far the opened glass extends above the screen top (>= its corner radius), hiding its top corners.
    static let topOvershoot: CGFloat = 28
    static let glassRadius: CGFloat = 28
    /// Distance of the corner buttons (back, rearrange, bring back) from the island's side edge.
    private static let sideMargin: CGFloat = 12
    private static let contentTop = topOvershoot + 40

    var onPointerExited: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    /// The user rearranged or put away tiles: all module ids in their order (shown first) and the hidden ones.
    var onArrangement: (([String], [String]) -> Void)?

    private let content = NSView()
    private let home = NSView()
    private let pageHost = NSView()
    private let pageSlot = NSView()
    private let backButton = PillButton(symbol: "chevron.left", width: 44, height: 32)
    private let editButton = PillButton(symbol: "arrow.up.and.down.and.arrow.left.and.right", width: 44, height: 32)
    /// Rearranging mode only, and only when something is put away: opens the page to bring tiles back.
    private let addButton = PillButton(symbol: "plus", width: 44, height: 32)
    private var pickerOpen = false
    private var isEditing = false
    private var dragging: TileView?
    private var dragOffset = CGPoint.zero
    /// The arrangement when the current drag began (restored if the drag is cancelled).
    private var arrangementBeforeDrag: TileArrangement?
    /// The tiles of the shown page in their current order (changes live while one is dragged).
    private var pageOrder: [TileView] = []
    private var glassBackdrop: NSView!
    private let dots = NSStackView()
    /// One line under the grid: name and state of the tile under the pointer.
    private let caption = NSTextField(labelWithString: "")
    private weak var hoveredTile: TileView?
    private var tilesByID: [String: TileView] = [:]
    private var arrangement = TileArrangement(ids: [])
    /// What the grid lists: the shown tiles (put-away ones are gone until brought back).
    private var displayIDs: [String] { arrangement.shown }
    /// The frame around the grid while rearranging; a tile dragged out of it is put away (the frame turns red).
    private let board = NSView()
    /// The grid sits a little higher on the normal screen (room for the name line under it) and lower while rearranging.
    private lazy var homeTop = home.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.homeTopNormal)
    private static let homeTopNormal = contentTop - TileView.pad - 4
    private static let homeTopEditing = homeTopNormal + 10
    private var homePage = 0
    private var swipe = ScrollAccumulator()
    private var swipeSpent = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Everything is layer-backed so the layers composite in subview order.
        wantsLayer = true
        registerForDraggedTypes(FileDrop.types)
        home.translatesAutoresizingMaskIntoConstraints = false
        home.wantsLayer = true
        home.layer?.masksToBounds = false
        board.wantsLayer = true
        board.layer?.cornerRadius = 22
        board.layer?.borderWidth = 1.5
        board.frame = NSRect(origin: .zero, size: TileGridLayout.size)
        board.isHidden = true
        home.addSubview(board)
        content.addSubview(home)

        pageHost.translatesAutoresizingMaskIntoConstraints = false
        pageHost.isHidden = true
        pageSlot.translatesAutoresizingMaskIntoConstraints = false
        // The "bring back" frame lies a few points outside the page area, as the rearranging frame does on the grid.
        pageSlot.wantsLayer = true
        pageSlot.layer?.masksToBounds = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.onPress = { [weak self] in Haptics.tick(.alignment); self?.showHome(keepEditing: self?.pickerOpen == true) }
        pageHost.addSubview(pageSlot)
        pageHost.addSubview(backButton)
        content.addSubview(pageHost)

        dots.orientation = .horizontal
        dots.spacing = 6
        dots.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(dots)

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.setAccessibilityLabel(L10n.rearrange)
        editButton.onPress = { [weak self] in self?.toggleEditing() }
        content.addSubview(editButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.isHidden = true
        content.addSubview(addButton)
        addButton.setAccessibilityLabel(L10n.bringBackIcons)
        addButton.onPress = { [weak self] in self?.showHiddenPicker() }

        caption.font = .systemFont(ofSize: 12, weight: .medium)
        caption.textColor = Glass.ink
        caption.alignment = .center
        caption.lineBreakMode = .byTruncatingTail
        caption.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(caption)

        NSLayoutConstraint.activate([
            dots.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            dots.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -7),
            home.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            home.widthAnchor.constraint(equalToConstant: TileGridLayout.size.width),
            home.heightAnchor.constraint(equalToConstant: TileGridLayout.size.height),
            editButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.sideMargin - PillButton.pad),
            editButton.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.topOvershoot + 6 - PillButton.pad),
            // The "+" sits under the rearrange button, both in the free column left of the frame.
            addButton.leadingAnchor.constraint(equalTo: editButton.leadingAnchor),
            addButton.topAnchor.constraint(equalTo: editButton.bottomAnchor, constant: 4 - 2 * PillButton.pad),
            caption.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            caption.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -40),
            caption.topAnchor.constraint(equalTo: home.bottomAnchor, constant: 6),
            homeTop,
            pageHost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: content.topAnchor),
            pageHost.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            backButton.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor, constant: Self.sideMargin - PillButton.pad),
            backButton.topAnchor.constraint(equalTo: pageHost.topAnchor, constant: Self.topOvershoot + 6 - PillButton.pad),
            pageSlot.centerXAnchor.constraint(equalTo: pageHost.centerXAnchor),
            // The page fills the area below the notch (it centres its own content in it).
            pageSlot.topAnchor.constraint(equalTo: pageHost.topAnchor, constant: Self.topOvershoot + 34),

        ])
        // Fills the area when there is room, but must never force a minimum window height (the collapsed panel is
        // only as tall as the notch), hence the low priority.
        let fill = pageSlot.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor, constant: -10)
        fill.priority = .defaultLow
        fill.isActive = true
        glassBackdrop = Glass.make(around: content, cornerRadius: Self.glassRadius)
        glassBackdrop.frame = bounds
        glassBackdrop.autoresizingMask = [.width, .height]
        addSubview(glassBackdrop)
        applyLook()
        NotificationCenter.default.addObserver(forName: IslandLookSetting.changed, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyLook() }
        }
    }

    /// Black look: an opaque black layer over the glass (so it melts into the notch), and everything drawn as on a
    /// dark surface (white ink). Glass look: the layer is clear again and the system appearance applies.
    private func applyLook() {
        let look = IslandLookSetting.current
        content.wantsLayer = true
        content.layer?.cornerRadius = Self.glassRadius
        content.layer?.masksToBounds = true
        content.layer?.backgroundColor = look == .black ? NSColor.black.cgColor : NSColor.clear.cgColor
        appearance = look.forcesDarkAppearance ? NSAppearance(named: .darkAqua) : nil
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// The module tiles, ten to a page (two rows of five); more tiles make more pages.
    func setTiles(_ tiles: [TileView], order: [String], hidden: [String]) {
        tilesByID = Dictionary(tiles.map { ($0.moduleID, $0) }, uniquingKeysWith: { first, _ in first })
        arrangement = TileArrangement(ids: tiles.map(\.moduleID), order: order, hidden: hidden)
        homePage = HomePaging.clamped(page: homePage, tiles: displayIDs.count)
        showHomePage()
    }

    private func showHomePage() {
        home.subviews.filter { $0 !== board }.forEach { $0.removeFromSuperview() }
        let range = HomePaging.range(page: homePage, tiles: displayIDs.count)
        pageOrder = displayIDs[range].compactMap { tilesByID[$0] }
        wireCaption(pageOrder)
        for tile in pageOrder {
            home.addSubview(tile)
            tile.onDrag = { [weak self, weak tile] phase, event in
                if let tile { self?.handleDrag(tile, phase, event) }
            }
            tile.alphaValue = 1
            tile.isDoomed = false
            tile.layer?.zPosition = 0
            tile.isEditing = isEditing
            tile.restartEditingAnimation()
        }
        board.isHidden = !isEditing
        markBoard(armed: false)
        layoutTiles(animated: false)
        updateEditControls()
        updateDots()
    }

    private func slotOrigin(_ index: Int) -> CGPoint { TileGridLayout.origin(index: index, count: pageOrder.count) }

    private func layoutTiles(animated: Bool, except moving: NSView? = nil) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated && !reduceMotion ? 0.15 : 0
            for (index, tile) in pageOrder.enumerated() where tile !== moving {
                if animated { tile.animator().setFrameOrigin(slotOrigin(index)) } else { tile.setFrameOrigin(slotOrigin(index)) }
            }
        }
    }

    // MARK: Rearranging

    private func toggleEditing() { setEditing(!isEditing) }

    private func setEditing(_ on: Bool) {
        if !on { cancelDrag() }
        guard isEditing != on else { return }
        isEditing = on
        Haptics.tick(.generic)
        editButton.isProminent = on
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
            homeTop.animator().constant = on ? Self.homeTopEditing : Self.homeTopNormal
        }
        homePage = HomePaging.clamped(page: homePage, tiles: displayIDs.count)
        showHomePage()
        updateEditControls()
        updateCaption()
    }

    private func handleDrag(_ tile: TileView, _ phase: TileView.DragPhase, _ event: NSEvent) {
        let pointer = home.convert(event.locationInWindow, from: nil)
        switch phase {
        case .began:
            dragging = tile
            arrangementBeforeDrag = arrangement
            dragOffset = CGPoint(x: pointer.x - tile.frame.minX, y: pointer.y - tile.frame.minY)
            tile.layer?.zPosition = 10
        case .moved:
            guard dragging === tile else { return }
            tile.setFrameOrigin(clampedOrigin(CGPoint(x: pointer.x - dragOffset.x, y: pointer.y - dragOffset.y)))
            let center = CGPoint(x: tile.frame.midX, y: tile.frame.midY)
            // Nothing more can be put away once five are: the frame then stays calm and the tile just goes back.
            let outside = arrangement.canHide && !board.frame.contains(center)
            if outside != tile.isDoomed { Haptics.tick(.levelChange) }
            tile.isDoomed = outside
            markBoard(armed: outside)
            guard !outside, let slot = nearestSlot(to: center), let from = pageOrder.firstIndex(of: tile), slot != from else { return }
            let start = HomePaging.range(page: homePage, tiles: displayIDs.count).lowerBound
            arrangement.move(tile.moduleID, to: start + slot)
            pageOrder = displayIDs[HomePaging.range(page: homePage, tiles: displayIDs.count)].compactMap { tilesByID[$0] }
            Haptics.tick(.alignment)
            layoutTiles(animated: true, except: tile)
        case .ended:
            guard dragging === tile else { return }
            dragging = nil
            arrangementBeforeDrag = nil
            tile.layer?.zPosition = 0
            if tile.isDoomed {
                tile.isDoomed = false
                arrangement.hide(tile.moduleID)
                Haptics.tick(.generic)
                putAway(tile)
            } else {
                layoutTiles(animated: true)
            }
            markBoard(armed: false)
            commitArrangement()
        }
    }

    /// A drag that cannot finish (the pointer left and the island closed while the button was still down) is cancelled:
    /// nothing is put away, the tile is drawn normally again and the order is what it was before the drag.
    private func cancelDrag() {
        guard let tile = dragging else { return }
        dragging = nil
        tile.isDoomed = false
        tile.layer?.zPosition = 0
        markBoard(armed: false)
        if let before = arrangementBeforeDrag { arrangement = before }
        arrangementBeforeDrag = nil
    }

    /// The tile fades out and the others close the gap.
    private func putAway(_ tile: TileView) {
        pageOrder.removeAll { $0 === tile }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
            tile.animator().alphaValue = 0
        }, completionHandler: { tile.removeFromSuperview() })
        layoutTiles(animated: true)
        updateEditControls()
    }

    /// The "bring back" page: the put-away tiles as round icons; pressing one returns it.
    private func showHiddenPicker() {
        let items = arrangement.hidden.compactMap { id in
            tilesByID[id].map { HiddenTilesPage.Item(id: id, symbol: $0.symbolName, title: $0.title) }
        }
        guard !items.isEmpty else { return showHome(keepEditing: true) }
        let page = HiddenTilesPage(items: items)
        page.onPick = { [weak self] id in self?.bringBack { $0.restore(id) } }
        page.onBringBackAll = { [weak self] in self?.bringBack { $0.restoreAll() } }
        showPage(page)
        pickerOpen = true
    }

    private func bringBack(_ change: (inout TileArrangement) -> Void) {
        change(&arrangement)
        Haptics.tick(.generic)
        commitArrangement()
        if arrangement.hidden.isEmpty { showHome(keepEditing: true) } else { showHiddenPicker() }
    }

    /// The edit button needs any tile at all; the "bring back" button only while rearranging and something is put away.
    private func updateEditControls() {
        let onHome = pageHost.isHidden
        editButton.isHidden = arrangement.all.isEmpty || !onHome
        addButton.isHidden = !isEditing || arrangement.hidden.isEmpty || !onHome
    }

    /// A dragged tile may go anywhere over the visible island, never out of sight (the top strip above the screen is hidden).
    private func clampedOrigin(_ origin: CGPoint) -> CGPoint {
        var visible = bounds
        visible.size.height -= Self.topOvershoot
        let area = home.convert(visible, from: self)
        let size = TileView.fullSize
        return CGPoint(x: min(max(origin.x, area.minX), area.maxX - size.width),
                       y: min(max(origin.y, area.minY), area.maxY - size.height))
    }

    private func nearestSlot(to point: CGPoint) -> Int? {
        let half = TileView.fullSize.width / 2
        let distances = pageOrder.indices.map { index -> CGFloat in
            let origin = slotOrigin(index)
            return hypot(origin.x + half - point.x, origin.y + half - point.y)
        }
        return distances.indices.min { distances[$0] < distances[$1] }
    }

    private func markBoard(armed: Bool) {
        let red = NSColor.systemRed
        effectiveAppearance.performAsCurrentDrawingAppearance {
            board.layer?.borderColor = (armed ? red : Glass.ink.withAlphaComponent(0.25)).cgColor
            board.layer?.backgroundColor = (armed ? red.withAlphaComponent(0.14) : NSColor.clear).cgColor
        }
    }

    private func commitArrangement() {
        onArrangement?(arrangement.all, arrangement.hidden)
    }

    /// Hovering a tile shows its name and state in the caption; the caption follows the tile's text while hovered.
    private func wireCaption(_ tiles: [TileView]) {
        hoveredTile = nil
        caption.stringValue = ""
        for case let tile as TileView in tiles {
            tile.onHover = { [weak self, weak tile] inside in
                guard let self, let tile else { return }
                if inside { self.hoveredTile = tile } else if self.hoveredTile === tile { self.hoveredTile = nil }
                self.updateCaption()
            }
            tile.onTextChange = { [weak self, weak tile] in
                if let self, self.hoveredTile === tile { self.updateCaption() }
            }
        }
    }

    private func updateCaption() {
        if isEditing { caption.stringValue = ""; return }
        guard let tile = hoveredTile else { caption.stringValue = ""; return }
        caption.stringValue = tile.statusText.isEmpty ? tile.title : "\(tile.title) · \(tile.statusText)"
    }

    private func updateDots() {
        dots.arrangedSubviews.forEach { dots.removeArrangedSubview($0); $0.removeFromSuperview() }
        let count = HomePaging.pageCount(tiles: displayIDs.count)
        guard count > 1 else { return }
        for index in 0..<count {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 3
            dot.layer?.backgroundColor = Glass.ink.withAlphaComponent(index == homePage ? 1 : 0.35).cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dots.addArrangedSubview(dot)
        }
        dots.isHidden = count < 2 || !pageHost.isHidden
    }

    /// Moves to another page of tiles with a short cross-fade.
    private func goToHomePage(_ page: Int) {
        let target = HomePaging.clamped(page: page, tiles: displayIDs.count)
        guard target != homePage else { return }
        homePage = target
        Haptics.tick(.alignment)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0 : 0.07
            home.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.showHomePage()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0 : 0.1
                self.home.animator().alphaValue = 1
            }
        })
    }

    /// A two-finger swipe to the left shows the next page, to the right the previous one: one page per swipe.
    override func scrollWheel(with event: NSEvent) {
        guard pageHost.isHidden, HomePaging.pageCount(tiles: displayIDs.count) > 1 else { return super.scrollWheel(with: event) }
        // A new gesture (or a device without gesture phases, like a wheel) starts counting again.
        if event.phase == .began || event.phase == .mayBegin || (event.phase.isEmpty && event.momentumPhase.isEmpty) {
            swipe.reset()
            swipeSpent = false
        }
        guard !swipeSpent, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        // Fingers moving left (content follows) means "next".
        let travel = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaX : event.scrollingDeltaX
        let step = swipe.add(travel, threshold: 40)
        if step != 0 {
            swipeSpent = true
            goToHomePage(homePage + (step > 0 ? 1 : -1))
        }
    }

    /// A dot press jumps to its page (for a mouse without horizontal scrolling).
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, dot) in dots.arrangedSubviews.enumerated() {
            let frame = dots.convert(dot.frame, to: self).insetBy(dx: -5, dy: -8)
            if !dots.isHidden, frame.contains(point) { goToHomePage(index); return }
        }
        super.mouseDown(with: event)
    }

    func showPage(_ page: NSView) {
        pageSlot.subviews.forEach { $0.removeFromSuperview() }
        page.translatesAutoresizingMaskIntoConstraints = false
        pageSlot.addSubview(page)
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: pageSlot.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: pageSlot.trailingAnchor),
            page.topAnchor.constraint(equalTo: pageSlot.topAnchor),
            page.bottomAnchor.constraint(equalTo: pageSlot.bottomAnchor),
        ])
        home.isHidden = true
        caption.isHidden = true
        editButton.isHidden = true
        addButton.isHidden = true
        dots.isHidden = true
        pageHost.isHidden = false
    }

    func handleKey(_ event: NSEvent) -> Bool {
        (pageSlot.subviews.first as? KeyHandling)?.handleKey(event) ?? false
    }

    func showHome(keepEditing: Bool = false) {
        pageSlot.subviews.forEach { $0.removeFromSuperview() }
        pageHost.isHidden = true
        pickerOpen = false
        if !keepEditing { setEditing(false) }
        home.isHidden = false
        caption.isHidden = false
        showHomePage()
        updateCaption()
        dots.isHidden = HomePaging.pageCount(tiles: displayIDs.count) < 2
    }

    /// Back to the first page (the island has been closed).
    func resetHomePage() {
        setEditing(false)
        guard homePage != 0 else { return }
        homePage = 0
        showHomePage()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
        super.updateTrackingAreas()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrop.hasFiles(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDrop.fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }

    override func mouseEntered(with event: NSEvent) { onPointerEntered?() }
    override func mouseExited(with event: NSEvent) { onPointerExited?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

import AppKit
import LedgeCore

/// Glue between display changes, pointer events, the state machine and the two windows:
/// the collapsed pill (black notch shape with clocks) and the opened glass island.
/// Holds no timers. The island opens only on a click; hovering gives a light haptic tick on the trackpad.
@MainActor
final class IslandController {
    private let panel = IslandPanel()
    private let pill = PillPanel()
    private let registry: ModuleRegistry
    private let modules: [UIModule]
    private var machine = IslandStateMachine()
    /// The hardware notch rectangle; the pill is this plus the strips beside it that show clocks.
    private var notchFrame: CGRect?
    private var ears: (left: CGFloat, right: CGFloat) = (0, 0)
    private let fullscreenWatcher = FullscreenWatcher()
    /// The app that had the focus when the island opened.
    private var focusedAppBeforeOpen: NSRunningApplication?

    private let openingScale: CGFloat = 0.92
    private let openDuration: TimeInterval = 0.14
    private let closeDuration: TimeInterval = 0.1

    private let dragWatcher = FileDragWatcher()
    /// Keeps the island open while a module's system window (AirDrop's device picker) is up.
    private var hold = IslandHold()
    /// Work a module asked to do after the island has closed (cleaning mode must start after the focus is handed back).
    private var afterClose: ((NSRunningApplication?) -> Void)?

    init(registry: ModuleRegistry, modules: [UIModule]) {
        self.registry = registry
        self.modules = modules
    }

    /// Menu shown on a right click on the closed island (the same as the menu-bar icon's).
    func setContextMenu(_ menu: NSMenu) { pill.pillView.menu = menu }

    func start() {
        registry.addObserver { [weak self] in
            self?.refreshTiles()
            self?.updateCompact()
            self?.updateDragWatcher()
        }
        dragWatcher.onEnterZone = { [weak self] in self?.filesDraggedOver() }
        dragWatcher.onDragEnded = { [weak self] in self?.pointerExited() }
        modules.forEach { $0.setCompactObserver { [weak self] in self?.updateCompact() } }
        modules.forEach { $0.setHoldHandler { [weak self] in self?.setHold($0) } }
        modules.forEach { $0.setHomeHandler { [weak self] in self?.panel.islandView.showHome() } }
        modules.forEach { $0.setCloseHandler { [weak self] in self?.closeIsland(then: $0) } }
        fullscreenWatcher.onChange = { [weak self] _ in self?.updateCompact() }
        fullscreenWatcher.start()
        NotificationCenter.default.addObserver(forName: CompactSettings.changed, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCompact() }
        }
        NotificationCenter.default.addObserver(forName: CompactSettings.beat, object: nil, queue: .main) { [weak self] note in
            let side = note.object as? CompactSide
            MainActor.assumeIsolated { if let side { self?.pill.pillView.pulseClock(on: side) } }
        }
        pill.pillView.onFilesDragEntered = { [weak self] in self?.filesDraggedOver() }
        pill.pillView.onFilesDropped = { [weak self] in self?.filesDropped($0) }
        panel.islandView.onFilesDropped = { [weak self] in self?.filesDropped($0) }
        panel.islandView.onArrangement = { TileOrderStore.saved = $0; TileOrderStore.hidden = $1 }
        panel.islandView.onPointerEntered = { [weak self] in self?.hold.pointerEntered() }
        pill.pillView.onPointerEntered = { [weak self] in self?.pointerEntered() }
        pill.pillView.onClicked = { [weak self] in self?.send(.clicked) }
        pill.pillView.onSwipedDown = { [weak self] in self?.send(.clicked) }
        panel.islandView.onSwipedUp = { [weak self] in self?.swipedUp() }
        panel.islandView.onPointerExited = { [weak self] in self?.pointerExited() }
        // Event-driven: display plug/unplug, resolution change, wake, menu-bar auto-hide change.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screensChanged()
                self?.fullscreenWatcher.evaluate()
            }
        }
        // Safety net: a system window of a module (AirDrop's picker, the file chooser) can disappear without telling us
        // when the user activates another app. A held island would then never close, so losing the focus ends the hold.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.hold.isHeld == true { self?.setHold(false) } }
        }
        screensChanged()
        refreshTiles()
    }

    private var running: [UIModule] { modules.filter { registry.state(of: $0.id) == .running } }

    /// One tile per running module.
    private func refreshTiles() {
        let tiles = running.compactMap { module -> TileView? in
            let tile = module.makeTile { [weak self, weak module] in
                guard let self, let module else { return }
                self.showPage(of: module)
            } as? TileView
            tile?.moduleID = module.id
            return tile
        }
        panel.islandView.setTiles(tiles, order: TileOrderStore.saved, hidden: TileOrderStore.hidden)
    }

    /// The watcher for files near the notch exists only while a module that takes files is running.
    private func updateDragWatcher() {
        if dropZones.isEmpty { dragWatcher.stop() } else { dragWatcher.start() }
    }

    private func showPage(of module: UIModule) {
        guard let page = module.makePage() else { return }
        panel.islandView.showPage(page)
    }

    /// The drop zones of the running modules, in module order (the first one is the default target).
    private var dropZones: [(module: UIModule, zone: DropZone)] {
        running.compactMap { module in module.dropZone.map { (module, $0) } }
    }

    /// Files dragged onto the notch open the island on the drop screen: one zone per module that takes files.
    private func filesDraggedOver() {
        if !machine.isExpanded { send(.clicked) }
        let zones = dropZones
        guard !zones.isEmpty else { return }
        let screen = DropScreenView(zones: zones.map(\.zone))
        screen.onDrop = { [weak self] urls, index, anchor in self?.filesDropped(urls, zone: index, anchor: anchor) }
        panel.islandView.showPage(screen)
    }

    /// `zone` is the zone that was hit; a drop elsewhere (closed notch, empty island space) goes to the first one.
    private func filesDropped(_ urls: [URL], zone hit: Int? = nil, anchor: NSView? = nil) {
        let zones = dropZones
        guard !urls.isEmpty, let index = DropRouting.zone(hit: hit, zoneCount: zones.count) else { return }
        let target = zones[index]
        target.zone.handle(urls, anchor)
        if target.zone.showsPageAfterDrop { showPage(of: target.module) }
        if !machine.isExpanded { send(.clicked) }
    }

    /// Closes the island and runs `action` once it is gone (at once if it is already closed). The focus is left to `action`.
    private func closeIsland(then action: @escaping (NSRunningApplication?) -> Void) {
        guard machine.isExpanded else { return action(focusedAppBeforeOpen) }
        afterClose = action
        send(.pointerLeft)
    }

    private func setHold(_ held: Bool) {
        if hold.setHeld(held) { pointerExited() }
    }

    /// Shows the clocks of pinned, running modules on the strips beside the notch (timer left, stopwatch right) and
    /// sizes the pill to fit. Hidden in full screen if the setting says so.
    private func updateCompact() {
        guard let notch = notchFrame else { return }
        let items = running.compactMap { module -> CompactItem? in
            CompactPolicy.isVisible(pinned: CompactSettings.isPinned(module.id),
                                    hideInFullscreen: CompactSettings.hideInFullscreen,
                                    isFullscreen: fullscreenWatcher.isFullscreen) ? module.compactItem : nil
        }
        let left = items.first { $0.side == .left }?.text
        let right = items.first { $0.side == .right }?.text
        func width(_ text: String?) -> CGFloat? {
            text.map { ($0 as NSString).size(withAttributes: [.font: PillView.font]).width }
        }
        ears = (IslandGeometry.earWidth(forTextWidth: width(left)), IslandGeometry.earWidth(forTextWidth: width(right)))
        pill.pillView.setClocks(left: left, right: right, leftEar: ears.left, rightEar: ears.right)
        pill.setFrame(IslandGeometry.widened(notch, left: ears.left, right: ears.right), display: true)
    }

    private func screensChanged() {
        let infos = NSScreen.screens.map(ScreenInfo.init)
        guard let index = IslandGeometry.notchedScreenIndex(infos) else {
            notchFrame = nil
            pill.orderOut(nil)
            panel.orderOut(nil)
            return
        }
        notchFrame = IslandGeometry.collapsedFrame(on: infos[index])
        if let notch = notchFrame {
            // Slightly wider than the notch and a little below it: the island opens before the pointer touches the
            // top edge of the screen, which would make macOS show Mission Control.
            dragWatcher.zone = CGRect(x: notch.minX - 14, y: notch.minY - 26, width: notch.width + 28, height: notch.height + 26)
        }
        updateCompact()
        if machine.isExpanded, let final = expandedFrame() {
            panel.setFrame(final, display: true)
        } else {
            pill.orderFrontRegardless()
        }
    }

    /// The opened island: grows downward from the notch and extends above the screen edge to hide its top corners.
    private func expandedFrame() -> CGRect? {
        guard let notch = notchFrame else { return nil }
        var frame = IslandGeometry.expandedFrame(from: notch)
        frame.size.height += IslandView.topOvershoot
        return frame
    }

    /// Light tick when the pointer reaches the notch, so the user feels it is clickable.
    private func pointerEntered() {
        guard !machine.isExpanded else { return }
        Haptics.tick(.alignment)
    }

    /// Resizing the panel can report an exit while the pointer is still over it, so close only if it is really outside.
    private func pointerExited() {
        guard !panel.frame.contains(NSEvent.mouseLocation), hold.pointerLeft() else { return }
        send(.pointerLeft)
    }

    /// Like the pointer leaving, a swipe up respects a hold (a module's system window is up).
    private func swipedUp() {
        guard hold.pointerLeft() else { return }
        send(.pointerLeft)
    }

    private func send(_ event: IslandEvent) {
        let before = machine.state
        machine.handle(event)
        guard machine.state != before else { return }
        Haptics.tick(machine.isExpanded ? .levelChange : .alignment)
        running.forEach { $0.islandVisibilityChanged(machine.isExpanded) }
        if machine.isExpanded { open() } else { close() }
    }

    /// Opening: the pill steps aside and the glass appears at its final place, fading in while growing slightly from
    /// the top centre, as one object. The panel becomes key (needed for the full glass look).
    private func open() {
        guard let final = expandedFrame() else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { focusedAppBeforeOpen = front }
        pill.orderOut(nil)
        panel.keyAllowed = true
        panel.alphaValue = 0
        panel.setFrame(Self.scaled(final, by: reduceMotion ? 1 : openingScale), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.05 : openDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(final, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Closing: the pill (with the clocks) is shown at once under the glass, and the glass fades out over it, so the
    /// clocks appear in step with the closing instead of after it.
    private func close() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        pill.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.05 : closeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.machine.isExpanded else { return }
            self.panel.keyAllowed = false
            // Ordering the key panel out hands the key state back to the app that had the focus before; activating
            // that app (no window raising, no reopen) is a harmless second safeguard.
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.panel.islandView.showHome()
            self.panel.islandView.resetHomePage()
            if let action = self.afterClose {
                self.afterClose = nil
                action(self.focusedAppBeforeOpen)
            } else {
                self.focusedAppBeforeOpen?.activate(options: [])
            }
        })
    }

    /// `frame` shrunk by `scale`, keeping its top edge and horizontal centre.
    private static func scaled(_ frame: CGRect, by scale: CGFloat) -> CGRect {
        let size = CGSize(width: frame.width * scale, height: frame.height * scale)
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }
}

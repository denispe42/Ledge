import AppKit
import LedgeCore

/// One borderless window per display, above everything, that swallows keys and clicks.
@MainActor
private final class CleaningPanel: NSPanel {
    let cleaningView = CleaningView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        contentView = cleaningView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
    /// Command shortcuts of the app (and of the system, when they reach us) are swallowed.
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

/// Cleaning mode: black screens, the whole keyboard is blocked (event tap, Accessibility permission), the trackpad
/// stays live; hold Esc (or the on-screen button) for a few seconds to leave. `presentationOptions` also switches off
/// the system shortcuts it can. Not blocked: the hardware power button press itself and Mission Control gestures.
///
/// Ends itself when the app loses focus or the displays change. While it runs the Mac and the display stay awake.
/// It holds nothing and observes nothing until `start()`.
@MainActor
final class CleaningSession {
    static let holdSeconds = 3.0

    var onEnd: (() -> Void)?
    private(set) var isActive = false

    private var panels: [CleaningPanel] = []
    private var keyHold = HoldToExit(duration: holdSeconds)
    private var buttonHold = HoldToExit(duration: holdSeconds)
    private var observers: [NSObjectProtocol] = []
    private var previousOptions: NSApplication.PresentationOptions = []
    private let keepAwake = KeepAwake(provider: IOKitPowerAssertions())
    private let blocker = KeyboardBlocker()
    /// The app that had the focus before; gets it back when the mode ends by the user's own exit.
    private var returnFocusTo: NSRunningApplication?

    /// False (and nothing changes) if the keyboard cannot be blocked because the permission is missing.
    @discardableResult
    func start(returningFocusTo app: NSRunningApplication?) -> Bool {
        guard !isActive else { return true }
        blocker.onEscape = { [weak self] in self?.escape(down: $0) }
        guard blocker.start() else { return false }
        returnFocusTo = app
        isActive = true
        keepAwake.setActive(true, reason: "Ledge cleaning mode")
        previousOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication,
                                     .disableForceQuit, .disableSessionTermination, .disableAppleMenu]
        panels = NSScreen.screens.map { screen in
            let panel = CleaningPanel(screen: screen)
            panel.cleaningView.onButtonHold = { [weak self] in self?.buttonHold($0) }
            return panel
        }
        NSApp.activate(ignoringOtherApps: true)
        panels.forEach { $0.orderFrontRegardless() }
        (panels.first { $0.screen == NSScreen.main } ?? panels.first)?.makeKey()
        let center = NotificationCenter.default
        let end: (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.end() } }
        observers = [
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main, using: end),
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: end),
        ]
        return true
    }

    func end(restoringFocus: Bool = false) {
        guard isActive else { return }
        isActive = false
        blocker.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        panels.forEach { $0.orderOut(nil) }
        panels = []
        NSApp.presentationOptions = previousOptions
        keepAwake.shutdown()
        keyHold.release()
        buttonHold.release()
        if restoringFocus { returnFocusTo?.activate(options: []) }
        returnFocusTo = nil
        onEnd?()
    }

    private func escape(down: Bool) {
        if down {
            press(&keyHold)
        } else {
            keyHold.release()
            resetRings()
        }
    }

    private func buttonHold(_ down: Bool) {
        if down {
            press(&buttonHold)
        } else {
            buttonHold.release()
            resetRings()
        }
    }

    /// Starts a hold (key repeats are ignored) and schedules the single check for the moment it would complete.
    private func press(_ hold: inout HoldToExit) {
        let now = ProcessInfo.processInfo.systemUptime
        guard hold.press(at: now) else { return }
        panels.forEach { $0.cleaningView.startRing(duration: hold.duration) }
        DispatchQueue.main.asyncAfter(deadline: .now() + hold.duration + 0.02) { [weak self] in
            guard let self, self.isActive else { return }
            let later = ProcessInfo.processInfo.systemUptime
            if self.keyHold.isComplete(at: later) || self.buttonHold.isComplete(at: later) { self.end(restoringFocus: true) }
        }
    }

    private func resetRings() { panels.forEach { $0.cleaningView.resetRing() } }
}

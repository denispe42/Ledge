import AppKit
import ApplicationServices

/// Swallows every keyboard event system-wide while cleaning mode runs, except that Escape is reported to the session
/// (it must be held to leave). Needs the Accessibility permission (an active event tap); the pointer and trackpad are
/// not touched. Media keys (volume, brightness) and the power key arrive as system-defined events and are swallowed too;
/// whether the system still acts on the power key first is up to macOS (a long press always works, by hardware).
@MainActor
final class KeyboardBlocker {
    /// Escape went down (true) or up (false).
    var onEscape: ((Bool) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private static let escapeKeyCode: Int64 = 53
    private static let systemDefined: UInt32 = 14

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Shows the system's request for the permission (opens System Settings).
    static func requestPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// False if the system refused the tap (no permission).
    func start() -> Bool {
        let keyMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue) | (1 << Self.systemDefined)
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(info).takeUnretainedValue()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let pass = MainActor.assumeIsolated { blocker.shouldPass(type: type, keyCode: keyCode) }
            return pass ? Unmanaged.passUnretained(event) : nil
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(keyMask), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    /// True if the system may deliver the event (only the tap's own "disabled" notices).
    private func shouldPass(type: CGEventType, keyCode: Int64) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system switches a slow tap off; the mode must not silently stop protecting.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        case .keyDown, .keyUp:
            if keyCode == Self.escapeKeyCode { onEscape?(type == .keyDown) }
            return false
        default:
            return false
        }
    }
}

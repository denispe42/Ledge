import AppKit


enum ShareOutcome { case shared, cancelled, failed }

/// Sends files through a system sharing service. Behind a protocol so the module does not depend on AppKit's service.
@MainActor
protocol FileSharing: AnyObject {
    var isAvailable: Bool { get }
    /// Shows the system window for choosing the recipient; `completion` is called once, when it is gone.
    func share(_ urls: [URL], from anchor: NSView?, completion: @escaping (ShareOutcome) -> Void)
}

/// AirDrop through the public `NSSharingService`: the system draws the window with the nearby devices. The service
/// and its delegate are kept (strongly) until the system reports the end, otherwise the window can vanish early.
@MainActor
final class AirDropSharer: NSObject, FileSharing, NSSharingServiceDelegate {
    private var service: NSSharingService?
    private var anchor: NSView?
    private var completion: ((ShareOutcome) -> Void)?

    var isAvailable: Bool { NSSharingService(named: .sendViaAirDrop) != nil }

    func share(_ urls: [URL], from anchor: NSView?, completion: @escaping (ShareOutcome) -> Void) {
        finish(.cancelled)
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            completion(.failed)
            return
        }
        service.delegate = self
        self.service = service
        self.anchor = anchor
        self.completion = completion
        service.perform(withItems: urls)
    }

    private func finish(_ outcome: ShareOutcome) {
        let done = completion
        service = nil
        anchor = nil
        completion = nil
        done?(outcome)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish(.shared) }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let cancelled = (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError
        finish(cancelled ? .cancelled : .failed)
    }

    /// The picker opens just below the island: the island's glass lies above ordinary windows and would hide the top of
    /// the picker (its title) if the picker were anchored to the zone inside the island.
    func sharingService(_ sharingService: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect {
        guard let window = anchor?.window, let anchor else { return .zero }
        let zone = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        return NSRect(x: zone.midX - 1, y: window.frame.minY - 2, width: 2, height: 2)
    }
}

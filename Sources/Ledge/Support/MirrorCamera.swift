import AVFoundation
import LedgeCore

/// The camera behind the mirror: a capture session that exists only while the mirror window is open. Starting and
/// stopping run on a private queue because `startRunning` blocks.
final class MirrorCamera: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.ledge.mirror")

    static var authorization: CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        default: .denied
        }
    }

    /// False if there is no camera or the system refuses to hand it over.
    func configure() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }

    func start() { queue.async { [session] in session.startRunning() } }
    func stop() { queue.async { [session] in session.stopRunning() } }
}

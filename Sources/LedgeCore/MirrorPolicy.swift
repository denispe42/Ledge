/// The camera permission as the mirror cares about it (a plain copy of the system's status, so tests need no AVFoundation).
public enum CameraAuthorization: Equatable, Sendable {
    case notDetermined, authorized, denied, restricted
}

public enum MirrorAction: Equatable, Sendable {
    case start, askPermission, showNoAccess
}

/// What pressing the mirror tile does for each permission state.
public enum MirrorPolicy {
    public static func action(for status: CameraAuthorization) -> MirrorAction {
        switch status {
        case .authorized: .start
        case .notDetermined: .askPermission
        case .denied, .restricted: .showNoAccess
        }
    }
}

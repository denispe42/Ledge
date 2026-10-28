/// What the system reports about the default input device: whether it can be muted or have its input volume set
/// (some USB and Bluetooth microphones allow neither), and the current values.
public struct MicrophoneReading: Equatable, Sendable {
    public let canMute: Bool
    public let canSetVolume: Bool
    public let isMuteOn: Bool
    public let volume: Float

    public init(canMute: Bool, canSetVolume: Bool, isMuteOn: Bool, volume: Float) {
        self.canMute = canMute
        self.canSetVolume = canSetVolume
        self.isMuteOn = isMuteOn
        self.volume = volume
    }
}

public enum MicrophoneState: Equatable, Sendable {
    case live, muted, unavailable
}

/// A change to apply to the device, and the volume to remember for the next unmute (volume method only).
public struct MicrophoneAction: Equatable, Sendable {
    public enum Change: Equatable, Sendable {
        case mute(Bool)
        case volume(Float)
    }
    public let change: Change
    public let remember: Float?

    public init(change: Change, remember: Float?) {
        self.change = change
        self.remember = remember
    }
}

/// How the microphone is muted. The device's own mute property is preferred; without it the input volume is set to 0
/// and the previous level is remembered; a device with neither cannot be muted. Pure rules on explicit values.
public enum MicrophoneMute {
    public static func state(_ reading: MicrophoneReading) -> MicrophoneState {
        if reading.canMute { return reading.isMuteOn ? .muted : .live }
        if reading.canSetVolume { return reading.volume == 0 ? .muted : .live }
        return .unavailable
    }

    /// The action for one press: nil when the device cannot be muted. `remembered` is the volume kept from the
    /// last mute by volume (nil when none).
    public static func toggle(_ reading: MicrophoneReading, remembered: Float?) -> MicrophoneAction? {
        switch state(reading) {
        case .unavailable:
            return nil
        case .muted where reading.canMute:
            return MicrophoneAction(change: .mute(false), remember: nil)
        case .live where reading.canMute:
            return MicrophoneAction(change: .mute(true), remember: nil)
        case .muted:
            // Never restore to silence: a remembered 0 (or nothing) means full volume.
            let level = (remembered ?? 0) > 0 ? remembered! : 1
            return MicrophoneAction(change: .volume(level), remember: nil)
        case .live:
            return MicrophoneAction(change: .volume(0), remember: reading.volume)
        }
    }
}

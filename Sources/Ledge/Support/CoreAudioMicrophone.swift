import CoreAudio
import LedgeCore

/// The system's default microphone: its mute state and a way to change it, with change notifications.
@MainActor
protocol MicrophoneControl: AnyObject {
    var onChange: (() -> Void)? { get set }
    /// Starts listening for changes (device switch, mute, volume); `onChange` reports each one.
    func start()
    /// Removes every listener; nothing is delivered afterwards.
    func stop()
    /// nil when there is no input device.
    func reading() -> MicrophoneReading?
    func apply(_ change: MicrophoneAction.Change)
}

/// Public CoreAudio only. The default input device is looked up on every call (it changes when a headset is plugged in),
/// and the listeners follow it: they exist only between `start()` and `stop()`, so nothing runs while the island is closed.
/// A device may have the property on its main element or only per channel, so both are handled.
@MainActor
final class CoreAudioMicrophone: MicrophoneControl {
    var onChange: (() -> Void)?

    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var listenedDevice: AudioObjectID?

    func start() {
        guard defaultListener == nil else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.listenToDevice()
                self?.onChange?()
            }
        }
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(system, &address, .main, block)
        defaultListener = block
        listenToDevice()
    }

    func stop() {
        if let block = defaultListener {
            var address = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectRemovePropertyListenerBlock(system, &address, .main, block)
            defaultListener = nil
        }
        stopListeningToDevice()
    }

    func reading() -> MicrophoneReading? {
        guard let device = defaultInput() else { return nil }
        let mutes = Self.elements(device, kAudioDevicePropertyMute)
        let volumes = Self.elements(device, kAudioDevicePropertyVolumeScalar)
        let muteValues = mutes.compactMap { Self.value(device, kAudioDevicePropertyMute, $0) as UInt32? }
        let volumeValues = volumes.compactMap { Self.value(device, kAudioDevicePropertyVolumeScalar, $0) as Float32? }
        return MicrophoneReading(
            canMute: !mutes.isEmpty && mutes.allSatisfy { Self.isSettable(device, kAudioDevicePropertyMute, $0) },
            canSetVolume: !volumes.isEmpty && volumes.allSatisfy { Self.isSettable(device, kAudioDevicePropertyVolumeScalar, $0) },
            isMuteOn: !muteValues.isEmpty && muteValues.allSatisfy { $0 != 0 },
            volume: volumeValues.max() ?? 0)
    }

    func apply(_ change: MicrophoneAction.Change) {
        guard let device = defaultInput() else { return }
        switch change {
        case .mute(let on):
            for element in Self.elements(device, kAudioDevicePropertyMute) {
                Self.set(device, kAudioDevicePropertyMute, element, UInt32(on ? 1 : 0))
            }
        case .volume(let level):
            for element in Self.elements(device, kAudioDevicePropertyVolumeScalar) {
                Self.set(device, kAudioDevicePropertyVolumeScalar, element, Float32(level))
            }
        }
    }

    // MARK: Listeners on the current device

    private func listenToDevice() {
        let device = defaultInput()
        guard device != listenedDevice else { return }
        stopListeningToDevice()
        guard let device else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
        for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
            for element in Self.elements(device, selector) {
                var address = Self.address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
                AudioObjectAddPropertyListenerBlock(device, &address, .main, block)
            }
        }
        deviceListener = block
        listenedDevice = device
    }

    private func stopListeningToDevice() {
        if let device = listenedDevice, let block = deviceListener {
            for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
                for element in Self.elements(device, selector) {
                    var address = Self.address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
                    AudioObjectRemovePropertyListenerBlock(device, &address, .main, block)
                }
            }
        }
        deviceListener = nil
        listenedDevice = nil
    }

    // MARK: CoreAudio plumbing

    private func defaultInput() -> AudioObjectID? {
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope,
                                element: UInt32 = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    /// The elements that carry `selector` on the input side: the main element if it has it, else channels 1 and 2.
    private static func elements(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [UInt32] {
        let candidates: [UInt32] = [kAudioObjectPropertyElementMain]
        let main = candidates.filter { has(device, selector, $0) }
        return main.isEmpty ? [1, 2].filter { has(device, selector, $0) } : main
    }

    private static func has(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ element: UInt32) -> Bool {
        var address = address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
        return AudioObjectHasProperty(device, &address)
    }

    private static func isSettable(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ element: UInt32) -> Bool {
        var address = address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private static func value<T: Numeric>(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ element: UInt32) -> T? {
        var address = address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
        var result: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &result) == noErr ? result : nil
    }

    private static func set<T>(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ element: UInt32, _ value: T) {
        var address = address(selector, scope: kAudioDevicePropertyScopeInput, element: element)
        var copy = value
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<T>.size), &copy)
    }
}

import Testing
@testable import LedgeCore

private func reading(canMute: Bool = true, canSetVolume: Bool = true, mute: Bool = false, volume: Float = 0.8) -> MicrophoneReading {
    MicrophoneReading(canMute: canMute, canSetVolume: canSetVolume, isMuteOn: mute, volume: volume)
}

@Test func muteProperty_isPreferredAndReportsItsOwnState() {
    #expect(MicrophoneMute.state(reading()) == .live)
    #expect(MicrophoneMute.state(reading(mute: true)) == .muted)
    // The mute property wins even when the volume is 0.
    #expect(MicrophoneMute.state(reading(mute: false, volume: 0)) == .live)
}

@Test func withoutMute_zeroVolumeCountsAsMuted() {
    #expect(MicrophoneMute.state(reading(canMute: false, volume: 0)) == .muted)
    #expect(MicrophoneMute.state(reading(canMute: false, volume: 0.5)) == .live)
}

@Test func withNeitherCapability_isUnavailable() {
    let r = reading(canMute: false, canSetVolume: false)
    #expect(MicrophoneMute.state(r) == .unavailable)
    #expect(MicrophoneMute.toggle(r, remembered: nil) == nil)
}

@Test func toggleUsesTheMuteProperty() {
    #expect(MicrophoneMute.toggle(reading(), remembered: nil) == .init(change: .mute(true), remember: nil))
    #expect(MicrophoneMute.toggle(reading(mute: true), remembered: nil) == .init(change: .mute(false), remember: nil))
}

@Test func volumeFallback_remembersAndRestores() {
    let live = reading(canMute: false, volume: 0.6)
    #expect(MicrophoneMute.toggle(live, remembered: nil) == .init(change: .volume(0), remember: 0.6))
    let muted = reading(canMute: false, volume: 0)
    #expect(MicrophoneMute.toggle(muted, remembered: 0.6) == .init(change: .volume(0.6), remember: nil))
}

@Test func volumeFallback_withNothingRememberedRestoresFullVolume() {
    let muted = reading(canMute: false, volume: 0)
    #expect(MicrophoneMute.toggle(muted, remembered: nil) == .init(change: .volume(1), remember: nil))
    #expect(MicrophoneMute.toggle(muted, remembered: 0) == .init(change: .volume(1), remember: nil))
}

@Test func togglingTwiceReturnsToTheStart_withVolume() {
    var r = reading(canMute: false, volume: 0.4)
    var remembered: Float?
    for _ in 0..<2 {
        guard let result = MicrophoneMute.toggle(r, remembered: remembered), case .volume(let v) = result.change else { Issue.record("no change"); return }
        r = reading(canMute: false, volume: v)
        remembered = result.remember
    }
    #expect(r.volume == 0.4)
}

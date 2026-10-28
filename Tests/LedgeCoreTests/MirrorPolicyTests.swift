import Testing
@testable import LedgeCore

@Test func authorizedCameraStartsTheMirror() {
    #expect(MirrorPolicy.action(for: .authorized) == .start)
}

@Test func unknownStatusAsksOnFirstPress() {
    #expect(MirrorPolicy.action(for: .notDetermined) == .askPermission)
}

@Test func deniedOrRestrictedShowsTheNoAccessNote() {
    #expect(MirrorPolicy.action(for: .denied) == .showNoAccess)
    #expect(MirrorPolicy.action(for: .restricted) == .showNoAccess)
}

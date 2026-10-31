import Testing
@testable import LedgeCore

@Test func firstRunRegistersTheLoginItem() {
    #expect(LaunchAtLogin.startupAction(stored: nil) == .register)
}

@Test func afterTheFirstRunTheUsersChoiceIsNeverOverridden() {
    #expect(LaunchAtLogin.startupAction(stored: true) == .nothing)
    #expect(LaunchAtLogin.startupAction(stored: false) == .nothing)
}

@Test func onlyAnEnabledItemCountsAsOn() {
    #expect(LaunchAtLogin.isOn(.enabled))
    #expect(!LaunchAtLogin.isOn(.notRegistered))
    #expect(!LaunchAtLogin.isOn(.requiresApproval))
    #expect(!LaunchAtLogin.isOn(.notFound))
}

@Test func onlyARealAppBundleMayBecomeALoginItem() {
    #expect(LaunchAtLogin.canRegister(bundlePath: "/Applications/Ledge.app"))
    #expect(!LaunchAtLogin.canRegister(bundlePath: "/Users/x/Library/Developer/Xcode/DerivedData/Ledge-abc/Build/Products/Debug"))
    #expect(!LaunchAtLogin.canRegister(bundlePath: "/Users/x/Ledge/.build/debug/Ledge.app"))
    #expect(!LaunchAtLogin.canRegister(bundlePath: "/Users/x/Ledge/.build/debug"))
}

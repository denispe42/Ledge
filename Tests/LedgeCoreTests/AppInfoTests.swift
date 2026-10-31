import Testing
@testable import LedgeCore

@Test func appIdentityIsLedge() {
    #expect(AppInfo.bundleID == "app.ledge.Ledge")
    #expect(AppInfo.name == "Ledge")
}

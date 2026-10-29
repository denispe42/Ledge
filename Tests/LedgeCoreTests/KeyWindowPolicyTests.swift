import Testing
@testable import LedgeCore

@Test func openIslandIsKeyOnAnOrdinaryDesktop() {
    #expect(KeyWindowPolicy.opensAsKey(frontAppIsFullscreen: false))
}

/// Making the panel key activates Ledge, and macOS then showed the opened island on another desktop instead of the
/// full-screen one the click was made in (28.10): there the island opens without becoming key.
@Test func openIslandIsNotKeyOverAFullScreenApp() {
    #expect(!KeyWindowPolicy.opensAsKey(frontAppIsFullscreen: true))
}

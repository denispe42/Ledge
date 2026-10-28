import Testing
@testable import LedgeCore

@Test func glassIsTheDefaultLook() {
    #expect(IslandLook.stored(nil) == .glass)
    #expect(IslandLook.stored("") == .glass)
}

@Test func storedLooksAreRead() {
    #expect(IslandLook.stored("black") == .black)
    #expect(IslandLook.stored("glass") == .glass)
}

@Test func anUnknownStoredLookFallsBackToGlass() {
    #expect(IslandLook.stored("neon") == .glass)
}

@Test func theBlackLookAlwaysUsesWhiteInk() {
    #expect(IslandLook.black.forcesDarkAppearance)
    #expect(!IslandLook.glass.forcesDarkAppearance)
}

@Test func theLooksRoundTripThroughTheirStoredNames() {
    for look in IslandLook.allCases { #expect(IslandLook.stored(look.rawValue) == look) }
}

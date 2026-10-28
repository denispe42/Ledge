import Testing
@testable import LedgeCore

@Test func dropOnAZoneGoesToThatZone() {
    #expect(DropRouting.zone(hit: 1, zoneCount: 2) == 1)
    #expect(DropRouting.zone(hit: 0, zoneCount: 2) == 0)
}

@Test func dropOutsideAnyZoneGoesToTheFirstZone() {
    #expect(DropRouting.zone(hit: nil, zoneCount: 2) == 0)
    #expect(DropRouting.zone(hit: 5, zoneCount: 2) == 0)
}

@Test func dropWithNoZonesGoesNowhere() {
    #expect(DropRouting.zone(hit: nil, zoneCount: 0) == nil)
    #expect(DropRouting.zone(hit: 0, zoneCount: 0) == nil)
}

@Test func heldIslandIgnoresThePointerLeavingAndClosesOnRelease() {
    var hold = IslandHold()
    hold.setHeld(true)
    let mayClose = hold.pointerLeft()
    let closeNow = hold.setHeld(false)
    #expect(!mayClose)          // a system window is up: stay open
    #expect(closeNow)           // it is gone and the pointer had left: close now
}

@Test func releaseWithoutAnEarlierExitDoesNotClose() {
    var hold = IslandHold()
    hold.setHeld(true)
    let closeNow = hold.setHeld(false)
    #expect(!closeNow)
}

@Test func freeIslandClosesOnExitAsBefore() {
    var hold = IslandHold()
    let mayClose = hold.pointerLeft()
    #expect(mayClose)
}

@Test func anExitBeforeTheHoldDoesNotCloseLater() {
    var hold = IslandHold()
    _ = hold.pointerLeft()      // closed normally
    hold.setHeld(true)
    let closeNow = hold.setHeld(false)
    #expect(!closeNow)          // the old exit must not count
}

@Test func pointerReturningCancelsTheDeferredClose() {
    var hold = IslandHold()
    hold.setHeld(true)
    _ = hold.pointerLeft()
    hold.pointerEntered()
    let closeNow = hold.setHeld(false)
    #expect(!closeNow)
}

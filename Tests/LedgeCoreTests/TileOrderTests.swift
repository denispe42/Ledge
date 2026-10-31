import Testing
@testable import LedgeCore

@Test func savedOrderIsApplied() {
    #expect(TileOrder.arranged(["a", "b", "c"], saved: ["c", "a", "b"]) == ["c", "a", "b"])
}

@Test func newModulesGoToTheEndInTheirOwnOrder() {
    #expect(TileOrder.arranged(["a", "b", "c", "d"], saved: ["c", "a"]) == ["c", "a", "b", "d"])
}

@Test func forgottenOrSwitchedOffModulesAreDropped() {
    #expect(TileOrder.arranged(["a", "c"], saved: ["x", "c", "b", "a"]) == ["c", "a"])
}

@Test func noSavedOrderKeepsTheDefault() {
    #expect(TileOrder.arranged(["a", "b"], saved: []) == ["a", "b"])
}

@Test func movingATileShiftsTheOthers() {
    #expect(TileOrder.moved(["a", "b", "c", "d"], from: 0, to: 2) == ["b", "c", "a", "d"])
    #expect(TileOrder.moved(["a", "b", "c", "d"], from: 3, to: 1) == ["a", "d", "b", "c"])
}

@Test func movingOutOfRangeChangesNothing() {
    #expect(TileOrder.moved(["a", "b"], from: 5, to: 0) == ["a", "b"])
    #expect(TileOrder.moved(["a", "b"], from: 0, to: 9) == ["a", "b"])
}

@Test func arrangementSplitsShownAndHidden() {
    let arrangement = TileArrangement(ids: ["a", "b", "c", "d"], order: ["c", "a"], hidden: ["a", "x"])
    #expect(arrangement.shown == ["c", "b", "d"])
    #expect(arrangement.hidden == ["a"])
    #expect(arrangement.all == ["c", "b", "d", "a"])
}

@Test func hidingMovesATileToTheFrontOfTheHiddenOnes() {
    var arrangement = TileArrangement(ids: ["a", "b", "c"], order: [], hidden: ["c"])
    arrangement.hide("a")
    #expect(arrangement.shown == ["b"])
    #expect(arrangement.hidden == ["a", "c"])
}

@Test func restoringAppendsToTheShownTiles() {
    var arrangement = TileArrangement(ids: ["a", "b", "c"], order: [], hidden: ["a"])
    arrangement.restore("a")
    #expect(arrangement.shown == ["b", "c", "a"])
    #expect(arrangement.hidden.isEmpty)
}

@Test func movingWorksOnShownTilesOnly() {
    var arrangement = TileArrangement(ids: ["a", "b", "c", "d"], order: [], hidden: ["d"])
    arrangement.move("c", to: 0)
    #expect(arrangement.shown == ["c", "a", "b"])
    arrangement.move("a", to: 99)   // out of range: nothing happens
    #expect(arrangement.shown == ["c", "a", "b"])
    arrangement.move("d", to: 0)    // hidden: nothing happens
    #expect(arrangement.shown == ["c", "a", "b"])
}

@Test func hidingAnUnknownOrHiddenTileChangesNothing() {
    var arrangement = TileArrangement(ids: ["a", "b"], order: [], hidden: ["b"])
    arrangement.hide("zzz")
    arrangement.hide("b")
    arrangement.restore("a")
    #expect(arrangement.shown == ["a"])
    #expect(arrangement.hidden == ["b"])
}

@Test func restoringAllBringsEveryHiddenTileBackInOrder() {
    var arrangement = TileArrangement(ids: ["a", "b", "c", "d"], order: [], hidden: ["c", "a"])
    arrangement.restoreAll()
    #expect(arrangement.shown == ["b", "d", "c", "a"])
    #expect(arrangement.hidden.isEmpty)
}

@Test func atMostFiveTilesCanBePutAway() {
    var arrangement = TileArrangement(ids: ["a", "b", "c", "d", "e", "f", "g"])
    for id in ["a", "b", "c", "d", "e"] {
        #expect(arrangement.canHide)
        arrangement.hide(id)
    }
    #expect(!arrangement.canHide)
    arrangement.hide("f")
    #expect(arrangement.hidden.count == 5)
    #expect(arrangement.shown == ["f", "g"])
    arrangement.restore("a")
    #expect(arrangement.canHide)
}

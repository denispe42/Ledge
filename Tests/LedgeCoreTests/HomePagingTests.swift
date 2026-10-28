import Testing
@testable import LedgeCore

@Test func tilesAreSplitIntoPagesOfTen() {
    #expect(HomePaging.pageCount(tiles: 0) == 1)
    #expect(HomePaging.pageCount(tiles: 10) == 1)
    #expect(HomePaging.pageCount(tiles: 11) == 2)
    #expect(HomePaging.pageCount(tiles: 25) == 3)
}

@Test func tileRangeOfAPage() {
    #expect(HomePaging.range(page: 0, tiles: 11) == 0..<10)
    #expect(HomePaging.range(page: 1, tiles: 11) == 10..<11)
    #expect(HomePaging.range(page: 3, tiles: 11) == 10..<11)   // out of range pages show the last one
}

@Test func pageIsKeptInsideTheAvailablePages() {
    #expect(HomePaging.clamped(page: -1, tiles: 25) == 0)
    #expect(HomePaging.clamped(page: 5, tiles: 25) == 2)
    #expect(HomePaging.clamped(page: 1, tiles: 3) == 0)
}

@Test func steppingStopsAtTheEnds() {
    #expect(HomePaging.stepped(from: 0, by: 1, tiles: 25) == 1)
    #expect(HomePaging.stepped(from: 2, by: 1, tiles: 25) == 2)
    #expect(HomePaging.stepped(from: 0, by: -1, tiles: 25) == 0)
    #expect(HomePaging.stepped(from: 1, by: -1, tiles: 25) == 0)
}

import Foundation
import Testing
@testable import LedgeCore

private func tempFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("ledge-shelf-\(UUID().uuidString)/shelf.json")
}

@Test func shelfStartsEmpty() {
    #expect(ShelfList().items.isEmpty)
}

@Test func newItemsComeFirst() {
    var shelf = ShelfList()
    shelf.add(bookmark: Data([1]), name: "a.txt")
    shelf.add(bookmark: Data([2]), name: "b.txt")
    #expect(shelf.items.map(\.name) == ["b.txt", "a.txt"])
}

@Test func theSameFileIsNotAddedTwice() {
    var shelf = ShelfList()
    shelf.add(bookmark: Data([1]), name: "a.txt")
    shelf.add(bookmark: Data([2]), name: "b.txt")
    shelf.add(bookmark: Data([1]), name: "a.txt")
    #expect(shelf.items.count == 2)
    #expect(shelf.items.first?.name == "a.txt")   // moved to the front
}

@Test func itemsCanBeRemovedOneByOneOrAll() {
    var shelf = ShelfList()
    shelf.add(bookmark: Data([1]), name: "a")
    shelf.add(bookmark: Data([2]), name: "b")
    let id = shelf.items[1].id
    shelf.remove(id: id)
    #expect(shelf.items.map(\.name) == ["b"])
    shelf.removeAll()
    #expect(shelf.items.isEmpty)
}

@Test func updatedBookmarkKeepsTheItem() {
    var shelf = ShelfList()
    shelf.add(bookmark: Data([1]), name: "a")
    let id = shelf.items[0].id
    shelf.update(id: id, bookmark: Data([9]), name: "renamed")
    #expect(shelf.items.count == 1)
    #expect(shelf.items[0].bookmark == Data([9]))
    #expect(shelf.items[0].name == "renamed")
}

@Test func shelfIsLimited() {
    var shelf = ShelfList()
    for i in 0..<(ShelfList.limit + 5) { shelf.add(bookmark: Data([UInt8(i % 250), UInt8(i / 250)]), name: "\(i)") }
    #expect(shelf.items.count == ShelfList.limit)
}

@Test func storeKeepsItemsBetweenRuns() throws {
    let file = tempFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    var shelf = ShelfList()
    shelf.add(bookmark: Data([1, 2, 3]), name: "a.txt")
    let store = FileShelfStore(file: file)
    try store.save(shelf)
    #expect(FileShelfStore(file: file).load() == shelf)
}

@Test func missingOrBrokenStoreGivesAnEmptyShelf() throws {
    let file = tempFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    #expect(FileShelfStore(file: file).load().items.isEmpty)
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: file)
    #expect(FileShelfStore(file: file).load().items.isEmpty)
}

@Test func severalItemsCanBeRemovedAtOnce() {
    var shelf = ShelfList()
    ["a", "b", "c"].forEach { shelf.add(bookmark: Data($0.utf8), name: $0) }
    let doomed = Set(shelf.items.filter { $0.name != "b" }.map(\.id))
    shelf.remove(ids: doomed)
    #expect(shelf.items.map(\.name) == ["b"])
}

@Test func selectionStartsInactiveAndEmpty() {
    let s = ShelfSelection()
    #expect(!s.isActive && s.count == 0)
}

@Test func tappingTogglesAnItemInSelectionMode() {
    var s = ShelfSelection()
    let a = UUID(), b = UUID()
    s.begin()
    s.toggle(a)
    s.toggle(b)
    #expect(s.count == 2 && s.contains(a) && s.contains(b))
    s.toggle(a)
    #expect(s.count == 1 && !s.contains(a))
}

@Test func togglingDoesNothingOutsideSelectionMode() {
    var s = ShelfSelection()
    s.toggle(UUID())
    #expect(s.count == 0)
}

@Test func selectAllThenNoneAndEndingForgetsTheSelection() {
    var s = ShelfSelection()
    let ids = [UUID(), UUID(), UUID()]
    s.begin()
    s.selectAll(ids)
    #expect(s.count == 3 && s.allSelected(of: ids))
    s.deselectAll()
    #expect(s.count == 0 && s.isActive)
    s.selectAll(ids)
    s.end()
    #expect(!s.isActive && s.count == 0)
}

@Test func selectionDropsItemsThatAreGone() {
    var s = ShelfSelection()
    let a = UUID(), b = UUID()
    s.begin()
    s.selectAll([a, b])
    s.prune(keeping: [b])
    #expect(s.count == 1 && s.contains(b))
}

@Test func allSelectedIsFalseForAnEmptyShelf() {
    var s = ShelfSelection()
    s.begin()
    #expect(!s.allSelected(of: []))
}

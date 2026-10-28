import Foundation

/// The files on the shelf, newest first. Items hold a bookmark (a link that survives moving or renaming the file),
/// never a copy of the file.
public struct ShelfList: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public let id: UUID
        public var bookmark: Data
        /// The file name when it was added, shown if the file cannot be found any more.
        public var name: String
    }

    public static let limit = 100

    public private(set) var items: [Item] = []

    public init() {}

    /// Adds a file; the same file again only moves to the front.
    public mutating func add(bookmark: Data, name: String) {
        if let index = items.firstIndex(where: { $0.bookmark == bookmark }) {
            let existing = items.remove(at: index)
            items.insert(existing, at: 0)
        } else {
            items.insert(Item(id: UUID(), bookmark: bookmark, name: name), at: 0)
        }
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
    }

    public mutating func update(id: UUID, bookmark: Data, name: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].bookmark = bookmark
        items[index].name = name
    }

    public mutating func remove(id: UUID) { items.removeAll { $0.id == id } }
    public mutating func remove(ids: Set<UUID>) { items.removeAll { ids.contains($0.id) } }
    public mutating func removeAll() { items = [] }
}

/// Which shelf items are ticked while the user is choosing several (like "Select" in a photo gallery).
public struct ShelfSelection: Equatable, Sendable {
    public private(set) var isActive = false
    public private(set) var ids: Set<UUID> = []

    public init() {}

    public var count: Int { ids.count }
    public func contains(_ id: UUID) -> Bool { ids.contains(id) }
    public func allSelected(of all: [UUID]) -> Bool { !all.isEmpty && all.allSatisfy(ids.contains) }

    public mutating func begin() { isActive = true }
    public mutating func end() { isActive = false; ids = [] }

    /// Ticks or unticks an item; only while choosing.
    public mutating func toggle(_ id: UUID) {
        guard isActive else { return }
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    public mutating func selectAll(_ all: [UUID]) { if isActive { ids = Set(all) } }
    public mutating func deselectAll() { ids = [] }
    public mutating func prune(keeping existing: [UUID]) { ids.formIntersection(existing) }
}

/// Where the shelf is kept between runs: one small JSON file.
public struct FileShelfStore: Sendable {
    public let file: URL

    public init(file: URL) { self.file = file }

    /// An empty shelf when there is no file or it cannot be read.
    public func load() -> ShelfList {
        guard let data = try? Data(contentsOf: file) else { return ShelfList() }
        return (try? JSONDecoder().decode(ShelfList.self, from: data)) ?? ShelfList()
    }

    public func save(_ shelf: ShelfList) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(shelf).write(to: file, options: .atomic)
    }
}

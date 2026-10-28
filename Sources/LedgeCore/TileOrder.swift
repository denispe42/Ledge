/// The user's own order of the home screen tiles. Saved as a list of module ids; modules that appeared or disappeared
/// since it was saved must not break it.
public enum TileOrder {
    /// `ids` (the running modules in their default order) arranged as `saved` says. Ids not in `saved` go to the end
    /// in their default order; saved ids that are no longer present are ignored.
    public static func arranged(_ ids: [String], saved: [String]) -> [String] {
        let present = Set(ids)
        var seen = Set<String>()
        let known = saved.filter { present.contains($0) && seen.insert($0).inserted }
        return known + ids.filter { !seen.contains($0) }
    }

    /// `ids` with the element at `from` taken out and put at `to` (the others shift); unchanged for a bad index.
    public static func moved(_ ids: [String], from: Int, to: Int) -> [String] {
        guard ids.indices.contains(from), ids.indices.contains(to) else { return ids }
        var result = ids
        result.insert(result.remove(at: from), at: to)
        return result
    }
}

/// The home screen tiles: the ones shown in the user's order, then the ones the user put away (kept so they can be
/// brought back). Pure data; the island keeps one of these and saves `all` and `hidden`.
public struct TileArrangement: Equatable, Sendable {
    public private(set) var shown: [String]
    public private(set) var hidden: [String]

    /// `ids` are the running modules in their default order, `order` the saved order, `hidden` the saved hidden ids.
    public init(ids: [String], order: [String] = [], hidden: [String] = []) {
        let arranged = TileOrder.arranged(ids, saved: order)
        let away = Set(hidden)
        shown = arranged.filter { !away.contains($0) }
        var seen = Set<String>()
        self.hidden = hidden.filter { arranged.contains($0) && seen.insert($0).inserted }
    }

    /// Shown tiles, then hidden ones.
    public var all: [String] { shown + hidden }

    /// Moves a shown tile to position `index` among the shown ones.
    public mutating func move(_ id: String, to index: Int) {
        guard let from = shown.firstIndex(of: id) else { return }
        shown = TileOrder.moved(shown, from: from, to: index)
    }

    /// The most tiles that can be put away at once: they must all fit in the "bring back" frame (one row of five).
    public static let maxHidden = 5

    public var canHide: Bool { hidden.count < Self.maxHidden }

    public mutating func hide(_ id: String) {
        guard canHide, let from = shown.firstIndex(of: id) else { return }
        shown.remove(at: from)
        hidden.insert(id, at: 0)
    }

    /// Brings every hidden tile back, after the shown ones.
    public mutating func restoreAll() {
        shown += hidden
        hidden = []
    }

    public mutating func restore(_ id: String) {
        guard let from = hidden.firstIndex(of: id) else { return }
        hidden.remove(at: from)
        shown.append(id)
    }
}

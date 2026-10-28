import AppKit
import LedgeCore

/// The shelf: files dropped on the island wait here as links (the files stay where they are) until they are opened,
/// dragged out or removed. The list is kept in a small JSON file; nothing runs in the background.
@MainActor
final class ShelfModule: UIModule {
    let id = "shelf"
    var title: String { L10n.shelf }
    var dropZone: DropZone? {
        DropZone(symbol: "tray", title: title, showsPageAfterDrop: true) { [weak self] urls, _ in self?.accept(files: urls) }
    }

    private let store: FileShelfStore
    private var shelf = ShelfList()
    private var locations: [UUID: URL] = [:]
    private var selection = ShelfSelection()
    private var tiles: [TileView] = []
    private weak var page: ShelfPageView?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = FileShelfStore(file: support.appendingPathComponent("Ledge/shelf.json"))
    }

    func start() throws {
        shelf = store.load()
        resolveAll()
    }

    func stop() {
        tiles.removeAll()
        shelf = ShelfList()
        locations = [:]
        selection = ShelfSelection()
    }

    /// Choosing several files ends when the island closes.
    func islandVisibilityChanged(_ open: Bool) {
        guard !open, selection.isActive else { return }
        selection.end()
        refresh()
    }

    func makeTile(open: @escaping () -> Void) -> NSView {
        let tile = TileView(symbol: "tray", title: title)
        tile.onPress = { Haptics.tick(.generic); open() }
        tiles.append(tile)
        apply(to: tile)
        return tile
    }

    func makePage() -> NSView? {
        let page = ShelfPageView(
            clear: { [weak self] in self?.clear() },
            toggleSelecting: { [weak self] in self?.toggleSelecting() },
            toggleAll: { [weak self] in self?.toggleAll() },
            removeSelected: { [weak self] in self?.removeSelected() })
        self.page = page
        refresh()
        return page
    }

    private func accept(files: [URL]) {
        for url in files {
            guard let bookmark = ShelfBookmarks.make(for: url) else { continue }
            shelf.add(bookmark: bookmark, name: url.lastPathComponent)
        }
        resolveAll()
        save()
        refresh()
    }

    // MARK: Items

    /// Finds every file again from its link (it may have moved) and renews links that went stale.
    private func resolveAll() {
        locations = [:]
        for item in shelf.items {
            guard let found = ShelfBookmarks.resolve(item.bookmark) else { continue }
            locations[item.id] = found.url
            if let fresh = found.refreshed { shelf.update(id: item.id, bookmark: fresh, name: found.url.lastPathComponent) }
        }
    }

    private func open(_ id: UUID) {
        guard let url = locations[id] else { return }
        NSWorkspace.shared.open(url)
    }

    private func reveal(_ id: UUID) {
        guard let url = locations[id] else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func remove(_ id: UUID) {
        shelf.remove(id: id)
        locations[id] = nil
        afterRemoval()
    }

    private func clear() {
        shelf.removeAll()
        locations = [:]
        afterRemoval()
    }

    private func removeSelected() {
        let ids = selection.ids
        shelf.remove(ids: ids)
        ids.forEach { locations[$0] = nil }
        afterRemoval()
    }

    private func afterRemoval() {
        selection.prune(keeping: shelf.items.map(\.id))
        if shelf.items.isEmpty { selection.end() }
        save()
        refresh()
    }

    // MARK: Choosing several

    private func toggleSelecting() {
        if selection.isActive { selection.end() } else { selection.begin() }
        refresh()
    }

    private func toggleAll() {
        let all = shelf.items.map(\.id)
        if selection.allSelected(of: all) { selection.deselectAll() } else { selection.selectAll(all) }
        refresh()
    }

    /// What a drag out of the shelf takes: all ticked files when a ticked one is dragged, otherwise just that file.
    private func dragURLs(for id: UUID) -> [URL] {
        guard selection.isActive, selection.contains(id) else { return locations[id].map { [$0] } ?? [] }
        return shelf.items.filter { selection.contains($0.id) }.compactMap { locations[$0.id] }
    }

    private func save() {
        try? store.save(shelf)
    }

    private func refresh() {
        tiles.forEach(apply)
        let all = shelf.items.map(\.id)
        page?.update(shelf.items.map { item in
            ShelfPageView.Entry(name: locations[item.id]?.lastPathComponent ?? item.name, url: locations[item.id],
                                isSelected: selection.contains(item.id),
                                dragURLs: { [weak self] in self?.dragURLs(for: item.id) ?? [] },
                                toggle: { [weak self] in self?.toggle(item.id) },
                                open: { [weak self] in self?.open(item.id) },
                                reveal: { [weak self] in self?.reveal(item.id) },
                                remove: { [weak self] in self?.remove(item.id) })
        }, selecting: selection.isActive, selectedCount: selection.count, allSelected: selection.allSelected(of: all))
    }

    private func toggle(_ id: UUID) {
        selection.toggle(id)
        refresh()
    }

    private func apply(to tile: TileView) {
        tile.statusText = shelf.items.isEmpty ? L10n.empty : String(format: L10n.filesCount, shelf.items.count)
    }
}

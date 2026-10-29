import AppKit

/// Reading files from a drag, and the links ("bookmarks") the shelf keeps instead of copies.
enum FileDrop {
    static let types: [NSPasteboard.PasteboardType] = [.fileURL]

    static func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                           options: [.urlReadingFileURLsOnly: true])
        return (objects as? [URL]) ?? []
    }

    static func hasFiles(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }
}

enum ShelfBookmarks {
    /// A link to the file that survives moving and renaming. Security scope is used so the same code works if the
    /// app is ever sandboxed; for an ordinary app it behaves like a plain bookmark.
    static func make(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The file's current location, or nil if it is gone. `refreshed` is a new bookmark when the old one was stale.
    static func resolve(_ bookmark: Data) -> (url: URL, refreshed: Data?)? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return (url, stale ? make(for: url) : nil)
    }
}

/// Shelf preference: take a file off the shelf once it has been dragged out and dropped somewhere.
enum ShelfSettings {
    private static let key = "shelf.removeAfterDrag"

    static var removeAfterDrag: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

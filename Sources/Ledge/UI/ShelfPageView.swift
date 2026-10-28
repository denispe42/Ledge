import AppKit

/// One file on the shelf: its icon and name. Click opens it, dragging takes the file out (the file stays where it is),
/// the context menu shows it in Finder or removes it from the shelf. A file that cannot be found is dimmed.
/// While several files are being chosen a click ticks the file instead, and dragging a ticked file takes all ticked ones.
@MainActor
final class ShelfItemView: NSView, NSDraggingSource {
    private let url: URL?
    private let isSelecting: Bool
    private let onToggle: () -> Void
    private let dragURLs: () -> [URL]
    private let onOpen: () -> Void
    private let onReveal: () -> Void
    private let onRemove: () -> Void
    private let iconView = NSImageView()
    private var pressPoint: NSPoint?
    private var dragging = false

    init(name: String, url: URL?, isSelecting: Bool, isSelected: Bool, dragURLs: @escaping () -> [URL],
         onToggle: @escaping () -> Void, onOpen: @escaping () -> Void, onReveal: @escaping () -> Void,
         onRemove: @escaping () -> Void) {
        self.url = url
        self.isSelecting = isSelecting
        self.dragURLs = dragURLs
        self.onToggle = onToggle
        self.onOpen = onOpen
        self.onReveal = onReveal
        self.onRemove = onRemove
        super.init(frame: .zero)
        iconView.image = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: name)
        iconView.alphaValue = url == nil ? 0.35 : 1
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(wrappingLabelWithString: name)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = url == nil ? Glass.ink.withAlphaComponent(0.45) : Glass.ink
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(label)
        let badge = isSelecting ? Self.makeBadge(selected: isSelected) : nil
        if let badge { addSubview(badge) }   // constraints below need the badge to be in the hierarchy
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 68),
            heightAnchor.constraint(equalToConstant: 90),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
        ])
        if let badge {
            NSLayoutConstraint.activate([
                badge.widthAnchor.constraint(equalToConstant: 18),
                badge.heightAnchor.constraint(equalToConstant: 18),
                badge.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
                badge.topAnchor.constraint(equalTo: iconView.topAnchor, constant: -4),
            ])
        }
        setAccessibilityRole(.button)
        setAccessibilityLabel(name)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// A ring while choosing, a white disc with a tick once the file is chosen.
    private static func makeBadge(selected: Bool) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 9
        badge.layer?.borderWidth = 1.5
        badge.layer?.borderColor = Glass.ink.cgColor
        badge.layer?.backgroundColor = selected ? Glass.ink.cgColor : NSColor.clear.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        if selected {
            let tick = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .heavy)) ?? NSImage())
            tick.contentTintColor = Glass.inverseInk
            tick.translatesAutoresizingMaskIntoConstraints = false
            badge.addSubview(tick)
            tick.centerXAnchor.constraint(equalTo: badge.centerXAnchor).isActive = true
            tick.centerYAnchor.constraint(equalTo: badge.centerYAnchor).isActive = true
        }
        return badge
    }

    override func mouseDown(with event: NSEvent) {
        pressPoint = event.locationInWindow
        dragging = false
        alphaValue = 0.6
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressPoint, !dragging, url != nil else { return }
        guard hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4 else { return }
        dragging = true
        alphaValue = 1
        let items = dragURLs().map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(iconView.frame, contents: iconView.image)
            return item
        }
        guard !items.isEmpty else { return }
        beginDraggingSession(with: items, event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1
        defer { pressPoint = nil }
        guard !dragging, pressPoint != nil else { return }
        if isSelecting { onToggle() } else if url != nil { onOpen() }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        if url != nil { menu.addItem(withTitle: L10n.showInFinder, action: #selector(reveal), keyEquivalent: "").target = self }
        menu.addItem(withTitle: L10n.removeFromShelf, action: #selector(remove), keyEquivalent: "").target = self
        return menu
    }

    @objc private func reveal() { onReveal() }
    @objc private func remove() { onRemove() }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .link, .generic]
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Document view with its origin at the top.
private final class TopOriginView: NSView {
    override var isFlipped: Bool { true }
}

/// Shelf page: the files in a row (scrolls sideways), or a hint to drop files here. The whole island is the drop target.
@MainActor
final class ShelfPageView: NSView {
    struct Entry {
        let name: String
        let url: URL?
        let isSelected: Bool
        let dragURLs: () -> [URL]
        let toggle: () -> Void
        let open: () -> Void
        let reveal: () -> Void
        let remove: () -> Void
    }

    private let scroll = NSScrollView()
    private let row = NSStackView()
    private let hint = NSTextField(labelWithString: L10n.dropFilesHere)
    private let clearButton = PillButton(symbol: "trash", width: 32, height: 22)
    private let selectButton = PillButton(symbol: "checkmark.circle", width: 32, height: 22)
    private let allButton = PillButton(title: L10n.all, width: 40, height: 22)
    private let countLabel = NSTextField(labelWithString: "")
    private var removeSelectedEnabled = false
    private var isSelecting = false

    init(clear: @escaping () -> Void, toggleSelecting: @escaping () -> Void, toggleAll: @escaping () -> Void,
         removeSelected: @escaping () -> Void) {
        super.init(frame: .zero)
        let document = TopOriginView()
        document.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(row)
        scroll.documentView = document
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.textColor = Glass.ink.withAlphaComponent(0.45)
        hint.translatesAutoresizingMaskIntoConstraints = false
        clearButton.onPress = { [weak self] in
            guard let self else { return }
            if self.isSelecting {
                guard self.removeSelectedEnabled else { return }
                Haptics.tick(.generic)
                removeSelected()
            } else {
                Haptics.tick(.generic)
                clear()
            }
        }
        selectButton.onPress = { Haptics.tick(.generic); toggleSelecting() }
        selectButton.toolTip = L10n.selectFiles
        allButton.onPress = { Haptics.tick(.generic); toggleAll() }
        allButton.isHidden = true
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = Glass.ink
        countLabel.isHidden = true
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        let tools = NSStackView(views: [allButton, selectButton, clearButton])
        tools.orientation = .horizontal
        tools.spacing = 4 - 2 * PillButton.pad
        tools.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        addSubview(hint)
        addSubview(tools)
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 400),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
            document.widthAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.widthAnchor),
            row.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            row.centerYAnchor.constraint(equalTo: document.centerYAnchor),
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 8),
            tools.trailingAnchor.constraint(equalTo: trailingAnchor, constant: PillButton.pad - 14),
            tools.topAnchor.constraint(equalTo: topAnchor, constant: -PillButton.pad + 1),
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -30),
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func update(_ entries: [Entry], selecting: Bool, selectedCount: Int, allSelected: Bool) {
        isSelecting = selecting
        row.arrangedSubviews.forEach { row.removeArrangedSubview($0); $0.removeFromSuperview() }
        for entry in entries {
            row.addArrangedSubview(ShelfItemView(name: entry.name, url: entry.url, isSelecting: selecting,
                                                 isSelected: entry.isSelected, dragURLs: entry.dragURLs,
                                                 onToggle: entry.toggle, onOpen: entry.open, onReveal: entry.reveal,
                                                 onRemove: entry.remove))
        }
        hint.isHidden = !entries.isEmpty
        scroll.isHidden = entries.isEmpty
        selectButton.isHidden = entries.isEmpty
        clearButton.isHidden = entries.isEmpty
        allButton.isHidden = entries.isEmpty || !selecting
        selectButton.isProminent = selecting
        allButton.isProminent = allSelected
        countLabel.isHidden = entries.isEmpty || !selecting
        countLabel.stringValue = String(format: L10n.selectedCount, selectedCount)
        removeSelectedEnabled = selectedCount > 0
        clearButton.alphaValue = selecting && selectedCount == 0 ? 0.3 : 1
        clearButton.toolTip = selecting ? L10n.removeSelected : L10n.clearShelf
    }
}

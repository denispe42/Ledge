import AppKit
import LedgeCore

/// One reading on the monitor page: a small caption, the value, and a bar (or a line of detail) under it.
@MainActor
private final class MetricCellView: NSView {
    private let caption = NSTextField(labelWithString: "")
    private let value = NSTextField(labelWithString: "–")
    private let detail = NSTextField(labelWithString: " ")
    /// The system's charging bolt, shown beside the value while charging.
    private let bolt = NSImageView()
    private let track = NSView()
    private let fill = NSView()
    private var fillWidth: NSLayoutConstraint!

    init(caption text: String) {
        super.init(frame: .zero)
        caption.stringValue = text
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.textColor = Glass.ink.withAlphaComponent(0.55)
        value.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        value.textColor = Glass.ink
        detail.font = .systemFont(ofSize: 10, weight: .medium)
        detail.textColor = Glass.ink.withAlphaComponent(0.55)
        for view in [track, fill] {
            view.wantsLayer = true
            view.layer?.cornerRadius = 2
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        track.layer?.backgroundColor = Glass.ink.withAlphaComponent(0.2).cgColor
        fill.layer?.backgroundColor = MonitorPalette.color(for: .ok).cgColor
        track.addSubview(fill)
        bolt.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: L10n.charging)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
        bolt.contentTintColor = Glass.ink
        bolt.isHidden = true
        let valueRow = NSStackView(views: [value, bolt])
        valueRow.orientation = .horizontal
        valueRow.spacing = 2
        let column = NSStackView(views: [caption, valueRow, track, detail])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 1
        column.setCustomSpacing(3, after: valueRow)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 118),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            track.widthAnchor.constraint(equalTo: column.widthAnchor),
            track.heightAnchor.constraint(equalToConstant: 4),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fillWidth,
        ])
        track.isHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// `fraction` nil hides the bar (speeds have no natural maximum).
    func update(value text: String, detail line: String?, fraction: Double?, level: HealthLevel = .ok, bolt isCharging: Bool = false) {
        value.stringValue = text
        bolt.isHidden = !isCharging
        fill.layer?.backgroundColor = MonitorPalette.color(for: level).cgColor
        detail.stringValue = (line?.isEmpty ?? true) ? " " : line!
        track.isHidden = fraction == nil
        if let fraction {
            // 118 pt wide track
            fillWidth.constant = 118 * CGFloat(min(max(fraction, 0), 1))
        }
    }
}

/// Monitor page: processor, memory, disk, network speeds and battery in a grid of three by two. The bar of each reading
/// is green, orange or red by how much attention it needs.
@MainActor
final class MonitorPageView: NSView {
    struct Readings {
        var cpu: Double?
        var memoryUsed: String
        var memoryTotal: String
        var memoryFraction: Double
        var diskFree: String
        var diskFraction: Double
        var download: String
        var upload: String
        var battery: String?
        var batteryFraction: Double?
        var batteryDetail: String?
        var batteryCharging = false
        var cpuLevel = HealthLevel.ok, memoryLevel = HealthLevel.ok, diskLevel = HealthLevel.ok, batteryLevel = HealthLevel.ok
    }

    private let cpu = MetricCellView(caption: L10n.cpu)
    private let memory = MetricCellView(caption: L10n.memory)
    private let disk = MetricCellView(caption: L10n.disk)
    private let download = MetricCellView(caption: L10n.download)
    private let upload = MetricCellView(caption: L10n.upload)
    private let battery = MetricCellView(caption: L10n.battery)
    private let grid = NSStackView()

    init() {
        super.init(frame: .zero)
        func row(_ cells: [NSView]) -> NSStackView {
            let r = NSStackView(views: cells)
            r.orientation = .horizontal
            r.spacing = 20
            r.alignment = .top
            return r
        }
        grid.setViews([row([cpu, memory, disk]), row([download, upload, battery])], in: .center)
        grid.orientation = .vertical
        grid.spacing = 9
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 400),
            grid.centerXAnchor.constraint(equalTo: centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 6),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func update(_ r: Readings) {
        cpu.update(value: r.cpu.map { MetricFormat.percent($0) } ?? "–", detail: nil, fraction: r.cpu ?? 0, level: r.cpuLevel)
        memory.update(value: r.memoryUsed, detail: String(format: L10n.ofTotal, r.memoryTotal), fraction: r.memoryFraction, level: r.memoryLevel)
        disk.update(value: r.diskFree, detail: L10n.freeSpace, fraction: 1 - r.diskFraction, level: r.diskLevel)   // the bar shows the free part, like the number
        download.update(value: r.download, detail: nil, fraction: nil)
        upload.update(value: r.upload, detail: nil, fraction: nil)
        battery.update(value: r.battery ?? L10n.noBattery, detail: r.batteryDetail, fraction: r.batteryFraction, level: r.batteryLevel, bolt: r.batteryCharging)
    }
}

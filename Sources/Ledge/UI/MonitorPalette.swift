import AppKit
import LedgeCore

/// Colour of a reading's bar by how much attention it needs. System colours, so they follow light and dark appearance.
enum MonitorPalette {
    static func color(for level: HealthLevel) -> NSColor {
        switch level {
        case .ok: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }
}

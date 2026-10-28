import AppKit
import LedgeCore
import SwiftUI

/// Bridges the registry to SwiftUI. Rebuilt on every registry change.
@MainActor
final class SettingsModel: ObservableObject {
    struct Row: Identifiable {
        let id: ModuleID
        let title: String
        let enabled: Bool
        let failure: String?
    }

    private let registry: ModuleRegistry
    private let modules: [UIModule]

    init(registry: ModuleRegistry, modules: [UIModule]) {
        self.registry = registry
        self.modules = modules
        registry.addObserver { [weak self] in self?.objectWillChange.send() }
    }

    var rows: [Row] {
        modules.map { module in
            var failure: String?
            if case .failed(let message) = registry.state(of: module.id) { failure = message }
            return Row(id: module.id, title: module.title, enabled: registry.isEnabled(module.id), failure: failure)
        }
    }

    func setEnabled(_ id: ModuleID, _ on: Bool) { registry.setEnabled(id, on) }

    var hideTimeInFullscreen: Bool {
        get { CompactSettings.hideInFullscreen }
        set { CompactSettings.hideInFullscreen = newValue; objectWillChange.send() }
    }

    var sounds: [String] { TimerSettings.availableSounds }

    var soundName: String {
        get { TimerSettings.soundName }
        set { TimerSettings.soundName = newValue; objectWillChange.send(); previewSound() }
    }

    func previewSound() { Chime.shared.play(named: TimerSettings.soundName, times: 1) }

    var haptics: Bool {
        get { Haptics.isEnabled }
        set { Haptics.isEnabled = newValue; objectWillChange.send() }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section(L10n.modules) {
                ForEach(model.rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(row.title, isOn: Binding(get: { row.enabled },
                                                        set: { model.setEnabled(row.id, $0) }))
                        if let failure = row.failure {
                            Text(L10n.failure(failure)).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            Section(L10n.timer) {
                Picker(L10n.timerSound, selection: Binding(get: { model.soundName }, set: { model.soundName = $0 })) {
                    ForEach(model.sounds, id: \.self) { Text($0).tag($0) }
                }
                Button(L10n.testSound) { model.previewSound() }
            }
            Section(L10n.general) {
                Toggle(L10n.hideTimeInFullscreen,
                       isOn: Binding(get: { model.hideTimeInFullscreen }, set: { model.hideTimeInFullscreen = $0 }))
                Toggle(L10n.haptics, isOn: Binding(get: { model.haptics }, set: { model.haptics = $0 }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 440)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let model: SettingsModel

    init(model: SettingsModel) { self.model = model }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            w.title = L10n.settings.replacingOccurrences(of: "…", with: "")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

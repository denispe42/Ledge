import AppKit
import LedgeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let modules: [UIModule] = [KeepAwakeModule(), TimerModule(), StopwatchModule(), CalculatorModule(), ShelfModule(), AirDropModule(), MicrophoneModule(), CleaningModule(), MirrorModule(), MonitorModule()]
    private lazy var registry = ModuleRegistry(entries: modules.map { .init($0) }, store: UserDefaultsModuleStore())
    private lazy var island = IslandController(registry: registry, modules: modules)
    private lazy var settings = SettingsWindowController(model: SettingsModel(registry: registry, modules: modules))
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        island.start()
        registry.startEnabled()
        statusItem = StatusItemController { [weak self] in self?.settings.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        registry.shutdown()
    }
}

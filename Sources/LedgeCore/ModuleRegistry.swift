import Foundation
public typealias ModuleID = String

/// A self-contained feature. `start` must be cheap and may throw; `stop` must release everything the module holds.
@MainActor
public protocol ModuleLifecycle: AnyObject {
    var id: ModuleID { get }
    func start() throws
    func stop()
}

public enum ModuleState: Equatable, Sendable {
    case off
    case running
    case failed(String)
}

/// Persistence for module switches. The shell backs it with UserDefaults; tests use a fake.
@MainActor
public protocol ModuleSettingsStore: AnyObject {
    /// nil = the user never touched the switch.
    func isEnabled(_ id: ModuleID) -> Bool?
    func setEnabled(_ id: ModuleID, _ enabled: Bool)
    /// Set just before a module starts and cleared right after. If it is still set on the next launch,
    /// that module crashed the app while starting, so it is switched off to avoid a crash loop.
    var startingModule: ModuleID? { get set }
}

/// Starts, stops and isolates modules. One module failing never affects the others.
@MainActor
public final class ModuleRegistry {
    public struct Entry {
        public let module: ModuleLifecycle
        public let defaultEnabled: Bool
        public init(_ module: ModuleLifecycle, defaultEnabled: Bool = true) {
            self.module = module
            self.defaultEnabled = defaultEnabled
        }
    }

    private let entries: [Entry]
    private let store: ModuleSettingsStore
    private var states: [ModuleID: ModuleState] = [:]
    private var observers: [() -> Void] = []

    public init(entries: [Entry], store: ModuleSettingsStore) {
        self.entries = entries
        self.store = store
    }

    public var moduleIDs: [ModuleID] { entries.map(\.module.id) }

    public func state(of id: ModuleID) -> ModuleState { states[id] ?? .off }

    public func isEnabled(_ id: ModuleID) -> Bool {
        guard let entry = entry(id) else { return false }
        return store.isEnabled(id) ?? entry.defaultEnabled
    }

    public func addObserver(_ observer: @escaping () -> Void) { observers.append(observer) }

    /// Call once at launch.
    public func startEnabled() {
        if let crashed = store.startingModule {
            store.startingModule = nil
            store.setEnabled(crashed, false)
            states[crashed] = .failed("Crashed on the previous launch, switched off")
        }
        for entry in entries where isEnabled(entry.module.id) { start(entry) }
        notify()
    }

    public func setEnabled(_ id: ModuleID, _ enabled: Bool) {
        guard let entry = entry(id) else { return }
        store.setEnabled(id, enabled)
        if enabled {
            if state(of: id) != .running { start(entry) }
        } else {
            stopIfNeeded(entry)
            states[id] = .off
        }
        notify()
    }

    /// For modules that notice a runtime problem (device gone, API error): stops only that module.
    public func reportFailure(_ id: ModuleID, message: String) {
        guard let entry = entry(id) else { return }
        stopIfNeeded(entry)
        states[id] = .failed(message)
        notify()
    }

    /// Call when the app quits.
    public func shutdown() {
        for entry in entries { stopIfNeeded(entry) }
    }

    private func entry(_ id: ModuleID) -> Entry? { entries.first { $0.module.id == id } }

    private func start(_ entry: Entry) {
        let id = entry.module.id
        store.startingModule = id
        do {
            try entry.module.start()
            states[id] = .running
        } catch {
            entry.module.stop()
            states[id] = .failed(error.localizedDescription)
        }
        store.startingModule = nil
    }

    private func stopIfNeeded(_ entry: Entry) {
        guard state(of: entry.module.id) == .running else { return }
        entry.module.stop()
        states[entry.module.id] = .off
    }

    private func notify() { observers.forEach { $0() } }
}

import Foundation
import Testing
@testable import LedgeCore

@MainActor
private final class FakeStore: ModuleSettingsStore {
    var enabled: [ModuleID: Bool] = [:]
    var startingModule: ModuleID?
    func isEnabled(_ id: ModuleID) -> Bool? { enabled[id] }
    func setEnabled(_ id: ModuleID, _ on: Bool) { enabled[id] = on }
}

@MainActor
private final class FakeModule: ModuleLifecycle {
    let id: ModuleID
    var failOnStart = false
    var crashMarkerSeenDuringStart: ModuleID?
    private(set) var starts = 0, stops = 0
    weak var store: FakeStore?
    init(_ id: ModuleID) { self.id = id }
    struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }
    func start() throws {
        starts += 1
        crashMarkerSeenDuringStart = store?.startingModule
        if failOnStart { throw Boom() }
    }
    func stop() { stops += 1 }
}

@MainActor
private func make(_ ids: [String], store: FakeStore = FakeStore()) -> (ModuleRegistry, [FakeModule], FakeStore) {
    let modules = ids.map(FakeModule.init)
    modules.forEach { $0.store = store }
    return (ModuleRegistry(entries: modules.map { .init($0) }, store: store), modules, store)
}

@MainActor @Test func enabledModulesStartAndDisabledOnesNeverDo() {
    let store = FakeStore(); store.enabled["b"] = false
    let (registry, m, _) = make(["a", "b"], store: store)
    registry.startEnabled()
    #expect(registry.state(of: "a") == .running)
    #expect(registry.state(of: "b") == .off)
    #expect(m[1].starts == 0)
}

@MainActor @Test func failingModuleDoesNotAffectOthers() {
    let (registry, m, _) = make(["a", "b", "c"])
    m[1].failOnStart = true
    registry.startEnabled()
    #expect(registry.state(of: "a") == .running)
    #expect(registry.state(of: "b") == .failed("boom"))
    #expect(registry.state(of: "c") == .running)
}

@MainActor @Test func switchingOffStopsAndSwitchingOnRestarts() {
    let (registry, m, _) = make(["a"])
    registry.startEnabled()
    registry.setEnabled("a", false)
    #expect(m[0].stops == 1)
    #expect(registry.state(of: "a") == .off)
    registry.setEnabled("a", true)
    #expect(m[0].starts == 2)
    #expect(registry.state(of: "a") == .running)
}

@MainActor @Test func failedModuleCanBeRetriedFromSettings() {
    let (registry, m, _) = make(["a"])
    m[0].failOnStart = true
    registry.startEnabled()
    m[0].failOnStart = false
    registry.setEnabled("a", true)
    #expect(registry.state(of: "a") == .running)
}

@MainActor @Test func moduleThatCrashedWhileStartingIsSwitchedOffNextLaunch() {
    let store = FakeStore(); store.startingModule = "b"
    let (registry, m, _) = make(["a", "b"], store: store)
    registry.startEnabled()
    #expect(m[1].starts == 0)
    #expect(registry.isEnabled("b") == false)
    #expect(registry.state(of: "b") != .running)
    #expect(registry.state(of: "a") == .running)
    #expect(store.startingModule == nil)
}

@MainActor @Test func startMarkerIsSetDuringStartAndClearedAfter() {
    let (registry, m, store) = make(["a"])
    registry.startEnabled()
    #expect(m[0].crashMarkerSeenDuringStart == "a")
    #expect(store.startingModule == nil)
}

@MainActor @Test func reportedRuntimeFailureStopsOnlyThatModule() {
    let (registry, m, _) = make(["a", "b"])
    registry.startEnabled()
    registry.reportFailure("a", message: "device gone")
    #expect(registry.state(of: "a") == .failed("device gone"))
    #expect(m[0].stops == 1)
    #expect(registry.state(of: "b") == .running)
}

@MainActor @Test func observersAreNotified() {
    let (registry, _, _) = make(["a"])
    var count = 0
    registry.addObserver { count += 1 }
    registry.startEnabled()
    registry.setEnabled("a", false)
    #expect(count == 2)
}

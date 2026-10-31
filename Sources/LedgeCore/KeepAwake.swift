/// Abstraction over the system's "prevent sleep" assertions, so the logic can be tested.
@MainActor
public protocol PowerAssertionProvider: AnyObject {
    /// Returns a token, or nil if the system refused.
    func acquire(reason: String) -> UInt32?
    func release(_ token: UInt32)
}

/// Keeps the Mac (and display) awake while active. Holds a system assertion only while active.
@MainActor
public final class KeepAwake {
    public private(set) var isActive = false
    public var onChange: (() -> Void)?

    private let provider: PowerAssertionProvider
    private var token: UInt32?

    public init(provider: PowerAssertionProvider) { self.provider = provider }

    /// Returns false if the system refused to keep the Mac awake.
    @discardableResult
    public func setActive(_ active: Bool, reason: String = "Ledge Keep Awake") -> Bool {
        guard active != isActive else { return true }
        if active {
            guard let token = provider.acquire(reason: reason) else { return false }
            self.token = token
        } else if let token {
            provider.release(token)
            self.token = nil
        }
        isActive = active
        onChange?()
        return true
    }

    @discardableResult
    public func toggle() -> Bool { setActive(!isActive) }

    /// Releases the assertion; used when the module is switched off or the app quits.
    public func shutdown() { setActive(false) }
}

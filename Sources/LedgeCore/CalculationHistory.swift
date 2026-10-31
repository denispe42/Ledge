import Foundation

/// Finished calculations of one calculator, newest first. Kept in memory only.
public struct CalculationHistory: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let expression: String
        /// The result as it was shown (a fraction, or in the number base of that moment).
        public let result: String
        /// The result as a signed decimal with a decimal point, to take it over into the next calculation.
        public let value: String
    }

    public static let limit = 50

    public private(set) var entries: [Entry] = []

    public init() {}

    public mutating func add(expression: String, result: String, value: String) {
        let entry = Entry(expression: expression, result: result, value: value)
        guard entries.first != entry else { return }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }

    public mutating func clear() { entries = [] }
}

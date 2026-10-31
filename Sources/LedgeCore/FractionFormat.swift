import Foundation

/// Turns a decimal result into a common fraction ("0.583333333333333" → "7/12") with continued fractions.
public enum FractionFormat {
    static let maxDenominator = 100_000

    /// nil for whole numbers and for values that are not a fraction with a small denominator (π, √2).
    public static func string(for value: Decimal) -> String? {
        let x = NSDecimalNumber(decimal: value).doubleValue
        guard x.isFinite, x != x.rounded() else { return nil }
        let target = abs(x)
        let tolerance = 1e-12 * max(1, target)
        // Convergents h/k of the continued fraction of `target`.
        var (h0, k0): (Double, Double) = (1, 0)
        var (h1, k1): (Double, Double) = (target.rounded(.down), 1)
        var rest = target - target.rounded(.down)
        while abs(target - h1 / k1) > tolerance {
            guard rest > 1e-15 else { return nil }
            let inverse = 1 / rest
            let a = inverse.rounded(.down)
            rest = inverse - a
            (h0, h1) = (h1, a * h1 + h0)
            (k0, k1) = (k1, a * k1 + k0)
            if k1 > Double(maxDenominator) { return nil }
        }
        guard k1 > 1 else { return nil }
        return "\(x < 0 ? "-" : "")\(Int(h1))/\(Int(k1))"
    }
}

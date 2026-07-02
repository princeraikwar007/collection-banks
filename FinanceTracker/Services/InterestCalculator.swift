import Foundation

/// Pure, offline financial math.
enum InterestCalculator {
    enum Kind: String, CaseIterable, Identifiable {
        case simple, compound
        var id: String { rawValue }
        var displayName: String { self == .simple ? "Simple" : "Compound" }
    }

    /// Simple interest: I = P * r * t.
    static func simpleInterest(principal: Double, annualRatePercent: Double, years: Double) -> Double {
        principal * (annualRatePercent / 100.0) * years
    }

    /// Compound interest total accrued: A - P where A = P(1 + r/n)^(n*t).
    static func compoundInterest(
        principal: Double,
        annualRatePercent: Double,
        years: Double,
        compoundsPerYear: Int
    ) -> Double {
        let r = annualRatePercent / 100.0
        let n = Double(max(1, compoundsPerYear))
        let amount = principal * pow(1.0 + r / n, n * years)
        return amount - principal
    }

    struct Result {
        let interest: Double
        let total: Double
    }

    static func calculate(
        kind: Kind,
        principal: Double,
        annualRatePercent: Double,
        years: Double,
        compoundsPerYear: Int = 12
    ) -> Result {
        let interest: Double
        switch kind {
        case .simple:
            interest = simpleInterest(principal: principal, annualRatePercent: annualRatePercent, years: years)
        case .compound:
            interest = compoundInterest(principal: principal, annualRatePercent: annualRatePercent, years: years, compoundsPerYear: compoundsPerYear)
        }
        return Result(interest: interest, total: principal + interest)
    }
}

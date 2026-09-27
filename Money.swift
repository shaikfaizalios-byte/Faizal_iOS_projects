import Foundation

/// Currency amounts are held in minor units (paise) as an integer.
/// Floating point is never used for money: 0.1 + 0.2 != 0.3 in binary
/// floating point, and a rounding error in a payment app is a defect.
struct Money: Equatable, Hashable, Codable, Sendable {
    let minorUnits: Int
    let currencyCode: String

    init(minorUnits: Int, currencyCode: String = "INR") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    static let zero = Money(minorUnits: 0)

    var isPositive: Bool { minorUnits > 0 }

    /// Parses user input such as "1,250.50" into minor units.
    /// Returns nil for anything that is not a well-formed, non-negative amount.
    init?(userInput: String, currencyCode: String = "INR") {
        let cleaned = userInput
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }

        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        guard let major = Int(parts[0]), major >= 0 else { return nil }

        var minor = 0
        if parts.count == 2 {
            let fraction = String(parts[1])
            guard fraction.count <= 2, fraction.allSatisfy(\.isNumber) else { return nil }
            let padded = fraction.padding(toLength: 2, withPad: "0", startingAt: 0)
            guard let parsed = Int(padded) else { return nil }
            minor = parsed
        }

        // Guard against overflow on absurd input rather than trapping.
        let (product, overflowed) = major.multipliedReportingOverflow(by: 100)
        guard !overflowed else { return nil }
        self.init(minorUnits: product + minor, currencyCode: currencyCode)
    }

    func adding(_ other: Money) -> Money {
        precondition(currencyCode == other.currencyCode, "Cannot add mismatched currencies")
        return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode)
    }

    func subtracting(_ other: Money) -> Money {
        precondition(currencyCode == other.currencyCode, "Cannot subtract mismatched currencies")
        return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode)
    }

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        let value = Decimal(minorUnits) / 100
        return formatter.string(from: value as NSDecimalNumber)
            ?? "\(currencyCode) \(value)"
    }
}

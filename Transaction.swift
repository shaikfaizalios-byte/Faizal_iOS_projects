import Foundation

struct Transaction: Identifiable, Equatable, Hashable, Codable, Sendable {
    enum Direction: String, Codable, Sendable {
        case debit
        case credit
    }

    /// A payment is a state machine, never a Bool. An interrupted network
    /// call leaves a transaction `pending`, and the app must be able to
    /// represent that honestly rather than guessing success or failure.
    enum Status: String, Codable, Sendable {
        case pending
        case completed
        case failed
        case reversed
    }

    let id: String
    let counterparty: String
    let amount: Money
    let direction: Direction
    let status: Status
    let occurredAt: Date
    let note: String?

    var signedAmount: Money {
        direction == .debit
            ? Money(minorUnits: -amount.minorUnits, currencyCode: amount.currencyCode)
            : amount
    }
}

struct Wallet: Equatable, Codable, Sendable {
    let accountName: String
    let balance: Money
    let transactions: [Transaction]
}

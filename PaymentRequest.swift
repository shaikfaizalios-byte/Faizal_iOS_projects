import Foundation

struct PaymentRequest: Equatable, Sendable {
    let payee: String
    let amount: Money
    let note: String?

    /// Client-generated idempotency key.
    ///
    /// If the request times out the client cannot know whether the server
    /// executed the debit. Retrying with the same key lets the server
    /// recognise the duplicate and return the original result instead of
    /// debiting twice. This is the single most important property of a
    /// payment API and the key must be generated once, at intent time,
    /// not regenerated on each retry.
    let idempotencyKey: String

    init(payee: String, amount: Money, note: String? = nil, idempotencyKey: String = UUID().uuidString) {
        self.payee = payee
        self.amount = amount
        self.note = note
        self.idempotencyKey = idempotencyKey
    }
}

enum PaymentOutcome: Equatable, Sendable {
    case completed(Transaction)
    /// Accepted by the server but not yet settled, or the result is unknown
    /// to the client. The UI must show this as pending, never as success.
    case pending(transactionID: String)
}

enum PaymentError: Error, Equatable, LocalizedError {
    case invalidAmount
    case insufficientFunds
    case authenticationFailed
    case authenticationUnavailable
    case network(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Enter a valid amount greater than zero."
        case .insufficientFunds:
            return "This payment is more than your available balance."
        case .authenticationFailed:
            return "We could not verify it was you. Please try again."
        case .authenticationUnavailable:
            return "Set up Face ID, Touch ID or a device passcode to send payments."
        case .network(let detail):
            return "Connection problem: \(detail)"
        case .server(let detail):
            return detail
        }
    }
}

import Foundation

/// The domain depends on this protocol, not on URLSession. That inversion is
/// what lets the view models be unit-tested with a stub and what lets the
/// networking implementation be replaced without touching the UI.
protocol WalletRepository: Sendable {
    func loadWallet() async throws -> Wallet
    func submitPayment(_ request: PaymentRequest) async throws -> PaymentOutcome
}

protocol PaymentAuthenticator: Sendable {
    /// Throws `PaymentError.authenticationFailed` or
    /// `.authenticationUnavailable` rather than returning false, so a caller
    /// cannot accidentally ignore the result.
    func authenticate(reason: String) async throws
}

protocol SecureStore: Sendable {
    func save(_ data: Data, for key: String) throws
    func read(key: String) throws -> Data?
    func delete(key: String) throws
}

import Foundation

/// One use case, one job: validate, authenticate, submit.
///
/// Keeping this out of the view model means the rule "biometric auth happens
/// before the network call, never after" is expressed in one testable place
/// rather than being a property of how a button handler happens to be written.
struct SendPaymentUseCase: Sendable {
    private let repository: WalletRepository
    private let authenticator: PaymentAuthenticator

    init(repository: WalletRepository, authenticator: PaymentAuthenticator) {
        self.repository = repository
        self.authenticator = authenticator
    }

    func callAsFunction(
        request: PaymentRequest,
        availableBalance: Money
    ) async throws -> PaymentOutcome {
        guard request.amount.isPositive else {
            throw PaymentError.invalidAmount
        }
        guard request.amount.minorUnits <= availableBalance.minorUnits else {
            throw PaymentError.insufficientFunds
        }

        try await authenticator.authenticate(
            reason: "Confirm payment of \(request.amount.formatted) to \(request.payee)"
        )

        return try await repository.submitPayment(request)
    }
}

struct LoadWalletUseCase: Sendable {
    private let repository: WalletRepository

    init(repository: WalletRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> Wallet {
        try await repository.loadWallet()
    }
}

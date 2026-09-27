import Foundation

/// Composition root. Every dependency is constructed here and injected
/// downward, so nothing in the app reaches out for a singleton. That is what
/// makes the view models testable and what lets the whole app run against a
/// stub repository in previews.
@MainActor
final class AppContainer {
    private let repository: WalletRepository
    private let authenticator: PaymentAuthenticator
    let secureStore: SecureStore

    init(
        repository: WalletRepository,
        authenticator: PaymentAuthenticator,
        secureStore: SecureStore = KeychainStore()
    ) {
        self.repository = repository
        self.authenticator = authenticator
        self.secureStore = secureStore
    }

    static var live: AppContainer {
        AppContainer(
            repository: InMemoryWalletRepository(),
            authenticator: BiometricAuthenticator()
        )
    }

    /// Previews must never hit a biometric prompt or a network.
    static var preview: AppContainer {
        AppContainer(
            repository: InMemoryWalletRepository(artificialLatency: .milliseconds(80)),
            authenticator: AlwaysAllowAuthenticator()
        )
    }

    func makeWalletViewModel() -> WalletViewModel {
        WalletViewModel(loadWallet: LoadWalletUseCase(repository: repository))
    }

    func makeSendPaymentViewModel(availableBalance: Money) -> SendPaymentViewModel {
        SendPaymentViewModel(
            sendPayment: SendPaymentUseCase(
                repository: repository,
                authenticator: authenticator
            ),
            availableBalance: availableBalance
        )
    }
}

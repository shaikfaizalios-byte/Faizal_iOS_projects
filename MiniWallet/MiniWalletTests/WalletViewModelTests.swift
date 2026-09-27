import XCTest
@testable import MiniWallet

private struct ThrowingRepository: WalletRepository {
    func loadWallet() async throws -> Wallet {
        throw APIError.transport("offline")
    }
    func submitPayment(_ request: PaymentRequest) async throws -> PaymentOutcome {
        throw APIError.transport("offline")
    }
}

@MainActor
final class WalletViewModelTests: XCTestCase {

    func test_loadsWalletIntoLoadedState() async {
        let repository = InMemoryWalletRepository(artificialLatency: .zero)
        let viewModel = WalletViewModel(loadWallet: LoadWalletUseCase(repository: repository))

        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.load()

        XCTAssertNotNil(viewModel.state.value)
        XCTAssertFalse(viewModel.transactions.isEmpty)
    }

    func test_failureProducesFailedStateNotEmptyContent() async {
        let viewModel = WalletViewModel(loadWallet: LoadWalletUseCase(repository: ThrowingRepository()))

        await viewModel.load()

        guard case .failed = viewModel.state else {
            return XCTFail("A failed load must be distinguishable from an empty wallet")
        }
        XCTAssertEqual(viewModel.balance, .zero)
    }
}

@MainActor
final class SendPaymentViewModelTests: XCTestCase {

    private func makeViewModel(
        balance: Money = Money(minorUnits: 100_000),
        authenticator: PaymentAuthenticator = AlwaysAllowAuthenticator()
    ) -> SendPaymentViewModel {
        SendPaymentViewModel(
            sendPayment: SendPaymentUseCase(
                repository: InMemoryWalletRepository(balance: balance, transactions: [], artificialLatency: .zero),
                authenticator: authenticator
            ),
            availableBalance: balance
        )
    }

    func test_cannotSubmitWithEmptyPayee() {
        let viewModel = makeViewModel()
        viewModel.amountText = "100"
        XCTAssertFalse(viewModel.canSubmit)
    }

    func test_cannotSubmitWithInvalidAmount() {
        let viewModel = makeViewModel()
        viewModel.payee = "Ravi"
        viewModel.amountText = "abc"
        XCTAssertFalse(viewModel.canSubmit)
    }

    func test_showsValidationMessageWhenAmountExceedsBalance() {
        let viewModel = makeViewModel()
        viewModel.payee = "Ravi"
        viewModel.amountText = "5000"
        XCTAssertNotNil(viewModel.validationMessage)
    }

    func test_successfulSubmissionReachesSucceededPhase() async {
        let viewModel = makeViewModel()
        viewModel.payee = "Ravi"
        viewModel.amountText = "250"

        await viewModel.submit()

        guard case .succeeded = viewModel.phase else {
            return XCTFail("Expected succeeded, got \(viewModel.phase)")
        }
    }

    func test_whitespaceOnlyPayeeIsRejected() {
        let viewModel = makeViewModel()
        viewModel.payee = "   "
        viewModel.amountText = "250"
        XCTAssertFalse(viewModel.canSubmit)
    }
}

import XCTest
@testable import MiniWallet

// MARK: - Stubs

private actor StubRepository: WalletRepository {
    var submittedRequests: [PaymentRequest] = []
    var outcome: Result<PaymentOutcome, Error>

    init(outcome: Result<PaymentOutcome, Error> = .success(.pending(transactionID: "txn-1"))) {
        self.outcome = outcome
    }

    func loadWallet() async throws -> Wallet {
        Wallet(accountName: "Test", balance: Money(minorUnits: 100_000), transactions: [])
    }

    func submitPayment(_ request: PaymentRequest) async throws -> PaymentOutcome {
        submittedRequests.append(request)
        return try outcome.get()
    }

    func requestCount() -> Int { submittedRequests.count }
}

private struct FailingAuthenticator: PaymentAuthenticator {
    let error: PaymentError
    func authenticate(reason: String) async throws { throw error }
}

// MARK: - Tests

final class SendPaymentUseCaseTests: XCTestCase {

    private let balance = Money(minorUnits: 100_000) // ₹1,000

    func test_rejectsZeroAmount() async {
        let repository = StubRepository()
        let useCase = SendPaymentUseCase(repository: repository, authenticator: AlwaysAllowAuthenticator())
        let request = PaymentRequest(payee: "Ravi", amount: .zero)

        await assertThrows(PaymentError.invalidAmount) {
            _ = try await useCase(request: request, availableBalance: balance)
        }

        let count = await repository.requestCount()
        XCTAssertEqual(count, 0, "A zero-amount payment must never reach the network")
    }

    func test_rejectsAmountAboveBalance() async {
        let repository = StubRepository()
        let useCase = SendPaymentUseCase(repository: repository, authenticator: AlwaysAllowAuthenticator())
        let request = PaymentRequest(payee: "Ravi", amount: Money(minorUnits: 100_001))

        await assertThrows(PaymentError.insufficientFunds) {
            _ = try await useCase(request: request, availableBalance: balance)
        }
    }

    func test_allowsPaymentOfExactlyTheFullBalance() async throws {
        let repository = StubRepository()
        let useCase = SendPaymentUseCase(repository: repository, authenticator: AlwaysAllowAuthenticator())
        let request = PaymentRequest(payee: "Ravi", amount: balance)

        _ = try await useCase(request: request, availableBalance: balance)

        let count = await repository.requestCount()
        XCTAssertEqual(count, 1, "Boundary case: spending the whole balance is legal")
    }

    func test_doesNotSubmitWhenAuthenticationFails() async {
        let repository = StubRepository()
        let useCase = SendPaymentUseCase(
            repository: repository,
            authenticator: FailingAuthenticator(error: .authenticationFailed)
        )
        let request = PaymentRequest(payee: "Ravi", amount: Money(minorUnits: 5_000))

        await assertThrows(PaymentError.authenticationFailed) {
            _ = try await useCase(request: request, availableBalance: balance)
        }

        let count = await repository.requestCount()
        XCTAssertEqual(count, 0, "Authentication must gate the debit, not follow it")
    }

    func test_forwardsIdempotencyKeyUnchanged() async throws {
        let repository = StubRepository()
        let useCase = SendPaymentUseCase(repository: repository, authenticator: AlwaysAllowAuthenticator())
        let request = PaymentRequest(
            payee: "Ravi",
            amount: Money(minorUnits: 5_000),
            idempotencyKey: "fixed-key"
        )

        _ = try await useCase(request: request, availableBalance: balance)

        let submitted = await repository.submittedRequests
        XCTAssertEqual(submitted.first?.idempotencyKey, "fixed-key")
    }

    // MARK: - Helper

    private func assertThrows(
        _ expected: PaymentError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected) but no error was thrown", file: file, line: line)
        } catch let error as PaymentError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected \(expected) but got \(error)", file: file, line: line)
        }
    }
}

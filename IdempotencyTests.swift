import XCTest
@testable import MiniWallet

/// The test that matters most in a payments app: a retry must not debit twice.
final class IdempotencyTests: XCTestCase {

    func test_retryingWithSameKeyDoesNotDebitTwice() async throws {
        let repository = InMemoryWalletRepository(
            balance: Money(minorUnits: 100_000),
            transactions: [],
            artificialLatency: .zero
        )

        let request = PaymentRequest(
            payee: "Ravi",
            amount: Money(minorUnits: 25_000),
            idempotencyKey: "same-key"
        )

        _ = try await repository.submitPayment(request)
        _ = try await repository.submitPayment(request) // the retry

        let wallet = try await repository.loadWallet()
        XCTAssertEqual(wallet.balance.minorUnits, 75_000, "Balance must reflect one debit, not two")
        XCTAssertEqual(wallet.transactions.count, 1, "The retry must not create a second transaction")
    }

    func test_differentKeysProduceSeparatePayments() async throws {
        let repository = InMemoryWalletRepository(
            balance: Money(minorUnits: 100_000),
            transactions: [],
            artificialLatency: .zero
        )

        _ = try await repository.submitPayment(
            PaymentRequest(payee: "Ravi", amount: Money(minorUnits: 25_000), idempotencyKey: "key-1")
        )
        _ = try await repository.submitPayment(
            PaymentRequest(payee: "Ravi", amount: Money(minorUnits: 25_000), idempotencyKey: "key-2")
        )

        let wallet = try await repository.loadWallet()
        XCTAssertEqual(wallet.balance.minorUnits, 50_000)
        XCTAssertEqual(wallet.transactions.count, 2)
    }
}

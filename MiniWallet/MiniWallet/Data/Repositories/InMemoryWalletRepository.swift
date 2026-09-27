import Foundation

/// An actor, not a class with a lock.
///
/// The repository holds mutable state (the ledger) that is read from the main
/// actor and written from background tasks. Making it an actor lets the
/// compiler prove there is no data race, which is the whole point of Swift's
/// concurrency model — the bug class disappears rather than being tested for.
actor InMemoryWalletRepository: WalletRepository {
    private var balance: Money
    private var transactions: [Transaction]
    private let artificialLatency: Duration

    /// Maps idempotency key -> outcome, so a retried request returns the
    /// original result instead of debiting twice. A real backend does this
    /// server-side; modelling it here keeps the client contract honest.
    private var processedKeys: [String: PaymentOutcome] = [:]

    init(
        balance: Money = Money(minorUnits: 4_82_650),
        transactions: [Transaction] = Transaction.samples,
        artificialLatency: Duration = .milliseconds(700)
    ) {
        self.balance = balance
        self.transactions = transactions
        self.artificialLatency = artificialLatency
    }

    func loadWallet() async throws -> Wallet {
        try await Task.sleep(for: artificialLatency)
        return Wallet(
            accountName: "Everyday Account",
            balance: balance,
            transactions: transactions.sorted { $0.occurredAt > $1.occurredAt }
        )
    }

    func submitPayment(_ request: PaymentRequest) async throws -> PaymentOutcome {
        if let existing = processedKeys[request.idempotencyKey] {
            return existing
        }

        try await Task.sleep(for: artificialLatency)

        guard request.amount.minorUnits <= balance.minorUnits else {
            throw PaymentError.insufficientFunds
        }

        let transaction = Transaction(
            id: UUID().uuidString,
            counterparty: request.payee,
            amount: request.amount,
            direction: .debit,
            status: .completed,
            occurredAt: .now,
            note: request.note
        )

        balance = balance.subtracting(request.amount)
        transactions.insert(transaction, at: 0)

        let outcome = PaymentOutcome.completed(transaction)
        processedKeys[request.idempotencyKey] = outcome
        return outcome
    }
}

extension Transaction {
    static var samples: [Transaction] {
        let now = Date.now
        return [
            Transaction(id: "1", counterparty: "Blue Tokai Coffee", amount: Money(minorUnits: 47_000),
                        direction: .debit, status: .completed,
                        occurredAt: now.addingTimeInterval(-3_600), note: "Cold brew"),
            Transaction(id: "2", counterparty: "Salary — Tata Consultancy", amount: Money(minorUnits: 12_50_000),
                        direction: .credit, status: .completed,
                        occurredAt: now.addingTimeInterval(-86_400 * 2), note: nil),
            Transaction(id: "3", counterparty: "Airtel Postpaid", amount: Money(minorUnits: 89_900),
                        direction: .debit, status: .pending,
                        occurredAt: now.addingTimeInterval(-86_400 * 3), note: "Auto-pay"),
            Transaction(id: "4", counterparty: "Rahul Verma", amount: Money(minorUnits: 2_50_000),
                        direction: .debit, status: .completed,
                        occurredAt: now.addingTimeInterval(-86_400 * 4), note: "Split — dinner"),
            Transaction(id: "5", counterparty: "Swiggy", amount: Money(minorUnits: 64_500),
                        direction: .debit, status: .failed,
                        occurredAt: now.addingTimeInterval(-86_400 * 5), note: nil)
        ]
    }
}

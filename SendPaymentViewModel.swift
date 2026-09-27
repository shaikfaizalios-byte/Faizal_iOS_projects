import Foundation
import Observation

@MainActor
@Observable
final class SendPaymentViewModel {
    enum Phase: Equatable {
        case editing
        case authenticating
        case submitting
        case succeeded(Transaction)
        case pending(transactionID: String)
        case failed(String)
    }

    var payee: String = ""
    var amountText: String = ""
    var note: String = ""

    private(set) var phase: Phase = .editing

    private let sendPayment: SendPaymentUseCase
    private let availableBalance: Money

    /// Generated once, when the screen is created — not per attempt.
    /// A retry after a timeout must carry the same key or the server cannot
    /// tell a retry from a second payment.
    private let idempotencyKey = UUID().uuidString

    init(sendPayment: SendPaymentUseCase, availableBalance: Money) {
        self.sendPayment = sendPayment
        self.availableBalance = availableBalance
    }

    var parsedAmount: Money? {
        Money(userInput: amountText)
    }

    var canSubmit: Bool {
        guard case .editing = phase else { return false }
        guard !payee.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let amount = parsedAmount, amount.isPositive else { return false }
        return true
    }

    var validationMessage: String? {
        guard !amountText.isEmpty else { return nil }
        guard let amount = parsedAmount else { return "Enter a valid amount." }
        guard amount.isPositive else { return "Amount must be more than zero." }
        guard amount.minorUnits <= availableBalance.minorUnits else {
            return "That is more than your available balance of \(availableBalance.formatted)."
        }
        return nil
    }

    var isBusy: Bool {
        phase == .authenticating || phase == .submitting
    }

    func submit() async {
        guard canSubmit, let amount = parsedAmount else { return }

        let request = PaymentRequest(
            payee: payee.trimmingCharacters(in: .whitespaces),
            amount: amount,
            note: note.isEmpty ? nil : note,
            idempotencyKey: idempotencyKey
        )

        // The use case authenticates before it submits, so the screen shows
        // the biometric phase first; the system prompt appears over it.
        phase = .authenticating
        do {
            let outcome = try await sendPayment(
                request: request,
                availableBalance: availableBalance
            )

            switch outcome {
            case .completed(let transaction):
                phase = .succeeded(transaction)
            case .pending(let id):
                phase = .pending(transactionID: id)
            }
        } catch let error as PaymentError {
            phase = .failed(error.localizedDescription ?? "Payment failed.")
        } catch {
            // Unknown failure after submission: never claim failure outright.
            phase = .failed("We could not confirm this payment. Check your transaction history before retrying.")
        }
    }

    func reset() {
        phase = .editing
    }
}

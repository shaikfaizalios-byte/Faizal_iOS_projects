import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.counterparty)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.occurredAt, format: .dateTime.day().month().hour().minute())
                    if transaction.status != .completed {
                        Text("·")
                        Text(statusLabel)
                            .foregroundStyle(tint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(amountLabel)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(transaction.direction == .credit ? Color.green : Color.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var amountLabel: String {
        let sign = transaction.direction == .credit ? "+" : "−"
        return "\(sign)\(transaction.amount.formatted)"
    }

    private var statusLabel: String {
        switch transaction.status {
        case .pending: return "Pending"
        case .failed: return "Failed"
        case .reversed: return "Reversed"
        case .completed: return ""
        }
    }

    private var icon: String {
        switch transaction.status {
        case .pending: return "clock"
        case .failed: return "exclamationmark"
        case .reversed: return "arrow.uturn.backward"
        case .completed: return transaction.direction == .credit ? "arrow.down" : "arrow.up"
        }
    }

    private var tint: Color {
        switch transaction.status {
        case .pending: return .orange
        case .failed: return .red
        case .reversed: return .purple
        case .completed: return transaction.direction == .credit ? .green : .accentColor
        }
    }

    private var accessibilityDescription: String {
        let direction = transaction.direction == .credit ? "Received from" : "Paid to"
        let status = transaction.status == .completed ? "" : ", \(statusLabel)"
        return "\(direction) \(transaction.counterparty), \(transaction.amount.formatted)\(status)"
    }
}

#Preview {
    List {
        ForEach(Transaction.samples) { TransactionRow(transaction: $0) }
    }
}

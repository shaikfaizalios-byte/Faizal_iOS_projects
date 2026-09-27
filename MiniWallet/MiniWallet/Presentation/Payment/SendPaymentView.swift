import SwiftUI

struct SendPaymentView: View {
    @State var viewModel: SendPaymentViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case payee, amount, note }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .editing, .authenticating, .submitting, .failed:
                    form
                case .succeeded(let transaction):
                    PaymentResultView(
                        style: .success,
                        title: "Payment sent",
                        message: "\(transaction.amount.formatted) to \(transaction.counterparty)",
                        primaryTitle: "Done",
                        primaryAction: { dismiss() }
                    )
                case .pending(let id):
                    PaymentResultView(
                        style: .pending,
                        title: "Payment pending",
                        message: "We've received your request but it hasn't settled yet. Reference \(id.prefix(8)). Check your history before sending again.",
                        primaryTitle: "Done",
                        primaryAction: { dismiss() }
                    )
                }
            }
            .navigationTitle("Send money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isBusy)
                }
            }
            .interactiveDismissDisabled(viewModel.isBusy)
        }
    }

    private var form: some View {
        Form {
            Section("Pay to") {
                TextField("Name or UPI ID", text: $viewModel.payee)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .payee)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .amount }
            }

            Section {
                HStack {
                    Text("₹")
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .focused($focusedField, equals: .amount)
                }
            } header: {
                Text("Amount")
            } footer: {
                if let message = viewModel.validationMessage {
                    Text(message).foregroundStyle(.red)
                }
            }

            Section("Note (optional)") {
                TextField("What's this for?", text: $viewModel.note)
                    .focused($focusedField, equals: .note)
            }

            if case .failed(let message) = viewModel.phase {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                    Button("Try again") { viewModel.reset() }
                }
            }

            Section {
                Button {
                    focusedField = nil
                    Task { await viewModel.submit() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isBusy {
                            ProgressView().controlSize(.small)
                            Text(viewModel.phase == .authenticating ? "Verifying…" : "Sending…")
                        } else {
                            Text("Confirm and send")
                        }
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit || viewModel.isBusy)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } footer: {
                Text("You'll confirm with Face ID, Touch ID or your passcode.")
            }
        }
        .onAppear { focusedField = .payee }
    }
}

private struct PaymentResultView: View {
    enum Style { case success, pending }

    let style: Style
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: style == .success ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 56))
                .foregroundStyle(style == .success ? Color.green : Color.orange)
                .accessibilityHidden(true)

            Text(title).font(.title2.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    SendPaymentView(
        viewModel: AppContainer.preview.makeSendPaymentViewModel(
            availableBalance: Money(minorUnits: 4_82_650)
        )
    )
}

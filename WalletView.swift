import SwiftUI

struct WalletView: View {
    @State private var viewModel: WalletViewModel
    @State private var isPresentingPayment = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeWalletViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("MiniWallet")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresentingPayment = true
                        } label: {
                            Label("Send money", systemImage: "arrow.up.circle.fill")
                        }
                        .disabled(viewModel.state.value == nil)
                    }
                }
                .task { await viewModel.load() }
                .refreshable { await viewModel.refresh() }
                .sheet(isPresented: $isPresentingPayment) {
                    SendPaymentView(
                        viewModel: container.makeSendPaymentViewModel(
                            availableBalance: viewModel.balance
                        )
                    )
                    .presentationDetents([.large])
                }
                .onChange(of: isPresentingPayment) { _, isPresented in
                    // Balance and history are stale once a payment is sent.
                    if !isPresented {
                        Task { await viewModel.refresh() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .loaded(let wallet):
            WalletContent(wallet: wallet)
        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
        }
    }
}

private struct WalletContent: View {
    let wallet: Wallet

    var body: some View {
        List {
            Section {
                BalanceCard(accountName: wallet.accountName, balance: wallet.balance)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("Recent activity") {
                if wallet.transactions.isEmpty {
                    Text("No transactions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(wallet.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your wallet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load your wallet", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    WalletView(container: .preview)
}

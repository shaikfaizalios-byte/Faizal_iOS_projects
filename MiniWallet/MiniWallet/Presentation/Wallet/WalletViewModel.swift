import Foundation
import Observation

/// `@Observable` (iOS 17+) rather than `ObservableObject`: SwiftUI tracks the
/// individual properties a view actually reads, so a view that only shows the
/// balance is not re-rendered when the transaction list changes.
///
/// `@MainActor` on the whole type means every mutation of published state is
/// main-thread by construction, enforced at compile time.
@MainActor
@Observable
final class WalletViewModel {
    private(set) var state: LoadState<Wallet> = .idle

    private let loadWallet: LoadWalletUseCase

    init(loadWallet: LoadWalletUseCase) {
        self.loadWallet = loadWallet
    }

    var balance: Money {
        state.value?.balance ?? .zero
    }

    var transactions: [Transaction] {
        state.value?.transactions ?? []
    }

    func load() async {
        // Don't restart an in-flight load when the view reappears.
        guard !state.isLoading else { return }
        state = .loading
        await fetch()
    }

    /// Pull-to-refresh keeps the current content on screen while refreshing,
    /// so the list does not flash empty.
    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            let wallet = try await loadWallet()
            state = .loaded(wallet)
        } catch is CancellationError {
            // The view went away; leaving the previous state is correct.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

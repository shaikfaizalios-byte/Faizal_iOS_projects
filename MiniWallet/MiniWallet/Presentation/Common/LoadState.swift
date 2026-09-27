import Foundation

/// Four states, not `isLoading: Bool` plus an optional error.
///
/// Booleans allow impossible combinations — loading and failed at the same
/// time — which is how "spinner stuck over an error message" ships. An enum
/// makes those states unrepresentable.
enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

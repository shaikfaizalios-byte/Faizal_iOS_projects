import Foundation
import LocalAuthentication

/// Wraps LocalAuthentication behind the domain's `PaymentAuthenticator`
/// protocol so the payment use case can be tested without a biometric prompt.
///
/// Policy choice: `.deviceOwnerAuthentication` rather than
/// `.deviceOwnerAuthenticationWithBiometrics`, so a user whose Face ID fails
/// or who has none enrolled can still confirm with the device passcode.
/// Biometric-only locks people out of their own money.
struct BiometricAuthenticator: PaymentAuthenticator {
    private let contextFactory: @Sendable () -> LAContext

    init(contextFactory: @escaping @Sendable () -> LAContext = { LAContext() }) {
        self.contextFactory = contextFactory
    }

    func authenticate(reason: String) async throws {
        let context = contextFactory()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw PaymentError.authenticationUnavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            guard success else { throw PaymentError.authenticationFailed }
        } catch let paymentError as PaymentError {
            throw paymentError
        } catch {
            throw PaymentError.authenticationFailed
        }
    }
}

/// Used by previews and tests.
struct AlwaysAllowAuthenticator: PaymentAuthenticator {
    func authenticate(reason: String) async throws {}
}

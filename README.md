# MiniWallet

A small iOS wallet app built to explore SwiftUI state management, Swift structured concurrency, and the correctness constraints that a payments UI actually has to satisfy.

It is deliberately not a to-do list with a currency symbol. The interesting parts are the ones that only matter when the thing on screen is someone's money.

## Screens

<!-- Add wallet.png, payment.png and confirmation.png to screenshots/ and these will render. -->
| Wallet | Send money | Confirmation |
| --- | --- | --- |
| ![Wallet](screenshots/wallet.png) | ![Send money](screenshots/payment.png) | ![Confirmation](screenshots/confirmation.png) |

## What it does

- Shows an account balance and recent transaction history, with pull-to-refresh and a privacy toggle on the balance
- Sends a payment behind Face ID / Touch ID / passcode confirmation
- Distinguishes **completed**, **pending** and **failed** payments rather than treating a payment as a boolean

## Design decisions worth reading

**Money is an integer, never a `Double`.** Amounts are held as minor units (paise). Binary floating point cannot represent 0.10 exactly, so `0.1 + 0.2 != 0.3` — a rounding error that is invisible in a shopping app and a defect in a payments one.

**Payments carry a client-generated idempotency key.** If a request times out, the client cannot know whether the server executed the debit. Retrying with the same key lets the server return the original result instead of debiting twice. The key is generated once when the screen opens, not per attempt — regenerating it on retry defeats the entire mechanism. `IdempotencyTests` is the test that proves it.

**An interrupted payment resolves to `pending`, never to failure.** The most dangerous thing a payment UI can do is tell the user a payment failed when the server actually processed it, because the user will send it again. The `PaymentOutcome` type has no "unknown failure" case that the UI can quietly render as an error.

**Authentication gates the debit, it does not follow it.** The ordering lives inside `SendPaymentUseCase`, so it is one testable rule rather than a property of how a button handler happens to be written. `test_doesNotSubmitWhenAuthenticationFails` asserts the network is never reached.

**Biometrics fall back to the passcode.** The policy is `.deviceOwnerAuthentication`, not `.deviceOwnerAuthenticationWithBiometrics`. Biometric-only locks people out of their own money when Face ID fails or is not enrolled.

**The window is covered when the app resigns active.** iOS snapshots the window for the app switcher; without the overlay in `MiniWalletApp`, the balance is visible to anyone who opens multitasking.

**Secrets go in the Keychain with `WhenUnlockedThisDeviceOnly`.** The item is unavailable while the device is locked and is not carried into a backup or migrated to a new device. For a payment credential, losing it on restore beats it travelling somewhere invisible.

**View state is an enum, not a bag of booleans.** `LoadState` has four cases, so "loading and failed simultaneously" — the state behind every stuck spinner over an error message — cannot be constructed.

**The repository is an `actor`.** Mutable ledger state is read from the main actor and written from background tasks. Making it an actor means the compiler proves there is no data race, rather than the race being something to test for.

## Architecture

```
Domain/        Models, repository protocols, use cases. No UIKit, no SwiftUI, no URLSession.
Data/          Networking, security (Keychain, LocalAuthentication), repository implementations.
Presentation/  SwiftUI views and @Observable view models.
App/           Composition root and app entry point.
```

Dependencies point inward: the domain defines the protocols and the data layer conforms to them. Nothing reaches for a singleton — `AppContainer` constructs everything and injects it downward, which is what makes the view models testable and lets previews run against a stub with no biometric prompt and no network.

## Tests

```
MoneyTests                 Parsing, boundaries, overflow, exact arithmetic
SendPaymentUseCaseTests    Validation, auth ordering, idempotency-key propagation
IdempotencyTests           A retry must not debit twice
WalletViewModelTests       Load states, validation, phase transitions
```

Run with `Cmd-U` in Xcode.

## Building it

Requires Xcode 15 or later (iOS 17 deployment target — the code uses `@Observable` and the two-parameter `onChange`).

1. Xcode → File → New → Project → iOS → App
2. Product Name **MiniWallet**, Interface **SwiftUI**, Language **Swift**, tick **Include Tests**
3. Delete the generated `ContentView.swift` and `MiniWalletApp.swift`
4. Drag the `MiniWallet/` folder from this archive into the app target, and `MiniWalletTests/` into the test target — choose **Create groups**, and tick the correct target for each
5. In the target's **Info** tab add `NSFaceIDUsageDescription` with a value such as *"MiniWallet uses Face ID to confirm payments."* — without it the app crashes the first time it requests biometrics
6. Build and run on a simulator; in the simulator, **Features → Face ID → Enrolled** so the confirmation prompt works

The repository is in-memory, so there is no backend to run.

## What is deliberately missing

Real networking (`APIClient` exists but nothing calls it yet), certificate pinning, offline persistence, and a settled/reconciliation flow for pending payments. These are the next things to build, not oversights.

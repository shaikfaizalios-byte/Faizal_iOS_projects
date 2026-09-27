import SwiftUI

@main
struct MiniWalletApp: App {
    @State private var container = AppContainer.live
    @Environment(\.scenePhase) private var scenePhase
    @State private var isObscured = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                WalletView(container: container)

                // App-switcher privacy.
                //
                // iOS snapshots the window when the app resigns active, and
                // that snapshot is shown in the multitasking switcher. Without
                // this the user's balance is visible to anyone who
                // double-clicks the home button. Covering the window while
                // inactive is the standard banking-app control.
                if isObscured {
                    PrivacyOverlay()
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isObscured = (phase != .active)
                }
            }
        }
    }
}

private struct PrivacyOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                Text("MiniWallet")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

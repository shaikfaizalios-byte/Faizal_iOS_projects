import SwiftUI

struct BalanceCard: View {
    let accountName: String
    let balance: Money

    @State private var isHidden = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(accountName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button {
                    withAnimation(.snappy) { isHidden.toggle() }
                } label: {
                    Image(systemName: isHidden ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityLabel(isHidden ? "Show balance" : "Hide balance")
            }

            Text(isHidden ? "••••••" : balance.formatted)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                // Dynamic Type is respected, but the balance is capped so a
                // large accessibility size cannot push it off the card.
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("Available balance")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accountName), available balance \(isHidden ? "hidden" : balance.formatted)")
    }
}

#Preview {
    BalanceCard(accountName: "Everyday Account", balance: Money(minorUnits: 4_82_650))
        .padding()
}

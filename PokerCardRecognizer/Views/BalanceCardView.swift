import SwiftUI

struct BalanceCardView: View {
    let balance: Decimal
    let isPositive: Bool

    @State private var displayedBalance: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Текущий баланс")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(Decimal(displayedBalance)))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    .linearGradient(
                        colors: isPositive ? [.green, .blue] : [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(isPositive ? "Прибыль" : "Убыток")
            }
            .font(.caption)
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .onAppear { animateBalance() }
    }

    private func animateBalance() {
        withAnimation(.easeOut(duration: 1.0)) {
            displayedBalance = Double(truncating: NSDecimalNumber(decimal: balance))
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0"
    }
}


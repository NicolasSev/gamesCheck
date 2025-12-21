import SwiftUI

struct StatisticsTabView: View {
    let statistics: UserStatistics?
    let gameTypeStats: [GameTypeStatistics]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let stats = statistics {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Баланс: \(formatCurrency(stats.currentBalance))")
                            .font(.headline)
                        Text("Buy-ins: \(formatCurrency(stats.totalBuyins)) • Cashouts: \(formatCurrency(stats.totalCashouts))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Text("По типам игр")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(gameTypeStats, id: \.gameType) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.gameType)
                                    .font(.headline)
                                Text("\(item.gamesCount) игр • WinRate \(Int(item.winRate * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatCurrency(item.totalProfit))
                                    .font(.headline)
                                    .foregroundColor(item.totalProfit >= 0 ? .green : .red)
                                Text("avg \(formatCurrency(item.averageProfit))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else {
                    ProgressView("Загрузка...")
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0"
    }
}


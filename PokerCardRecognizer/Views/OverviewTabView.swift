import SwiftUI

struct OverviewTabView: View {
    let statistics: UserStatistics?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let stats = statistics {
                    BalanceCardView(balance: stats.currentBalance, isPositive: stats.isPositive)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 15) {
                        StatCardView(
                            title: "Всего игр",
                            value: "\(stats.totalSessions)",
                            icon: "gamecontroller.fill",
                            color: .blue
                        )

                        StatCardView(
                            title: "Win Rate",
                            value: "\(Int(stats.winRate * 100))%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )

                        StatCardView(
                            title: "Лучшая сессия",
                            value: formatCurrency(stats.bestSession),
                            icon: "star.fill",
                            color: .yellow
                        )

                        StatCardView(
                            title: "Средний профит",
                            value: formatCurrency(stats.averageProfit),
                            icon: "dollarsign.circle.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Последние игры")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(stats.recentGames.prefix(5), id: \.gameId) { game in
                            GameRowView(game: game)
                        }
                    }
                    .padding(.vertical)
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


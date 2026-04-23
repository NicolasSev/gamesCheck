import SwiftUI

struct EquityGuesserSummaryView: View {
    let rounds: [EquityGuessRound]
    let totalScore: Int
    let bestStreak: Int
    let config: EquitySessionConfig

    private var mae: Double {
        guard !rounds.isEmpty else { return 0 }
        return rounds.map(\.delta).reduce(0, +) / Double(rounds.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Итог")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Очки: \(totalScore) · MAE: \(String(format: "%.2f", mae))% · стрик: \(bestStreak)")
                    .foregroundColor(.white.opacity(0.85))
                Text("Раундов: \(rounds.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .v2ScreenBackground()
    }
}

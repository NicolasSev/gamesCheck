import SwiftUI

struct GameRowView: View {
    let game: GameSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.gameType)
                        .font(.headline)

                    if game.isCreator {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(game.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(game.formattedProfit)
                    .font(.headline)
                    .foregroundColor(game.profit >= 0 ? .green : .red)

                Text("\(game.totalPlayers) игроков")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}


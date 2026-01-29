//
//  PlayerStatisticsRowBilliard.swift
//  PokerCardRecognizer
//
//  Created by Николас on 06.04.2025.
//


import SwiftUI
import CoreData

struct PlayerStatisticsRowBilliard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player
    var filteredGames: [Game]
    var onShowDetails: () -> Void

    var body: some View {
        let gamesForPlayer = filteredGames.filter { game in
            game.player1 == player || game.player2 == player
        }

        let allBatches = gamesForPlayer.flatMap { game in
            (game.billiardBatches as? Set<BilliardBatche>) ?? []
        }

        let totalBalls = allBatches.reduce(0) { sum, batch in
            let isPlayer1 = batch.game?.player1 == player
            return sum + Int(isPlayer1 ? batch.scorePlayer1 : batch.scorePlayer2)
        }

        let winCount = allBatches.reduce(0) { count, batch in
            let isPlayer1 = batch.game?.player1 == player
            let won = (isPlayer1 && batch.scorePlayer1 == 8) || (!isPlayer1 && batch.scorePlayer2 == 8)
            return count + (won ? 1 : 0)
        }

        if totalBalls == 0 && winCount == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name ?? "Без имени")
                    .font(.headline)
                Text("Выигранных партий: \(winCount)")
                Text("Всего забито шаров: \(totalBalls)")
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .contextMenu {
                Button(action: copyBilliardStatistics) {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
                Button(action: { onShowDetails() }) {
                    Label("Подробнее", systemImage: "info.circle")
                }
            }
        }
    }

    private func copyBilliardStatistics() {
        UIPasteboard.general.string = """
        \(player.name ?? "Без имени")
        Бильярд: Партии и шары рассчитаны
        """
    }
}

import SwiftUI
import CoreData

struct PlayerStatisticsRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player
    var filteredGames: [Game]
    var selectedDate: Date?
    var selectedGameType: GameType
    var onShowDetails: () -> Void

    var body: some View {
        let isBilliard = selectedGameType == .billiards

        if isBilliard {
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

        } else {
            let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
            let filtered = set.filter { gwp in
                guard let game = gwp.game else { return false }
                let isInFilteredGames = filteredGames.contains(where: { $0.objectID == game.objectID })

                if let selected = selectedDate {
                    if let timestamp = game.timestamp {
                        return isInFilteredGames && Calendar.current.isDate(timestamp, inSameDayAs: selected)
                    } else {
                        return false
                    }
                }

                return isInFilteredGames
            }

            if filtered.isEmpty {
                EmptyView()
            } else {
                let buyin = filtered.reduce(0) { $0 + Int($1.buyin) }
                let cashout = filtered.reduce(0) { $0 + Int($1.cashout) }
                let final = cashout - (buyin * 2000)
                let gamesCount = filtered.count

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name ?? "Без имени")
                        .font(.headline)

                    HStack {
                        Text("Сумма байинов: \(buyin)")
                        Spacer()
                        Text("Сумма кэшаутов: \(cashout)")
                    }

                    HStack {
                        Text("Участвовал(а): \(gamesCount)")
                        Spacer()
                        Text("Финальная сумма: \(final)")
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .contextMenu {
                    Button(action: copyPokerStatistics) {
                        Label("Копировать", systemImage: "doc.on.doc")
                    }
                    Button(action: { onShowDetails() }) {
                        Label("Подробнее", systemImage: "info.circle")
                    }
                }
            }
        }
    }

    private func copyPokerStatistics() {
        let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let filtered = set.filter { gwp in
            guard let game = gwp.game else { return false }
            return filteredGames.contains(where: { $0.objectID == game.objectID })
        }
        let buyin = filtered.reduce(0) { $0 + Int($1.buyin) }
        let cashout = filtered.reduce(0) { $0 + Int($1.cashout) }
        let final = cashout - (buyin * 2000)

        UIPasteboard.general.string = """
        \(player.name ?? "Без имени")
        Байины: \(buyin), Кэшауты: \(cashout), Финал: \(final)
        """
    }

    private func copyBilliardStatistics() {
        UIPasteboard.general.string = """
        \(player.name ?? "Без имени")
        Бильярд: Партии и шары рассчитаны
        """
    }
}

//
//  PlayerStatisticsRow.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.03.2025.
//
import SwiftUI
import CoreData

struct PlayerStatisticsRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var player: Player
    var selectedDate: Date?
    
    var onShowDetails: () -> Void
        
    // Фильтруем связи GameWithPlayer по дате, если selectedDate задан
    var filteredGameWithPlayers: [GameWithPlayer] {
        let set = (player.gameWithPlayers as? Set<GameWithPlayer>)?.filter { $0.game != nil } ?? []
        if let selected = selectedDate {
            return set.filter { gwp in
                if let timestamp = gwp.game?.timestamp {
                    return Calendar.current.isDate(timestamp, inSameDayAs: selected)
                }
                return false
            }
            .sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
        } else {
            return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
        }
    }
    
    // Количество игр, в которых участвовал игрок, по связи gameWithPlayers
    var gamesCount: Int {
        filteredGameWithPlayers.count
    }
    
    var totalBuyin: Int {
        filteredGameWithPlayers.reduce(0) { $0 + Int($1.buyin) }
    }
    
    var totalCashout: Int {
        filteredGameWithPlayers.reduce(0) { $0 + Int($1.cashout) }
    }
    
    // Финальная сумма: (сумма байинов * 2000) - сумма кэшаутов
    var finalValue: Int {
        return totalCashout - (totalBuyin * 2000)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Имя игрока
            Text(player.name ?? "Без имени")
                .font(.headline)
            
            // Вторая строка: слева сумма байинов, справа количество игр
            HStack {
                Text("Сумма байинов: \(totalBuyin)")
                Spacer()
                Text("Сумма кэшаутов: \(totalCashout)")
            }
            
            // Третья строка: слева сумма кэшаутов, справа финальная сумма
            HStack {
                Text("Участвовал(а): \(gamesCount)")
                Spacer()
                Text("Финальная сумма: \(finalValue)")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .onAppear {
            // Принудительно обновляем объект, чтобы UI увидел изменения
            print("filteredGameWithPlayers for \(player.name ?? "Без имени"):", filteredGameWithPlayers)
            viewContext.refresh(player, mergeChanges: true)
        }
        .contextMenu {
            Button(action: copyStatistics) {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            Button(action: {
                onShowDetails()
            }) {
                Label("Подробнее", systemImage: "info.circle")
            }
        }
    }
    
    private func copyStatistics() {
        let text = """
        \(player.name ?? "Без имени")
        Сумма байинов: \(totalBuyin)    Участвовал(а): \(gamesCount)
        Сумма кэшаутов: \(totalCashout)    Финальная сумма: \(finalValue)
        """
        UIPasteboard.general.string = text
    }
}

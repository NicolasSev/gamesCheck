import SwiftUI
import CoreData

struct PlayerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: Player
    var selectedDate: Date?
    
    // Фильтруем связи GameWithPlayer по выбранной дате и исключаем записи, где game == nil.
    var filteredGameWithPlayers: [GameWithPlayer] {
        let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let validSet = set.filter { $0.game != nil } // исключаем записи, где game равен nil
        if let selected = selectedDate {
            return validSet.filter { gwp in
                if let timestamp = gwp.game?.timestamp {
                    return Calendar.current.isDate(timestamp, inSameDayAs: selected)
                }
                return false
            }
            .sorted { ($0.game?.timestamp ?? Date()) > ($1.game?.timestamp ?? Date()) }
        } else {
            return validSet.sorted { ($0.game?.timestamp ?? Date()) > ($1.game?.timestamp ?? Date()) }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredGameWithPlayers) { gwp in
                VStack(alignment: .leading, spacing: 4) {
                    if let timestamp = gwp.game?.timestamp {
                        Text("Дата: \(formattedDate(from: timestamp))")
                            .font(.subheadline)
                    }
                    Text("Байины: \(gwp.buyin)")
                    Text("Кэшауты: \(gwp.cashout)")
                    Text("Финальная сумма: \(Int(gwp.cashout) - (Int(gwp.buyin) * 2000))")
                        .font(.footnote)
                        .bold(true)
                }
                .padding(4)
            }
            .navigationTitle("Об \(player.name ?? "Без имени")")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

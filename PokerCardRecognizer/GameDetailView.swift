import SwiftUI
import CoreData

// Структура для передачи элементов в лист шаринга.
// Делаем её Identifiable, чтобы использовать sheet(item:)
struct ShareData: Identifiable {
    let id = UUID()
    let items: [Any]
}

// Обёртка над UIActivityViewController для Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct GameDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: Game

    @State private var isAddPlayerSheetPresented = false
    @State private var showDeleteConfirmation = false

    // Вместо флагов и массивов используем один @State shareData
    @State private var shareData: ShareData?

    var gameWithPlayers: [GameWithPlayer] {
        let set = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }

    var body: some View {
        VStack {
            List {
                ForEach(gameWithPlayers, id: \.self) { gwp in
                    PlayerRow(
                        gameWithPlayer: gwp,
                        updateBuyIn: updateBuyIn,
                        setCashout: setCashout
                    )
                }
                .onDelete(perform: removeGameWithPlayer)
            }

            // Кнопка "Отправить статистику"
            Button(action: shareStatistics) {
                Text("Отправить статистику по игре")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle("Детали игры")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Кнопка "Добавить игрока"
                Button {
                    isAddPlayerSheetPresented = true
                } label: {
                    Label("Добавить игрока", systemImage: "person.fill.badge.plus")
                }
                // Кнопка "Удалить игру"
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Удалить игру", systemImage: "trash")
                }
            }
        }
        // Лист добавления игроков
        .sheet(isPresented: $isAddPlayerSheetPresented) {
            AddPlayerToGameSheet(game: game, isPresented: $isAddPlayerSheetPresented)
                .environment(\.managedObjectContext, viewContext)
        }
        // Лист шаринга - вызывается только если shareData != nil
        .sheet(item: $shareData) { data in
            ShareSheet(activityItems: data.items)
        }
        .alert("Удалить игру?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                deleteGame()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Вы уверены, что хотите удалить игру и все связанные данные?")
        }
    }

    private func updateBuyIn(for gwp: GameWithPlayer, change: Int16) {
        let newBuyIn = gwp.buyin + change
        if newBuyIn >= 0 {
            gwp.buyin = newBuyIn
            saveContext()
        }
    }

    private func setCashout(for gwp: GameWithPlayer, value: Int64) {
        gwp.cashout = value
        saveContext()
    }

    private func removeGameWithPlayer(at offsets: IndexSet) {
        for index in offsets {
            let gwp = gameWithPlayers[index]
            viewContext.delete(gwp)
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
            game.objectWillChange.send()
        } catch {
            print("Ошибка сохранения: \(error.localizedDescription)")
        }
    }

    /// Собирает статистику игры в виде строки
    private func buildStatistics() -> String {
        var message = "Статистика игры:\n"
        if let timestamp = game.timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message += "Дата игры: \(formatter.string(from: timestamp))\n"
        }
        for gwp in gameWithPlayers {
            let playerName = gwp.player?.name ?? "Без имени"
            message += "\(playerName): Buy-in: \(gwp.buyin), Cashout: \(gwp.cashout)\n"
        }
        return message
    }

    /// Создаёт временный файл со статистикой и назначает shareData
    private func shareStatistics() {
        let message = buildStatistics()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("statistics_\(UUID().uuidString).txt")
        do {
            try message.write(to: fileURL, atomically: true, encoding: .utf8)
            // Считываем данные из файла для проверки
            let data = try Data(contentsOf: fileURL)
            print("Файл записан, размер: \(data.count) байт")

            // Создаём объект ShareData
            shareData = ShareData(items: [fileURL])
            // При присвоении shareData, SwiftUI автоматически вызывает sheet(item:)
        } catch {
            print("Ошибка записи файла статистики: \(error.localizedDescription)")
        }
    }
    
    /// Удаляет игру и связанные с ней данные, затем закрывает экран
    private func deleteGame() {
        // Если отношения настроены без каскадного удаления, можно удалить все связи вручную:
        if let set = game.gameWithPlayers as? Set<GameWithPlayer> {
            for gwp in set {
                viewContext.delete(gwp)
            }
        }
        viewContext.delete(game)
        saveContext()
        dismiss()
    }
}

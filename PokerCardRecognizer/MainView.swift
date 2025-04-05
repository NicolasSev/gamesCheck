import SwiftUI
import CoreData

enum SortOption: String, CaseIterable, Identifiable {
    case byFinal = "Тотал"
    case byName = "Имя"
    case byBuyin = "Байин"
    case byGamesCount = "Игры"
    case byCashout = "Кэшаут"
    
    
    var id: String { self.rawValue }
}

// Обёртка над UIActivityViewController (Share Sheet)
struct ShareContentViewSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// Объект для передачи данных в Share Sheet
struct ShareContentViewData: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var authViewModel: AuthViewModel
    
    // Список игр (новейшие первыми)
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)])
    private var games: FetchedResults<Game>

    // Глобальный список игроков (по имени)
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)])
    private var allPlayers: FetchedResults<Player>

    @State private var isAddPlayerSheetPresented = false
    @State private var isAddGameSheetPresented = false
    @State private var isCameraSheetPresented = false
    @State private var selectedDate: Date? = nil

    @State private var sortOption: SortOption = .byFinal
    
    // Свойство для передачи данных в Share Sheet
    @State private var shareData: ShareContentViewData?
    
    // Новое состояние для выбранного игрока (детали)
    @State private var selectedPlayerForDetails: Player? = nil
    
    // MARK: - Сортировка
    private var sortedPlayers: [Player] {
        let playersArray = Array(allPlayers)
        switch sortOption {
        case .byName:
            return playersArray.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .byBuyin:
            return playersArray.sorted {
                let buyin0 = totalBuyin($0, filtered: true)
                let buyin1 = totalBuyin($1, filtered: true)
                return buyin0 > buyin1
            }
        case .byGamesCount:
            return playersArray.sorted {
                let count0 = filteredGameWithPlayers(for: $0).count
                let count1 = filteredGameWithPlayers(for: $1).count
                return count0 > count1
            }
        case .byCashout:
            return playersArray.sorted {
                let cashout0 = totalCashout($0, filtered: true)
                let cashout1 = totalCashout($1, filtered: true)
                return cashout0 > cashout1
            }
        case .byFinal:
            return playersArray.sorted {
                let final0 = totalCashout($0, filtered: true) - (totalBuyin($0, filtered: true) * 2000)
                let final1 = totalCashout($1, filtered: true) - (totalBuyin($1, filtered: true) * 2000)
                return final0 > final1
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Календарь
                    CalendarView(games: games, selectedDate: $selectedDate)
                        .padding(.horizontal)
                    
                    // Секция "Статистика всех игр"
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Статистика всех игр")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)

                        // Picker для сортировки статистики
                        Picker("Сортировать по", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)

                        if sortedPlayers.isEmpty {
                            Text("Нет данных")
                                .padding()
                        } else {
                            ForEach(sortedPlayers) { player in
                                // PlayerStatisticsRow тоже использует filteredGameWithPlayers(for:)
                                PlayerStatisticsRow(player: player, selectedDate: selectedDate, onShowDetails: {
                                        selectedPlayerForDetails = player
                                    })
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Кнопка "Отправить статистику"
                        Button(action: shareAllStatistics) {
                            Text("Отправить статистику")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Игры")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { isCameraSheetPresented = true }) {
                        Label("Камера", systemImage: "camera.fill")
                    }
                    Button(action: { isAddPlayerSheetPresented = true }) {
                        Label("Добавить игрока", systemImage: "person.fill.badge.plus")
                    }
                    Button(action: { isAddGameSheetPresented = true }) {
                        Label("Добавить игру", systemImage: "plus")
                    }
                    Button(action: { authViewModel.signOut()}) {
                        Label("Выйти", systemImage: "power")
                    }
                }
            }
            .sheet(isPresented: $isCameraSheetPresented) {
                CameraView()
            }
            .sheet(isPresented: $isAddPlayerSheetPresented) {
                AddPlayerSheet(isPresented: $isAddPlayerSheetPresented)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $isAddGameSheetPresented) {
                AddGameSheet(isPresented: $isAddGameSheetPresented)
                    .environment(\.managedObjectContext, viewContext)
            }
            // Sheet для деталей игрока
            .sheet(item: $selectedPlayerForDetails) { player in
                PlayerDetailSheet(player: player, selectedDate: selectedDate)
                    .environment(\.managedObjectContext, viewContext)
            }
            // Share Sheet (когда shareData != nil)
            .sheet(item: $shareData) { data in
                ShareSheet(activityItems: data.items)
            }
        }
    }
    
    // MARK: - Формирование текста для отправки
    private func shareAllStatistics() {
        let stats = buildGlobalStatistics()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("global_statistics_\(UUID().uuidString).txt")
        do {
            try stats.write(to: fileURL, atomically: true, encoding: .utf8)
            shareData = ShareContentViewData(items: [fileURL])
        } catch {
            print("Ошибка записи статистики: \(error.localizedDescription)")
        }
    }
    
    private func buildGlobalStatistics() -> String {
        var message = "Статистика игр:\n"
        if let selected = selectedDate {
            message += "Дата: \(formatDate(selected))\n"
        } else {
            message += "Дата: все даты\n"
        }
        for player in sortedPlayers {
            let filteredSet = filteredGameWithPlayers(for: player)
            let count = filteredSet.count
            let totalBuyin = filteredSet.reduce(0) { $0 + Int($1.buyin) }
            let totalCashout = filteredSet.reduce(0) { $0 + Int($1.cashout) }
            let final = totalCashout - (totalBuyin * 2000)
            
            message += "\(player.name ?? "Без имени"): байины: \(totalBuyin), кэшауты: \(totalCashout), игр: \(count), финальная сумма: \(final)\n"
        }
        return message
    }
    
    // MARK: - Фильтрация по выбранной дате (как в PlayerStatisticsRow)
    private func filteredGameWithPlayers(for player: Player) -> [GameWithPlayer] {
        let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
        if let selected = selectedDate {
            return set.filter { gwp in
                if let timestamp = gwp.game?.timestamp {
                    return Calendar.current.isDate(timestamp, inSameDayAs: selected)
                }
                return false
            }.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
        } else {
            return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
        }
    }
    
    private func totalBuyin(_ player: Player, filtered: Bool) -> Int {
        if filtered, let selected = selectedDate {
            // Фильтруем
            return filteredGameWithPlayers(for: player).reduce(0) { $0 + Int($1.buyin) }
        } else {
            // Без фильтра
            let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
            return set.reduce(0) { $0 + Int($1.buyin) }
        }
    }
    
    private func totalCashout(_ player: Player, filtered: Bool) -> Int {
        if filtered, let selected = selectedDate {
            return filteredGameWithPlayers(for: player).reduce(0) { $0 + Int($1.cashout) }
        } else {
            let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
            return set.reduce(0) { $0 + Int($1.cashout) }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения: \(error.localizedDescription)")
        }
    }
}

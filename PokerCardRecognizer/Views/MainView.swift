// MainView.swift — версия с поддержкой одиночной даты и периода

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

enum GameTypeFilter: String, CaseIterable, Identifiable {
    case poker = "Покер"
    case billiard = "Бильярд"

    var id: String { self.rawValue }
}

struct ShareContentViewData: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var authViewModel: AuthViewModel

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)])
    private var games: FetchedResults<Game>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)])
    private var allPlayers: FetchedResults<Player>

    @State private var isAddPlayerSheetPresented = false
    @State private var isAddGameSheetPresented = false
    @State private var isCameraSheetPresented = false

    @State private var selectedDate: Date? = nil
    @State private var dateRange: ClosedRange<Date>? = nil

    @State private var sortOption: SortOption = .byFinal
    @State private var shareData: ShareContentViewData?
    @State private var selectedPlayerForDetails: Player? = nil
    @State private var selectedGameType: GameTypeFilter = .poker

    @State private var periodStart: Date? = nil
    @State private var periodEnd: Date? = nil

    private var filteredGames: [Game] {
        games.filter { game in
            let type = game.gameType?.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesType = selectedGameType == .billiard
                ? type == GameTypeFilter.billiard.rawValue
                : type != GameTypeFilter.billiard.rawValue

            let matchesDate: Bool
            if let start = periodStart, let end = periodEnd, let timestamp = game.timestamp {
                matchesDate = (start...end).contains(timestamp)
            } else if let selected = selectedDate {
                matchesDate = Calendar.current.isDate(game.timestamp ?? Date(), inSameDayAs: selected)
            } else {
                matchesDate = true
            }

            return matchesType && matchesDate
        }
    }

    private var sortedPlayers: [Player] {
        let playersArray = Array(allPlayers)

        func filteredGameWithPlayers(for player: Player) -> [GameWithPlayer] {
            let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
            return set.filter { gwp in
                guard let game = gwp.game else { return false }
                return filteredGames.contains(where: { $0.objectID == game.objectID })
            }
        }

        switch sortOption {
        case .byName:
            return playersArray.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .byBuyin:
            return playersArray.sorted {
                filteredGameWithPlayers(for: $0).reduce(0) { $0 + Int($1.buyin) } >
                filteredGameWithPlayers(for: $1).reduce(0) { $0 + Int($1.buyin) }
            }
        case .byCashout:
            return playersArray.sorted {
                filteredGameWithPlayers(for: $0).reduce(0) { $0 + Int($1.cashout) } >
                filteredGameWithPlayers(for: $1).reduce(0) { $0 + Int($1.cashout) }
            }
        case .byGamesCount:
            return playersArray.sorted {
                filteredGameWithPlayers(for: $0).count > filteredGameWithPlayers(for: $1).count
            }
        case .byFinal:
            return playersArray.sorted {
                let g0 = filteredGameWithPlayers(for: $0)
                let g1 = filteredGameWithPlayers(for: $1)
                let f0 = g0.reduce(0) { $0 + Int($1.cashout) } - g0.reduce(0) { $0 + Int($1.buyin) } * 2000
                let f1 = g1.reduce(0) { $0 + Int($1.cashout) } - g1.reduce(0) { $0 + Int($1.buyin) } * 2000
                return f0 > f1
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Тип игры", selection: $selectedGameType) {
                        ForEach(GameTypeFilter.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    CalendarView(
                        games: filteredGames,
                        selectedDate: $selectedDate,
                        periodStart: $periodStart,
                        periodEnd: $periodEnd
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Статистика всех игр")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        if selectedGameType == .poker {
                            Picker("Сортировать по", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                        }
                        

                        if sortedPlayers.isEmpty {
                            Text("Нет данных").padding()
                        } else {
                            ForEach(sortedPlayers) { player in
                                PlayerStatisticsRow(
                                    player: player,
                                    filteredGames: filteredGames,
                                    selectedDate: selectedDate,
                                    selectedGameType: selectedGameType,
                                    onShowDetails: {
                                        selectedPlayerForDetails = player
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }

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
                    Button(action: { authViewModel.signOut() }) {
                        Label("Выйти", systemImage: "power")
                    }
                }
            }
            .sheet(isPresented: $isCameraSheetPresented) { CameraView() }
            .sheet(isPresented: $isAddPlayerSheetPresented) {
                AddPlayerSheet(isPresented: $isAddPlayerSheetPresented)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $isAddGameSheetPresented) {
                AddGameSheet(isPresented: $isAddGameSheetPresented)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedPlayerForDetails) { player in
                PlayerDetailSheet(player: player, selectedDate: selectedDate)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $shareData) { data in
                ShareSheet(activityItems: data.items)
            }
        }
    }

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
        } else if let range = dateRange {
            message += "Период: \(formatDate(range.lowerBound)) - \(formatDate(range.upperBound))\n"
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

    private func filteredGameWithPlayers(for player: Player) -> [GameWithPlayer] {
        let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let array = Array(set)

        return array.filter { gwp in
            guard let game = gwp.game else { return false }
            return filteredGames.contains(where: { $0.objectID == game.objectID })
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

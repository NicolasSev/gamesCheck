import SwiftUI
import CoreData

/// Страница профиля игрока для суперадмина. Сразу список с мультиселектом (как при импорте).
struct PlayerProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedPlayerNames: Set<String> = []
    /// Имена, по которым сейчас показан профиль (1 или несколько для объединённой статистики)
    @State private var selectedPlayerNamesForProfile: [String] = []
    @State private var selectedPlayerName: String? = nil
    @State private var playerNames: [String] = []
    @State private var isLoading = true
    @State private var statistics: UserStatistics? = nil
    @State private var games: [Game] = []
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    
    private let persistence = PersistenceController.shared
    
    private var backgroundGroup: some View {
        Group {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.4), Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let selectedName = selectedPlayerName {
                    OverviewTabView(
                        statistics: statistics,
                        games: games,
                        authViewModel: nil,
                        selectedPlayerNameForStats: selectedName,
                        selectedPlayerNamesForStats: selectedPlayerNamesForProfile.isEmpty ? nil : selectedPlayerNamesForProfile,
                        onRefresh: {
                            if !selectedPlayerNamesForProfile.isEmpty {
                                loadPlayerStats(for: selectedPlayerNamesForProfile)
                            }
                        },
                        onPlayerSelected: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Как на "Обзор": ScrollView + контент + .background, без ZStack/VStack-обёрток
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Выберите одного или нескольких игроков")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            if isLoading {
                                ProgressView("Загрузка...")
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else if playerNames.isEmpty {
                                Text("Нет игроков в базе")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                ForEach(playerNames, id: \.self) { playerName in
                                    Button(action: {
                                        if selectedPlayerNames.contains(playerName) {
                                            selectedPlayerNames.remove(playerName)
                                        } else {
                                            selectedPlayerNames.insert(playerName)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedPlayerNames.contains(playerName) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(selectedPlayerNames.contains(playerName) ? .blue : .white.opacity(0.6))
                                                .font(.system(size: 22))
                                            
                                            Text(playerName)
                                                .font(.body)
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if selectedPlayerNames.contains(playerName) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 18))
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                }
                            }
                            
                            if !selectedPlayerNames.isEmpty {
                                Button(action: {
                                    let names = Array(selectedPlayerNames).sorted()
                                    selectedPlayerNamesForProfile = names
                                    selectedPlayerName = names.count == 1 ? names[0] : "Несколько (\(names.count))"
                                    loadPlayerStats(for: names)
                                }) {
                                    HStack {
                                        Image(systemName: "chart.bar.fill")
                                        Text("Смотреть профиль")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical)
                    }
                    .frame(maxWidth: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(backgroundGroup)
                }
            }
            .navigationTitle("Профиль игрока")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedPlayerName != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            selectedPlayerName = nil
                            selectedPlayerNamesForProfile = []
                            selectedPlayerNames = []
                            statistics = nil
                            games = []
                        }) {
                            Text("Сменить игрока")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .onAppear {
                if selectedPlayerName == nil && playerNames.isEmpty {
                    loadPlayerNames()
                }
            }
        }
    }
    
    private func loadPlayerNames() {
        isLoading = true
        let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["player"]
        
        do {
            let allGWP = try viewContext.fetch(fetchRequest)
            var uniqueNames = Set<String>()
            for gwp in allGWP {
                if let player = gwp.player, let name = player.name, !name.isEmpty {
                    uniqueNames.insert(name)
                }
            }
            playerNames = Array(uniqueNames).sorted()
        } catch {
            print("❌ [PlayerProfileView] Error loading player names: \(error)")
            playerNames = []
        }
        isLoading = false
    }
    
    private func loadPlayerStats(for playerNames: [String]) {
        guard !playerNames.isEmpty else { return }
        // Сразу обнуляем, чтобы не показывать старые данные при смене игрока
        games = []
        statistics = nil

        let namesSet = Set(playerNames.map { $0.lowercased() })
        let gamesFetch: NSFetchRequest<Game> = Game.fetchRequest()
        gamesFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let allGames = try viewContext.fetch(gamesFetch)

            // Игры, где участвовал хотя бы один из выбранных игроков
            games = allGames.filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return namesSet.contains(name.lowercased())
                }
            }

            statistics = calculatePlayerStatistics(playerNames: playerNames, games: games)
        } catch {
            print("❌ Error loading games: \(error)")
        }
    }
    
    /// Объединённая статистика по одному или нескольким игрокам. Выбор нескольких имён увеличивает выборку.
    private func calculatePlayerStatistics(playerNames: [String], games: [Game]) -> UserStatistics {
        let namesSet = Set(playerNames.map { $0.lowercased() })
        var totalBuyinsRaw: Decimal = 0
        var totalCashoutsRaw: Decimal = 0
        var sessionsCount = 0
        var mvpCount = 0
        var bestSession: Decimal = 0
        var worstSession: Decimal = 0
        var sessionProfits: [Decimal] = []
        var profitByType: [String: Decimal] = [:]
        var recentGames: [GameSummary] = []

        for game in games {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            // Участия выбранных игроков в этой игре (в одной игре может быть несколько выбранных)
            let myParticipations = participations.filter { gwp in
                guard let player = gwp.player, let name = player.name else { return false }
                return namesSet.contains(name.lowercased())
            }

            let maxProfitInGame = participations.map { gwp in
                Decimal(Int(gwp.cashout)) - (Decimal(Int(gwp.buyin)) * 2000)
            }.max() ?? 0

            for myParticipation in myParticipations {
                let buyin = Decimal(Int(myParticipation.buyin))
                let cashout = Decimal(Int(myParticipation.cashout))
                let profit = cashout - (buyin * 2000)

                totalBuyinsRaw += buyin
                totalCashoutsRaw += cashout
                sessionsCount += 1
                sessionProfits.append(profit)

                if let gameType = game.gameType {
                    profitByType[gameType, default: 0] += profit
                }

                if profit == maxProfitInGame {
                    mvpCount += 1
                }
                if profit > bestSession {
                    bestSession = profit
                }

                if recentGames.count < 20 {
                    recentGames.append(GameSummary(
                        gameId: game.gameId,
                        gameType: game.gameType ?? "Покер",
                        timestamp: game.timestamp ?? Date(),
                        totalPlayers: participations.count,
                        myBuyin: buyin,
                        myCashout: cashout,
                        profit: profit,
                        isCreator: false
                    ))
                }
            }
        }

        worstSession = sessionProfits.min() ?? 0
        let currentBalance = totalCashoutsRaw - (totalBuyinsRaw * 2000)
        let winRate = sessionsCount > 0 ? Double(sessionProfits.filter { $0 > 0 }.count) / Double(sessionsCount) : 0
        let averageProfit = sessionsCount > 0 ? currentBalance / Decimal(sessionsCount) : 0

        return UserStatistics(
            totalGamesCreated: 0,
            totalGamesParticipated: sessionsCount,
            totalBuyins: totalBuyinsRaw,
            totalCashouts: totalCashoutsRaw,
            currentBalance: currentBalance,
            winRate: winRate,
            profitByGameType: profitByType,
            recentGames: recentGames,
            bestSession: bestSession,
            worstSession: worstSession,
            averageProfit: averageProfit,
            totalSessions: sessionsCount,
            mvpCount: mvpCount
        )
    }
}

/// Sheet для выбора игрока (профиль игрока суперадмина). Список — все уникальные playerName из GWP.
struct PlayerProfileSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let onPlayerSelected: (String) -> Void
    
    @State private var playerNames: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Загрузка...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if playerNames.isEmpty {
                    Text("Нет игроков в базе")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(playerNames, id: \.self) { playerName in
                            Button(action: {
                                onPlayerSelected(playerName)
                                dismiss()
                            }) {
                                HStack {
                                    Text(playerName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Выберите игрока")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPlayerNames()
            }
        }
    }
    
    private func loadPlayerNames() {
        isLoading = true
        let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["player"]
        
        do {
            let allGWP = try viewContext.fetch(fetchRequest)
            var uniqueNames = Set<String>()
            
            for gwp in allGWP {
                if let player = gwp.player, let name = player.name, !name.isEmpty {
                    uniqueNames.insert(name)
                }
            }
            
            playerNames = Array(uniqueNames).sorted()
        } catch {
            print("❌ [PlayerProfileSelectionSheet] Error loading player names: \(error)")
            playerNames = []
        }
        isLoading = false
    }
}

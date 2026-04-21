import SwiftUI
import CoreData

struct StatisticsTabView: View {
    let statistics: UserStatistics?
    let gameTypeStats: [GameTypeStatistics]
    let topAnalytics: TopAnalytics?
    let chartData: [(date: Date, buyin: Decimal, gameId: UUID)]

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var equityGuesserStats: EquityGuesserUserStatsRow?
    @State private var equityGuesserLoading = false
    
    @State private var selectedGame: Game?
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // График байинов по датам
                    if !chartData.isEmpty {
                        Text("График байинов по датам")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        BuyinsChartView(data: chartData, formatCurrency: { $0.formatCurrency() })
                            .padding(.bottom, 8)
                    }

                    if equityGuesserLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else if let eg = equityGuesserStats, (eg.total_sessions ?? 0) > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Тренажёр эквити")
                                .font(.headline)
                                .foregroundColor(.white)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                equityStatCell(title: "Сессий", value: "\(eg.total_sessions ?? 0)")
                                equityStatCell(title: "Раундов", value: "\(eg.total_rounds ?? 0)")
                                equityStatCell(
                                    title: "MAE",
                                    value: eg.overall_mae != nil
                                        ? String(format: "%.2f%%", eg.overall_mae!)
                                        : "—"
                                )
                                equityStatCell(title: "Лучший стрик", value: "\(eg.best_streak ?? 0)")
                            }

                            NavigationLink {
                                EquityGuesserLobbyView()
                            } label: {
                                HStack {
                                    Image(systemName: "scope")
                                    Text("Играть ещё")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.casinoAccentGreen)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                    }
                    
                    // Топовая аналитика
                    if let analytics = topAnalytics {
                            Text("Топовая аналитика")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                // Самый большой выигрыш
                                if let biggestWin = analytics.biggestWin {
                                    TopRecordCard(
                                        title: "Самый большой выигрыш",
                                        icon: "arrow.up.circle.fill",
                                        color: .green,
                                        record: biggestWin,
                                        formatValue: { $0.formatCurrency() },
                                        onTap: {
                                            if let gameId = biggestWin.gameId {
                                                selectedGame = persistence.fetchGame(byId: gameId)
                                            }
                                        }
                                    )
                                }
                                
                                // Самый большой проигрыш
                                if let biggestLoss = analytics.biggestLoss {
                                    TopRecordCard(
                                        title: "Самый большой проигрыш",
                                        icon: "arrow.down.circle.fill",
                                        color: .red,
                                        record: biggestLoss,
                                        formatValue: { $0.formatCurrency() },
                                        onTap: {
                                            if let gameId = biggestLoss.gameId {
                                                selectedGame = persistence.fetchGame(byId: gameId)
                                            }
                                        }
                                    )
                                }
                                
                                // Самое большое количество байинов
                                if let maxBuyins = analytics.maxBuyins {
                                    TopRecordCard(
                                        title: "Самое большое количество байинов",
                                        icon: "creditcard.fill",
                                        color: .blue,
                                        record: maxBuyins,
                                        formatValue: { $0.formatCurrency() },
                                        onTap: {
                                            if let gameId = maxBuyins.gameId {
                                                selectedGame = persistence.fetchGame(byId: gameId)
                                            }
                                        }
                                    )
                                }
                                
                                // Самая дорогая игра
                                if let mostExpensiveGame = analytics.mostExpensiveGame {
                                    TopRecordCard(
                                        title: "Самая дорогая игра",
                                        icon: "banknote.fill",
                                        color: .orange,
                                        record: mostExpensiveGame,
                                        formatValue: { $0.formatCurrency() },
                                        onTap: {
                                            if let gameId = mostExpensiveGame.gameId {
                                                selectedGame = persistence.fetchGame(byId: gameId)
                                            }
                                        }
                                    )
                                }
                                
                                // Самый длинный винстрик
                                if let winStreak = analytics.longestWinStreak {
                                    StreakCard(
                                        title: "Самый длинный винстрик",
                                        icon: "flame.fill",
                                        color: .green,
                                        streak: winStreak,
                                        onTap: {
                                            selectedGame = findGameForStreak(winStreak)
                                        }
                                    )
                                }
                                
                                // Самый длинный феилстрик
                                if let loseStreak = analytics.longestLoseStreak {
                                    StreakCard(
                                        title: "Самый длинный феилстрик",
                                        icon: "exclamationmark.triangle.fill",
                                        color: .red,
                                        streak: loseStreak,
                                        onTap: {
                                            selectedGame = findGameForStreak(loseStreak)
                                        }
                                    )
                                }
                            }
                    } else {
                        ProgressView("Загрузка...")
                            .tint(.white)
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .casinoBackground()
            .task(id: authViewModel.currentUserId) {
                await refreshEquityGuesserStats()
            }
            .refreshable {
                await refreshEquityGuesserStats()
            }
        .sheet(item: Binding(
            get: { selectedGame },
            set: { selectedGame = $0 }
        )) { game in
            GameDetailView(game: game)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
    }

    private func equityStatCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func refreshEquityGuesserStats() async {
        equityGuesserStats = nil
        guard authViewModel.currentUserId != nil else {
            equityGuesserLoading = false
            return
        }
        equityGuesserLoading = true
        defer { equityGuesserLoading = false }
        guard await SupabaseService.shared.isAvailable() else { return }
        do {
            equityGuesserStats = try await SupabaseService.shared.fetchEquityGuesserUserStats()
        } catch {
            debugLog("StatisticsTabView: equity guesser stats — \(error.localizedDescription)")
        }
    }

    private func findGameForStreak(_ streak: StreakRecord) -> Game? {
        // Ищем игру по дате (используем startDate) и имени игрока
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: streak.startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        guard let games = try? viewContext.fetch(request) else { return nil }
        
        // Если есть имя игрока, фильтруем игры по этому игроку
        if let playerName = streak.playerName {
            for game in games {
                let gameWithPlayers = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                if gameWithPlayers.contains(where: { $0.player?.name?.caseInsensitiveCompare(playerName) == .orderedSame }) {
                    return game
                }
            }
        }
        
        // Если не нашли по имени, возвращаем первую игру за эту дату
        return games.first
    }
}

// Компонент для отображения топовой записи
struct TopRecordCard: View {
    let title: String
    let icon: String
    let color: Color
    let record: TopRecord
    let formatValue: (Decimal) -> String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Сумма:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(formatValue(record.value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                HStack {
                    Text("Игрок:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(record.playerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Text("Дата:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(record.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
        .onTapGesture {
            onTap()
        }
    }
}

// Компонент для отображения стрика
struct StreakCard: View {
    let title: String
    let icon: String
    let color: Color
    let streak: StreakRecord
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 6) {
                if let playerName = streak.playerName {
                    HStack {
                        Text("Игрок:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(playerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                
                HStack {
                    Text("Длина:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(streak.length) игр")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                HStack {
                    Text("Период:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(streak.formattedPeriod)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
        .onTapGesture {
            onTap()
        }
    }
}

// Компонент для отображения эффективности игрока
struct EfficiencyCard: View {
    let title: String
    let icon: String
    let color: Color
    let record: TopRecord
    let formatValue: (Decimal) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Профит:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(formatValue(record.value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(record.value >= 0 ? .green : .red)
                }
                
                if let efficiency = record.efficiency {
                    HStack {
                        Text("Эффективность:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(String(format: "%.2f", Double(truncating: NSDecimalNumber(decimal: efficiency * 100))))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(color)
                    }
                }
                
                HStack {
                    Text("Игрок:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(record.playerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                if record.gameId != nil {
                    HStack {
                        Text("Дата:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(record.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    HStack {
                        Text("Период:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("За все время")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}

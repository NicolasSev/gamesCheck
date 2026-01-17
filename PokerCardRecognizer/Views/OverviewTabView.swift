import SwiftUI
import CoreData

struct OverviewTabView: View {
    let statistics: UserStatistics?
    let games: [Game]
    var authViewModel: AuthViewModel? = nil
    let onRefresh: (() -> Void)?
    var onPlayerSelected: ((UUID?, String?) -> Void)? = nil
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared
    @State private var animationId = UUID() // Идентификатор для перезапуска анимации
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    @State private var expandedYears: Set<Int> = [] // Отслеживаем раскрытые годы
    @State private var expandedMonths: Set<String> = [] // Отслеживаем раскрытые месяцы
    @State private var selectedPlayerId: UUID? = nil // Выбранный игрок для супер админа
    @State private var selectedPlayerName: String? = nil // Выбранный игрок по имени (если не привязан к пользователю)
    @State private var allPlayerNames: [(name: String, userId: UUID?, isLinked: Bool)] = []
    
    private var isSuperAdmin: Bool {
        authViewModel?.currentUser?.isSuperAdmin ?? false
    }
    
    // Получаем userId для вычисления профита (выбранный игрок для супер админа или текущий пользователь)
    private var targetUserId: UUID? {
        if isSuperAdmin, let selectedId = selectedPlayerId {
            return selectedId
        }
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Селектор игроков для супер админа
                    if isSuperAdmin {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Выбрать игрока")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Picker("Игрок", selection: Binding(
                                get: {
                                    if let playerId = selectedPlayerId {
                                        return "user_\(playerId.uuidString)"
                                    } else if let playerName = selectedPlayerName {
                                        return "name_\(playerName)"
                                    }
                                    return "all"
                                },
                                set: { (newValue: String) in
                                    if newValue == "all" {
                                        selectedPlayerId = nil
                                        selectedPlayerName = nil
                                        onPlayerSelected?(nil, nil)
                                    } else if newValue.hasPrefix("user_") {
                                        let uuidString = String(newValue.dropFirst(5))
                                        if let uuid = UUID(uuidString: uuidString) {
                                            selectedPlayerId = uuid
                                            selectedPlayerName = nil
                                            onPlayerSelected?(uuid, nil)
                                        }
                                    } else if newValue.hasPrefix("name_") {
                                        let name = String(newValue.dropFirst(5))
                                        selectedPlayerId = nil
                                        selectedPlayerName = name
                                        onPlayerSelected?(nil, name) // Передаем имя игрока
                                    }
                                }
                            )) {
                                Text("Все игроки").tag("all")
                                ForEach(allPlayerNames, id: \.name) { playerInfo in
                                    HStack {
                                        Text(playerInfo.name)
                                        if playerInfo.isLinked {
                                            Image(systemName: "person.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        }
                                    }
                                    .tag(playerInfo.userId != nil ? "user_\(playerInfo.userId!.uuidString)" : "name_\(playerInfo.name)")
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.white)
                            .padding()
                            .liquidGlass(cornerRadius: 12)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    if let stats = statistics {
                        BalanceCardView(balance: stats.currentBalance, isPositive: stats.isPositive, animationId: animationId)

                        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 15) {
                                // Первая строка: Всего игр / MVP раз
                                StatCardView(
                                    title: "Всего игр",
                                    value: "\(stats.totalSessions)",
                                    icon: "gamecontroller.fill",
                                    color: .blue,
                                    numericValue: Double(stats.totalSessions),
                                    isPercentage: false,
                                    isCurrency: false,
                                    animationId: animationId
                                )

                                StatCardView(
                                    title: "MVP раз",
                                    value: "\(stats.mvpCount)",
                                    icon: "trophy.fill",
                                    color: .orange,
                                    numericValue: Double(stats.mvpCount),
                                    isPercentage: false,
                                    isCurrency: false,
                                    animationId: animationId
                                )

                                // Вторая строка: Win Rate / MVP Rate
                                StatCardView(
                                    title: "Win Rate",
                                    value: "\(Int(stats.winRate * 100))%",
                                    icon: "chart.line.uptrend.xyaxis",
                                    color: .green,
                                    numericValue: stats.winRate * 100,
                                    isPercentage: true,
                                    isCurrency: false,
                                    animationId: animationId
                                )

                                StatCardView(
                                    title: "MVP Rate",
                                    value: {
                                        let mvpRate = stats.totalSessions > 0 ? (Double(stats.mvpCount) / Double(stats.totalSessions)) * 100 : 0.0
                                        return "\(Int(mvpRate))%"
                                    }(),
                                    icon: "trophy.circle.fill",
                                    color: .orange,
                                    numericValue: stats.totalSessions > 0 ? (Double(stats.mvpCount) / Double(stats.totalSessions)) * 100 : 0.0,
                                    isPercentage: true,
                                    isCurrency: false,
                                    animationId: animationId
                                )

                                // Третья строка: Лучшая сессия / Средний профит
                                StatCardView(
                                    title: "Лучшая сессия",
                                    value: formatCurrency(stats.bestSession),
                                    icon: "star.fill",
                                    color: .yellow,
                                    numericValue: Double(truncating: NSDecimalNumber(decimal: stats.bestSession)),
                                    isPercentage: false,
                                    isCurrency: true,
                                    animationId: animationId
                                )

                                StatCardView(
                                    title: "Средний профит",
                                    value: formatCurrency(stats.averageProfit),
                                    icon: "tengesign.circle.fill",
                                    color: .purple,
                                    numericValue: Double(truncating: NSDecimalNumber(decimal: stats.averageProfit)),
                                    isPercentage: false,
                                    isCurrency: true,
                                    animationId: animationId
                                )
                            }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Последние игры")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(stats.recentGames.prefix(5), id: \.gameId) { gameSummary in
                                NavigationLink {
                                    if let game = persistence.fetchGame(byId: gameSummary.gameId) {
                                        if gameSummary.gameType == "Бильярд" {
                                            BilliardGameDetailView(game: game)
                                        } else {
                                            GameDetailView(game: game)
                                        }
                                    }
                                } label: {
                                    if let game = persistence.fetchGame(byId: gameSummary.gameId) {
                                        GameRowView(game: game, userProfit: gameSummary.profit)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle()) // Убираем стандартный стиль NavigationLink
                            }
                        }
                        .padding(.vertical)
                        
                        // Блок "По месяцам"
                        if !gamesByYear.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("По месяцам")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(gamesByYear, id: \.year) { yearData in
                                    YearAccordionView(
                                        yearData: yearData,
                                        isYearExpanded: expandedYears.contains(yearData.year),
                                        expandedMonths: $expandedMonths,
                                        onYearToggle: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                if expandedYears.contains(yearData.year) {
                                                    expandedYears.remove(yearData.year)
                                                } else {
                                                    expandedYears.insert(yearData.year)
                                                }
                                            }
                                        },
                                        persistence: persistence,
                                        formatCurrency: formatCurrency,
                                        targetUserId: targetUserId,
                                        targetPlayerName: isSuperAdmin && selectedPlayerId == nil ? selectedPlayerName : nil
                                    )
                                }
                            }
                            .padding(.vertical)
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
            .refreshable {
                // Перезапускаем анимацию при обновлении
                animationId = UUID()
                onRefresh?()
            }
            .onAppear {
                if isSuperAdmin {
                    allPlayerNames = persistence.fetchAllUniquePlayerNamesWithInfo()
                }
            }
            .background(
            Group {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        )
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₸0"
    }
    
    // Группировка игр по годам и месяцам
    private var gamesByYear: [YearGameData] {
        let calendar = Calendar.current
        var yearGroups: [Int: [String: MonthGameData]] = [:]
        
        // Если выбран игрок по имени (без userId), ищем его в играх по имени
        let targetPlayerName: String? = isSuperAdmin && selectedPlayerId == nil ? selectedPlayerName : nil
        
        // Получаем профиль или null для игроков без userId
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()
        
        // Если нет ни userId, ни имени - возвращаем пустой массив
        if profile == nil && targetPlayerName == nil {
            return []
        }
        
        for game in games {
            guard let timestamp = game.timestamp else { continue }
            
            let year = calendar.component(.year, from: timestamp)
            let monthKey = monthKeyFromDate(timestamp)
            let monthName = monthNameFromDate(timestamp)
            
            // Вычисляем профит пользователя в этой игре
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            
            // Ищем участие: сначала по профилю, затем по имени (без учета регистра)
            let myParticipation: GameWithPlayer? = {
                if let profile = profile {
                    return participations.first(where: { $0.playerProfile == profile })
                } else if let targetName = targetPlayerName {
                    return participations.first { gwp in
                        guard let player = gwp.player, let playerName = player.name else { return false }
                        return playerName.lowercased() == targetName.lowercased()
                    }
                }
                return nil
            }()
            
            // Если пользователь не участвовал, profit = 0 (не учитываем в общей статистике месяца)
            let buyin = Decimal(Int(myParticipation?.buyin ?? 0))
            let cashout = Decimal(Int(myParticipation?.cashout ?? 0))
            let profit = myParticipation != nil ? (cashout - (buyin * 2000)) : 0
            
            if yearGroups[year] == nil {
                yearGroups[year] = [:]
            }
            
            if var monthData = yearGroups[year]![monthKey] {
                monthData.games.append(game)
                monthData.totalProfit += profit
                monthData.totalBuyins += buyin * 2000
                monthData.totalCashouts += cashout
                monthData.gamesCount += 1
                yearGroups[year]![monthKey] = monthData
            } else {
                yearGroups[year]![monthKey] = MonthGameData(
                    monthKey: monthKey,
                    monthName: monthName,
                    games: [game],
                    totalProfit: profit,
                    totalBuyins: buyin * 2000,
                    totalCashouts: cashout,
                    gamesCount: 1
                )
            }
        }
        
        // Преобразуем в массив YearGameData и сортируем
        return yearGroups.map { year, months in
            let sortedMonths = months.values.sorted { month1, month2 in
                guard let date1 = dateFromMonthKey(month1.monthKey),
                      let date2 = dateFromMonthKey(month2.monthKey) else {
                    return false
                }
                return date1 > date2
            }
            
            let totalProfit = sortedMonths.reduce(Decimal(0)) { $0 + $1.totalProfit }
            let totalGames = sortedMonths.reduce(0) { $0 + $1.gamesCount }
            
            return YearGameData(
                year: year,
                months: sortedMonths,
                totalProfit: totalProfit,
                totalGames: totalGames
            )
        }.sorted { $0.year > $1.year }
    }
    
    private func monthKeyFromDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
    
    private func monthNameFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    private func dateFromMonthKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components)
    }
}

// Структура для данных месяца
struct MonthGameData {
    let monthKey: String
    let monthName: String
    var games: [Game]
    var totalProfit: Decimal
    var totalBuyins: Decimal
    var totalCashouts: Decimal
    var gamesCount: Int
}

// Структура для данных года
struct YearGameData {
    let year: Int
    let months: [MonthGameData]
    let totalProfit: Decimal
    let totalGames: Int
}

// Компонент аккордеона для года
struct YearAccordionView: View {
    let yearData: YearGameData
    let isYearExpanded: Bool
    @Binding var expandedMonths: Set<String>
    let onYearToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок года (кликабельный)
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onYearToggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(yearData.year)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Text("\(yearData.totalGames) игр")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Профит: \(formatCurrency(yearData.totalProfit))")
                                .font(.caption)
                                .foregroundColor(yearData.totalProfit >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isYearExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isYearExpanded ? 0 : -90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isYearExpanded)
                }
                .padding()
                .liquidGlass(cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Раскрытый контент с месяцами
            if isYearExpanded {
                VStack(spacing: 8) {
                    ForEach(yearData.months, id: \.monthKey) { monthData in
                        MonthAccordionView(
                            monthData: monthData,
                            isExpanded: expandedMonths.contains(monthData.monthKey),
                            onToggle: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    if expandedMonths.contains(monthData.monthKey) {
                                        expandedMonths.remove(monthData.monthKey)
                                    } else {
                                        expandedMonths.insert(monthData.monthKey)
                                    }
                                }
                            },
                            persistence: persistence,
                            formatCurrency: formatCurrency,
                            targetUserId: targetUserId,
                            targetPlayerName: targetPlayerName
                        )
                        .padding(.leading, 16) // Отступ слева для вложенных месяцев
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

// Компонент аккордеона для месяца
struct MonthAccordionView: View {
    let monthData: MonthGameData
    let isExpanded: Bool
    let onToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?
    
    private func gameProfit(for game: Game) -> Decimal? {
        
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()
        
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        
        // Ищем участие: сначала по профилю, затем по имени (без учета регистра)
        let myParticipation: GameWithPlayer? = {
            if let profile = profile {
                return participations.first(where: { $0.playerProfile == profile })
            } else if let targetName = targetPlayerName {
                return participations.first { gwp in
                    guard let player = gwp.player, let playerName = player.name else { return false }
                    return playerName.lowercased() == targetName.lowercased()
                }
            }
            return nil
        }()
        
        guard let myParticipation = myParticipation else {
            return nil // Пользователь не участвовал
        }
        
        let buyin = Decimal(Int(myParticipation.buyin))
        let cashout = Decimal(Int(myParticipation.cashout))
        return cashout - (buyin * 2000)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок месяца (кликабельный)
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onToggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthData.monthName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Text("\(monthData.gamesCount) игр")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Профит: \(formatCurrency(monthData.totalProfit))")
                                .font(.caption)
                                .foregroundColor(monthData.totalProfit >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
                }
                .padding()
                .liquidGlass(cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Раскрытый контент с играми
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(monthData.games.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }), id: \.gameId) { game in
                        NavigationLink {
                            if let gameType = game.gameType, gameType == "Бильярд" {
                                BilliardGameDetailView(game: game)
                            } else {
                                GameDetailView(game: game)
                            }
                        } label: {
                            GameRowView(game: game, userProfit: gameProfit(for: game))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 16) // Отступ слева для вложенных игр
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}


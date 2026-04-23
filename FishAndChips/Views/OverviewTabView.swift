import SwiftUI
import CoreData

struct OverviewTabView: View {
    let statistics: UserStatistics?
    let games: [Game]
    var authViewModel: AuthViewModel? = nil
    /// Режим "Профиль игрока": отображаемое имя (одно или "Несколько (N)")
    var selectedPlayerNameForStats: String? = nil
    /// Режим "Профиль игрока": несколько имён — объединённая статистика по годам/месяцам
    var selectedPlayerNamesForStats: [String]? = nil
    let onRefresh: (() -> Void)?
    var onPlayerSelected: ((UUID?, String?) -> Void)? = nil
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared
    @State private var animationId = UUID() // Идентификатор для перезапуска анимации
    @State private var expandedYears: Set<Int> = [] // Отслеживаем раскрытые годы
    @State private var expandedMonths: Set<String> = [] // Отслеживаем раскрытые месяцы
    
    /// Суперадмин: из CloudKit или по email только в локальных билдах (DEBUG)
    private var isSuperAdmin: Bool {
        #if DEBUG
        if authViewModel?.currentUser?.email?.lowercased() == "sevasresident@gmail.com" {
            return true
        }
        #endif
        return authViewModel?.currentUser?.isSuperAdmin ?? false
    }
    
    // Получаем userId для вычисления профита (текущий пользователь)
    private var targetUserId: UUID? {
        return authViewModel?.currentUserId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let stats = statistics {
                    BalanceCardView(balance: stats.currentBalance, isPositive: stats.isPositive, animationId: animationId)
                        .accessibilityIdentifier("overview_balance_card")

                    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 15) {
                        let mvpRatePercent = stats.totalSessions > 0
                            ? (Double(stats.mvpCount) / Double(stats.totalSessions)) * 100
                            : 0.0
                        // Первая строка: Всего игр / MVP раз
                        StatTileV2(
                            systemIcon: "gamecontroller.fill",
                            value: "\(stats.totalSessions)",
                            label: "Всего игр",
                            accent: DS.Color.sky
                        )

                        StatTileV2(
                            systemIcon: "trophy.fill",
                            value: "\(stats.mvpCount)",
                            label: "MVP раз",
                            accent: DS.Color.orange
                        )

                        // Вторая строка: Win Rate / MVP Rate
                        StatTileV2(
                            systemIcon: "chart.line.uptrend.xyaxis",
                            value: "\(Int(stats.winRate * 100))%",
                            label: "Win Rate",
                            accent: DS.Color.green
                        )

                        StatTileV2(
                            systemIcon: "trophy.circle.fill",
                            value: "\(Int(mvpRatePercent))%",
                            label: "MVP Rate",
                            accent: DS.Color.orange
                        )

                        // Третья строка: Лучшая сессия / Средний профит
                        StatTileV2(
                            systemIcon: "star.fill",
                            value: stats.bestSession.formatCurrency(),
                            label: "Лучшая сессия",
                            accent: DS.Color.gold
                        )

                        StatTileV2(
                            systemIcon: "tengesign.circle.fill",
                            value: stats.averageProfit.formatCurrency(),
                            label: "Средний профит",
                            accent: DS.Color.violet
                        )
                    }

                    if selectedPlayerNameForStats == nil {
                        NavigationLink {
                            EquityGuesserLobbyView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "scope")
                                    .font(.title2)
                                    .foregroundColor(.casinoAccentGreen)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Тренажёр эквити")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Угадайте equity против конкретной руки")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .glassCardStyle(.plain)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if authViewModel != nil, selectedPlayerNameForStats == nil, let userId = authViewModel?.currentUserId,
                       let profile = persistence.fetchPlayerProfile(byUserId: userId) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Профиль")
                                .font(.headline)
                                .foregroundColor(.white)
                            Toggle("Сделать профиль публичным", isOn: Binding(
                                get: { profile.isPublic },
                                set: { newValue in
                                    profile.isPublic = newValue
                                    try? viewContext.save()
                                    Task {
                                        try? await SyncCoordinator.shared.quickSyncPlayerProfile(profile)
                                        if newValue {
                                            Task { @MainActor in
                                                NotificationService.shared.saveNotificationToStore(
                                                    title: "Профиль публичный",
                                                    body: "Ваш профиль теперь виден всем игрокам",
                                                    type: "profile_public_self"
                                                )
                                            }
                                        }
                                    }
                                }
                            ))
                            .tint(.blue)
                            Button {
                                if !profile.isPublic {
                                    profile.isPublic = true
                                    try? viewContext.save()
                                    Task {
                                        try? await SyncCoordinator.shared.quickSyncPlayerProfile(profile)
                                        await MainActor.run {
                                            NotificationService.shared.saveNotificationToStore(
                                                title: "Профиль публичный",
                                                body: "Ваш профиль теперь виден всем игрокам",
                                                type: "profile_public_self"
                                            )
                                        }
                                    }
                                }
                                let url = URL(string: "fishchips://profile/\(profile.profileId.uuidString)")!
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootVC = windowScene.windows.first?.rootViewController {
                                    rootVC.present(av, animated: true)
                                }
                            } label: {
                                Label("Поделиться профилем", systemImage: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .glassCardStyle(.plain)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Последние игры")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(stats.recentGames.prefix(5), id: \.gameId) { gameSummary in
                            NavigationLink {
                                if let game = persistence.fetchGame(byId: gameSummary.gameId) {
                                    GameDetailView(game: game)
                                }
                            } label: {
                                if let game = persistence.fetchGame(byId: gameSummary.gameId) {
                                    GameRowView(game: game, userProfit: gameSummary.profit)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                    formatCurrency: { $0.formatCurrency() },
                                    targetUserId: targetUserId,
                                    targetPlayerName: selectedPlayerNameForStats
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                    }
                } else {
                    ProgressView("Загрузка...")
                        .tint(.white)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("overview_content")
        .scrollContentBackground(.hidden)
        .refreshable {
            animationId = UUID()
            onRefresh?()
        }
    }

    // Группировка игр по годам и месяцам
    private var gamesByYear: [YearGameData] {
        let calendar = Calendar.current
        var yearGroups: [Int: [String: MonthGameData]] = [:]
        
        // Профиль (для обычного Обзора) или имя/имена игроков (для "Профиль игрока")
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()

        let targetPlayerName: String? = selectedPlayerNameForStats
        let targetPlayerNamesSet: Set<String>? = {
            guard let names = selectedPlayerNamesForStats, !names.isEmpty else { return nil }
            return Set(names.map { $0.lowercased() })
        }()

        if profile == nil && targetPlayerName == nil && targetPlayerNamesSet == nil {
            return []
        }

        for game in games {
            guard let timestamp = game.timestamp else { continue }

            let year = calendar.component(.year, from: timestamp)
            let monthKey = monthKeyFromDate(timestamp)
            let monthName = monthNameFromDate(timestamp)

            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []

            // Сумма buyin/cashout/profit: по профилю (одно участие), по одному имени или по нескольким именам
            var buyin = Decimal(0)
            var cashout = Decimal(0)
            if let profile = profile {
                if let one = participations.first(where: { $0.playerProfile == profile }) {
                    buyin = Decimal(Int(one.buyin))
                    cashout = Decimal(Int(one.cashout))
                }
            } else if let namesSet = targetPlayerNamesSet {
                for gwp in participations {
                    guard let player = gwp.player, let n = player.name, namesSet.contains(n.lowercased()) else { continue }
                    buyin += Decimal(Int(gwp.buyin))
                    cashout += Decimal(Int(gwp.cashout))
                }
            } else if let name = targetPlayerName, let one = participations.first(where: { gwp in
                guard let player = gwp.player, let n = player.name else { return false }
                return n.lowercased() == name.lowercased()
            }) {
                buyin = Decimal(Int(one.buyin))
                cashout = Decimal(Int(one.cashout))
            }

            let profit = (buyin != 0 || cashout != 0) ? (cashout - buyin * Decimal(ChipValue.tengePerChip)) : 0
            
            if yearGroups[year] == nil {
                yearGroups[year] = [:]
            }
            
            if var monthData = yearGroups[year]![monthKey] {
                monthData.games.append(game)
                monthData.totalProfit += profit
                monthData.totalBuyins += buyin * Decimal(ChipValue.tengePerChip)
                monthData.totalCashouts += cashout
                monthData.gamesCount += 1
                yearGroups[year]![monthKey] = monthData
            } else {
                yearGroups[year]![monthKey] = MonthGameData(
                    monthKey: monthKey,
                    monthName: monthName,
                    games: [game],
                    totalProfit: profit,
                    totalBuyins: buyin * Decimal(ChipValue.tengePerChip),
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


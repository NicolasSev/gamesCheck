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
    @State private var animationId = UUID()
    @State private var expandedYears: Set<Int> = []
    @State private var expandedMonths: Set<String> = []

    /// Суперадмин: из CloudKit или по email только в локальных билдах (DEBUG)
    private var isSuperAdmin: Bool {
        #if DEBUG
        if authViewModel?.currentUser?.email?.lowercased() == "sevasresident@gmail.com" {
            return true
        }
        #endif
        return authViewModel?.currentUser?.isSuperAdmin ?? false
    }

    private var targetUserId: UUID? {
        return authViewModel?.currentUserId
    }

    /// True when no game data is loaded yet (Core Data still warming up).
    private var isLoading: Bool { statistics == nil }

    /// True when stats loaded but contain no participated games (empty state).
    private var isEmpty: Bool {
        guard let stats = statistics else { return false }
        return stats.totalSessions == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if isLoading {
                    skeletonContent
                } else if let stats = statistics {
                    heroCardSection(stats)
                    if !isEmpty {
                        statsGridSection(stats)
                        SectionDividerV2(label: "ПОСЛЕДНИЕ ИГРЫ")
                            .padding(.top, 4)
                        recentGamesSection(stats)
                    } else {
                        emptyStateCard
                    }
                    preservedExtras(stats)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("overview_content")
        .scrollContentBackground(.hidden)
        .refreshable {
            animationId = UUID()
            onRefresh?()
        }
    }

    // MARK: - Hero card (balance + 3-stat trio)

    @ViewBuilder
    private func heroCardSection(_ stats: UserStatistics) -> some View {
        HeroCard {
            VStack(spacing: 0) {
                Text("БАЛАНС")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.4)
                    .foregroundColor(DS.Color.txt2)
                    .padding(.bottom, 10)

                GreenNumber(
                    size: .lg,
                    tone: heroBalanceTone(stats.currentBalance),
                    text: heroBalanceText(stats.currentBalance)
                )
                .tracking(-2)
                .id(animationId)

                Text(verbatim: heroSubtitle(stats))
                    .font(.system(size: 13))
                    .foregroundColor(DS.Color.txt2)
                    .padding(.top, 8)

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 16)

                HStack(spacing: 0) {
                    heroTrioCell(value: heroWinRateText(stats), label: "Винрейт", color: DS.Color.green)
                    Spacer(minLength: 0)
                    heroTrioCell(value: "\(stats.mvpCount)", label: "MVP", color: DS.Color.gold)
                    Spacer(minLength: 0)
                    heroTrioCell(value: streakDisplay, label: "Серия", color: DS.Color.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 26 - 16, leading: 22 - 16, bottom: 22 - 16, trailing: 22 - 16))
        }
        .accessibilityIdentifier("overview_balance_card")
    }

    @ViewBuilder
    private func heroTrioCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.55), radius: 12, x: 0, y: 0)
            Text(verbatim: label)
                .font(.system(size: 10))
                .foregroundColor(DS.Color.txt3)
        }
        .frame(maxWidth: .infinity)
    }

    private func heroBalanceText(_ balance: Decimal) -> String {
        balance.formatTengeProto()
    }

    private func heroBalanceTone(_ balance: Decimal) -> GreenNumber.Tone {
        if balance > 0 { return .positive }
        if balance < 0 { return .negative }
        return .neutral
    }

    private func heroWinRateText(_ stats: UserStatistics) -> String {
        let pct = stats.winRate * 100
        return String(format: pct == pct.rounded() ? "%.0f%%" : "%.1f%%", pct)
    }

    private func heroSubtitle(_ stats: UserStatistics) -> String {
        let stacks = totalBuyinsCount
        let sessions = stats.totalSessions
        let stackWord = RussianPlural.pick(stacks, one: "стопка", few: "стопки", many: "стопок")
        let sessionWord = RussianPlural.pick(sessions, one: "сессия", few: "сессии", many: "сессий")
        if stacks == 0 {
            return "\(sessions) \(sessionWord)"
        }
        return "+\(stacks) \(stackWord) · \(sessions) \(sessionWord)"
    }

    /// 🔥 N or just N (per Q2: derive from `recentGames` while profit > 0).
    private var streakDisplay: String {
        let streak = currentStreak
        return streak > 0 ? "🔥 \(streak)" : "0"
    }

    private var currentStreak: Int {
        guard let stats = statistics else { return 0 }
        var n = 0
        for s in stats.recentGames {
            if s.profit > 0 { n += 1 } else { break }
        }
        return n
    }

    /// Sum of `Int(gwp.buyin)` across all games for the active target.
    /// Returns 0 if there is no obvious target (e.g. multi-name aggregate without a profile).
    private var totalBuyinsCount: Int {
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()
        let targetName = selectedPlayerNameForStats?.lowercased()
        let targetNamesSet: Set<String>? = {
            guard let names = selectedPlayerNamesForStats, !names.isEmpty else { return nil }
            return Set(names.map { $0.lowercased() })
        }()

        var total = 0
        for game in games {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            if let profile {
                if let one = participations.first(where: { $0.playerProfile == profile }) {
                    total += Int(one.buyin)
                }
            } else if let namesSet = targetNamesSet {
                for gwp in participations {
                    guard let n = gwp.player?.name?.lowercased(), namesSet.contains(n) else { continue }
                    total += Int(gwp.buyin)
                }
            } else if let name = targetName,
                      let one = participations.first(where: { $0.player?.name?.lowercased() == name }) {
                total += Int(one.buyin)
            }
        }
        return total
    }

    // MARK: - 6-tile stats grid

    @ViewBuilder
    private func statsGridSection(_ stats: UserStatistics) -> some View {
        let mvpRatePct = stats.totalSessions > 0
            ? (Double(stats.mvpCount) / Double(stats.totalSessions)) * 100
            : 0.0

        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            StatPillV2(systemIcon: "target", value: "\(stats.totalSessions)",
                       label: "Сессии", accent: DS.Color.sky)
            StatPillV2(systemIcon: "trophy.fill", value: "\(stats.mvpCount)",
                       label: "MVP", accent: DS.Color.orange)
            StatPillV2(systemIcon: "chart.line.uptrend.xyaxis",
                       value: String(format: "%.0f%%", stats.winRate * 100),
                       label: "Винрейт", accent: DS.Color.green)
            StatPillV2(systemIcon: "star.fill",
                       value: String(format: "%.0f%%", mvpRatePct),
                       label: "MVP Rate", accent: DS.Color.gold)
            StatPillV2(systemIcon: "flame.fill",
                       value: stats.bestSession.compactKTenge(),
                       label: "Лучшая", accent: DS.Color.green)
            StatPillV2(systemIcon: "diamond.fill",
                       value: stats.averageProfit.compactKTenge(),
                       label: "Средняя", accent: DS.Color.violet)
        }
    }

    // MARK: - Recent games (3 rows, tappable)

    @ViewBuilder
    private func recentGamesSection(_ stats: UserStatistics) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(stats.recentGames.prefix(3)), id: \.gameId) { summary in
                if let game = persistence.fetchGame(byId: summary.gameId) {
                    NavigationLink {
                        GameDetailView(game: game)
                    } label: {
                        GameRowV2(
                            type: summary.gameType,
                            place: gamePlace(for: game),
                            date: shortDate(summary.timestamp),
                            result: gameResultText(summary.profit),
                            win: summary.profit > 0 ? 1 : (summary.profit < 0 ? -1 : 0),
                            mvpName: recentGameMVPName(for: game),
                            isSelfMvp: isUserMVP(in: game)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func gameResultText(_ profit: Decimal) -> String {
        profit.formatTengeProto()
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func gamePlace(for game: Game) -> String {
        // Game CoreData doesn't model a "place" string; fall back to em-dash.
        return "—"
    }

    /// Name of the session MVP (highest profit) for subtitle / row parity with `GamesViewV2`.
    private func recentGameMVPName(for game: Game) -> String? {
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        guard !participations.isEmpty else { return nil }
        let withProfit = participations.map { gwp -> (gwp: GameWithPlayer, profit: Decimal) in
            let buyin = Decimal(Int(gwp.buyin))
            let cashout = Decimal(Int(gwp.cashout))
            let profit = cashout - buyin * Decimal(ChipValue.tengePerChip)
            return (gwp, profit)
        }
        guard let leader = withProfit.max(by: { $0.profit < $1.profit })?.gwp else { return nil }
        let name = leader.playerProfile?.displayName ?? leader.player?.name ?? ""
        return name.isEmpty ? nil : name
    }

    /// MVP = participant with highest profit; check whether that participant is the current target.
    private func isUserMVP(in game: Game) -> Bool {
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        guard !participations.isEmpty else { return false }

        let withProfit = participations.map { gwp -> (gwp: GameWithPlayer, profit: Decimal) in
            let buyin = Decimal(Int(gwp.buyin))
            let cashout = Decimal(Int(gwp.cashout))
            let profit = cashout - buyin * Decimal(ChipValue.tengePerChip)
            return (gwp, profit)
        }
        guard let leader = withProfit.max(by: { $0.profit < $1.profit })?.gwp else { return false }

        if let userId = targetUserId,
           let profile = leader.playerProfile,
           let leaderUserId = profile.userId {
            return leaderUserId == userId
        }
        if let name = selectedPlayerNameForStats?.lowercased(),
           let leaderName = leader.player?.name?.lowercased() {
            return leaderName == name
        }
        if let names = selectedPlayerNamesForStats?.map({ $0.lowercased() }),
           let leaderName = leader.player?.name?.lowercased() {
            return names.contains(leaderName)
        }
        return false
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Text("Пока нет игр")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.Color.txt)
            Text("Добавьте первую игру, чтобы увидеть статистику.")
                .font(.system(size: 13))
                .foregroundColor(DS.Color.txt3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .glassCardStyle(.plain)
    }

    // MARK: - Skeleton (loading)

    @ViewBuilder
    private var skeletonContent: some View {
        VStack(spacing: 10) {
            heroSkeleton
            statsGridSkeleton
            recentGamesSkeleton
        }
        .redacted(reason: .placeholder)
    }

    @ViewBuilder
    private var heroSkeleton: some View {
        HeroCard {
            VStack(spacing: 12) {
                Color.white.opacity(0.10).frame(width: 80, height: 12)
                Color.white.opacity(0.18).frame(width: 220, height: 44)
                Color.white.opacity(0.10).frame(width: 160, height: 12)
                Color.white.opacity(0.06).frame(height: 1).padding(.vertical, 8)
                HStack {
                    ForEach(0..<3) { _ in
                        VStack(spacing: 6) {
                            Color.white.opacity(0.18).frame(width: 40, height: 18)
                            Color.white.opacity(0.10).frame(width: 50, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var statsGridSkeleton: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DS.Color.border, lineWidth: 1)
                    )
            }
        }
    }

    @ViewBuilder
    private var recentGamesSkeleton: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(DS.Color.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Preserved blocks (Equity link, profile, accordion)

    @ViewBuilder
    private func preservedExtras(_ stats: UserStatistics) -> some View {
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
            .padding(.top, 6)
        }

        if authViewModel != nil, selectedPlayerNameForStats == nil,
           let userId = authViewModel?.currentUserId,
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
        }

        if !gamesByYear.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                // Proto ref: ios-app-v2.jsx:244-248 — "ВСЯ ИСТОРИЯ" section divider
                HStack(spacing: 10) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.08))
                    Text("ВСЯ ИСТОРИЯ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Color.txt3)
                        .kerning(0.5)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.08))
                }

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
    }

    // MARK: - Existing year/month aggregator (preserved verbatim)

    private var gamesByYear: [YearGameData] {
        let calendar = Calendar.current
        var yearGroups: [Int: [String: MonthGameData]] = [:]

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

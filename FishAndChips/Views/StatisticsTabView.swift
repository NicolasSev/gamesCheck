import SwiftUI
import CoreData

struct StatisticsTabView: View {
    let statistics: UserStatistics?
    let gameTypeStats: [GameTypeStatistics]
    let placeStats: [PlaceStatistics]
    let topAnalytics: TopAnalytics?
    let chartData: [(date: Date, buyin: Decimal, gameId: UUID)]

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var equityGuesserStats: EquityGuesserUserStatsRow?
    @State private var equityGuesserLoading = false
    @State private var selectedGame: Game?
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared

    // Cumulative profit sparkline from recentGames (chronological order)
    private var sparklinePoints: [Double] {
        guard let games = statistics?.recentGames, !games.isEmpty else { return [] }
        let sorted = games.sorted { $0.timestamp < $1.timestamp }
        var result: [Double] = []
        var cumulative = 0.0
        for g in sorted {
            cumulative += Double(truncating: g.profit as NSDecimalNumber)
            result.append(cumulative)
        }
        return result
    }

    // Breakdown bars derived from gameTypeStats
    private var breakdownBars: [(label: String, pct: Double, color: Color, value: String)] {
        let absTotal = gameTypeStats.reduce(0.0) {
            $0 + abs(Double(truncating: $1.totalProfit as NSDecimalNumber))
        }
        guard absTotal > 0 else { return [] }
        return gameTypeStats.prefix(4).map { stat in
            let profit = Double(truncating: stat.totalProfit as NSDecimalNumber)
            let pct = abs(profit) / absTotal * 100
            let color: Color = profit >= 0 ? DS.Color.green : DS.Color.red
            return (label: stat.gameType, pct: pct, color: color, value: stat.totalProfit.compactKTenge())
        }
    }

    // Breakdown bars derived from placeStats
    private var placeBreakdownBars: [(label: String, pct: Double, color: Color, value: String)] {
        let absTotal = placeStats.reduce(0.0) {
            $0 + abs(Double(truncating: $1.totalProfit as NSDecimalNumber))
        }
        guard absTotal > 0 else { return [] }
        return placeStats.prefix(5).map { stat in
            let profit = Double(truncating: stat.totalProfit as NSDecimalNumber)
            let pct = abs(profit) / absTotal * 100
            let color: Color = profit >= 0 ? DS.Color.green : DS.Color.red
            return (label: stat.placeName, pct: pct, color: color, value: stat.totalProfit.compactKTenge())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // ─── V2: section label ───────────────────────────────────────
                Text("ТОПОВАЯ АНАЛИТИКА")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(DS.Color.txt3)

                // ─── V2: hero card ───────────────────────────────────────────
                heroCard

                // ─── V2: 2×2 stat grid ──────────────────────────────────────
                if let stats = statistics {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        statCell(
                            label: "Сессии",
                            value: "\(stats.totalSessions)",
                            color: DS.Color.sky
                        )
                        statCell(
                            label: "Винрейт",
                            value: String(format: "%.1f%%", stats.winRate),
                            color: DS.Color.green
                        )
                        statCell(
                            label: "MVP",
                            value: "\(stats.mvpCount)",
                            color: DS.Color.gold
                        )
                        statCell(
                            label: "Средняя",
                            value: stats.averageProfit.compactKTenge(),
                            color: DS.Color.violet
                        )
                    }
                }

                // ─── V2: по типу игры ────────────────────────────────────────
                if !breakdownBars.isEmpty {
                    GlassCardV2 {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("По типу игры")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(DS.Color.txt)
                            ForEach(breakdownBars, id: \.label) { row in
                                breakdownRow(row)
                            }
                        }
                        .padding(16)
                    }
                }

                // ─── V2: по месту ────────────────────────────────────────────
                if !placeBreakdownBars.isEmpty {
                    GlassCardV2 {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("По месту")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(DS.Color.txt)
                            ForEach(placeBreakdownBars, id: \.label) { row in
                                breakdownRow(row)
                            }
                        }
                        .padding(16)
                    }
                }

                // ─── V2: streak card (best historical streak as proxy) ───────
                if let streak = topAnalytics?.longestWinStreak, streak.length > 0 {
                    streakCard(streak)
                }

                // ─── PRESERVED: EquityGuesser ────────────────────────────────
                equityGuesserBlock

                // ─── PRESERVED: TopAnalytics records ─────────────────────────
                if let analytics = topAnalytics {
                    topAnalyticsBlock(analytics)
                } else {
                    ProgressView("Загрузка...")
                        .tint(.white)
                        .padding()
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .task(id: authViewModel.currentUserId) {
            await refreshEquityGuesserStats()
        }
        .refreshable {
            await refreshEquityGuesserStats()
        }
        .sheet(item: Binding(get: { selectedGame }, set: { selectedGame = $0 })) { game in
            GameDetailView(game: game)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
    }

    // MARK: - Hero card

    @ViewBuilder
    private var heroCard: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Суммарная прибыль")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Color.txt3)
                        if let stats = statistics {
                            GreenNumber(
                                size: .md,
                                tone: stats.currentBalance >= 0 ? .positive : .negative,
                                text: stats.currentBalance.formatTengeProto()
                            )
                        } else {
                            GreenNumber(size: .md, tone: .neutral, text: "₸\u{00A0}0")
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 14)

                if sparklinePoints.count > 1 {
                    StatsSparklineView(points: sparklinePoints)
                        .frame(height: 72)
                }
            }
        }
    }

    // MARK: - Stat cell

    @ViewBuilder
    private func statCell(label: String, value: String, color: Color) -> some View {
        GlassCardV2 {
            VStack(alignment: .leading, spacing: 5) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(DS.Color.txt3)
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        }
    }

    // MARK: - Breakdown row

    @ViewBuilder
    private func breakdownRow(_ row: (label: String, pct: Double, color: Color, value: String)) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(row.label)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.txt2)
                Spacer()
                Text(row.value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(row.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(row.color)
                        .shadow(color: row.color.opacity(0.4), radius: 4, x: 0, y: 0)
                        .frame(width: geo.size.width * row.pct / 100)
                        .animation(.easeOut(duration: 0.8), value: row.pct)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Streak card

    @ViewBuilder
    private func streakCard(_ streak: StreakRecord) -> some View {
        GlassCardV2 {
            HStack(spacing: 14) {
                Text("🔥").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak.length) \(RussianPlural.pick(streak.length, one: "игра", few: "игры", many: "игр")) подряд")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(DS.Color.orange)
                        .shadow(color: DS.Color.orange.opacity(0.6), radius: 12, x: 0, y: 0)
                    Text("Лучший винстрик")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Color.txt2)
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.Color.orange.opacity(0.25), lineWidth: 1)
        )
        .background(DS.Color.orange.opacity(0.08).cornerRadius(18))
    }

    // MARK: - Preserved: EquityGuesser block

    @ViewBuilder
    private var equityGuesserBlock: some View {
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
                        value: eg.overall_mae != nil ? String(format: "%.2f%%", eg.overall_mae!) : "—"
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
            .glassCardStyle(.plain)
        }
    }

    // MARK: - Preserved: TopAnalytics block

    @ViewBuilder
    private func topAnalyticsBlock(_ analytics: TopAnalytics) -> some View {
        VStack(spacing: 12) {
            if let biggestWin = analytics.biggestWin {
                TopRecordCard(title: "Самый большой выигрыш", icon: "arrow.up.circle.fill", color: .green, record: biggestWin, formatValue: { $0.formatCurrency() }) {
                    if let gameId = biggestWin.gameId { selectedGame = persistence.fetchGame(byId: gameId) }
                }
            }
            if let biggestLoss = analytics.biggestLoss {
                TopRecordCard(title: "Самый большой проигрыш", icon: "arrow.down.circle.fill", color: .red, record: biggestLoss, formatValue: { $0.formatCurrency() }) {
                    if let gameId = biggestLoss.gameId { selectedGame = persistence.fetchGame(byId: gameId) }
                }
            }
            if let maxBuyins = analytics.maxBuyins {
                TopRecordCard(title: "Самое большое количество байинов", icon: "creditcard.fill", color: .blue, record: maxBuyins, formatValue: { $0.formatCurrency() }) {
                    if let gameId = maxBuyins.gameId { selectedGame = persistence.fetchGame(byId: gameId) }
                }
            }
            if let mostExpensiveGame = analytics.mostExpensiveGame {
                TopRecordCard(title: "Самая дорогая игра", icon: "banknote.fill", color: .orange, record: mostExpensiveGame, formatValue: { $0.formatCurrency() }) {
                    if let gameId = mostExpensiveGame.gameId { selectedGame = persistence.fetchGame(byId: gameId) }
                }
            }
            if let winStreak = analytics.longestWinStreak {
                StreakCard(title: "Самый длинный винстрик", icon: "flame.fill", color: .green, streak: winStreak) {
                    selectedGame = findGameForStreak(winStreak)
                }
            }
            if let loseStreak = analytics.longestLoseStreak {
                StreakCard(title: "Самый длинный феилстрик", icon: "exclamationmark.triangle.fill", color: .red, streak: loseStreak) {
                    selectedGame = findGameForStreak(loseStreak)
                }
            }
        }
    }

    // MARK: - Private helpers

    private func equityStatCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.white.opacity(0.65))
            Text(value).font(.subheadline.weight(.semibold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func refreshEquityGuesserStats() async {
        equityGuesserStats = nil
        guard authViewModel.currentUserId != nil else { equityGuesserLoading = false; return }
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
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: streak.startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        guard let games = try? viewContext.fetch(request) else { return nil }
        if let playerName = streak.playerName {
            for game in games {
                let gwps = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                if gwps.contains(where: { $0.player?.name?.caseInsensitiveCompare(playerName) == .orderedSame }) {
                    return game
                }
            }
        }
        return games.first
    }
}

// MARK: - Sparkline

private struct StatsSparklineView: View {
    let points: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let minY = points.min()!
            let maxY = points.max()!
            let range = maxY == minY ? 1.0 : maxY - minY
            let step = size.width / Double(points.count - 1)

            func y(for value: Double) -> Double {
                size.height - ((value - minY) / range) * (size.height - 8) - 4
            }

            var linePath = Path()
            for (i, v) in points.enumerated() {
                let pt = CGPoint(x: Double(i) * step, y: y(for: v))
                if i == 0 { linePath.move(to: pt) } else { linePath.addLine(to: pt) }
            }

            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            ctx.fill(fillPath, with: .linearGradient(
                Gradient(colors: [DS.Color.green.opacity(0.3), DS.Color.green.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            ctx.stroke(
                linePath,
                with: .color(DS.Color.green),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Preserved sub-components (originally in this file)

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
                Image(systemName: icon).foregroundColor(color).font(.title3)
                Text(title).font(.headline).foregroundColor(.white)
            }
            Divider().background(Color.white.opacity(0.3))
            VStack(alignment: .leading, spacing: 6) {
                row(label: "Сумма:", value: formatValue(record.value), valueColor: color)
                row(label: "Игрок:", value: record.playerName, valueColor: .white)
                row(label: "Дата:", value: record.formattedDate, valueColor: .white.opacity(0.8))
            }
        }
        .padding()
        .glassCardStyle(.plain)
        .onTapGesture { onTap() }
    }

    private func row(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(valueColor)
        }
    }
}

struct StreakCard: View {
    let title: String
    let icon: String
    let color: Color
    let streak: StreakRecord
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.title3)
                Text(title).font(.headline).foregroundColor(.white)
            }
            Divider().background(Color.white.opacity(0.3))
            VStack(alignment: .leading, spacing: 6) {
                if let playerName = streak.playerName {
                    HStack {
                        Text("Игрок:").font(.subheadline).foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(playerName).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
                    }
                }
                HStack {
                    Text("Длина:").font(.subheadline).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(streak.length) игр").font(.subheadline).fontWeight(.semibold).foregroundColor(color)
                }
                HStack {
                    Text("Период:").font(.subheadline).foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(streak.formattedPeriod).font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .glassCardStyle(.plain)
        .onTapGesture { onTap() }
    }
}

// MARK: - Preview

private func previewRecentGames() -> [GameSummary] {
    (0..<20).map { i in
        let isLoss = i % 3 == 0
        return GameSummary(
            gameId: UUID(),
            gameType: i % 4 == 0 ? "Tournament" : "Cash Game",
            timestamp: Date(timeIntervalSinceNow: -Double(i) * 86400),
            totalPlayers: 6,
            myBuyin: 2,
            myCashout: isLoss ? 0 : 4,
            profit: isLoss ? -4000 : 4000,
            isCreator: i == 0
        )
    }.reversed()
}

#Preview("Stats — default") {
    let recentGames = previewRecentGames()
    let stats = UserStatistics(
        totalGamesCreated: 5,
        totalGamesParticipated: 23,
        totalBuyins: 46,
        totalCashouts: 88,
        currentBalance: 84000,
        winRate: 65.2,
        profitByGameType: ["Cash Game": 98000, "Tournament": -14000],
        recentGames: recentGames,
        bestSession: 18000,
        worstSession: -8000,
        averageProfit: 3652,
        totalSessions: 23,
        mvpCount: 8
    )

    let gameTypeStats = [
        GameTypeStatistics(gameType: "Cash Game", gamesCount: 18, totalProfit: 98000, winRate: 0.72, averageProfit: 5444, bestSession: 18000),
        GameTypeStatistics(gameType: "Tournament", gamesCount: 5, totalProfit: -14000, winRate: 0.20, averageProfit: -2800, bestSession: 4000),
    ]

    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        GameBackgroundView()
        StatisticsTabView(
            statistics: stats,
            gameTypeStats: gameTypeStats,
            placeStats: [],
            topAnalytics: nil,
            chartData: []
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Stats — empty") {
    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        GameBackgroundView()
        StatisticsTabView(
            statistics: nil,
            gameTypeStats: [],
            placeStats: [],
            topAnalytics: nil,
            chartData: []
        )
    }
    .preferredColorScheme(.dark)
}

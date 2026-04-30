import SwiftUI
import CoreData

// MARK: - Data models (unchanged)

struct MonthGameData {
    let monthKey: String
    let monthName: String
    var games: [Game]
    var totalProfit: Decimal
    var totalBuyins: Decimal
    var totalCashouts: Decimal
    var gamesCount: Int
}

struct YearGameData {
    let year: Int
    let months: [MonthGameData]
    let totalProfit: Decimal
    let totalGames: Int
}

// MARK: - YearAccordionView
// Proto ref: `IosYearAccordion` — game-history.jsx:116-165

struct YearAccordionView: View {
    let yearData: YearGameData
    let isYearExpanded: Bool
    @Binding var expandedMonths: Set<String>
    let onYearToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?

    private var win: Bool { yearData.totalProfit >= 0 }
    private var yearShort: String { String(String(yearData.year).suffix(2)) }
    private var monthsCount: Int { yearData.months.count }

    var body: some View {
        VStack(spacing: 0) {
            yearHeader
            if isYearExpanded {
                monthsList
            }
        }
        .background(Color.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: isYearExpanded ? .black.opacity(0.30) : .clear,
            radius: 12, x: 0, y: 4
        )
    }

    private var yearHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                onYearToggle()
            }
        }) {
            HStack(spacing: 12) {
                // '26 badge tile
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(win
                              ? DS.Color.green.opacity(0.15)
                              : DS.Color.red.opacity(0.12))
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(win
                                      ? DS.Color.green.opacity(0.30)
                                      : DS.Color.red.opacity(0.22),
                                      lineWidth: 1)
                    Text(yearShort)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(win ? DS.Color.green : DS.Color.red)
                }
                .frame(width: 32, height: 32)

                // Year + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(yearData.year))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.Color.txt)
                    Text("\(yearData.totalGames) игр · \(monthsCount) мес.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Color.txt3)
                }

                Spacer()

                // Profit
                VStack(alignment: .trailing, spacing: 1) {
                    Text(yearData.totalProfit.formatTengeProto())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(win ? DS.Color.green : DS.Color.red)
                        .shadow(color: (win ? DS.Color.green : DS.Color.red).opacity(0.40),
                                radius: 6)
                    Text("профит")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DS.Color.txt3)
                }

                // Chevron
                Text("›")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.txt3)
                    .rotationEffect(.degrees(isYearExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isYearExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isYearExpanded ? Color.white.opacity(0.04) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var monthsList: some View {
        VStack(spacing: 0) {
            ForEach(yearData.months, id: \.monthKey) { monthData in
                MonthAccordionView(
                    monthData: monthData,
                    isExpanded: expandedMonths.contains(monthData.monthKey),
                    onToggle: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
            }
        }
        .background(Color.black.opacity(0.14))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
            removal:   .scale(scale: 0.97, anchor: .top).combined(with: .opacity)
        ))
    }
}

// MARK: - MonthAccordionView
// Proto ref: `IosMonthAccordion` — game-history.jsx:87-114

struct MonthAccordionView: View {
    let monthData: MonthGameData
    let isExpanded: Bool
    let onToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?

    private var win: Bool { monthData.totalProfit >= 0 }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            if isExpanded {
                gameRows
            }
        }
    }

    private var monthHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                onToggle()
            }
        }) {
            HStack(spacing: 10) {
                Text("›")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Color.txt3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)

                Text(monthData.monthName.capitalized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.Color.txt)

                Text("\(monthData.gamesCount) игр")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Color.txt3)

                Spacer()

                Text(monthData.totalProfit.formatTengeProto())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(win ? DS.Color.green : DS.Color.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.10)),
            alignment: .top
        )
    }

    private var gameRows: some View {
        VStack(spacing: 8) {
            ForEach(
                monthData.games.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }),
                id: \.gameId
            ) { game in
                NavigationLink {
                    GameDetailView(game: game)
                } label: {
                    gameRowLabel(for: game)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
            removal:   .scale(scale: 0.97, anchor: .top).combined(with: .opacity)
        ))
    }

    /// Same `GameRowV2` row as `OverviewTabView.recentGamesSection` — not `GameRowView`.
    @ViewBuilder
    private func gameRowLabel(for game: Game) -> some View {
        let p = gameProfit(for: game) ?? 0
        let w: Int = p > 0 ? 1 : (p < 0 ? -1 : 0)
        GameRowV2(
            type: game.gameType ?? "—",
            place: "—",
            date: shortDateForGameRow(game.timestamp ?? Date()),
            result: p.formatTengeProto(),
            win: w,
            mvpName: gameRowMVPName(for: game),
            isSelfMvp: isUserMVPInAccordion(in: game)
        )
    }

    private func shortDateForGameRow(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func gameRowMVPName(for game: Game) -> String? {
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

    /// Mirrors `OverviewTabView.isUserMVP` (userId + single player name; no multi-name set here).
    private func isUserMVPInAccordion(in game: Game) -> Bool {
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
        if let name = targetPlayerName?.lowercased(),
           let leaderName = leader.player?.name?.lowercased() {
            return leaderName == name
        }
        return false
    }

    private func gameProfit(for game: Game) -> Decimal? {
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let myParticipation: GameWithPlayer? = {
            if let profile = profile {
                return participations.first(where: { $0.playerProfile == profile })
            } else if let targetName = targetPlayerName {
                return participations.first { gwp in
                    guard let player = gwp.player,
                          let playerName = player.name else { return false }
                    return playerName.lowercased() == targetName.lowercased()
                }
            }
            return nil
        }()
        guard let p = myParticipation else { return nil }
        let buyin = Decimal(Int(p.buyin))
        let cashout = Decimal(Int(p.cashout))
        return cashout - buyin * Decimal(ChipValue.tengePerChip)
    }
}

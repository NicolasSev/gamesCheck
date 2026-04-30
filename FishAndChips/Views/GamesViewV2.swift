import SwiftUI

/// V2 Games tab — replaces `GamesListTabView`.
///
/// Structure (top → bottom):
///   MonthNavCardV2 → MiniCalendarV2 → FilterChipsRow (Все / Мои) → GameRowV2 list
///
/// All state owned here; parent passes pre-fetched `games` and filter binding.
/// Pull-to-refresh, pagination, search, and sync overlay are preserved from V1.
struct GamesViewV2: View {
    let games: [Game]
    let userId: UUID?
    @Binding var selectedFilter: GameFilter
    let onFilterChange: (GameFilter) -> Void
    var onLoadMore: (() -> Void)? = nil

    @EnvironmentObject var syncCoordinator: SyncCoordinator

    @State private var searchText = ""
    @State private var selectedDay: Date? = nil
    @State private var periodStart: Date? = nil
    @State private var periodEnd: Date? = nil
    @State private var currentMonth: Date = Date()
    @State private var isRangeSelection: Bool = false

    private let cal = Calendar.current
    // Place names come from the Core Data `place` relationship on each Game.

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MonthNavCardV2(
                    title: monthTitle,
                    subtitle: rangeSubtitle,
                    onPrev: { withAnimation { stepMonth(-1) } },
                    onNext: { withAnimation { stepMonth(+1) } },
                    onSubtitleTap: { withAnimation { toggleRangeMode() } }
                )
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

                MiniCalendarV2(
                    month: currentMonth,
                    markedDays: markedDays,
                    selectedDay: isRangeSelection ? nil : selectedDay,
                    rangeStart: isRangeSelection ? periodStart : nil,
                    rangeEnd: isRangeSelection ? periodEnd : nil,
                    onDayTap: { handleDayTap($0) }
                )
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

                // Reset button — visible only when a filter is active
                if selectedDay != nil || (isRangeSelection && periodStart != nil) {
                    Button(action: { withAnimation { clearDateFilter() } }) {
                        Label("Сбросить выбор дней", systemImage: "xmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DS.Color.txt2)
                    }
                    .padding(.bottom, 8)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        FilterChipV2(title: "Все", isActive: selectedFilter == .allGames, filled: true) {
                            selectedFilter = .allGames; onFilterChange(.allGames)
                        }
                        FilterChipV2(title: "Мои", isActive: selectedFilter == .all, filled: true) {
                            selectedFilter = .all; onFilterChange(.all)
                        }
                    }
                    .padding(.horizontal, 15)
                }
                .padding(.bottom, 8)

                if filteredGames.isEmpty {
                    ContentUnavailableView(
                        "Нет игр",
                        systemImage: "tray",
                        description: Text("Добавьте вашу первую игру")
                    )
                    .frame(minHeight: 200)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredGames.enumerated()), id: \.element.gameId) { i, game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                GameRowV2(
                                    type: game.gameType ?? "Игра",
                                    place: game.place?.name ?? game.gameType ?? "Игра",
                                    date: shortDate(game.timestamp),
                                    result: formattedProfit(for: game),
                                    win: winState(for: game),
                                    mvpName: mvpName(for: game),
                                    isSelfMvp: isSelfMvp(game)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                if i == filteredGames.count - 1 { onLoadMore?() }
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("games_list")
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Поиск по типу или заметкам")
        .refreshable { await refreshGames() }
        .overlay { syncOverlay }
    }

    // MARK: - Month title

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: currentMonth).capitalized
    }

    private var rangeSubtitle: String {
        guard isRangeSelection else { return "Выбрать период" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        if let s = periodStart, let e = periodEnd { return "\(f.string(from: s)) – \(f.string(from: e))" }
        if let s = periodStart { return "\(f.string(from: s)) – …" }
        return "Выберите начало"
    }

    private func stepMonth(_ delta: Int) {
        currentMonth = cal.date(byAdding: .month, value: delta, to: currentMonth) ?? currentMonth
    }

    // MARK: - Calendar state

    private var markedDays: Set<Date> {
        Set(games.compactMap { game -> Date? in
            guard let ts = game.timestamp else { return nil }
            return cal.startOfDay(for: ts)
        })
    }

    private func handleDayTap(_ date: Date) {
        withAnimation {
            if isRangeSelection {
                if periodStart == nil {
                    periodStart = date
                } else if periodEnd == nil {
                    if date < periodStart! {
                        let tmp = periodStart; periodStart = date; periodEnd = tmp
                    } else {
                        periodEnd = date
                    }
                } else {
                    periodStart = date; periodEnd = nil
                }
            } else {
                let isSame = selectedDay.map { cal.isDate(date, inSameDayAs: $0) } ?? false
                selectedDay = isSame ? nil : date
            }
        }
    }

    private func toggleRangeMode() {
        isRangeSelection.toggle()
        if isRangeSelection { clearDateFilter() }
    }

    private func clearDateFilter() {
        selectedDay = nil; periodStart = nil; periodEnd = nil
    }

    // MARK: - Filtering

    private var filteredByDate: [Game] {
        if isRangeSelection, let s = periodStart, let e = periodEnd {
            let start = cal.startOfDay(for: s); let end = cal.startOfDay(for: e)
            return games.filter {
                guard let ts = $0.timestamp else { return false }
                let d = cal.startOfDay(for: ts)
                return d >= start && d <= end
            }
        }
        if let day = selectedDay {
            let target = cal.startOfDay(for: day)
            return games.filter { $0.timestamp.map { cal.startOfDay(for: $0) == target } ?? false }
        }
        return games
    }

    private var filteredGames: [Game] {
        guard !searchText.isEmpty else { return filteredByDate }
        let q = searchText.lowercased()
        return filteredByDate.filter {
            ($0.gameType ?? "").lowercased().contains(q) ||
            ($0.notes ?? "").lowercased().contains(q) ||
            ($0.place?.name ?? "").lowercased().contains(q)
        }
    }

    // MARK: - Row data helpers

    private func shortDate(_ ts: Date?) -> String {
        guard let ts else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: ts)
    }

    private func myParticipation(for game: Game) -> GameWithPlayer? {
        guard let uid = userId else { return nil }
        let parts = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return parts.first { $0.playerProfile?.userId == uid }
    }

    private func profitDecimal(for game: Game) -> Decimal? {
        guard let gwp = myParticipation(for: game) else { return nil }
        return Decimal(Int(gwp.cashout)) - Decimal(Int(gwp.buyin)) * Decimal(ChipValue.tengePerChip)
    }

    private func formattedProfit(for game: Game) -> String {
        guard let p = profitDecimal(for: game) else { return "₸ 0" }
        let absVal = p < 0 ? -p : p
        let sign = p > 0 ? "+" : (p < 0 ? "−" : "")
        let fmt = NumberFormatter()
        fmt.groupingSeparator = "\u{00A0}"; fmt.groupingSize = 3
        fmt.usesGroupingSeparator = true; fmt.maximumFractionDigits = 0
        let numStr = fmt.string(from: NSDecimalNumber(decimal: absVal)) ?? "0"
        return "\(sign)₸\u{00A0}\(numStr)"
    }

    private func winState(for game: Game) -> Int {
        guard let p = profitDecimal(for: game) else { return 0 }
        return p > 0 ? 1 : (p < 0 ? -1 : 0)
    }

    private struct MVPCandidate { let profileUserId: UUID?; let name: String; let profit: Decimal }

    private func topMVP(for game: Game) -> MVPCandidate? {
        let parts = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return parts.compactMap { gwp -> MVPCandidate? in
            let name = gwp.playerProfile?.displayName ?? gwp.player?.name ?? ""
            guard !name.isEmpty else { return nil }
            let p = Decimal(Int(gwp.cashout)) - Decimal(Int(gwp.buyin)) * Decimal(ChipValue.tengePerChip)
            return MVPCandidate(profileUserId: gwp.playerProfile?.userId, name: name, profit: p)
        }.max(by: { $0.profit < $1.profit })
    }

    private func mvpName(for game: Game) -> String? { topMVP(for: game)?.name }

    private func isSelfMvp(_ game: Game) -> Bool {
        guard let uid = userId, let mvp = topMVP(for: game) else { return false }
        return mvp.profileUserId == uid
    }

    // MARK: - Sync overlay & refresh

    @ViewBuilder
    private var syncOverlay: some View {
        if syncCoordinator.isSyncing {
            VStack(spacing: 6) {
                ProgressView().scaleEffect(1.2)
                Text("Синхронизация…")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Color.txt3)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
        }
    }

    private func refreshGames() async {
        do { try await syncCoordinator.performIncrementalSync() }
        catch { debugLog("❌ Pull-to-refresh error: \(error)") }
    }
}

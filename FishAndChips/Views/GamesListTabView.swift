import SwiftUI

struct GamesListTabView: View {
    let games: [Game]
    let userId: UUID?
    @Binding var selectedFilter: GameFilter
    let onFilterChange: (GameFilter) -> Void
    
    @State private var searchText = ""
    @State private var selectedDate: Date? = nil
    @State private var periodStart: Date? = nil
    @State private var periodEnd: Date? = nil
    @State private var currentMonth: Date = Date()
    @State private var isRangeSelection: Bool = false
    
    // Группировка игр по дате
    private var gamesByDay: [Date: [Game]] {
        var dict: [Date: [Game]] = [:]
        for game in games {
            guard let timestamp = game.timestamp else { continue }
            let day = Calendar.current.startOfDay(for: timestamp)
            dict[day, default: []].append(game)
        }
        return dict
    }
    
    // Количество игр на конкретный день
    private func countGames(on date: Date) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        return gamesByDay[day]?.count ?? 0
    }
    
    // Фильтрация игр по выбранному периоду/дате
    private var filteredByDate: [Game] {
        if isRangeSelection {
            // Режим выбора периода
            guard let start = periodStart, let end = periodEnd else {
                return games // Если период не выбран полностью, показываем все игры
            }
            let startDay = Calendar.current.startOfDay(for: start)
            let endDay = Calendar.current.startOfDay(for: end)
            return games.filter { game in
                guard let timestamp = game.timestamp else { return false }
                let gameDay = Calendar.current.startOfDay(for: timestamp)
                return gameDay >= startDay && gameDay <= endDay
            }
        } else if let selectedDate = selectedDate {
            // Одиночный выбор даты
            let day = Calendar.current.startOfDay(for: selectedDate)
            return gamesByDay[day] ?? []
        } else {
            // Ничего не выбрано - показываем все игры
            return games
        }
    }
    
    private var filteredBySearch: [Game] {
        let dateFiltered = filteredByDate
        guard !searchText.isEmpty else { return dateFiltered }
        let q = searchText.lowercased()
        return dateFiltered.filter { game in
            (game.gameType ?? "").lowercased().contains(q) ||
            (game.notes ?? "").lowercased().contains(q)
        }
    }
    
    // Дни текущего месяца
    private var daysInMonth: [Date] {
        guard let firstDay = firstDayOfMonth(),
              let range = Calendar.current.range(of: .day, in: .month, for: firstDay)
        else { return [] }
        
        return range.compactMap { day -> Date? in
            var components = Calendar.current.dateComponents([.year, .month], from: firstDay)
            components.day = day
            return Calendar.current.date(from: components)
        }
    }
    
    private func firstDayOfMonth() -> Date? {
        let comps = Calendar.current.dateComponents([.year, .month], from: currentMonth)
        return Calendar.current.date(from: comps)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    private func isSameDay(_ d1: Date, _ d2: Date?) -> Bool {
        guard let d2 = d2 else { return false }
        return Calendar.current.isDate(d1, inSameDayAs: d2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    
    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Календарь
                    VStack(spacing: 12) {
                        // Заголовок с навигацией по месяцам
                        HStack {
                            Button(action: {
                                withAnimation {
                                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Text(monthYearString(from: currentMonth))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Кнопка выбора периода
                        HStack {
                            Button(action: {
                                withAnimation {
                                    isRangeSelection.toggle()
                                    if isRangeSelection {
                                        selectedDate = nil
                                        periodStart = nil
                                        periodEnd = nil
                                    }
                                }
                            }) {
                                Text("Выбрать период")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isRangeSelection ? Color.blue.opacity(0.5) : Color.white.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            // Кнопка сброса фильтра
                            if selectedDate != nil || periodStart != nil {
                                Button(action: {
                                    withAnimation {
                                        selectedDate = nil
                                        periodStart = nil
                                        periodEnd = nil
                                        isRangeSelection = false
                                    }
                                }) {
                                    Text("Сбросить")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.3))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Информация о выбранном периоде
                        Group {
                            if isRangeSelection {
                                if let start = periodStart, let end = periodEnd {
                                    Text("Период: \(formatDate(start)) - \(formatDate(end))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(height: 20)
                                } else if let start = periodStart {
                                    Text("Начало периода: \(formatDate(start))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(height: 20)
                                } else {
                                    // Пустое место для стабильности интерфейса
                                    Text("")
                                        .font(.caption)
                                        .frame(height: 20)
                                }
                            } else if let selectedDate = selectedDate {
                                Text("Выбранная дата: \(formatDate(selectedDate))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(height: 20)
                            } else {
                                // Пустое место для стабильности интерфейса
                                Text("")
                                    .font(.caption)
                                    .frame(height: 20)
                            }
                        }
                        
                        // Сетка дней
                        let columns = Array(repeating: GridItem(.flexible(minimum: 30)), count: 7)
                        LazyVGrid(columns: columns, spacing: 8) {
                            // Заголовки дней недели
                            ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                                Text(day)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Дни месяца
                            ForEach(daysInMonth, id: \.self) { date in
                                DayCell(
                                    date: date,
                                    count: countGames(on: date),
                                    isSelected: {
                                        if isRangeSelection {
                                            if let start = periodStart, periodEnd == nil {
                                                return Calendar.current.isDate(date, inSameDayAs: start)
                                            } else if let start = periodStart, let end = periodEnd {
                                                let day = Calendar.current.startOfDay(for: date)
                                                let startDay = Calendar.current.startOfDay(for: start)
                                                let endDay = Calendar.current.startOfDay(for: end)
                                                return day >= startDay && day <= endDay
                                            } else {
                                                return false
                                            }
                                        } else {
                                            return isSameDay(date, selectedDate)
                                        }
                                    }(),
                                    onTap: {
                                        if isRangeSelection {
                                            if periodStart == nil {
                                                periodStart = date
                                            } else if periodEnd == nil {
                                                if date < periodStart! {
                                                    periodEnd = periodStart
                                                    periodStart = date
                                                } else {
                                                    periodEnd = date
                                                }
                                            } else {
                                                periodStart = date
                                                periodEnd = nil
                                            }
                                        } else {
                                            if isSameDay(date, selectedDate) {
                                                selectedDate = nil
                                            } else {
                                                selectedDate = date
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 20)
                    
                    // Divider между календарем и списком игр
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // Фильтры и список игр
                    VStack(spacing: 12) {
                        // Фильтр по типу игры (кастомный стиль как TabBar)
                        VStack(spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    FilterTabButton(
                                        title: "Мои",
                                        isSelected: selectedFilter == .all,
                                        action: {
                                            selectedFilter = .all
                                            onFilterChange(.all)
                                        }
                                    )
                                    
                                    FilterTabButton(
                                        title: "Все игры",
                                        isSelected: selectedFilter == .allGames,
                                        action: {
                                            selectedFilter = .allGames
                                            onFilterChange(.allGames)
                                        }
                                    )
                                    
                                    FilterTabButton(
                                        title: "Мои игры",
                                        isSelected: selectedFilter == .created,
                                        action: {
                                            selectedFilter = .created
                                            onFilterChange(.created)
                                        }
                                    )
                                    
                                    FilterTabButton(
                                        title: "Участвовал",
                                        isSelected: selectedFilter == .participated,
                                        action: {
                                            selectedFilter = .participated
                                            onFilterChange(.participated)
                                        }
                                    )
                                    
                                    FilterTabButton(
                                        title: "Прибыльные",
                                        isSelected: selectedFilter == .profitable,
                                        action: {
                                            selectedFilter = .profitable
                                            onFilterChange(.profitable)
                                        }
                                    )
                                    
                                    FilterTabButton(
                                        title: "Убыточные",
                                        isSelected: selectedFilter == .losing,
                                        action: {
                                            selectedFilter = .losing
                                            onFilterChange(.losing)
                                        }
                                    )
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        
                        // Список игр
                        if filteredBySearch.isEmpty {
                            ContentUnavailableView(
                                "Нет игр",
                                systemImage: "tray",
                                description: Text("Добавьте вашу первую игру")
                            )
                            .frame(minHeight: 200)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredBySearch, id: \.gameId) { game in
                                    NavigationLink {
                                        if let type = game.gameType, type == "Бильярд" {
                                            BilliardGameDetailView(game: game)
                                        } else {
                                            GameDetailView(game: game)
                                        }
                                    } label: {
                                        GameListRowView(game: game, userId: userId)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Поиск игр")
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
    
    struct GameListRowView: View {
        let game: Game
        let userId: UUID?
        
        private let persistence = PersistenceController.shared
        
        private var mvp: (name: String, profit: Decimal)? {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            guard !participations.isEmpty else { return nil }
            
            let playersWithProfit = participations.compactMap { gwp -> (name: String, profit: Decimal)? in
                guard let player = gwp.player,
                      let name = player.name else { return nil }
                
                // Конвертируем байин в тенге: 1 байин = 2000 тенге
                let buyin = Decimal(Int(gwp.buyin))
                let cashout = Decimal(Int(gwp.cashout))
                let profit = cashout - (buyin * 2000)
                
                return (name: name, profit: profit)
            }
            
            return playersWithProfit.max(by: { $0.profit < $1.profit })
        }
        
        private var formattedMVPProfit: String {
            guard let mvp = mvp else { return "" }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "₸"
            formatter.currencyCode = "KZT"
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSDecimalNumber(decimal: mvp.profit)) ?? "₸0"
        }
        
        private var formattedDate: String {
            guard let timestamp = game.timestamp else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM"
            return formatter.string(from: timestamp)
        }
        
        private var isCreator: Bool {
            guard let userId = userId else { return false }
            return game.creatorUserId == userId
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(game.gameType ?? "Unknown")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if !formattedDate.isEmpty {
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if isCreator {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if let mvp = mvp {
                        HStack(spacing: 4) {
                            Text("MVP:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(mvp.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                            Text(formattedMVPProfit)
                                .font(.caption)
                                .foregroundColor(mvp.profit >= 0 ? .green : .red)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(game.gameWithPlayers?.count ?? 0) игроков")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .liquidGlass(cornerRadius: 12)
        }
    }
    
    struct FilterTabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial.opacity(0.7))
                            } else {
                                Color.clear
                            }
                        }
                    )
            }
        }
    }
}

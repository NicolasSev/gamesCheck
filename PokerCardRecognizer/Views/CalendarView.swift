import SwiftUI
import CoreData

struct CalendarView: View {
    var games: [Game]
    @Binding var selectedDate: Date?
    @Binding var periodStart: Date?
    @Binding var periodEnd: Date?
    // Состояние для отображаемого месяца (начинается с текущего)
    @State private var currentMonth: Date = Date()
    
    // Новые состояния для выбора периода
    @State private var isRangeSelection: Bool = false
//    @State private var periodStart: Date? = nil
//    @State private var periodEnd: Date? = nil

    // Генерируем массив дней для текущего отображаемого месяца
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
    
    // Сгруппируем игры по дате (сбрасывая время)
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
    
    // Список игр за выбранный день (одиночный выбор)
    private var selectedDayGames: [Game] {
        guard let selectedDate = selectedDate else { return [] }
        let day = Calendar.current.startOfDay(for: selectedDate)
        return gamesByDay[day] ?? []
    }
    
    // Если выбран период, получаем игры за период
    private var periodGames: [Game] {
        guard let start = periodStart, let end = periodEnd else { return [] }
        let startDay = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        return games.filter { game in
            if let timestamp = game.timestamp {
                let gameDay = Calendar.current.startOfDay(for: timestamp)
                return gameDay >= startDay && gameDay <= endDay
            }
            return false
        }
    }
    
    var body: some View {
        VStack {
            // Заголовок с навигацией по месяцам
            HStack {
                Button(action: {
                    withAnimation {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString(from: currentMonth))
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Кнопка "Выбрать период"
            HStack {
                Button(action: {
                    isRangeSelection.toggle()
                    if isRangeSelection {
                        // При включении режима сбрасываем одиночный выбор и предыдущий диапазон
                        selectedDate = nil
                        periodStart = nil
                        periodEnd = nil
                    }
                }) {
                    Text("Выбрать период")
                        .font(.subheadline)
                        .padding(6)
                        .background(isRangeSelection ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Сетка дней для currentMonth
            let columns = Array(repeating: GridItem(.flexible(minimum: 30)), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    DayCell(
                        date: date,
                        count: countGames(on: date),
                        isSelected: {
                            if isRangeSelection {
                                // Режим выбора диапазона
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
                                // Логика выбора диапазона:
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
                                // Одиночный выбор
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
            .padding(.horizontal, 8)
            
            // Отображение списка игр
            if isRangeSelection {
                if let start = periodStart, let end = periodEnd {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Игры с \(formatDate(start)) по \(formatDate(end)):")
                            .font(.headline)
                        if periodGames.isEmpty {
                            Text("Нет игр за этот период")
                        } else {
                            let count = periodGames.count
                            let listHeight: CGFloat = count <= 1 ? 100 : 100 + CGFloat(count - 1) * 40
                            List(periodGames) { game in
                                let info = GameResultInfo(game: game)
                                NavigationLink(destination: {
                                    if game.gameType == "Бильярд" {
                                        BilliardGameDetailView(game: game)
                                    } else {
                                        GameDetailView(game: game)
                                    }
                                }, label: {
                                    VStack(alignment: .leading) {
                                        Text(formattedTime(from: game.timestamp))
                                        Text("Дата: \(info.shortDate)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Партии: \(info.batches.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Результат: \(info.resultText)")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                })
                            }
                            .frame(height: listHeight)
                        }
                    }
                    .padding(.horizontal, 8)
                } else if let start = periodStart {
                    Text("Начало периода: \(formatDate(start))")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
            } else {
                // Одиночный режим – выводим игры за выбранный день
                if let selectedDate = selectedDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Игры за \(formatDate(selectedDate)):")
                            .font(.headline)
                        if selectedDayGames.isEmpty {
                            Text("Нет игр в этот день")
                        } else {
                            List(selectedDayGames) { game in
                                NavigationLink(destination: {
                                    // Если тип игры "billiards", открываем специальное вью, иначе стандартное GameDetailView
                                    if let type = game.gameType, type == "Бильярд" {
                                        BilliardGameDetailView(game: game)
                                    } else {
                                        GameDetailView(game: game)
                                    }
                                }, label: {
                                    HStack {
                                        if let type = game.gameType, type == "Бильярд" {
                                            let info = GameResultInfo(game: game)
                                            // Для игр по бильярду — отображаем информацию о партиях
                                            VStack(alignment: .leading) {
                                                Text(formattedTime(from: game.timestamp))
                                                Text("Дата: \(info.shortDate)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("Партии: \(info.batches.count)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("Результат: \(info.resultText)")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        } else {
                                            // Для покера — иконка карты (например, spade)
                                            Image(systemName: "suit.spade.fill")
                                                .foregroundColor(.red)
                                            Text("\(formattedShortDate(from: game.timestamp)) - Байины: \(totalBuyin(for: game)), Тип: - \(String(describing: game.gameType))")
                                        }
                                    }
                                })

                            }
                            .frame(height: 100)
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Выбранные игры")
                            .font(.headline)
                        if games.isEmpty {
                            Text("Нет игр для отображения")
                        } else {
                            let count = games.count
                            let listHeight: CGFloat = count <= 1 ? 100 : 100 + CGFloat(count - 1) * 40
                            List(games) { game in
                                NavigationLink(destination: {
                                    if let type = game.gameType, type == "Бильярд" {
                                        BilliardGameDetailView(game: game)
                                    } else {
                                        GameDetailView(game: game)
                                    }
                                }, label: {
                                    HStack {
                                        if let type = game.gameType, type == "Бильярд" {
                                            let info = GameResultInfo(game: game)
                                            // Для игр по бильярду — отображаем информацию о партиях
                                            VStack(alignment: .leading) {
                                                Text(formattedTime(from: game.timestamp))
                                                Text("Дата: \(info.shortDate)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("Партии: \(info.batches.count)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("Результат: \(info.resultText)")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        } else {
                                            Image(systemName: "suit.spade.fill")
                                                .foregroundColor(.red)
                                            Text("\(formattedShortDate(from: game.timestamp)) - Байины: \(totalBuyin(for: game))")
                                        }
                                    }
                                })
                            }
                            .frame(height: listHeight)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private func formattedShortDate(from date: Date?) -> String {
        guard let date = date else { return "--.--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
    
    // Возвращает первый день текущего отображаемого месяца
    private func firstDayOfMonth() -> Date? {
        let comps = Calendar.current.dateComponents([.year, .month], from: currentMonth)
        return Calendar.current.date(from: comps)
    }
    
    // Форматирование даты для заголовков
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Форматирование времени для отображения в списке игр
    private func formattedTime(from date: Date?) -> String {
        guard let date = date else { return "??:??" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Возвращает общее количество байинов для игры (сумма buyin из всех GameWithPlayer)
    private func totalBuyin(for game: Game) -> Int {
        return (game.gameWithPlayers as? Set<GameWithPlayer>)?.reduce(0) { $0 + Int($1.buyin) } ?? 0
    }
    
    // Форматирование строки "Месяц Год"
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    private func isSameDay(_ d1: Date, _ d2: Date?) -> Bool {
        guard let d2 = d2 else { return false }
        return Calendar.current.isDate(d1, inSameDayAs: d2)
    }
}

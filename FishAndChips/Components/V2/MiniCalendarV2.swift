import SwiftUI

/// Compact 7-column calendar grid for the Games screen.
///
/// Does NOT include month-navigation controls — those live in `MonthNavCardV2`
/// above this component. The parent owns all state and passes pre-computed
/// markers and selection values down; this view is purely presentational.
///
/// - `markedDays` — startOfDay dates that have ≥1 game recorded
/// - `selectedDay` — active single-day filter (nil = none)
/// - `rangeStart` / `rangeEnd` — active range endpoints (nil = range mode off)
struct MiniCalendarV2: View {
    let month: Date
    let markedDays: Set<Date>
    var selectedDay: Date? = nil
    var rangeStart: Date? = nil
    var rangeEnd: Date? = nil
    var onDayTap: ((Date) -> Void)? = nil

    private let cal = Calendar.current
    private let weekLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        VStack(spacing: 4) {
            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DS.Color.txt3)
                        .frame(maxWidth: .infinity)
                }
            }
            // Day grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(gridDays, id: \.self) { date in
                    let inMonth = cal.isDate(date, equalTo: month, toGranularity: .month)
                    DayCellV2(
                        date: date,
                        isToday: cal.isDateInToday(date),
                        hasGame: markedDays.contains(cal.startOfDay(for: date)),
                        isSelected: isSelected(date),
                        isInRange: isInRange(date),
                        isOutOfMonth: !inMonth,
                        onTap: inMonth ? { onDayTap?(date) } : nil
                    )
                }
            }
        }
        .padding(10)
        .glassCardStyle(.plain)
    }

    // MARK: - Grid computation

    private var gridDays: [Date] {
        guard let first = firstDayOfMonth else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let leadingPad = (weekday + 5) % 7  // Mon-first: Mon=0 … Sun=6

        guard let start = cal.date(byAdding: .day, value: -leadingPad, to: first),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }

        let totalDays = leadingPad + range.count
        let total = Int(ceil(Double(totalDays) / 7.0)) * 7
        return (0..<total).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var firstDayOfMonth: Date? {
        cal.date(from: cal.dateComponents([.year, .month], from: month))
    }

    // MARK: - Selection helpers

    private func isSelected(_ date: Date) -> Bool {
        if let rangeStart, let rangeEnd {
            return cal.isDate(date, inSameDayAs: rangeStart) ||
                   cal.isDate(date, inSameDayAs: rangeEnd)
        }
        if let rangeStart { return cal.isDate(date, inSameDayAs: rangeStart) }
        if let selectedDay { return cal.isDate(date, inSameDayAs: selectedDay) }
        return false
    }

    private func isInRange(_ date: Date) -> Bool {
        guard let s = rangeStart, let e = rangeEnd else { return false }
        let d = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: s)
        let end = cal.startOfDay(for: e)
        return d > start && d < end
    }
}

#Preview("MiniCalendarV2") {
    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        VStack(spacing: 12) {
            MonthNavCardV2(title: "Апрель 2026", onPrev: {}, onNext: {})
            MiniCalendarV2(
                month: Date(),
                markedDays: {
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: Date())
                    let d1 = cal.date(byAdding: .day, value: -2, to: today)!
                    let d2 = cal.date(byAdding: .day, value: 5, to: today)!
                    return [today, d1, d2]
                }(),
                selectedDay: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                onDayTap: { _ in }
            )
        }
        .padding()
    }
}

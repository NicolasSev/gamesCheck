import SwiftUI

/// Single-day cell for `MiniCalendarV2`.
///
/// Visual priority (highest wins):
///  1. today          → solid green bg + dark fg
///  2. selected       → green-20%-bg + green 1pt border + bold
///  3. inRange        → green-10%-bg + green text
///  4. hasGame        → green text + green-30%-border
///  5. default        → dim text, no bg
///  6. outOfMonth     → everything above at 0.25 opacity, not tappable
struct DayCellV2: View {
    let date: Date
    let isToday: Bool
    let hasGame: Bool
    let isSelected: Bool
    let isInRange: Bool
    let isOutOfMonth: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(dayNumber)
                        .font(.system(size: 12, weight: labelWeight))
                        .foregroundColor(labelColor)
                    Spacer(minLength: 0)
                }
                if hasGame && !isToday {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 3)
                }
            }
            .frame(width: 32, height: 34)
            .background(cellBg)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(cellBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isOutOfMonth || onTap == nil)
        .opacity(isOutOfMonth ? 0.25 : 1)
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private var labelWeight: Font.Weight {
        isToday || isSelected ? .bold : .regular
    }

    private var labelColor: Color {
        if isToday    { return DS.Color.bgBase }
        if isSelected { return DS.Color.green }
        if isInRange  { return DS.Color.green }
        if hasGame    { return DS.Color.green }
        return DS.Color.txt3
    }

    private var cellBg: Color {
        if isToday    { return DS.Color.green }
        if isSelected { return DS.Color.green.opacity(0.20) }
        if isInRange  { return DS.Color.green.opacity(0.10) }
        return .clear
    }

    private var cellBorder: Color {
        if isToday    { return .clear }
        if isSelected { return DS.Color.green }
        if hasGame    { return DS.Color.green.opacity(0.30) }
        return .clear
    }

    private var dotColor: Color {
        isSelected ? DS.Color.green : DS.Color.green.opacity(0.70)
    }
}

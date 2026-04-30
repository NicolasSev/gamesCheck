import SwiftUI

/// Glass card with prev/next month chevron buttons and a centre title block.
///
/// - `title` — e.g. "Апрель 2026"
/// - `subtitle` — tappable line below the title; triggers `onSubtitleTap`
///   to open the range picker (default: "Выбрать период")
/// - `onPrev` / `onNext` — nil → button rendered at 35% opacity (disabled state)
struct MonthNavCardV2: View {
    let title: String
    var subtitle: String = "Выбрать период"
    var onPrev: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    var onSubtitleTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            navButton(systemName: "chevron.left", action: onPrev)
            Spacer(minLength: 8)
            VStack(spacing: 3) {
                Text(verbatim: title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.Color.txt)
                Button(action: { onSubtitleTap?() }) {
                    Text(verbatim: subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(DS.Color.txt3)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            navButton(systemName: "chevron.right", action: onNext)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCardStyle(.plain)
    }

    @ViewBuilder
    private func navButton(systemName: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Color.green)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DS.Color.green.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DS.Color.green.opacity(0.30), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PressScale())
        .opacity(action == nil ? 0.35 : 1)
        .disabled(action == nil)
    }
}

#Preview("MonthNavCardV2") {
    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        VStack(spacing: 12) {
            MonthNavCardV2(
                title: "Апрель 2026",
                onPrev: {},
                onNext: {},
                onSubtitleTap: {}
            )
            MonthNavCardV2(
                title: "Январь 2026",
                subtitle: "15 янв — 28 янв",
                onPrev: nil,
                onNext: {},
                onSubtitleTap: {}
            )
        }
        .padding()
    }
}

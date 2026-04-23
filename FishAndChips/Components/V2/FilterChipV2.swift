import SwiftUI

struct FilterChipV2: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? DS.Color.green.opacity(0.12)
                                : DS.Color.glass
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? DS.Color.green.opacity(0.35) : DS.Color.border,
                            lineWidth: 1
                        )
                )
                .foregroundColor(isActive ? DS.Color.txt : DS.Color.txt2)
        }
        .buttonStyle(PressScale())
    }
}

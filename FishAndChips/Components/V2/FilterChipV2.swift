import SwiftUI

struct FilterChipV2: View {
    let title: String
    let isActive: Bool
    var filled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(chipBg))
                .overlay(Capsule().stroke(chipBorder, lineWidth: 1))
                .foregroundColor(chipFg)
                .shadow(color: chipGlow, radius: 8, x: 0, y: 0)
        }
        .buttonStyle(PressScale())
    }

    private var chipBg: Color {
        if isActive && filled { return DS.Color.green }
        if isActive { return DS.Color.green.opacity(0.12) }
        return DS.Color.glass
    }

    private var chipBorder: Color {
        if isActive && filled { return DS.Color.green }
        if isActive { return DS.Color.green.opacity(0.35) }
        return DS.Color.border
    }

    private var chipFg: Color {
        if isActive && filled { return DS.Color.bgBase }
        return isActive ? DS.Color.txt : DS.Color.txt2
    }

    private var chipGlow: Color {
        isActive && filled ? DS.Color.green.opacity(0.35) : .clear
    }
}

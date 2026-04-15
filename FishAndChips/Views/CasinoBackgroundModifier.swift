//
//  CasinoBackgroundModifier.swift
//  FishAndChips
//

import SwiftUI

/// Акценты в духе casino dark UI (см. Figma: зелёный CTA, золотой вторичный).
extension Color {
    static let casinoAccentGreen = Color(red: 0.2, green: 0.78, blue: 0.5)
    static let casinoAccentGold = Color(red: 0.95, green: 0.78, blue: 0.3)
}

/// Общий фон с casino-background для экранов приложения
struct CasinoBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            Group {
                if let image = UIImage(named: "casino-background") {
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
                        )
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        )
    }
}

extension View {
    func casinoBackground() -> some View {
        modifier(CasinoBackgroundModifier())
    }
}

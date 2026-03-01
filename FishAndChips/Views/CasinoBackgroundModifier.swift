//
//  CasinoBackgroundModifier.swift
//  FishAndChips
//

import SwiftUI

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

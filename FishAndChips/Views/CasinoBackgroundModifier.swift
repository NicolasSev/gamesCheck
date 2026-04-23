//
//  CasinoBackgroundModifier.swift
//  FishAndChips
//

import SwiftUI

/// Общий фон с casino-background для экранов приложения.
@available(
    *,
    deprecated,
    message: "Use GameBackgroundView for V2 or `.background { GameBackgroundView() }`"
)
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
    @available(
        *,
        deprecated,
        message: "Use GameBackgroundView for V2 or `.background { GameBackgroundView() }`"
    )
    func casinoBackground() -> some View {
        modifier(CasinoBackgroundModifier())
    }
}

//
//  PokerUIHelpers.swift
//  FishAndChips
//

import SwiftUI

extension Card {
    /// Цвет масти для отображения (красный/чёрный)
    var displayColor: Color {
        switch suit {
        case .hearts, .diamonds:
            return .red
        case .spades, .clubs:
            return .black
        }
    }
}

extension Double {
    /// Цвет эквити для отображения (зелёный/оранжевый/красный)
    var equityDisplayColor: Color {
        if self > 60 {
            return .green
        } else if self > 40 {
            return .orange
        } else {
            return .red
        }
    }
}

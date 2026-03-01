//
//  HandAddCardSlot.swift
//  FishAndChips
//

import SwiftUI

struct CardSlot: View {
    let card: Card?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let card = card {
                VStack(spacing: 2) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(card.displayColor)
                    
                    Text(card.suit.symbol)
                        .font(.system(size: 16))
                }
                .frame(width: 50, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            }
        }
    }
    
}

// MARK: - Card Selection Model

enum HandAddCardSelection {
    case playerCard1(Int)
    case playerCard2(Int)
    case board(Int)
}

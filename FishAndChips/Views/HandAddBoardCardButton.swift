//
//  HandAddBoardCardButton.swift
//  FishAndChips
//

import SwiftUI

struct SimpleBoardCardButton: View {
    let card: Card?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let card = card {
                VStack(spacing: 2) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(card.displayColor)
                    
                    Text(card.suit.symbol)
                        .font(.system(size: 14))
                }
                .frame(width: 45, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                )
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 45, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            }
        }
    }
}

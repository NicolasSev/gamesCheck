//
//  HandAddPlayerCardRow.swift
//  FishAndChips
//

import SwiftUI

struct PlayerCardRow: View {
    @Binding var player: HandPlayer
    let excludedCards: [Card]
    let onSelectCard1: () -> Void
    let onSelectCard2: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                if let equity = player.equity {
                    Text(String(format: "%.1f%%", equity))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(equity.equityDisplayColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(equity.equityDisplayColor.opacity(0.2))
                        )
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                CardSlot(
                    card: player.card1,
                    onTap: onSelectCard1
                )
                
                CardSlot(
                    card: player.card2,
                    onTap: onSelectCard2
                )
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
}

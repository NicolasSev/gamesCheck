//
//  HandDetailComponents.swift
//  FishAndChips
//

import SwiftUI

struct PlayerHandRowView: View {
    let player: HandPlayerModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(player.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
                
            HStack(spacing: 6) {
                HandDetailPlayerCardView(notation: player.card1)
                HandDetailPlayerCardView(notation: player.card2)
            }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", player.equity))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(player.equity.equityDisplayColor)
                    
                    Text("(\(player.wins)W/\(player.ties)T)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            HStack(spacing: 10) {
                EquityStreetColumn(street: "Pre-Flop", equity: player.preFlopEquity)
                EquityStreetColumn(street: "Flop", equity: player.flopEquity)
                EquityStreetColumn(street: "Turn", equity: player.turnEquity)
                EquityStreetColumn(street: "River", equity: player.riverEquity)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial.opacity(0.7))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
}

struct EquityStreetColumn: View {
    let street: String
    let equity: Double?
    
    var body: some View {
        VStack(spacing: 2) {
            Text(street)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(equityText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(equityColor)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 64)
    }
    
    private var equityText: String {
        guard let equity = equity else { return "—" }
        return String(format: "%.1f%%", equity)
    }
    
    private var equityColor: Color {
        guard let equity = equity else { return .white.opacity(0.4) }
        return equity.equityDisplayColor
    }
}

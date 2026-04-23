//
//  HandRowView.swift
//  PokerCardRecognizer
//
//  View for displaying a poker hand
//

import SwiftUI

struct HandRowView: View {
    let hand: HandModel
    let game: Game
    @State private var showingDetailSheet = false
    
    var body: some View {
        Button(action: {
            showingDetailSheet = true
        }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Автор: \(hand.creatorName)")
                    Text("Дата: \(formattedDate)")
                    Text(winnerLine)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(hand.players.prefix(3)) { player in
                        HStack(spacing: 4) {
                            Text(player.name)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 70, alignment: .leading)
                            HandRowCardView(notation: player.card1)
                            HandRowCardView(notation: player.card2)
                        }
                    }
                    if hand.players.count > 3 {
                        Text("+\(hand.players.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .glassCardStyle(.plain)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetailSheet) {
            HandDetailView(hand: hand, game: game)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: hand.timestamp)
    }
    
    private var winnerLine: String {
        guard let maxEquity = hand.players.map(\.equity).max() else {
            return "Победитель: —"
        }
        
        let winners = hand.players.filter { abs($0.equity - maxEquity) < 0.01 }
        let names = winners.map(\.name).joined(separator: ", ")
        if winners.count > 1 {
            return "Ничья: \(names)"
        }
        return "Победитель: \(names)"
    }
}

// MARK: - Preview

struct HandRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHand = HandModel(
            gameId: UUID(),
            creatorName: "Ник",
            players: [
                HandPlayerModel(
                    name: "Игрок 1",
                    card1: "Ah",
                    card2: "As",
                    equity: 82.4,
                    wins: 8240,
                    ties: 0,
                    losses: 1760
                ),
                HandPlayerModel(
                    name: "Игрок 2",
                    card1: "Kd",
                    card2: "Kc",
                    equity: 17.6,
                    wins: 1760,
                    ties: 0,
                    losses: 8240
                )
            ],
            boardCards: ["7d", "9d", "Ts"],
            oddsResult: OddsResultModel(
                iterations: 1000,
                executionTime: 0.085,
                gameVariant: "texas_holdem"
            )
        )
        
        // Note: game parameter is required but not used in preview
        // You would need to provide a mock Game entity for a complete preview
        Text("Preview requires Game entity")
            .background(Color(red: 0.1, green: 0.15, blue: 0.2))
            .previewLayout(.sizeThatFits)
    }
}

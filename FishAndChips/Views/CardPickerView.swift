//
//  CardPickerView.swift
//  PokerCardRecognizer
//
//  Card picker component for selecting poker cards
//

import SwiftUI

struct CardPickerView: View {
    @Binding var selectedCard: Card?
    let excludedCards: [Card]
    @Environment(\.dismiss) var dismiss
    
    private let ranks: [CardRank] = [.ace, .king, .queen, .jack, .ten, .nine, .eight, .seven, .six, .five, .four, .three, .two]
    private let suits: [CardSuit] = [.spades, .hearts, .diamonds, .clubs]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(suits, id: \.self) { suit in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(suitName(suit))
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ranks, id: \.self) { rank in
                                        let card = Card(rank: rank, suit: suit)
                                        let isExcluded = excludedCards.contains(card)
                                        
                                        CardButton(
                                            card: card,
                                            isExcluded: isExcluded
                                        ) {
                                            if !isExcluded {
                                                selectedCard = card
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(red: 0.1, green: 0.15, blue: 0.2))
            .navigationTitle("Выберите карту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func suitName(_ suit: CardSuit) -> String {
        switch suit {
        case .spades: return "Пики ♠"
        case .hearts: return "Червы ♥"
        case .diamonds: return "Бубны ♦"
        case .clubs: return "Трефы ♣"
        }
    }
}

struct CardButton: View {
    let card: Card
    let isExcluded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(card.rank.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(cardColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 20))
            }
            .frame(width: 60, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isExcluded ? Color.gray.opacity(0.3) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isExcluded ? Color.gray : Color.clear, lineWidth: 2)
            )
            .opacity(isExcluded ? 0.4 : 1.0)
        }
        .disabled(isExcluded)
    }
    
    private var cardColor: Color {
        if isExcluded {
            return .gray
        }
        switch card.suit {
        case .hearts, .diamonds:
            return .red
        case .spades, .clubs:
            return .black
        }
    }
}

// MARK: - Preview

struct CardPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CardPickerView(
            selectedCard: .constant(nil),
            excludedCards: []
        )
    }
}

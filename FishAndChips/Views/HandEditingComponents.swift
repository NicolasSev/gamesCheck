//
//  HandEditingComponents.swift
//  PokerCardRecognizer
//
//  Shared components for hand editing and creation
//

import SwiftUI

// MARK: - Data Models

struct HandPlayer: Identifiable {
    let id = UUID()
    var name: String
    var card1: Card?
    var card2: Card?
    var equity: Double?
}

// MARK: - UI Components

struct PlayerCardSelectionRow: View {
    @Binding var player: HandPlayer
    let allSelectedCards: [Card]
    let onSelectCard1: () -> Void
    let onSelectCard2: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Имя игрока
            Text(player.name)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            
            // Карта 1
            PlayerCardButton(card: player.card1, allSelectedCards: allSelectedCards, onTap: onSelectCard1)
            
            // Карта 2
            PlayerCardButton(card: player.card2, allSelectedCards: allSelectedCards, onTap: onSelectCard2)
            
            Spacer()
            
            // Кнопка удаления
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

struct PlayerCardButton: View {
    let card: Card?
    let allSelectedCards: [Card]
    let onTap: () -> Void
    
    private var isCardAlreadySelected: Bool {
        guard let card = card else { return false }
        return allSelectedCards.contains(card)
    }
    
    var body: some View {
        Button(action: onTap) {
            if let card = card {
                VStack(spacing: 2) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(cardColor(card))
                    Text(card.suit.symbol)
                        .font(.system(size: 14))
                }
                .frame(width: 45, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isCardAlreadySelected ? Color.red : Color.clear, lineWidth: 2)
                        )
                )
            } else {
                VStack {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .frame(width: 45, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(.gray)
                            )
                    )
                .foregroundColor(.gray)
            }
        }
    }
    
    private func cardColor(_ card: Card) -> Color {
        switch card.suit {
        case .hearts, .diamonds:
            return .red
        case .spades, .clubs:
            return .black
        }
    }
}

struct BoardCardButton: View {
    let card: Card?
    let allSelectedCards: [Card]
    let onTap: () -> Void
    let onClear: () -> Void
    
    private var isCardAlreadySelected: Bool {
        guard let card = card else { return false }
        return allSelectedCards.contains(card)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                if let card = card {
                    VStack(spacing: 2) {
                        Text(card.rank.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(cardColor(card))
                        Text(card.suit.symbol)
                            .font(.system(size: 16))
                    }
                    .frame(width: 50, height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCardAlreadySelected ? Color.red : Color.clear, lineWidth: 2)
                            )
                    )
                } else {
                    VStack {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .frame(width: 50, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        .foregroundColor(.gray)
                                )
                        )
                    .foregroundColor(.gray)
                }
            }
            
            if card != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 8, y: -8)
            }
        }
    }
    
    private func cardColor(_ card: Card) -> Color {
        switch card.suit {
        case .hearts, .diamonds:
            return .red
        case .spades, .clubs:
            return .black
        }
    }
}

struct SimplePlayerPickerSheet: View {
    let availablePlayers: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(availablePlayers, id: \.self) { playerName in
                Button(action: {
                    onSelect(playerName)
                }) {
                    Text(playerName)
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Выбрать игрока")
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
}

struct OddsResultView: View {
    let oddsResult: OddsResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты расчета")
                .font(.headline)
            
            ForEach(oddsResult.equities.indices, id: \.self) { index in
                let equity = oddsResult.equities[index]
                HStack {
                    Text("Игрок \(index + 1)")
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", equity.equity))
                            .font(.headline)
                            .foregroundColor(equityColor(equity.equity))
                        Text("\(equity.wins)W / \(equity.ties)T / \(equity.losses)L")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Text("Симуляций: \(oddsResult.iterations)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(String(format: "Время: %.0fms", oddsResult.executionTime * 1000))
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private func equityColor(_ equity: Double) -> Color {
        if equity > 60 {
            return .green
        } else if equity > 40 {
            return .orange
        } else {
            return .red
        }
    }
}

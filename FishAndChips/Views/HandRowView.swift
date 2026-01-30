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
            .liquidGlass(cornerRadius: 12)
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

// Просмотр раздачи (открывается по клику)
struct HandDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    @State private var currentHand: HandModel
    
    init(hand: HandModel, game: Game) {
        self.game = game
        _currentHand = State(initialValue: hand)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Кнопка редактирования
                    HStack {
                        Spacer()
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Редактировать")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Борд
                    if !displayHand.boardCards.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Борд")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 10) {
                                ForEach(displayHand.boardCards, id: \.self) { cardNotation in
                                    HandDetailBoardCardView(notation: cardNotation)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Игроки и их equity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Игроки")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(displayHand.players) { player in
                            PlayerHandRowView(player: player)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Информация о расчете
                    Text("Симуляций: \(displayHand.oddsResult.iterations), Время: \(String(format: "%.0f", displayHand.oddsResult.executionTime * 1000))ms")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Детали раздачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .background(
                Group {
                    if let image = backgroundImage {
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
                                .ignoresSafeArea()
                            )
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            HandEditView(hand: displayHand, game: game)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handDidUpdate)) { _ in
            if let updated = HandsStorageService.shared.getAllHands().first(where: { $0.id == currentHand.id }) {
                currentHand = updated
            }
        }
    }
    
    private var displayHand: HandModel {
        let normalizedPlayers = currentHand.players.map { player in
            HandPlayerModel(
                id: player.id,
                name: player.name,
                card1: player.card1,
                card2: player.card2,
                equity: normalizeEquity(player.equity),
                wins: player.wins,
                ties: player.ties,
                losses: player.losses,
                preFlopEquity: player.preFlopEquity.map(normalizeEquity),
                flopEquity: player.flopEquity.map(normalizeEquity),
                turnEquity: player.turnEquity.map(normalizeEquity),
                riverEquity: player.riverEquity.map(normalizeEquity)
            )
        }
        
        return HandModel(
            id: currentHand.id,
            gameId: currentHand.gameId,
            creatorName: currentHand.creatorName,
            players: normalizedPlayers,
            boardCards: currentHand.boardCards,
            oddsResult: currentHand.oddsResult,
            timestamp: currentHand.timestamp
        )
    }
    
    private func normalizeEquity(_ value: Double) -> Double {
        return value > 100 ? value / 100 : value
    }
}

struct PlayerHandRowView: View {
    let player: HandPlayerModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Основная строка
            HStack(spacing: 12) {
                // Имя игрока
                Text(player.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
                
                // Карты
            HStack(spacing: 6) {
                HandDetailPlayerCardView(notation: player.card1)
                HandDetailPlayerCardView(notation: player.card2)
            }
                
                Spacer()
                
                // Equity и статистика
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", player.equity))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(equityColor(player.equity))
                    
                    Text("(\(player.wins)W/\(player.ties)T)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Эквити по улицам (горизонтально)
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
        if equity > 60 {
            return .green
        } else if equity > 40 {
            return .orange
        } else {
            return .red
        }
    }
}

struct CardDisplayView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(cardColor(card))
                
                Text(card.suit.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(cardColor(card))
            }
            .frame(width: 35, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
            )
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 35, height: 50)
                .cornerRadius(6)
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

struct HandDetailBoardCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(cardColor(card))
                
                Text(card.suit.symbol)
                    .font(.system(size: 14))
                    .foregroundColor(cardColor(card))
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
            )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 64)
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

struct HandDetailPlayerCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(cardColor(card))
                
                Text(card.suit.symbol)
                    .font(.system(size: 11))
                    .foregroundColor(cardColor(card))
            }
            .frame(width: 36, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
            )
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 52)
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

struct MiniCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            HStack(spacing: 1) {
                Text(card.rank.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(cardColor(card))
                
                Text(card.suit.symbol)
                    .font(.system(size: 9))
                    .foregroundColor(cardColor(card))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
            )
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

struct HandRowCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            HStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(cardColor(card))
                
                Text(card.suit.symbol)
                    .font(.system(size: 10))
                    .foregroundColor(cardColor(card))
            }
            .frame(width: 32, height: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
            )
            .frame(width: 42, height: 26)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 42, height: 26)
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

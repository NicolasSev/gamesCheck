//
//  HandEditView.swift
//  PokerCardRecognizer
//
//  View for editing an existing poker hand
//

import SwiftUI
import CoreData

struct HandEditView: View {
    let hand: HandModel
    let game: Game
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlayers: [HandPlayer] = []
    @State private var boardCards: [Card?] = [nil, nil, nil, nil, nil]
    @State private var showingPlayerPicker = false
    @State private var editingCard: EditingCardInfo?
    @State private var calculatedOdds: OddsResult?
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    private let calculationIterations = 1000
    private let streetIterations = 1000
    
    private var gamePlayers: [String] {
        if let gameWithPlayers = game.gameWithPlayers as? Set<GameWithPlayer> {
            let playerNames = gameWithPlayers.compactMap { $0.player?.name }
            return Array(Set(playerNames)).sorted()
        }
        return []
    }
    
    private var allSelectedCards: [Card] {
        var cards: [Card] = []
        for player in selectedPlayers {
            if let card1 = player.card1 { cards.append(card1) }
            if let card2 = player.card2 { cards.append(card2) }
        }
        for boardCard in boardCards {
            if let card = boardCard { cards.append(card) }
        }
        return cards
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                    // Игроки
                    VStack(spacing: 12) {
                        HStack {
                            Text("Игроки")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showingPlayerPicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить игрока")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if selectedPlayers.isEmpty {
                            Text("Нет игроков")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(selectedPlayers.indices, id: \.self) { index in
                                PlayerCardSelectionRow(
                                    player: $selectedPlayers[index],
                                    allSelectedCards: allSelectedCards,
                                    onSelectCard1: {
                                        editingCard = EditingCardInfo(playerIndex: index, cardNumber: 1)
                                    },
                                    onSelectCard2: {
                                        editingCard = EditingCardInfo(playerIndex: index, cardNumber: 2)
                                    },
                                    onRemove: {
                                        selectedPlayers.remove(at: index)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Борд
                    VStack(spacing: 12) {
                        Text("Борд (опционально)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { index in
                                BoardCardButton(
                                    card: boardCards[index],
                                    allSelectedCards: allSelectedCards,
                                    onTap: {
                                        editingCard = EditingCardInfo(boardIndex: index)
                                    },
                                    onClear: {
                                        boardCards[index] = nil
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Кнопка расчета
                    Button(action: calculateOdds) {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "function")
                                Text("Рассчитать эквити")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedPlayers.count >= 2 ? Color.blue : Color.gray)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(selectedPlayers.count < 2 || isCalculating)
                    .padding(.horizontal)
                    
                    // Результаты
                    if let odds = calculatedOdds {
                        OddsResultView(oddsResult: odds)
                            .padding(.horizontal)
                    }
                    
                    // Ошибка
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal)
                    }
                    
                        Spacer(minLength: 80)
                    }
                    .padding(.vertical)
                }
                
                if isSaving {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Сохранение...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveAndClose()
                    }
                    .disabled(calculatedOdds == nil || isSaving)
                }
            }
            .sheet(isPresented: $showingPlayerPicker) {
                SimplePlayerPickerSheet(
                    availablePlayers: gamePlayers.filter { playerName in
                        !selectedPlayers.contains(where: { $0.name == playerName })
                    },
                    onSelect: { playerName in
                        selectedPlayers.append(HandPlayer(name: playerName))
                        showingPlayerPicker = false
                    }
                )
            }
            .sheet(item: $editingCard) { cardInfo in
                CardPickerView(
                    selectedCard: Binding(
                        get: {
                            if let playerIndex = cardInfo.playerIndex {
                                return cardInfo.cardNumber == 1 ? selectedPlayers[playerIndex].card1 : selectedPlayers[playerIndex].card2
                            } else if let boardIndex = cardInfo.boardIndex {
                                return boardCards[boardIndex]
                            }
                            return nil
                        },
                        set: { newCard in
                            if let playerIndex = cardInfo.playerIndex {
                                if cardInfo.cardNumber == 1 {
                                    selectedPlayers[playerIndex].card1 = newCard
                                } else {
                                    selectedPlayers[playerIndex].card2 = newCard
                                }
                            } else if let boardIndex = cardInfo.boardIndex {
                                boardCards[boardIndex] = newCard
                            }
                            editingCard = nil
                        }
                    ),
                    excludedCards: allSelectedCards
                )
            }
        }
        .onAppear {
            loadHandData()
        }
    }
    
    private func loadHandData() {
        // Загружаем существующие данные раздачи
        selectedPlayers = hand.players.map { playerModel in
            var handPlayer = HandPlayer(name: playerModel.name)
            handPlayer.card1 = try? Card(notation: playerModel.card1)
            handPlayer.card2 = try? Card(notation: playerModel.card2)
            return handPlayer
        }
        
        // Загружаем карты борда
        for (index, cardNotation) in hand.boardCards.enumerated() where index < 5 {
            boardCards[index] = try? Card(notation: cardNotation)
        }
        
        // Загружаем существующие odds
        calculatedOdds = OddsResult(
            equities: hand.players.enumerated().map { index, player in
                PlayerEquity(
                    playerIndex: index,
                    hand: player.card1 + player.card2,
                    equity: normalizeEquity(player.equity),
                    wins: player.wins,
                    ties: player.ties,
                    losses: player.losses,
                    totalSimulations: hand.oddsResult.iterations
                )
            },
            executionTime: hand.oddsResult.executionTime,
            iterations: hand.oddsResult.iterations,
            gameVariant: .texasHoldem
        )
    }
    
    private func calculateOdds() {
        guard selectedPlayers.count >= 2 else {
            errorMessage = "Нужно минимум 2 игрока"
            return
        }
        
        // Проверяем, что у всех игроков выбраны обе карты
        for player in selectedPlayers {
            guard player.card1 != nil && player.card2 != nil else {
                errorMessage = "У всех игроков должны быть выбраны обе карты"
                return
            }
        }
        
        isCalculating = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let calculator = PokerOddsCalculator(iterations: calculationIterations)
                
                // Формируем руки игроков
                let playerHands: [[Card]] = self.selectedPlayers.compactMap { player in
                    guard let c1 = player.card1, let c2 = player.card2 else { return nil }
                    return [c1, c2]
                }
                
                // Формируем борд (только непустые карты)
                let board = self.boardCards.compactMap { $0 }
                
                let result = try calculator.calculate(playerHands: playerHands, board: board)
                
                DispatchQueue.main.async {
                    self.calculatedOdds = result
                    self.isCalculating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Ошибка расчета: \(error.localizedDescription)"
                    self.isCalculating = false
                }
            }
        }
    }
    
    private func saveAndClose() {
        errorMessage = nil
        guard selectedPlayers.count >= 2 else {
            errorMessage = "Нужно минимум 2 игрока"
            return
        }
        
        for player in selectedPlayers {
            guard player.card1 != nil && player.card2 != nil else {
                errorMessage = "У всех игроков должны быть выбраны обе карты"
                return
            }
        }
        
        isSaving = true
        
        let fullCalculator = PokerOddsCalculator(iterations: calculationIterations)
        let streetCalculator = PokerOddsCalculator(iterations: streetIterations)
        
        let playerHands: [[Card]] = selectedPlayers.compactMap { player in
            guard let c1 = player.card1, let c2 = player.card2 else { return nil }
            return [c1, c2]
        }
        
        let boardCardsList = self.boardCards.compactMap { $0 }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let odds = try fullCalculator.calculate(playerHands: playerHands, board: boardCardsList)
                
                var preFlopOdds: OddsResult?
                var flopOdds: OddsResult?
                var turnOdds: OddsResult?
                
                preFlopOdds = try? streetCalculator.calculate(playerHands: playerHands, board: [])
                
                if boardCardsList.count >= 3 {
                    let flopBoard = Array(boardCardsList.prefix(3))
                    flopOdds = try? streetCalculator.calculate(playerHands: playerHands, board: flopBoard)
                }
                
                if boardCardsList.count >= 4 {
                    let turnBoard = Array(boardCardsList.prefix(4))
                    turnOdds = try? streetCalculator.calculate(playerHands: playerHands, board: turnBoard)
                }
                
                DispatchQueue.main.async {
                    let updatedPlayers = self.selectedPlayers.enumerated().map { (index, player) -> HandPlayerModel in
                        let equity = odds.equities.indices.contains(index) ? odds.equities[index] : nil
                        
                        return HandPlayerModel(
                            name: player.name,
                            card1: player.card1?.shortNotation ?? "",
                            card2: player.card2?.shortNotation ?? "",
                            equity: equity?.equity ?? 0,
                            wins: equity?.wins ?? 0,
                            ties: equity?.ties ?? 0,
                            losses: equity?.losses ?? 0,
                            preFlopEquity: preFlopOdds?.equities.indices.contains(index) ?? false ? preFlopOdds!.equities[index].equity : nil,
                            flopEquity: flopOdds?.equities.indices.contains(index) ?? false ? flopOdds!.equities[index].equity : nil,
                            turnEquity: turnOdds?.equities.indices.contains(index) ?? false ? turnOdds!.equities[index].equity : nil,
                            riverEquity: odds.equities.indices.contains(index) ? odds.equities[index].equity : nil
                        )
                    }
                    
                    let updatedHand = HandModel(
                        id: self.hand.id,
                        gameId: self.game.gameId,
                        creatorName: self.hand.creatorName,
                        players: updatedPlayers,
                        boardCards: self.boardCards.compactMap { $0?.shortNotation },
                        oddsResult: OddsResultModel(
                            iterations: odds.iterations,
                            executionTime: odds.executionTime,
                            gameVariant: "texas_holdem"
                        ),
                        timestamp: self.hand.timestamp
                    )
                    
                    HandsStorageService.shared.updateHand(updatedHand)
                    NotificationCenter.default.post(name: .handDidUpdate, object: updatedHand.id)
                    
                    self.isSaving = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Ошибка расчета: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }

    private func normalizeEquity(_ value: Double) -> Double {
        return value > 100 ? value / 100 : value
    }
}

// MARK: - Supporting Types

struct EditingCardInfo: Identifiable {
    let id = UUID()
    let playerIndex: Int?
    let cardNumber: Int
    let boardIndex: Int?
    
    init(playerIndex: Int, cardNumber: Int) {
        self.playerIndex = playerIndex
        self.cardNumber = cardNumber
        self.boardIndex = nil
    }
    
    init(boardIndex: Int) {
        self.playerIndex = nil
        self.cardNumber = 0
        self.boardIndex = boardIndex
    }
}

// Note: HandPlayer and UI components are imported from HandEditingComponents.swift

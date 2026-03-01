//
//  HandAddView.swift
//  PokerCardRecognizer
//
//  View for adding a new poker hand with equity calculation
//

import SwiftUI
import CoreData

struct HandAddView: View {
    let game: Game
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlayers: [HandPlayer] = []
    @State private var boardCards: [Card?] = [nil, nil, nil, nil, nil]
    @State private var showingPlayerPicker = false
    @State private var showingCardPicker = false
    @State private var activeCardSelection: HandAddCardSelection?
    @State private var calculatedOdds: OddsResult?
    @State private var isCalculating = false
    @State private var errorMessage: String?
    
    private var gamePlayers: [String] {
        // Получаем игроков через gameWithPlayers (связь Game -> GameWithPlayer -> Player)
        if let gameWithPlayers = game.gameWithPlayers as? Set<GameWithPlayer> {
            let playerNames = gameWithPlayers.compactMap { $0.player?.name }
            return Array(Set(playerNames)).sorted() // Убираем дубликаты и сортируем
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Заголовок
                    Text("Новая раздача")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    // Игроки
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Игроки")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: { showingPlayerPicker = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if selectedPlayers.isEmpty {
                            Text("Добавьте минимум 2 игроков")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            ForEach(selectedPlayers.indices, id: \.self) { index in
                                PlayerCardRow(
                                    player: $selectedPlayers[index],
                                    excludedCards: allSelectedCards,
                                    onSelectCard1: {
                                        activeCardSelection = .playerCard1(index)
                                        showingCardPicker = true
                                    },
                                    onSelectCard2: {
                                        activeCardSelection = .playerCard2(index)
                                        showingCardPicker = true
                                    },
                                    onRemove: {
                                        selectedPlayers.remove(at: index)
                                        calculatedOdds = nil
                                    }
                                )
                            }
                        }
                    }
                    
                    // Борд
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Борд (опционально)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Флоп
                            HStack(spacing: 12) {
                                Text("Флоп")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                
                                ForEach(0..<3, id: \.self) { index in
                                    SimpleBoardCardButton(
                                        card: boardCards[index],
                                        onTap: {
                                            activeCardSelection = .board(index)
                                            showingCardPicker = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Терн
                            HStack(spacing: 12) {
                                Text("Терн")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                
                                SimpleBoardCardButton(
                                    card: boardCards[3],
                                    onTap: {
                                        activeCardSelection = .board(3)
                                        showingCardPicker = true
                                    }
                                )
                            }
                            .padding(.horizontal)
                            
                            // Ривер
                            HStack(spacing: 12) {
                                Text("Ривер")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                
                                SimpleBoardCardButton(
                                    card: boardCards[4],
                                    onTap: {
                                        activeCardSelection = .board(4)
                                        showingCardPicker = true
                                    }
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Кнопка расчета
                    Button(action: calculateOdds) {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "function")
                                Text("Рассчитать эквити")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canCalculate ? Color.blue : Color.gray)
                        )
                    }
                    .disabled(!canCalculate || isCalculating)
                    .padding(.horizontal)
                    
                    // Ошибка
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Результаты
                    if let odds = calculatedOdds {
                        OddsResultCard(result: odds)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .background(Color(red: 0.1, green: 0.15, blue: 0.2))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveAndClose()
                    }
                    .disabled(calculatedOdds == nil)
                }
            }
            .sheet(isPresented: $showingPlayerPicker) {
                PlayerPickerSheet(
                    availablePlayers: availablePlayers,
                    onSelect: { playerName in
                        addPlayer(name: playerName)
                    }
                )
            }
            .sheet(isPresented: $showingCardPicker) {
                CardPickerView(
                    selectedCard: Binding(
                        get: { getSelectedCard() },
                        set: { card in
                            if let card = card {
                                setSelectedCard(card)
                            }
                        }
                    ),
                    excludedCards: allSelectedCards
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var availablePlayers: [String] {
        let alreadyAdded = Set(selectedPlayers.map { $0.name })
        return gamePlayers.filter { !alreadyAdded.contains($0) }
    }
    
    private var canCalculate: Bool {
        return selectedPlayers.count >= 2 &&
               selectedPlayers.allSatisfy { $0.card1 != nil && $0.card2 != nil }
    }
    
    // MARK: - Actions
    
    private func addPlayer(name: String) {
        let player = HandPlayer(name: name)
        selectedPlayers.append(player)
        calculatedOdds = nil
    }
    
    private func getSelectedCard() -> Card? {
        guard let selection = activeCardSelection else { return nil }
        
        switch selection {
        case .playerCard1(let index):
            guard selectedPlayers.indices.contains(index) else { return nil }
            return selectedPlayers[index].card1
        case .playerCard2(let index):
            guard selectedPlayers.indices.contains(index) else { return nil }
            return selectedPlayers[index].card2
        case .board(let index):
            guard boardCards.indices.contains(index) else { return nil }
            return boardCards[index]
        }
    }
    
    private func setSelectedCard(_ card: Card) {
        guard let selection = activeCardSelection else { return }
        
        switch selection {
        case .playerCard1(let index):
            if selectedPlayers.indices.contains(index) {
                selectedPlayers[index].card1 = card
            }
        case .playerCard2(let index):
            if selectedPlayers.indices.contains(index) {
                selectedPlayers[index].card2 = card
            }
        case .board(let index):
            if boardCards.indices.contains(index) {
                boardCards[index] = card
            }
        }
        
        calculatedOdds = nil
    }
    
    private func saveAndClose() {
        guard let odds = calculatedOdds else { return }
        
        // Получаем имя текущего пользователя
        let currentUserName = getCurrentUserName()
        
        // Рассчитываем эквити для каждой улицы
        let boardNotations = boardCards.compactMap { $0?.shortNotation }
        
        // Pre-flop (всегда рассчитываем - только карты игроков)
        let preFlopOdds = calculateEquityForStreet(boardSize: 0)
        
        // Flop (если есть хотя бы 3 карты)
        let flopOdds = boardNotations.count >= 3 ? calculateEquityForStreet(boardSize: 3) : nil
        
        // Turn (если есть хотя бы 4 карты)
        let turnOdds = boardNotations.count >= 4 ? calculateEquityForStreet(boardSize: 4) : nil
        
        // River (если есть все 5 карт, используем основной результат)
        let riverOdds = boardNotations.count == 5 ? odds : nil
        
        // Создаем модели игроков с эквити для каждой улицы
        let handPlayers = selectedPlayers.enumerated().map { index, player in
            let equity = odds.equities.indices.contains(index) ? odds.equities[index] : nil
            
            let preFlopEquity: Double? = {
                guard let odds = preFlopOdds, odds.equities.indices.contains(index) else { return nil }
                return odds.equities[index].equity
            }()
            
            let flopEquity: Double? = {
                guard let odds = flopOdds, odds.equities.indices.contains(index) else { return nil }
                return odds.equities[index].equity
            }()
            
            let turnEquity: Double? = {
                guard let odds = turnOdds, odds.equities.indices.contains(index) else { return nil }
                return odds.equities[index].equity
            }()
            
            let riverEquity: Double? = {
                guard let odds = riverOdds, odds.equities.indices.contains(index) else { return nil }
                return odds.equities[index].equity
            }()
            
            return HandPlayerModel(
                name: player.name,
                card1: player.card1?.shortNotation ?? "",
                card2: player.card2?.shortNotation ?? "",
                equity: equity?.equity ?? 0,
                wins: equity?.wins ?? 0,
                ties: equity?.ties ?? 0,
                losses: equity?.losses ?? 0,
                preFlopEquity: preFlopEquity,
                flopEquity: flopEquity,
                turnEquity: turnEquity,
                riverEquity: riverEquity
            )
        }
        
        // Создаем модель результата
        let oddsResultModel = OddsResultModel(
            iterations: odds.iterations,
            executionTime: odds.executionTime,
            gameVariant: odds.gameVariant.rawValue
        )
        
        // Создаем и сохраняем раздачу
        let hand = HandModel(
            gameId: game.gameId,
            creatorName: currentUserName,
            players: handPlayers,
            boardCards: boardNotations,
            oddsResult: oddsResultModel
        )
        
        HandsStorageService.shared.saveHand(hand)
        
        dismiss()
    }
    
    private func calculateEquityForStreet(boardSize: Int) -> OddsResult? {
        let playerHands = selectedPlayers.compactMap { player -> String? in
            guard let card1 = player.card1, let card2 = player.card2 else {
                return nil
            }
            return card1.shortNotation + card2.shortNotation
        }
        
        guard playerHands.count == selectedPlayers.count else { return nil }
        
        let boardNotation: String? = {
            let cards = boardCards.compactMap { $0 }.prefix(boardSize)
            return cards.isEmpty ? nil : cards.map { $0.shortNotation }.joined()
        }()
        
        do {
            let result = try PokerOddsCalculator.calculate(
                players: playerHands,
                board: boardNotation,
                gameVariant: .texasHoldem,
                iterations: 1000 // Меньше итераций для быстрых расчетов
            )
            return result
        } catch {
            return nil
        }
    }
    
    private func getCurrentUserName() -> String {
        let keychain = KeychainService.shared
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            return "Неизвестный"
        }
        
        // Пытаемся найти имя пользователя
        let fetchRequest = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        if let user = try? viewContext.fetch(fetchRequest).first {
            return user.username ?? "Неизвестный"
        }
        
        return "Неизвестный"
    }
    
    private func calculateOdds() {
        guard canCalculate else { return }
        
        isCalculating = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Подготавливаем руки игроков
                let playerHands = selectedPlayers.compactMap { player -> String? in
                    guard let card1 = player.card1, let card2 = player.card2 else {
                        return nil
                    }
                    return card1.shortNotation + card2.shortNotation
                }
                
                // Подготавливаем борд
                let boardNotation: String? = {
                    let cards = boardCards.compactMap { $0 }
                    return cards.isEmpty ? nil : cards.map { $0.shortNotation }.joined()
                }()
                
                // Рассчитываем odds
                let result = try PokerOddsCalculator.calculate(
                    players: playerHands,
                    board: boardNotation,
                    gameVariant: .texasHoldem,
                    iterations: 1000
                )
                
                DispatchQueue.main.async {
                    calculatedOdds = result
                    
                    // Обновляем equity для каждого игрока
                    for (index, equity) in result.equities.enumerated() {
                        if selectedPlayers.indices.contains(index) {
                            selectedPlayers[index].equity = equity.equity
                        }
                    }
                    
                    isCalculating = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isCalculating = false
                }
            }
        }
    }
    
}

// MARK: - Preview

struct HandAddView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.gameId = UUID()
        game.timestamp = Date()
        
        return HandAddView(game: game)
            .environment(\.managedObjectContext, context)
    }
}

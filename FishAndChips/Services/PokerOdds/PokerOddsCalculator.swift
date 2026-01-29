//
//  PokerOddsCalculator.swift
//  PokerCardRecognizer
//
//  Public API for poker odds calculation
//

import Foundation

/// Главный класс для расчета покерных вероятностей
class PokerOddsCalculator {
    
    /// Количество симуляций по умолчанию
    static let defaultIterations = 10000
    
    /// Рассчитывает equity для всех игроков (статический метод для быстрого использования)
    /// - Parameters:
    ///   - players: Массив строк с картами игроков (формат: "AhKs", "TdTc")
    ///   - board: Опциональная строка с картами борда (формат: "7d9dTs")
    ///   - gameVariant: Вариант игры (.texasHoldem или .shortDeck)
    ///   - iterations: Количество симуляций (по умолчанию 10000)
    /// - Returns: OddsResult с equity для каждого игрока
    /// - Throws: PokerOddsError при некорректных данных
    static func calculate(
        players: [String],
        board: String? = nil,
        gameVariant: GameVariant = .texasHoldem,
        iterations: Int = defaultIterations
    ) throws -> OddsResult {
        let calculator = PokerOddsCalculator(
            gameVariant: gameVariant,
            iterations: iterations
        )
        return try calculator.calculate(players: players, board: board)
    }
    
    // MARK: - Instance Properties
    
    /// Вариант игры
    var gameVariant: GameVariant
    
    /// Количество симуляций
    var iterations: Int
    
    // MARK: - Initialization
    
    /// Создает калькулятор с заданными параметрами
    /// - Parameters:
    ///   - gameVariant: Вариант игры
    ///   - iterations: Количество симуляций
    init(gameVariant: GameVariant = .texasHoldem, iterations: Int = defaultIterations) {
        self.gameVariant = gameVariant
        self.iterations = iterations
    }
    
    // MARK: - Public Methods
    
    /// Рассчитывает equity для всех игроков (строковые обозначения)
    /// - Parameters:
    ///   - players: Массив строк с картами игроков
    ///   - board: Опциональная строка с картами борда
    /// - Returns: OddsResult с equity для каждого игрока
    /// - Throws: PokerOddsError при некорректных данных
    func calculate(players: [String], board: String? = nil) throws -> OddsResult {
        // Парсим руки игроков
        let playerHands = try players.map { playerStr -> [Card] in
            let hand = try PlayerHand(notation: playerStr)
            guard hand.cards.count == 2 else {
                throw PokerOddsError.invalidHandSize(hand.cards.count)
            }
            return hand.cards
        }
        
        // Парсим борд
        let boardCards: [Card]
        if let boardStr = board, !boardStr.isEmpty {
            let boardHand = try PlayerHand(notation: boardStr)
            guard boardHand.cards.count <= 5 else {
                throw PokerOddsError.invalidBoard
            }
            boardCards = boardHand.cards
        } else {
            boardCards = []
        }
        
        return try calculate(playerHands: playerHands, board: boardCards)
    }
    
    /// Рассчитывает equity для всех игроков (объекты Card)
    /// - Parameters:
    ///   - playerHands: Массив рук игроков (по 2 карты)
    ///   - board: Карты на столе (0-5 карт)
    /// - Returns: OddsResult с equity для каждого игрока
    /// - Throws: PokerOddsError при некорректных данных
    func calculate(playerHands: [[Card]], board: [Card]) throws -> OddsResult {
        let startTime = Date()
        
        // Валидация
        try DeckGenerator.validate(playerHands: playerHands, board: board, variant: gameVariant)
        
        // Создаем симулятор
        let engine = SimulationEngine(gameVariant: gameVariant, iterations: iterations)
        
        // Запускаем симуляцию
        let results = engine.simulate(playerHands: playerHands, board: board)
        
        // Конвертируем результаты
        let equities = results.enumerated().map { index, result in
            let handNotation = playerHands[index].map { $0.shortNotation }.joined()
            return result.toPlayerEquity(
                playerIndex: index,
                hand: handNotation,
                totalSimulations: iterations
            )
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return OddsResult(
            equities: equities,
            executionTime: executionTime,
            iterations: iterations,
            gameVariant: gameVariant
        )
    }
    
    /// Рассчитывает equity для всех игроков (с объектами PlayerHand и Board)
    /// - Parameters:
    ///   - playerHands: Массив объектов PlayerHand
    ///   - board: Объект Board или nil
    /// - Returns: OddsResult с equity для каждого игрока
    /// - Throws: PokerOddsError при некорректных данных
    func calculate(playerHands: [PlayerHand], board: Board?) throws -> OddsResult {
        let hands = playerHands.map { $0.cards }
        let boardCards = board?.cards ?? []
        return try calculate(playerHands: hands, board: boardCards)
    }
}

// MARK: - Convenience Extensions

extension PokerOddsCalculator {
    
    /// Быстрый расчет для pre-flop сценария
    /// - Parameters:
    ///   - players: Руки игроков
    ///   - gameVariant: Вариант игры
    /// - Returns: OddsResult
    static func calculatePreFlop(
        players: [String],
        gameVariant: GameVariant = .texasHoldem
    ) throws -> OddsResult {
        return try calculate(players: players, board: nil, gameVariant: gameVariant)
    }
    
    /// Быстрый расчет для post-flop сценария
    /// - Parameters:
    ///   - players: Руки игроков
    ///   - board: Карты борда
    ///   - gameVariant: Вариант игры
    /// - Returns: OddsResult
    static func calculatePostFlop(
        players: [String],
        board: String,
        gameVariant: GameVariant = .texasHoldem
    ) throws -> OddsResult {
        return try calculate(players: players, board: board, gameVariant: gameVariant)
    }
}

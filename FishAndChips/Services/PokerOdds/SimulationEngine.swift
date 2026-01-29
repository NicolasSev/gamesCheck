//
//  SimulationEngine.swift
//  PokerCardRecognizer
//
//  Monte Carlo simulation engine for poker odds calculation
//

import Foundation

class SimulationEngine {
    
    private let gameVariant: GameVariant
    private let iterations: Int
    private let useParallelComputation: Bool
    
    init(gameVariant: GameVariant = .texasHoldem, iterations: Int = 10000, useParallelComputation: Bool = true) {
        self.gameVariant = gameVariant
        self.iterations = iterations
        self.useParallelComputation = useParallelComputation && iterations >= 5000
    }
    
    /// Запускает Monte Carlo симуляцию для расчета equity
    /// - Parameters:
    ///   - playerHands: Руки игроков (по 2 карты)
    ///   - board: Карты на столе (0-5 карт)
    /// - Returns: Массив результатов для каждого игрока
    func simulate(playerHands: [[Card]], board: [Card]) -> [SimulationResult] {
        if useParallelComputation {
            return simulateParallel(playerHands: playerHands, board: board)
        } else {
            return simulateSequential(playerHands: playerHands, board: board)
        }
    }
    
    /// Последовательная симуляция (для небольших итераций)
    private func simulateSequential(playerHands: [[Card]], board: [Card]) -> [SimulationResult] {
        let playerCount = playerHands.count
        var results = Array(repeating: SimulationResult(), count: playerCount)
        
        // Собираем все известные карты
        var knownCards: [Card] = []
        for hand in playerHands {
            knownCards.append(contentsOf: hand)
        }
        knownCards.append(contentsOf: board)
        
        // Создаем колоду без известных карт
        let availableDeck = DeckGenerator.createDeck(excluding: knownCards, variant: gameVariant)
        let cardsNeeded = 5 - board.count
        
        // Запускаем симуляции
        for _ in 0..<iterations {
            let shuffledDeck = DeckGenerator.shuffle(availableDeck)
            let additionalCards = DeckGenerator.deal(count: cardsNeeded, from: shuffledDeck)
            let fullBoard = board + additionalCards
            
            var evaluatedHands: [EvaluatedHand] = []
            for hand in playerHands {
                let allCards = hand + fullBoard
                let evaluated = HandEvaluator.evaluate(cards: allCards, gameVariant: gameVariant)
                evaluatedHands.append(evaluated)
            }
            
            let winners = findWinners(evaluatedHands)
            updateResults(&results, winners: winners, playerCount: playerCount)
        }
        
        return results
    }
    
    /// Параллельная симуляция (для больших итераций)
    private func simulateParallel(playerHands: [[Card]], board: [Card]) -> [SimulationResult] {
        let playerCount = playerHands.count
        
        // Собираем все известные карты
        var knownCards: [Card] = []
        for hand in playerHands {
            knownCards.append(contentsOf: hand)
        }
        knownCards.append(contentsOf: board)
        
        let availableDeck = DeckGenerator.createDeck(excluding: knownCards, variant: gameVariant)
        let cardsNeeded = 5 - board.count
        
        // Определяем количество потоков
        let threadCount = ProcessInfo.processInfo.activeProcessorCount
        let iterationsPerThread = iterations / threadCount
        let remainderIterations = iterations % threadCount
        
        // Создаем очередь для параллельных вычислений
        let queue = DispatchQueue(label: "com.pokercalculator.simulation", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Массив для хранения результатов каждого потока
        var threadResults: [[SimulationResult]] = Array(repeating: [], count: threadCount)
        let lock = NSLock()
        
        // Запускаем потоки
        for threadIndex in 0..<threadCount {
            group.enter()
            queue.async {
                let threadIterations = threadIndex == 0 ? iterationsPerThread + remainderIterations : iterationsPerThread
                var localResults = Array(repeating: SimulationResult(), count: playerCount)
                
                for _ in 0..<threadIterations {
                    let shuffledDeck = DeckGenerator.shuffle(availableDeck)
                    let additionalCards = DeckGenerator.deal(count: cardsNeeded, from: shuffledDeck)
                    let fullBoard = board + additionalCards
                    
                    var evaluatedHands: [EvaluatedHand] = []
                    for hand in playerHands {
                        let allCards = hand + fullBoard
                        let evaluated = HandEvaluator.evaluate(cards: allCards, gameVariant: self.gameVariant)
                        evaluatedHands.append(evaluated)
                    }
                    
                    let winners = self.findWinners(evaluatedHands)
                    self.updateResults(&localResults, winners: winners, playerCount: playerCount)
                }
                
                lock.lock()
                threadResults[threadIndex] = localResults
                lock.unlock()
                
                group.leave()
            }
        }
        
        group.wait()
        
        // Объединяем результаты всех потоков
        var finalResults = Array(repeating: SimulationResult(), count: playerCount)
        for threadResult in threadResults {
            for i in 0..<playerCount {
                finalResults[i].wins += threadResult[i].wins
                finalResults[i].ties += threadResult[i].ties
                finalResults[i].losses += threadResult[i].losses
            }
        }
        
        return finalResults
    }
    
    /// Обновляет результаты симуляции
    private func updateResults(_ results: inout [SimulationResult], winners: [Int], playerCount: Int) {
        if winners.count == 1 {
            results[winners[0]].wins += 1
            for i in 0..<playerCount {
                if !winners.contains(i) {
                    results[i].losses += 1
                }
            }
        } else {
            for winner in winners {
                results[winner].ties += 1
            }
            for i in 0..<playerCount {
                if !winners.contains(i) {
                    results[i].losses += 1
                }
            }
        }
    }
    
    /// Находит индексы победивших игроков
    /// - Parameter hands: Оцененные руки всех игроков
    /// - Returns: Массив индексов победителей
    private func findWinners(_ hands: [EvaluatedHand]) -> [Int] {
        guard !hands.isEmpty else { return [] }
        
        // Находим лучшую руку
        let bestHand = hands.max()!
        
        // Находим всех игроков с такой же рукой (для ничьих)
        var winners: [Int] = []
        for (index, hand) in hands.enumerated() {
            if hand == bestHand {
                winners.append(index)
            }
        }
        
        return winners
    }
}

// MARK: - Simulation Result

struct SimulationResult {
    var wins: Int = 0
    var ties: Int = 0
    var losses: Int = 0
    
    var total: Int {
        return wins + ties + losses
    }
    
    /// Рассчитывает equity (в процентах)
    /// В случае ничьей засчитывается как половина победы
    func calculateEquity() -> Double {
        guard total > 0 else { return 0.0 }
        let effectiveWins = Double(wins) + (Double(ties) / Double(max(1, ties)))
        return (effectiveWins / Double(total)) * 100.0
    }
    
    func toPlayerEquity(playerIndex: Int, hand: String, totalSimulations: Int) -> PlayerEquity {
        return PlayerEquity(
            playerIndex: playerIndex,
            hand: hand,
            equity: calculateEquity(),
            wins: wins,
            ties: ties,
            losses: losses,
            totalSimulations: totalSimulations
        )
    }
}

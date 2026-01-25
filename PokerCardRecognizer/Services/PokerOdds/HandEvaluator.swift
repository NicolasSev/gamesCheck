//
//  HandEvaluator.swift
//  PokerCardRecognizer
//
//  Evaluates poker hands and determines winning combinations
//

import Foundation

class HandEvaluator {
    
    /// Оценивает покерную руку из 5-7 карт и возвращает лучшую комбинацию из 5 карт
    /// - Parameters:
    ///   - cards: Массив карт (обычно 7: 2 карты игрока + 5 карт борда)
    ///   - gameVariant: Вариант игры для определения правил
    /// - Returns: EvaluatedHand с рангом и значениями для сравнения
    static func evaluate(cards: [Card], gameVariant: GameVariant = .texasHoldem) -> EvaluatedHand {
        // Если 7 карт, пробуем все комбинации из 5 карт
        if cards.count == 7 {
            return findBestFiveCardHand(from: cards, gameVariant: gameVariant)
        } else if cards.count == 5 {
            return evaluateFiveCards(cards, gameVariant: gameVariant)
        } else if cards.count == 6 {
            return findBestFiveCardHand(from: cards, gameVariant: gameVariant)
        } else {
            // Недостаточно карт - возвращаем старшую карту
            let sorted = cards.sorted { $0.rank.value > $1.rank.value }
            return EvaluatedHand(
                rankType: .highCard,
                rankValues: sorted.map { $0.rank.value },
                cards: cards
            )
        }
    }
    
    /// Находит лучшую комбинацию из 5 карт из всех возможных
    private static func findBestFiveCardHand(from cards: [Card], gameVariant: GameVariant) -> EvaluatedHand {
        let combinations = generateFiveCardCombinations(from: cards)
        var bestHand: EvaluatedHand?
        
        for combination in combinations {
            let evaluated = evaluateFiveCards(combination, gameVariant: gameVariant)
            if bestHand == nil || evaluated > bestHand! {
                bestHand = evaluated
            }
        }
        
        return bestHand!
    }
    
    /// Генерирует все комбинации из 5 карт
    private static func generateFiveCardCombinations(from cards: [Card]) -> [[Card]] {
        guard cards.count >= 5 else { return [] }
        
        var combinations: [[Card]] = []
        let n = cards.count
        
        func combine(_ start: Int, _ current: [Card]) {
            if current.count == 5 {
                combinations.append(current)
                return
            }
            
            for i in start..<n {
                combine(i + 1, current + [cards[i]])
            }
        }
        
        combine(0, [])
        return combinations
    }
    
    /// Оценивает ровно 5 карт
    private static func evaluateFiveCards(_ cards: [Card], gameVariant: GameVariant) -> EvaluatedHand {
        let sorted = cards.sorted { $0.rank.value > $1.rank.value }
        
        // Проверяем комбинации от сильнейшей к слабейшей
        if let royalFlush = checkRoyalFlush(sorted) {
            return royalFlush
        }
        
        if let straightFlush = checkStraightFlush(sorted) {
            return straightFlush
        }
        
        if let fourOfAKind = checkFourOfAKind(sorted) {
            return fourOfAKind
        }
        
        if let fullHouse = checkFullHouse(sorted) {
            return fullHouse
        }
        
        if let flush = checkFlush(sorted) {
            return flush
        }
        
        if let straight = checkStraight(sorted) {
            return straight
        }
        
        if let threeOfAKind = checkThreeOfAKind(sorted) {
            return threeOfAKind
        }
        
        if let twoPair = checkTwoPair(sorted) {
            return twoPair
        }
        
        if let onePair = checkOnePair(sorted) {
            return onePair
        }
        
        // High card
        return EvaluatedHand(
            rankType: .highCard,
            rankValues: sorted.map { $0.rank.value },
            cards: sorted
        )
    }
    
    // MARK: - Combination Checkers
    
    private static func checkRoyalFlush(_ cards: [Card]) -> EvaluatedHand? {
        guard let straightFlush = checkStraightFlush(cards) else { return nil }
        
        // Royal Flush = Straight Flush с тузом сверху (A-K-Q-J-T)
        if straightFlush.rankValues.first == 14 {
            return EvaluatedHand(
                rankType: .royalFlush,
                rankValues: straightFlush.rankValues,
                cards: cards
            )
        }
        
        return nil
    }
    
    private static func checkStraightFlush(_ cards: [Card]) -> EvaluatedHand? {
        guard isFlush(cards) else { return nil }
        return checkStraight(cards)?.withRankType(.straightFlush)
    }
    
    private static func checkFourOfAKind(_ cards: [Card]) -> EvaluatedHand? {
        let groups = groupByRank(cards)
        
        for (rank, group) in groups {
            if group.count == 4 {
                let kicker = cards.first { $0.rank.value != rank }!
                return EvaluatedHand(
                    rankType: .fourOfAKind,
                    rankValues: [rank, kicker.rank.value],
                    cards: cards
                )
            }
        }
        
        return nil
    }
    
    private static func checkFullHouse(_ cards: [Card]) -> EvaluatedHand? {
        let groups = groupByRank(cards)
        var threeRank: Int?
        var pairRank: Int?
        
        // Ищем тройку и пару
        for (rank, group) in groups.sorted(by: { $0.key > $1.key }) {
            if group.count == 3 && threeRank == nil {
                threeRank = rank
            } else if group.count >= 2 && pairRank == nil {
                pairRank = rank
            }
        }
        
        if let three = threeRank, let pair = pairRank {
            return EvaluatedHand(
                rankType: .fullHouse,
                rankValues: [three, pair],
                cards: cards
            )
        }
        
        return nil
    }
    
    private static func checkFlush(_ cards: [Card]) -> EvaluatedHand? {
        guard isFlush(cards) else { return nil }
        
        let sorted = cards.sorted { $0.rank.value > $1.rank.value }
        return EvaluatedHand(
            rankType: .flush,
            rankValues: sorted.map { $0.rank.value },
            cards: sorted
        )
    }
    
    private static func checkStraight(_ cards: [Card]) -> EvaluatedHand? {
        let values = cards.map { $0.rank.value }.sorted(by: >)
        
        // Проверяем обычный стрит
        if isConsecutive(values) {
            return EvaluatedHand(
                rankType: .straight,
                rankValues: [values.first!],
                cards: cards
            )
        }
        
        // Проверяем wheel (A-2-3-4-5)
        if values.contains(14) { // Туз
            let wheelValues = values.filter { $0 != 14 } + [1] // Туз как 1
            if isConsecutive(wheelValues.sorted(by: >)) && wheelValues.count == 5 {
                return EvaluatedHand(
                    rankType: .straight,
                    rankValues: [5], // Wheel имеет значение 5-high
                    cards: cards
                )
            }
        }
        
        return nil
    }
    
    private static func checkThreeOfAKind(_ cards: [Card]) -> EvaluatedHand? {
        let groups = groupByRank(cards)
        
        for (rank, group) in groups.sorted(by: { $0.key > $1.key }) {
            if group.count == 3 {
                let kickers = cards.filter { $0.rank.value != rank }
                    .sorted { $0.rank.value > $1.rank.value }
                    .prefix(2)
                    .map { $0.rank.value }
                
                return EvaluatedHand(
                    rankType: .threeOfAKind,
                    rankValues: [rank] + kickers,
                    cards: cards
                )
            }
        }
        
        return nil
    }
    
    private static func checkTwoPair(_ cards: [Card]) -> EvaluatedHand? {
        let groups = groupByRank(cards)
        let pairs = groups.filter { $0.value.count == 2 }
            .sorted { $0.key > $1.key }
        
        if pairs.count >= 2 {
            let pairRanks = pairs.prefix(2).map { $0.key }
            let kicker = cards.first { !pairRanks.contains($0.rank.value) }!
            
            return EvaluatedHand(
                rankType: .twoPair,
                rankValues: pairRanks + [kicker.rank.value],
                cards: cards
            )
        }
        
        return nil
    }
    
    private static func checkOnePair(_ cards: [Card]) -> EvaluatedHand? {
        let groups = groupByRank(cards)
        
        for (rank, group) in groups.sorted(by: { $0.key > $1.key }) {
            if group.count == 2 {
                let kickers = cards.filter { $0.rank.value != rank }
                    .sorted { $0.rank.value > $1.rank.value }
                    .prefix(3)
                    .map { $0.rank.value }
                
                return EvaluatedHand(
                    rankType: .onePair,
                    rankValues: [rank] + kickers,
                    cards: cards
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private static func groupByRank(_ cards: [Card]) -> [Int: [Card]] {
        var groups: [Int: [Card]] = [:]
        
        for card in cards {
            let rank = card.rank.value
            if groups[rank] == nil {
                groups[rank] = []
            }
            groups[rank]!.append(card)
        }
        
        return groups
    }
    
    private static func isFlush(_ cards: [Card]) -> Bool {
        guard cards.count == 5 else { return false }
        let firstSuit = cards[0].suit
        return cards.allSatisfy { $0.suit == firstSuit }
    }
    
    private static func isConsecutive(_ values: [Int]) -> Bool {
        guard values.count == 5 else { return false }
        let sorted = values.sorted(by: >)
        
        for i in 0..<4 {
            if sorted[i] - sorted[i + 1] != 1 {
                return false
            }
        }
        
        return true
    }
}

// MARK: - EvaluatedHand Extension

extension EvaluatedHand {
    func withRankType(_ newType: HandRankType) -> EvaluatedHand {
        return EvaluatedHand(
            rankType: newType,
            rankValues: self.rankValues,
            cards: self.cards
        )
    }
}

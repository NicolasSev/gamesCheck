//
//  PokerOddsModels.swift
//  PokerCardRecognizer
//
//  Models for Poker Odds Calculator
//

import Foundation

// MARK: - Game Variant

enum GameVariant: String, Codable {
    case texasHoldem = "texas_holdem"
    case shortDeck = "short_deck"
    
    var usesShortDeck: Bool {
        return self == .shortDeck
    }
}

// MARK: - Player Hand

struct PlayerHand {
    let cards: [Card]
    let notation: String
    
    init(cards: [Card]) {
        self.cards = cards
        self.notation = cards.map { $0.shortNotation }.joined()
    }
    
    init(notation: String) throws {
        var parsedCards: [Card] = []
        var i = 0
        let chars = Array(notation)
        
        while i < chars.count {
            // Ранг может быть 1 или 2 символа (10 или T)
            var rankStr = String(chars[i])
            if i + 1 < chars.count && chars[i] == "1" && chars[i+1] == "0" {
                rankStr = "10"
                i += 1
            }
            i += 1
            
            // Масть - 1 символ
            guard i < chars.count else {
                throw PokerOddsError.invalidCardFormat(notation)
            }
            let suitStr = String(chars[i])
            i += 1
            
            let cardNotation = rankStr + suitStr
            let card = try Card(notation: cardNotation)
            parsedCards.append(card)
        }
        
        self.cards = parsedCards
        self.notation = notation
    }
}

// MARK: - Board

struct Board {
    let cards: [Card]
    
    init(cards: [Card]) {
        self.cards = cards
    }
    
    init?(notation: String?) throws {
        guard let notation = notation, !notation.isEmpty else {
            return nil
        }
        
        let hand = try PlayerHand(notation: notation)
        guard hand.cards.count <= 5 else {
            throw PokerOddsError.invalidBoard
        }
        self.cards = hand.cards
    }
}

// MARK: - Player Equity

struct PlayerEquity {
    let playerIndex: Int
    let hand: String
    let equity: Double
    let wins: Int
    let ties: Int
    let losses: Int
    let totalSimulations: Int
    
    func getEquityPercentage() -> String {
        return String(format: "%.2f%%", equity)
    }
}

// MARK: - Odds Result

struct OddsResult {
    let equities: [PlayerEquity]
    let executionTime: TimeInterval
    let iterations: Int
    let gameVariant: GameVariant
    
    func description() -> String {
        var result = "Poker Odds Result (\(gameVariant.rawValue)):\n"
        result += "Iterations: \(iterations), Time: \(String(format: "%.2f", executionTime * 1000))ms\n\n"
        
        for equity in equities {
            result += "Player \(equity.playerIndex + 1) (\(equity.hand)): \(equity.getEquityPercentage())\n"
            result += "  Wins: \(equity.wins), Ties: \(equity.ties), Losses: \(equity.losses)\n"
        }
        
        return result
    }
}

// MARK: - Hand Rank Type

enum HandRankType: Int, Comparable {
    case highCard = 0
    case onePair = 1
    case twoPair = 2
    case threeOfAKind = 3
    case straight = 4
    case flush = 5
    case fullHouse = 6
    case fourOfAKind = 7
    case straightFlush = 8
    case royalFlush = 9
    
    var description: String {
        switch self {
        case .highCard: return "High Card"
        case .onePair: return "One Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush: return "Royal Flush"
        }
    }
    
    static func < (lhs: HandRankType, rhs: HandRankType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Evaluated Hand

struct EvaluatedHand: Comparable {
    let rankType: HandRankType
    let rankValues: [Int] // Значения для разрешения ничьих (например, [14, 14, 13] для пары тузов с кикером королем)
    let cards: [Card]
    
    var description: String {
        return rankType.description
    }
    
    static func < (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        if lhs.rankType != rhs.rankType {
            return lhs.rankType < rhs.rankType
        }
        
        // Сравниваем по rankValues
        for (leftVal, rightVal) in zip(lhs.rankValues, rhs.rankValues) {
            if leftVal != rightVal {
                return leftVal < rightVal
            }
        }
        
        return false // Полная ничья
    }
    
    static func == (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        return lhs.rankType == rhs.rankType && lhs.rankValues == rhs.rankValues
    }
}

// MARK: - Poker Odds Error

enum PokerOddsError: Error, LocalizedError {
    case invalidCardFormat(String)
    case duplicateCards([String])
    case insufficientPlayers
    case invalidBoard
    case shortDeckInvalidCard(String)
    case invalidHandSize(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidCardFormat(let card):
            return "Invalid card format: \(card). Use format like 'AhKs'"
        case .duplicateCards(let cards):
            return "Duplicate cards found: \(cards.joined(separator: ", "))"
        case .insufficientPlayers:
            return "Need at least 2 players"
        case .invalidBoard:
            return "Board must have 0, 3, 4, or 5 cards"
        case .shortDeckInvalidCard(let card):
            return "Card \(card) not valid in Short Deck (6+)"
        case .invalidHandSize(let size):
            return "Invalid hand size: \(size). Must be exactly 2 cards"
        }
    }
}

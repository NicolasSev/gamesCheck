//
//  Card.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import Foundation

struct Card: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var rank: CardRank
    var suit: CardSuit
    var confidence: Float
    var rect: CGRect
    
    var displayName: String {
        return "\(rank.rawValue)\(suit.symbol)"
    }
    
    /// Короткая нотация для покерных расчетов (например, "Ah", "Ks")
    var shortNotation: String {
        return "\(rank.shortCode)\(suit.shortCode)"
    }
    
    init(rank: CardRank, suit: CardSuit, confidence: Float = 1.0, rect: CGRect = .zero) {
        self.id = UUID()
        self.rank = rank
        self.suit = suit
        self.confidence = confidence
        self.rect = rect
    }
    
    /// Создает карту из короткой нотации (например, "Ah", "Ks", "Td")
    /// - Parameter notation: Строка формата "Ah" (ранг + масть)
    /// - Throws: CardParseError если формат неверный
    init(notation: String) throws {
        guard notation.count >= 2 else {
            throw CardParseError.invalidFormat(notation)
        }
        
        let rankStr = String(notation.prefix(notation.count - 1))
        let suitStr = String(notation.suffix(1))
        
        guard let rank = CardRank(shortCode: rankStr) else {
            throw CardParseError.invalidRank(rankStr)
        }
        
        guard let suit = CardSuit(shortCode: suitStr) else {
            throw CardParseError.invalidSuit(suitStr)
        }
        
        self.id = UUID()
        self.rank = rank
        self.suit = suit
        self.confidence = 1.0
        self.rect = .zero
    }
    
    /// Проверяет, валидна ли карта для Short Deck (6+)
    var isValidForShortDeck: Bool {
        return rank.value >= 6 || rank == .ace
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rank)
        hasher.combine(suit)
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }
}

enum CardParseError: Error, LocalizedError {
    case invalidFormat(String)
    case invalidRank(String)
    case invalidSuit(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let str):
            return "Invalid card format: '\(str)'. Use format like 'Ah', 'Ks', 'Td'"
        case .invalidRank(let rank):
            return "Invalid rank: '\(rank)'"
        case .invalidSuit(let suit):
            return "Invalid suit: '\(suit)'"
        }
    }
}

enum CardRank: String, CaseIterable, Codable, Hashable, Comparable {
    case ace = "A"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    
    /// Числовое значение карты для сравнения (2 = 2, ..., K = 13, A = 14)
    var value: Int {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
    
    /// Короткий код для парсинга (A, 2, 3, ..., T, J, Q, K)
    var shortCode: String {
        switch self {
        case .ten: return "T"
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return self.rawValue
        }
    }
    
    /// Создает ранг из короткого кода
    init?(shortCode: String) {
        switch shortCode.uppercased() {
        case "A": self = .ace
        case "2": self = .two
        case "3": self = .three
        case "4": self = .four
        case "5": self = .five
        case "6": self = .six
        case "7": self = .seven
        case "8": self = .eight
        case "9": self = .nine
        case "T", "10": self = .ten
        case "J": self = .jack
        case "Q": self = .queen
        case "K": self = .king
        default: return nil
        }
    }
    
    static func < (lhs: CardRank, rhs: CardRank) -> Bool {
        return lhs.value < rhs.value
    }
}

enum CardSuit: String, CaseIterable, Codable, Hashable {
    case spades = "♠"
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"
    
    var symbol: String {
        return self.rawValue
    }
    
    /// Короткий код для парсинга (s, h, d, c)
    var shortCode: String {
        switch self {
        case .spades: return "s"
        case .hearts: return "h"
        case .diamonds: return "d"
        case .clubs: return "c"
        }
    }
    
    /// Создает масть из короткого кода
    init?(shortCode: String) {
        switch shortCode.lowercased() {
        case "s": self = .spades
        case "h": self = .hearts
        case "d": self = .diamonds
        case "c": self = .clubs
        default: return nil
        }
    }
}

struct Hand: Identifiable {
    let id: UUID
    var cards: [Card]
    var type: HandType
    
    enum HandType {
        case holeCards // Карты в руке (2 карты)
        case board // Карты на столе (flop, turn, river)
    }
    
    init(cards: [Card], type: HandType) {
        self.id = UUID()
        self.cards = cards
        self.type = type
    }
}

struct PokerHand: Identifiable {
    let id: UUID
    var holeCards: Hand // Карты в руке игрока
    var board: Hand // Карты на столе
    var timestamp: Date
    
    init(holeCards: Hand, board: Hand, timestamp: Date = Date()) {
        self.id = UUID()
        self.holeCards = holeCards
        self.board = board
        self.timestamp = timestamp
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

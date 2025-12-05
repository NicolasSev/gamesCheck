//
//  Card.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import Foundation

struct Card: Identifiable, Codable, Equatable {
    let id: UUID
    var rank: CardRank
    var suit: CardSuit
    var confidence: Float
    var rect: CGRect
    
    var displayName: String {
        return "\(rank.rawValue)\(suit.symbol)"
    }
    
    init(rank: CardRank, suit: CardSuit, confidence: Float = 1.0, rect: CGRect = .zero) {
        self.id = UUID()
        self.rank = rank
        self.suit = suit
        self.confidence = confidence
        self.rect = rect
    }
}

enum CardRank: String, CaseIterable, Codable {
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
}

enum CardSuit: String, CaseIterable, Codable {
    case spades = "♠"
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"
    
    var symbol: String {
        return self.rawValue
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


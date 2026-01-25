//
//  HandModel.swift
//  PokerCardRecognizer
//
//  In-memory model for poker hands
//

import Foundation

struct HandModel: Identifiable, Codable {
    let id: UUID
    let gameId: UUID
    let timestamp: Date
    let creatorName: String
    let players: [HandPlayerModel]
    let boardCards: [String] // Формат: ["Ah", "Ks", "Qd"]
    let oddsResult: OddsResultModel
    
    init(
        id: UUID = UUID(),
        gameId: UUID,
        creatorName: String,
        players: [HandPlayerModel],
        boardCards: [String],
        oddsResult: OddsResultModel,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.gameId = gameId
        self.timestamp = timestamp
        self.creatorName = creatorName
        self.players = players
        self.boardCards = boardCards
        self.oddsResult = oddsResult
    }
}

struct HandPlayerModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let card1: String
    let card2: String
    let equity: Double
    let wins: Int
    let ties: Int
    let losses: Int
    
    // Эквити для разных улиц
    let preFlopEquity: Double?
    let flopEquity: Double?
    let turnEquity: Double?
    let riverEquity: Double?
    
    init(
        id: UUID = UUID(),
        name: String,
        card1: String,
        card2: String,
        equity: Double,
        wins: Int,
        ties: Int,
        losses: Int,
        preFlopEquity: Double? = nil,
        flopEquity: Double? = nil,
        turnEquity: Double? = nil,
        riverEquity: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.card1 = card1
        self.card2 = card2
        self.equity = equity
        self.wins = wins
        self.ties = ties
        self.losses = losses
        self.preFlopEquity = preFlopEquity
        self.flopEquity = flopEquity
        self.turnEquity = turnEquity
        self.riverEquity = riverEquity
    }
}

struct OddsResultModel: Codable {
    let iterations: Int
    let executionTime: Double
    let gameVariant: String
    
    init(iterations: Int, executionTime: Double, gameVariant: String) {
        self.iterations = iterations
        self.executionTime = executionTime
        self.gameVariant = gameVariant
    }
}

// MARK: - Hands Storage Service

class HandsStorageService {
    static let shared = HandsStorageService()
    private let userDefaults = UserDefaults.standard
    private let handsKey = "saved_poker_hands"
    
    private init() {}
    
    func saveHand(_ hand: HandModel) {
        var hands = getAllHands()
        hands.append(hand)
        
        if let encoded = try? JSONEncoder().encode(hands) {
            userDefaults.set(encoded, forKey: handsKey)
        }
    }
    
    func getAllHands() -> [HandModel] {
        guard let data = userDefaults.data(forKey: handsKey),
              let hands = try? JSONDecoder().decode([HandModel].self, from: data) else {
            return []
        }
        return hands
    }
    
    func getHands(forGameId gameId: UUID) -> [HandModel] {
        return getAllHands().filter { $0.gameId == gameId }
    }
    
    func deleteHand(id: UUID) {
        var hands = getAllHands()
        hands.removeAll { $0.id == id }
        
        if let encoded = try? JSONEncoder().encode(hands) {
            userDefaults.set(encoded, forKey: handsKey)
        }
    }
    
    func updateHand(_ updatedHand: HandModel) {
        var hands = getAllHands()
        if let index = hands.firstIndex(where: { $0.id == updatedHand.id }) {
            hands[index] = updatedHand
            
            if let encoded = try? JSONEncoder().encode(hands) {
                userDefaults.set(encoded, forKey: handsKey)
            }
        }
    }
}

extension Notification.Name {
    static let handDidUpdate = Notification.Name("handDidUpdate")
}

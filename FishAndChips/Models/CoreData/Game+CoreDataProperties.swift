//
//  Game+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Николас on 05.04.2025.
//
//

import Foundation
import CoreData


extension Game {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    @NSManaged public var attribute: String?
    @NSManaged public var attribute1: String?
    @NSManaged public var creatorUserId: UUID?
    @NSManaged public var gameType: String?
    @NSManaged public var gameId: UUID
    @NSManaged public var isPublic: Bool
    @NSManaged public var notes: String?
    @NSManaged public var softDeleted: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var billiardBatches: NSSet?
    @NSManaged public var creator: User?
    @NSManaged public var gameWithPlayers: NSSet?
    @NSManaged public var player1: Player?
    @NSManaged public var player2: Player?
    @NSManaged public var players: NSSet?

}

// MARK: - Computed Properties (Task 1.2)
extension Game {
    var isOwnedByCurrentUser: Bool {
        let keychain = KeychainService.shared
        guard let currentUserId = keychain.getUserId(),
              let currentUUID = UUID(uuidString: currentUserId) else {
            return false
        }
        return creatorUserId == currentUUID
    }

    var displayTimestamp: String {
        guard let timestamp = timestamp else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Сумма buyin по связям `GameWithPlayer` (в текущей модели buyin/cashout = Int)
    var totalBuyins: Decimal {
        let set = gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.reduce(Decimal(0)) { $0 + Decimal(Int($1.buyin)) }
    }

    var totalCashouts: Decimal {
        let set = gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.reduce(Decimal(0)) { $0 + Decimal(Int($1.cashout)) }
    }

    var isBalanced: Bool {
        totalBuyins == totalCashouts
    }
}

// MARK: Generated accessors for billiardBatches
extension Game {

    @objc(addBilliardBatchesObject:)
    @NSManaged public func addToBilliardBatches(_ value: BilliardBatche)

    @objc(removeBilliardBatchesObject:)
    @NSManaged public func removeFromBilliardBatches(_ value: BilliardBatche)

    @objc(addBilliardBatches:)
    @NSManaged public func addToBilliardBatches(_ values: NSSet)

    @objc(removeBilliardBatches:)
    @NSManaged public func removeFromBilliardBatches(_ values: NSSet)

}

// MARK: Generated accessors for gameWithPlayers
extension Game {

    @objc(addGameWithPlayersObject:)
    @NSManaged public func addToGameWithPlayers(_ value: GameWithPlayer)

    @objc(removeGameWithPlayersObject:)
    @NSManaged public func removeFromGameWithPlayers(_ value: GameWithPlayer)

    @objc(addGameWithPlayers:)
    @NSManaged public func addToGameWithPlayers(_ values: NSSet)

    @objc(removeGameWithPlayers:)
    @NSManaged public func removeFromGameWithPlayers(_ values: NSSet)

}

// MARK: Generated accessors for players
extension Game {

    @objc(addPlayersObject:)
    @NSManaged public func addToPlayers(_ value: Player)

    @objc(removePlayersObject:)
    @NSManaged public func removeFromPlayers(_ value: Player)

    @objc(addPlayers:)
    @NSManaged public func addToPlayers(_ values: NSSet)

    @objc(removePlayers:)
    @NSManaged public func removeFromPlayers(_ values: NSSet)

}

extension Game : Identifiable {

}

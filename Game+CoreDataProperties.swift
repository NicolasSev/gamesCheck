//
//  Game+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Николас on 31.03.2025.
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
    @NSManaged public var gameType: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var billiardBatches: NSSet?
    @NSManaged public var gameWithPlayers: NSSet?
    @NSManaged public var player1: Player?
    @NSManaged public var player2: Player?
    @NSManaged public var players: NSSet?

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

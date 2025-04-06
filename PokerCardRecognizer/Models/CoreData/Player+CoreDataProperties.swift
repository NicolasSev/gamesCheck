//
//  Player+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Николас on 05.04.2025.
//
//

import Foundation
import CoreData


extension Player {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        return NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var buyin: Int16
    @NSManaged public var name: String?
    @NSManaged public var game: NSSet?
    @NSManaged public var gameWithPlayers: NSSet?

}

// MARK: Generated accessors for game
extension Player {

    @objc(addGameObject:)
    @NSManaged public func addToGame(_ value: Game)

    @objc(removeGameObject:)
    @NSManaged public func removeFromGame(_ value: Game)

    @objc(addGame:)
    @NSManaged public func addToGame(_ values: NSSet)

    @objc(removeGame:)
    @NSManaged public func removeFromGame(_ values: NSSet)

}

// MARK: Generated accessors for gameWithPlayers
extension Player {

    @objc(addGameWithPlayersObject:)
    @NSManaged public func addToGameWithPlayers(_ value: GameWithPlayer)

    @objc(removeGameWithPlayersObject:)
    @NSManaged public func removeFromGameWithPlayers(_ value: GameWithPlayer)

    @objc(addGameWithPlayers:)
    @NSManaged public func addToGameWithPlayers(_ values: NSSet)

    @objc(removeGameWithPlayers:)
    @NSManaged public func removeFromGameWithPlayers(_ values: NSSet)

}

extension Player : Identifiable {

}

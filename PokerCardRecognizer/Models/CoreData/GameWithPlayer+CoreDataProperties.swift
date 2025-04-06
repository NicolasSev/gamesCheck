//
//  GameWithPlayer+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Николас on 05.04.2025.
//
//

import Foundation
import CoreData


extension GameWithPlayer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GameWithPlayer> {
        return NSFetchRequest<GameWithPlayer>(entityName: "GameWithPlayer")
    }

    @NSManaged public var buyin: Int16
    @NSManaged public var cashout: Int64
    @NSManaged public var game: Game?
    @NSManaged public var player: Player?

}

extension GameWithPlayer : Identifiable {

}

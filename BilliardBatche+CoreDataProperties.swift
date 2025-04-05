//
//  BilliardBatche+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Николас on 31.03.2025.
//
//

import Foundation
import CoreData


extension BilliardBatche {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BilliardBatche> {
        return NSFetchRequest<BilliardBatche>(entityName: "BilliardBatche")
    }

    @NSManaged public var scorePlayer1: Int16
    @NSManaged public var scorePlayer2: Int16
    @NSManaged public var timestamp: Date?
    @NSManaged public var game: Game?

}

extension BilliardBatche : Identifiable {

}

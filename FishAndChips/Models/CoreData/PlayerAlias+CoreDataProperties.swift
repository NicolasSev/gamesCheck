//
//  PlayerAlias+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Task 1.4: PlayerAlias model
//

import Foundation
import CoreData

extension PlayerAlias {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerAlias> {
        NSFetchRequest<PlayerAlias>(entityName: "PlayerAlias")
    }

    @NSManaged public var aliasId: UUID
    @NSManaged public var profileId: UUID
    @NSManaged public var aliasName: String
    @NSManaged public var claimedAt: Date
    @NSManaged public var gamesCount: Int32

    // Relationships
    @NSManaged public var profile: PlayerProfile
}

// MARK: - Computed Properties
extension PlayerAlias {
    var formattedClaimedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: claimedAt)
    }

    var displayText: String {
        "\(aliasName) (\(gamesCount) игр)"
    }
}

// MARK: - Validation
extension PlayerAlias {
    func validateAliasName() -> Bool {
        !aliasName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


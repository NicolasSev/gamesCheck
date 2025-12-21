//
//  User+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import Foundation
import CoreData

extension User {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var userId: UUID
    @NSManaged public var username: String
    @NSManaged public var email: String?
    @NSManaged public var passwordHash: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastLoginAt: Date?
    @NSManaged public var subscriptionStatus: String
    @NSManaged public var subscriptionExpiresAt: Date?

    // Relationships (будут добавлены позже)
    @NSManaged public var createdGames: NSSet?
}

// MARK: - Computed Properties
extension User {
    var isPremium: Bool {
        guard subscriptionStatus == "premium" else { return false }
        guard let expiresAt = subscriptionExpiresAt else { return false }
        return expiresAt > Date()
    }

    var isSubscriptionExpired: Bool {
        guard let expiresAt = subscriptionExpiresAt else { return false }
        return expiresAt <= Date()
    }

    var displayName: String {
        username
    }
}

// MARK: - Collection Helpers
extension User {
    @objc(addCreatedGamesObject:)
    @NSManaged public func addToCreatedGames(_ value: Game)

    @objc(removeCreatedGamesObject:)
    @NSManaged public func removeFromCreatedGames(_ value: Game)

    @objc(addCreatedGames:)
    @NSManaged public func addToCreatedGames(_ values: NSSet)

    @objc(removeCreatedGames:)
    @NSManaged public func removeFromCreatedGames(_ values: NSSet)
}


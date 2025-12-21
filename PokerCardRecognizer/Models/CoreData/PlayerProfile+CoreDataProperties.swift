//
//  PlayerProfile+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Task 1.3: PlayerProfile model
//

import Foundation
import CoreData

extension PlayerProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerProfile> {
        NSFetchRequest<PlayerProfile>(entityName: "PlayerProfile")
    }

    @NSManaged public var profileId: UUID
    @NSManaged public var userId: UUID?
    @NSManaged public var displayName: String
    @NSManaged public var isAnonymous: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var totalGamesPlayed: Int32
    @NSManaged public var totalBuyins: NSDecimalNumber
    @NSManaged public var totalCashouts: NSDecimalNumber

    // Relationships
    @NSManaged public var user: User?
    @NSManaged public var aliases: NSSet?
    @NSManaged public var gameParticipations: NSSet?
}

// MARK: - Computed Properties
extension PlayerProfile {
    var balance: Decimal {
        (totalCashouts as Decimal) - (totalBuyins as Decimal)
    }

    var winRate: Double {
        let participations = gameParticipationsArray
        guard !participations.isEmpty else { return 0 }
        let wins = participations.filter { $0.profit > 0 }.count
        return Double(wins) / Double(participations.count)
    }

    var averageBuyin: Decimal {
        guard totalGamesPlayed > 0 else { return 0 }
        return (totalBuyins as Decimal) / Decimal(totalGamesPlayed)
    }

    var averageProfit: Decimal {
        guard totalGamesPlayed > 0 else { return 0 }
        return balance / Decimal(totalGamesPlayed)
    }

    var gameParticipationsArray: [GameWithPlayer] {
        let set = gameParticipations as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.game?.timestamp ?? Date()) > ($1.game?.timestamp ?? Date()) }
    }

    var aliasesArray: [PlayerAlias] {
        let set = aliases as? Set<PlayerAlias> ?? []
        return set.sorted { $0.aliasName < $1.aliasName }
    }

    var allKnownNames: [String] {
        var names = [displayName]
        names.append(contentsOf: aliasesArray.map { $0.aliasName })
        return Array(Set(names))
    }
}

// MARK: - Statistics Update
extension PlayerProfile {
    /// Пересчитать статистику из игр
    func recalculateStatistics() {
        let participations = gameParticipationsArray

        totalGamesPlayed = Int32(participations.count)

        let buyinsSum = participations.reduce(Decimal(0)) { $0 + Decimal(Int($1.buyin)) }
        totalBuyins = NSDecimalNumber(decimal: buyinsSum)

        let cashoutsSum = participations.reduce(Decimal(0)) { $0 + Decimal(Int($1.cashout)) }
        totalCashouts = NSDecimalNumber(decimal: cashoutsSum)
    }

    /// Обновить статистику при добавлении игры
    func addGameStatistics(buyin: Decimal, cashout: Decimal) {
        totalGamesPlayed += 1
        totalBuyins = NSDecimalNumber(decimal: (totalBuyins as Decimal) + buyin)
        totalCashouts = NSDecimalNumber(decimal: (totalCashouts as Decimal) + cashout)
    }
}

// MARK: - Collection Helpers
extension PlayerProfile {
    @objc(addAliasesObject:)
    @NSManaged public func addToAliases(_ value: PlayerAlias)

    @objc(removeAliasesObject:)
    @NSManaged public func removeFromAliases(_ value: PlayerAlias)

    @objc(addAliases:)
    @NSManaged public func addToAliases(_ values: NSSet)

    @objc(removeAliases:)
    @NSManaged public func removeFromAliases(_ values: NSSet)

    @objc(addGameParticipationsObject:)
    @NSManaged public func addToGameParticipations(_ value: GameWithPlayer)

    @objc(removeGameParticipationsObject:)
    @NSManaged public func removeFromGameParticipations(_ value: GameWithPlayer)

    @objc(addGameParticipations:)
    @NSManaged public func addToGameParticipations(_ values: NSSet)

    @objc(removeGameParticipations:)
    @NSManaged public func removeFromGameParticipations(_ values: NSSet)
}


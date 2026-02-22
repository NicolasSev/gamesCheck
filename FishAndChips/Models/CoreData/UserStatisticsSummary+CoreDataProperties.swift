//
//  UserStatisticsSummary+CoreDataProperties.swift
//  FishAndChips
//
//  Materialized view for Phase 2 optimization
//

import Foundation
import CoreData

extension UserStatisticsSummary {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserStatisticsSummary> {
        return NSFetchRequest<UserStatisticsSummary>(entityName: "UserStatisticsSummary")
    }

    @NSManaged public var userId: UUID
    @NSManaged public var totalGamesPlayed: Int64
    @NSManaged public var totalBuyins: Double
    @NSManaged public var totalCashouts: Double
    @NSManaged public var balance: Double
    @NSManaged public var lastGameDate: Date?
    @NSManaged public var winRate: Double
    @NSManaged public var avgProfit: Double
    @NSManaged public var lastUpdated: Date
}

extension UserStatisticsSummary: Identifiable {

}

//
//  GameSummary+CoreDataProperties.swift
//  FishAndChips
//
//  Materialized view for Phase 2 optimization
//

import Foundation
import CoreData

extension GameSummaryRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GameSummaryRecord> {
        return NSFetchRequest<GameSummaryRecord>(entityName: "GameSummaryRecord")
    }

    @NSManaged public var gameId: UUID
    @NSManaged public var creatorUserId: UUID?
    @NSManaged public var gameType: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var totalPlayers: Int64
    @NSManaged public var totalBuyins: Double
    @NSManaged public var isPublic: Bool
    @NSManaged public var lastModified: Date?
    @NSManaged public var checksum: String?
}

extension GameSummaryRecord: Identifiable {
    public var id: UUID { gameId }
}

//
//  UserGameIndex+CoreDataProperties.swift
//  FishAndChips
//
//  Materialized view for Phase 2 optimization
//

import Foundation
import CoreData

extension UserGameIndex {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserGameIndex> {
        return NSFetchRequest<UserGameIndex>(entityName: "UserGameIndex")
    }

    @NSManaged public var indexId: UUID
    @NSManaged public var userId: UUID
    @NSManaged public var gameId: UUID
    @NSManaged public var timestamp: Date?
    @NSManaged public var buyin: Double
    @NSManaged public var cashout: Double
    @NSManaged public var isHost: Bool
}

extension UserGameIndex: Identifiable {
    public var id: UUID { indexId }
}

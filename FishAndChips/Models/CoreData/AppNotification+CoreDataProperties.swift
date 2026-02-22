//
//  AppNotification+CoreDataProperties.swift
//  FishAndChips
//

import Foundation
import CoreData

extension AppNotification {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppNotification> {
        return NSFetchRequest<AppNotification>(entityName: "AppNotification")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var body: String
    @NSManaged public var type: String
    @NSManaged public var isRead: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var gameId: UUID?
}

extension AppNotification: Identifiable {}

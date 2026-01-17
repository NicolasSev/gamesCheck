//
//  PlayerClaim+CoreDataProperties.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import Foundation
import CoreData

extension PlayerClaim {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerClaim> {
        return NSFetchRequest<PlayerClaim>(entityName: "PlayerClaim")
    }

    @NSManaged public var claimId: UUID
    @NSManaged public var playerName: String
    @NSManaged public var gameId: UUID
    @NSManaged public var gameWithPlayerObjectId: String // NSManagedObjectID как строка
    @NSManaged public var claimantUserId: UUID // Пользователь, подающий заявку
    @NSManaged public var hostUserId: UUID // Создатель игры (хост)
    @NSManaged public var status: String // "pending" | "approved" | "rejected"
    @NSManaged public var createdAt: Date
    @NSManaged public var resolvedAt: Date?
    @NSManaged public var resolvedByUserId: UUID?
    @NSManaged public var notes: String? // Комментарий при одобрении/отклонении
    
    // Relationships
    @NSManaged public var claimantUser: User? // Пользователь, подающий заявку
    @NSManaged public var hostUser: User? // Хост (создатель игры)
    @NSManaged public var resolvedByUser: User? // Кто разрешил заявку
    @NSManaged public var game: Game? // Игра, к которой относится заявка
}

// MARK: - Computed Properties
extension PlayerClaim {
    var isPending: Bool {
        status == "pending"
    }
    
    var isApproved: Bool {
        status == "approved"
    }
    
    var isRejected: Bool {
        status == "rejected"
    }
    
    var statusDisplayName: String {
        switch status {
        case "pending": return "Ожидает"
        case "approved": return "Одобрено"
        case "rejected": return "Отклонено"
        default: return status
        }
    }
}

extension PlayerClaim : Identifiable {

}


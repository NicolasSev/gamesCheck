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
        NSFetchRequest<PlayerClaim>(entityName: "PlayerClaim")
    }

    @NSManaged public var claimId: UUID
    @NSManaged public var playerName: String
    /// Для bulk-заявок может быть nil (нет одной строки игры).
    @NSManaged public var gameId: UUID?
    /// Ссылка на Core Data object id GWP для single-потоков; для bulk часто "".
    @NSManaged public var gameWithPlayerObjectId: String?
    @NSManaged public var claimantUserId: UUID
    @NSManaged public var hostUserId: UUID
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var resolvedAt: Date?
    @NSManaged public var resolvedByUserId: UUID?
    @NSManaged public var notes: String?

    @NSManaged public var scope: String?
    /// Место из bulk-контекста (совпадает с `places.id` при наличии).
    @NSManaged public var placeId: UUID?
    @NSManaged public var playerKey: String?
    @NSManaged public var affectedGamePlayerIdsJson: String?
    @NSManaged public var blockReason: String?
    @NSManaged public var conflictProfileIdsJson: String?

    @NSManaged public var claimantUser: User?
    @NSManaged public var hostUser: User?
    @NSManaged public var resolvedByUser: User?
    @NSManaged public var game: Game?
}

// MARK: - Computed
extension PlayerClaim {
    var isPending: Bool { status == "pending" }

    var isApproved: Bool { status == "approved" }

    var isRejected: Bool { status == "rejected" }

    /// Блок-состояние при конфликте профилей (сервер `host_resolve_claim`).
    var isBlocked: Bool { status == "blocked" }

    /// JSON-массив UUID строк: `["…"]`; пустые → [].
    var affectedGamePlayerIds: [UUID] {
        get {
            Self.decodeUuidArray(from: affectedGamePlayerIdsJson)
        }
        set {
            affectedGamePlayerIdsJson = Self.encodeUuidArray(newValue)
        }
    }

    var conflictProfileIds: [UUID] {
        get {
            Self.decodeUuidArray(from: conflictProfileIdsJson)
        }
        set {
            conflictProfileIdsJson = Self.encodeUuidArray(newValue)
        }
    }

    var statusDisplayName: String {
        switch status {
        case "pending": return "Ожидает"
        case "approved": return "Одобрено"
        case "rejected": return "Отклонено"
        case "blocked": return "Блок (конфликт)"
        default: return status
        }
    }

    static func encodeUuidArray(_ ids: [UUID]) -> String? {
        guard !ids.isEmpty else { return "[]" }
        let strings = ids.map(\.uuidString)
        guard let data = try? JSONEncoder().encode(strings),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    static func decodeUuidArray(from json: String?) -> [UUID] {
        guard let json, let data = json.data(using: .utf8) else {
            return []
        }
        if let strings = try? JSONDecoder().decode([String].self, from: data) {
            return strings.compactMap { UUID(uuidString: $0) }
        }
        return []
    }
}

extension PlayerClaim: Identifiable {}

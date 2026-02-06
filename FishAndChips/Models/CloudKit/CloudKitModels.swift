//
//  CloudKitModels.swift
//  PokerCardRecognizer
//
//  Created for Phase 3: CloudKit Setup & Integration
//

import Foundation
import CloudKit
import CoreData

// MARK: - User CloudKit Extension

extension User {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: userId.uuidString)
        let record = CKRecord(recordType: "User", recordID: recordID)
        
        record["username"] = username as CKRecordValue
        record["email"] = (email ?? "") as CKRecordValue
        record["passwordHash"] = passwordHash as CKRecordValue
        record["subscriptionStatus"] = subscriptionStatus as CKRecordValue
        record["isSuperAdmin"] = (isSuperAdmin ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        
        if let lastLoginAt = lastLoginAt {
            record["lastLoginAt"] = lastLoginAt as CKRecordValue
        }
        
        if let subscriptionExpiresAt = subscriptionExpiresAt {
            record["subscriptionExpiresAt"] = subscriptionExpiresAt as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        // Don't update userId - it's the primary key
        if let username = record["username"] as? String {
            self.username = username
        }
        if let email = record["email"] as? String, !email.isEmpty {
            self.email = email
        }
        if let passwordHash = record["passwordHash"] as? String {
            self.passwordHash = passwordHash
        }
        if let subscriptionStatus = record["subscriptionStatus"] as? String {
            self.subscriptionStatus = subscriptionStatus
        }
        if let isSuperAdmin = record["isSuperAdmin"] as? Bool {
            self.isSuperAdmin = isSuperAdmin
        }
        if let createdAt = record["createdAt"] as? Date {
            self.createdAt = createdAt
        }
        if let lastLoginAt = record["lastLoginAt"] as? Date {
            self.lastLoginAt = lastLoginAt
        }
        if let subscriptionExpiresAt = record["subscriptionExpiresAt"] as? Date {
            self.subscriptionExpiresAt = subscriptionExpiresAt
        }
    }
}

// MARK: - Game CloudKit Extension

extension Game {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: gameId.uuidString)
        let record = CKRecord(recordType: "Game", recordID: recordID)
        
        record["gameType"] = (gameType ?? "Poker") as CKRecordValue
        record["isPublic"] = (isPublic ? 1 : 0) as CKRecordValue
        record["softDeleted"] = (softDeleted ? 1 : 0) as CKRecordValue
        
        if let timestamp = timestamp {
            record["timestamp"] = timestamp as CKRecordValue
        }
        if let notes = notes {
            record["notes"] = notes as CKRecordValue
        }
        if let creatorUserId = creatorUserId {
            let creatorReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: creatorUserId.uuidString),
                action: .none
            )
            record["creator"] = creatorReference as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let gameType = record["gameType"] as? String {
            self.gameType = gameType
        }
        if let isPublic = record["isPublic"] as? Bool {
            self.isPublic = isPublic
        }
        if let softDeleted = record["softDeleted"] as? Bool {
            self.softDeleted = softDeleted
        }
        if let timestamp = record["timestamp"] as? Date {
            self.timestamp = timestamp
        }
        if let notes = record["notes"] as? String {
            self.notes = notes
        }
        if let creatorReference = record["creator"] as? CKRecord.Reference {
            let creatorUUIDString = creatorReference.recordID.recordName
            self.creatorUserId = UUID(uuidString: creatorUUIDString)
        }
    }
}

// MARK: - PlayerProfile CloudKit Extension

extension PlayerProfile {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: profileId.uuidString)
        let record = CKRecord(recordType: "PlayerProfile", recordID: recordID)
        
        record["displayName"] = displayName as CKRecordValue
        record["isAnonymous"] = (isAnonymous ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["totalGamesPlayed"] = totalGamesPlayed as CKRecordValue
        record["totalBuyins"] = NSNumber(value: (totalBuyins as NSDecimalNumber).doubleValue)
        record["totalCashouts"] = NSNumber(value: (totalCashouts as NSDecimalNumber).doubleValue)
        
        if let userId = userId {
            let userReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: userId.uuidString),
                action: .deleteSelf
            )
            record["user"] = userReference as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let displayName = record["displayName"] as? String {
            self.displayName = displayName
        }
        if let isAnonymous = record["isAnonymous"] as? Bool {
            self.isAnonymous = isAnonymous
        }
        if let createdAt = record["createdAt"] as? Date {
            self.createdAt = createdAt
        }
        if let totalGamesPlayed = record["totalGamesPlayed"] as? Int32 {
            self.totalGamesPlayed = totalGamesPlayed
        }
        if let totalBuyins = record["totalBuyins"] as? Double {
            self.totalBuyins = NSDecimalNumber(value: totalBuyins)
        }
        if let totalCashouts = record["totalCashouts"] as? Double {
            self.totalCashouts = NSDecimalNumber(value: totalCashouts)
        }
        if let userReference = record["user"] as? CKRecord.Reference {
            let userUUIDString = userReference.recordID.recordName
            self.userId = UUID(uuidString: userUUIDString)
        }
    }
}

// MARK: - PlayerAlias CloudKit Extension

extension PlayerAlias {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: aliasId.uuidString)
        let record = CKRecord(recordType: "PlayerAlias", recordID: recordID)
        
        record["aliasName"] = aliasName as CKRecordValue
        record["claimedAt"] = claimedAt as CKRecordValue
        record["gamesCount"] = gamesCount as CKRecordValue
        
        let profileReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: profileId.uuidString),
            action: .deleteSelf
        )
        record["profile"] = profileReference as CKRecordValue
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let aliasName = record["aliasName"] as? String {
            self.aliasName = aliasName
        }
        if let claimedAt = record["claimedAt"] as? Date {
            self.claimedAt = claimedAt
        }
        if let gamesCount = record["gamesCount"] as? Int32 {
            self.gamesCount = gamesCount
        }
        if let profileReference = record["profile"] as? CKRecord.Reference {
            let profileUUIDString = profileReference.recordID.recordName
            self.profileId = UUID(uuidString: profileUUIDString) ?? profileId
        }
    }
}

// MARK: - PlayerClaim CloudKit Extension

extension PlayerClaim {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: claimId.uuidString)
        let record = CKRecord(recordType: "PlayerClaim", recordID: recordID)
        
        record["playerName"] = playerName as CKRecordValue
        record["gameWithPlayerObjectId"] = gameWithPlayerObjectId as CKRecordValue
        record["status"] = status as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        
        // Game reference
        let gameReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: gameId.uuidString),
            action: .none
        )
        record["game"] = gameReference as CKRecordValue
        
        // Claimant user reference
        let claimantReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: claimantUserId.uuidString),
            action: .none
        )
        record["claimantUser"] = claimantReference as CKRecordValue
        
        // Host user reference
        let hostReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: hostUserId.uuidString),
            action: .none
        )
        record["hostUser"] = hostReference as CKRecordValue
        
        if let resolvedAt = resolvedAt {
            record["resolvedAt"] = resolvedAt as CKRecordValue
        }
        if let resolvedByUserId = resolvedByUserId {
            let resolverReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: resolvedByUserId.uuidString),
                action: .none
            )
            record["resolvedByUser"] = resolverReference as CKRecordValue
        }
        if let notes = notes {
            record["notes"] = notes as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let playerName = record["playerName"] as? String {
            self.playerName = playerName
        }
        if let gameWithPlayerObjectId = record["gameWithPlayerObjectId"] as? String {
            self.gameWithPlayerObjectId = gameWithPlayerObjectId
        }
        if let status = record["status"] as? String {
            self.status = status
        }
        if let createdAt = record["createdAt"] as? Date {
            self.createdAt = createdAt
        }
        if let resolvedAt = record["resolvedAt"] as? Date {
            self.resolvedAt = resolvedAt
        }
        if let notes = record["notes"] as? String {
            self.notes = notes
        }
        
        // Update references
        if let gameReference = record["game"] as? CKRecord.Reference {
            let gameUUIDString = gameReference.recordID.recordName
            self.gameId = UUID(uuidString: gameUUIDString) ?? gameId
        }
        if let claimantReference = record["claimantUser"] as? CKRecord.Reference {
            let claimantUUIDString = claimantReference.recordID.recordName
            self.claimantUserId = UUID(uuidString: claimantUUIDString) ?? claimantUserId
        }
        if let hostReference = record["hostUser"] as? CKRecord.Reference {
            let hostUUIDString = hostReference.recordID.recordName
            self.hostUserId = UUID(uuidString: hostUUIDString) ?? hostUserId
        }
        if let resolverReference = record["resolvedByUser"] as? CKRecord.Reference {
            let resolverUUIDString = resolverReference.recordID.recordName
            self.resolvedByUserId = UUID(uuidString: resolverUUIDString)
        }
    }
}

// MARK: - GameWithPlayer CloudKit Extension

extension GameWithPlayer {
    func toCKRecord() -> CKRecord {
        // Генерируем уникальный ID для записи
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "GameWithPlayer", recordID: recordID)
        
        record["buyin"] = buyin as CKRecordValue
        record["cashout"] = cashout as CKRecordValue
        
        // Reference к Game (обязательный)
        if let game = game {
            let gameRef = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: game.gameId.uuidString),
                action: .deleteSelf  // Удалить при удалении игры
            )
            record["game"] = gameRef as CKRecordValue
        }
        
        // Reference к PlayerProfile (опциональный)
        if let playerProfile = playerProfile {
            let profileRef = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: playerProfile.profileId.uuidString),
                action: .none
            )
            record["playerProfile"] = profileRef as CKRecordValue
        }
        
        // Имя игрока для отображения
        if let player = player, let playerName = player.name {
            record["playerName"] = playerName as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let buyin = record["buyin"] as? Int16 {
            self.buyin = buyin
        }
        if let cashout = record["cashout"] as? Int64 {
            self.cashout = cashout
        }
        // References (game, playerProfile) обрабатываются при merge
    }
}

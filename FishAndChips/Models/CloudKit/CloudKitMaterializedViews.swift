//
//  CloudKitMaterializedViews.swift
//  FishAndChips
//
//  CloudKit extensions for Phase 2 materialized views
//

import Foundation
import CloudKit
import CoreData

// MARK: - UserStatisticsSummary CloudKit Extension

extension UserStatisticsSummary {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "UserStatisticsSummary_\(userId.uuidString)")
        let record = CKRecord(recordType: "UserStatisticsSummary", recordID: recordID)

        record["userId"] = userId.uuidString as CKRecordValue
        record["totalGamesPlayed"] = totalGamesPlayed as CKRecordValue
        record["totalBuyins"] = totalBuyins as CKRecordValue
        record["totalCashouts"] = totalCashouts as CKRecordValue
        record["balance"] = balance as CKRecordValue
        record["lastGameDate"] = lastGameDate as CKRecordValue?
        record["winRate"] = winRate as CKRecordValue
        record["avgProfit"] = avgProfit as CKRecordValue
        record["lastUpdated"] = lastUpdated as CKRecordValue

        return record
    }

    func updateFromCKRecord(_ record: CKRecord) {
        if let userIdString = record["userId"] as? String,
           let uuid = UUID(uuidString: userIdString) {
            self.userId = uuid
        }
        if let totalGamesPlayed = record["totalGamesPlayed"] as? Int64 {
            self.totalGamesPlayed = totalGamesPlayed
        }
        if let totalBuyins = record["totalBuyins"] as? Double {
            self.totalBuyins = totalBuyins
        }
        if let totalCashouts = record["totalCashouts"] as? Double {
            self.totalCashouts = totalCashouts
        }
        if let balance = record["balance"] as? Double {
            self.balance = balance
        }
        if let lastGameDate = record["lastGameDate"] as? Date {
            self.lastGameDate = lastGameDate
        }
        if let winRate = record["winRate"] as? Double {
            self.winRate = winRate
        }
        if let avgProfit = record["avgProfit"] as? Double {
            self.avgProfit = avgProfit
        }
        if let lastUpdated = record["lastUpdated"] as? Date {
            self.lastUpdated = lastUpdated
        }
    }
}

// MARK: - GameSummaryRecord CloudKit Extension

extension GameSummaryRecord {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "GameSummary_\(gameId.uuidString)")
        let record = CKRecord(recordType: "GameSummary", recordID: recordID)

        record["gameId"] = gameId.uuidString as CKRecordValue
        record["creatorUserId"] = creatorUserId?.uuidString as CKRecordValue?
        record["gameType"] = gameType as CKRecordValue?
        record["timestamp"] = timestamp as CKRecordValue?
        record["totalPlayers"] = totalPlayers as CKRecordValue
        record["totalBuyins"] = totalBuyins as CKRecordValue
        record["isPublic"] = (isPublic ? 1 : 0) as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue?
        record["checksum"] = checksum as CKRecordValue?

        return record
    }

    func updateFromCKRecord(_ record: CKRecord) {
        if let gameIdString = record["gameId"] as? String,
           let uuid = UUID(uuidString: gameIdString) {
            self.gameId = uuid
        }
        if let creatorUserIdString = record["creatorUserId"] as? String {
            self.creatorUserId = UUID(uuidString: creatorUserIdString)
        }
        if let gameType = record["gameType"] as? String {
            self.gameType = gameType
        }
        if let timestamp = record["timestamp"] as? Date {
            self.timestamp = timestamp
        }
        if let totalPlayers = record["totalPlayers"] as? Int64 {
            self.totalPlayers = totalPlayers
        }
        if let totalBuyins = record["totalBuyins"] as? Double {
            self.totalBuyins = totalBuyins
        }
        if let isPublic = record["isPublic"] as? Bool {
            self.isPublic = isPublic
        } else if let isPublicInt = record["isPublic"] as? Int64 {
            self.isPublic = (isPublicInt == 1)
        }
        if let lastModified = record["lastModified"] as? Date {
            self.lastModified = lastModified
        }
        if let checksum = record["checksum"] as? String {
            self.checksum = checksum
        }
    }
}

// MARK: - UserGameIndex CloudKit Extension

extension UserGameIndex {
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "UserGameIndex_\(indexId.uuidString)")
        let record = CKRecord(recordType: "UserGameIndex", recordID: recordID)

        record["indexId"] = indexId.uuidString as CKRecordValue
        record["userId"] = userId.uuidString as CKRecordValue
        record["gameId"] = gameId.uuidString as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue?
        record["buyin"] = buyin as CKRecordValue
        record["cashout"] = cashout as CKRecordValue
        record["isHost"] = (isHost ? 1 : 0) as CKRecordValue

        return record
    }

    func updateFromCKRecord(_ record: CKRecord) {
        if let indexIdString = record["indexId"] as? String,
           let uuid = UUID(uuidString: indexIdString) {
            self.indexId = uuid
        }
        if let userIdString = record["userId"] as? String,
           let uuid = UUID(uuidString: userIdString) {
            self.userId = uuid
        }
        if let gameIdString = record["gameId"] as? String,
           let uuid = UUID(uuidString: gameIdString) {
            self.gameId = uuid
        }
        if let timestamp = record["timestamp"] as? Date {
            self.timestamp = timestamp
        }
        if let buyin = record["buyin"] as? Double {
            self.buyin = buyin
        }
        if let cashout = record["cashout"] as? Double {
            self.cashout = cashout
        }
        if let isHost = record["isHost"] as? Bool {
            self.isHost = isHost
        } else if let isHostInt = record["isHost"] as? Int64 {
            self.isHost = (isHostInt == 1)
        }
    }
}

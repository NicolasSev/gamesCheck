//
//  CloudKitService.swift
//  PokerCardRecognizer
//
//  Created for Phase 3: CloudKit Setup & Integration
//

import Foundation
import CloudKit

/// Service for CloudKit database operations
class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    // MARK: - Database Type
    enum DatabaseType {
        case publicDB
        case privateDB
    }
    
    // MARK: - Record Types
    enum RecordType: String {
        case user = "User"
        case game = "Game"
        case playerProfile = "PlayerProfile"
        case playerAlias = "PlayerAlias"
        case gameWithPlayer = "GameWithPlayer"
        case playerClaim = "PlayerClaim"
    }
    
    // MARK: - Initialization
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.nicolascooper.FishAndChips")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
    
    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            return status == .available
        } catch {
            print("CloudKit account status check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Save Record
    
    func save(record: CKRecord, to database: DatabaseType = .privateDB) async throws -> CKRecord {
        let db = database == .publicDB ? publicDatabase : privateDatabase
        return try await db.save(record)
    }
    
    func saveRecords(_ records: [CKRecord], to database: DatabaseType = .privateDB) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []
            
            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    print("Failed to save record \(recordID): \(error)")
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            let db = database == .publicDB ? publicDatabase : privateDatabase
            db.add(operation)
        }
    }
    
    // MARK: - Fetch Record
    
    func fetch(recordID: CKRecord.ID, from database: DatabaseType = .privateDB) async throws -> CKRecord {
        let db = database == .publicDB ? publicDatabase : privateDatabase
        return try await db.record(for: recordID)
    }
    
    func fetchRecords(
        withType type: RecordType,
        from database: DatabaseType = .privateDB,
        predicate: NSPredicate = NSPredicate(value: true),
        limit: Int = 100
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type.rawValue, predicate: predicate)
        // Don't use sort by default - CloudKit system fields may not be indexed
        query.sortDescriptors = nil
        
        let db = database == .publicDB ? publicDatabase : privateDatabase
        let (matchResults, _) = try await db.records(matching: query, desiredKeys: nil, resultsLimit: limit)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        
        return records
    }
    
    // MARK: - Delete Record
    
    func delete(recordID: CKRecord.ID, from database: DatabaseType = .privateDB) async throws {
        let db = database == .publicDB ? publicDatabase : privateDatabase
        _ = try await db.deleteRecord(withID: recordID)
    }
    
    func deleteRecords(_ recordIDs: [CKRecord.ID], from database: DatabaseType = .privateDB) async throws {
        let operation = CKModifyRecordsOperation(recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            let db = database == .publicDB ? publicDatabase : privateDatabase
            db.add(operation)
        }
    }
    
    // MARK: - Query with Cursor (for pagination)
    
    func queryRecords(
        withType type: RecordType,
        from database: DatabaseType = .privateDB,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int = 100
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        let query = CKQuery(recordType: type.rawValue, predicate: predicate)
        // Don't use default sort - CloudKit system fields require special indexes
        query.sortDescriptors = sortDescriptors
        
        let db = database == .publicDB ? publicDatabase : privateDatabase
        let (matchResults, cursor) = try await db.records(matching: query, desiredKeys: nil, resultsLimit: resultsLimit)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        
        return (records, cursor)
    }
    
    // MARK: - Subscriptions
    
    func saveSubscription(subscription: CKSubscription) async throws -> CKSubscription {
        return try await privateDatabase.save(subscription)
    }
    
    func fetchAllSubscriptions() async throws -> [CKSubscription] {
        return try await privateDatabase.allSubscriptions()
    }
    
    func deleteSubscription(withID subscriptionID: CKSubscription.ID) async throws {
        _ = try await privateDatabase.deleteSubscription(withID: subscriptionID)
    }
    
    // MARK: - Error Handling
    
    func handleCloudKitError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }
        
        switch ckError.code {
        case .notAuthenticated:
            return "Необходимо войти в iCloud"
        case .networkFailure, .networkUnavailable:
            return "Проблема с сетевым подключением"
        case .quotaExceeded:
            return "Превышен лимит хранилища iCloud"
        case .serverRejectedRequest:
            return "Сервер отклонил запрос"
        case .serviceUnavailable:
            return "Сервис CloudKit временно недоступен"
        case .zoneBusy:
            return "Зона CloudKit занята. Попробуйте позже"
        default:
            return "Ошибка CloudKit: \(ckError.localizedDescription)"
        }
    }
}

// MARK: - CloudKit Error Extensions

extension CloudKitService {
    func isNetworkError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .networkFailure || ckError.code == .networkUnavailable
    }
    
    func isAuthenticationError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .notAuthenticated
    }
    
    func isRetryable(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        
        let retryableCodes: [CKError.Code] = [
            .networkFailure,
            .networkUnavailable,
            .serviceUnavailable,
            .zoneBusy
        ]
        
        return retryableCodes.contains(ckError.code)
    }
    
    func retryDelay(for error: Error) -> TimeInterval {
        guard let ckError = error as? CKError else { return 3.0 }
        
        if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return retryAfter
        }
        
        // Default delays based on error type
        switch ckError.code {
        case .zoneBusy:
            return 2.0
        default:
            return 3.0
        }
    }
}

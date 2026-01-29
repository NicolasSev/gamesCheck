//
//  CloudKitSyncService.swift
//  PokerCardRecognizer
//
//  Created for Phase 3: CloudKit Setup & Integration
//

import Foundation
import CloudKit
import CoreData
import Combine

/// Service to synchronize CoreData with CloudKit
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let cloudKit: CloudKitService
    private let persistence: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // Sync queue to prevent concurrent syncs
    private let syncQueue = DispatchQueue(label: "com.nicolascooper.FishAndChips.sync", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init(
        cloudKit: CloudKitService = .shared,
        persistence: PersistenceController = .shared
    ) {
        self.cloudKit = cloudKit
        self.persistence = persistence
        
        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date {
            self.lastSyncDate = lastSync
        }
    }
    
    // MARK: - Main Sync
    
    func sync() async throws {
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        // Check CloudKit availability
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }
        
        do {
            // Sync in order to maintain referential integrity
            try await syncUsers()
            try await syncPlayerProfiles()
            try await syncPlayerAliases()
            try await syncGames()
            try await syncPlayerClaims()
            
            // Update last sync date
            let now = Date()
            await MainActor.run {
                lastSyncDate = now
            }
            UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")
            
            print("✅ CloudKit sync completed successfully")
        } catch {
            let errorMessage = cloudKit.handleCloudKitError(error)
            await MainActor.run {
                syncError = errorMessage
            }
            throw error
        }
    }
    
    // MARK: - User Sync
    
    private func syncUsers() async throws {
        let context = persistence.container.viewContext
        
        // Fetch local users that need syncing
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(fetchRequest)
        
        // Convert to CKRecords and save
        let records = users.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records)
            print("✅ Synced \(records.count) users to CloudKit")
        }
    }
    
    // MARK: - PlayerProfile Sync
    
    private func syncPlayerProfiles() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        let profiles = try context.fetch(fetchRequest)
        
        let records = profiles.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records)
            print("✅ Synced \(records.count) player profiles to CloudKit")
        }
    }
    
    // MARK: - PlayerAlias Sync
    
    private func syncPlayerAliases() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        let aliases = try context.fetch(fetchRequest)
        
        let records = aliases.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records)
            print("✅ Synced \(records.count) player aliases to CloudKit")
        }
    }
    
    // MARK: - Game Sync
    
    private func syncGames() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "softDeleted == NO")
        let games = try context.fetch(fetchRequest)
        
        let records = games.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records)
            print("✅ Synced \(records.count) games to CloudKit")
        }
    }
    
    // MARK: - PlayerClaim Sync
    
    private func syncPlayerClaims() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        let claims = try context.fetch(fetchRequest)
        
        let records = claims.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records)
            print("✅ Synced \(records.count) player claims to CloudKit")
        }
    }
    
    // MARK: - Pull Changes from CloudKit
    
    func pullChanges() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        // Fetch changes from CloudKit
        let users = try await cloudKit.fetchRecords(withType: .user)
        let profiles = try await cloudKit.fetchRecords(withType: .playerProfile)
        let aliases = try await cloudKit.fetchRecords(withType: .playerAlias)
        let games = try await cloudKit.fetchRecords(withType: .game)
        let claims = try await cloudKit.fetchRecords(withType: .playerClaim)
        
        // Update local CoreData
        let context = persistence.container.viewContext
        
        // Process users
        for record in users {
            if let existingUser = persistence.fetchUser(byId: UUID(uuidString: record.recordID.recordName)!) {
                existingUser.updateFromCKRecord(record)
            }
        }
        
        // Process profiles
        for record in profiles {
            if let profileId = UUID(uuidString: record.recordID.recordName),
               let existingProfile = persistence.fetchPlayerProfile(byProfileId: profileId) {
                existingProfile.updateFromCKRecord(record)
            }
        }
        
        // Save context
        if context.hasChanges {
            try context.save()
        }
        
        print("✅ Pulled changes from CloudKit")
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(localRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        // Last-write-wins strategy based on modification date
        guard let localModDate = localRecord.modificationDate,
              let serverModDate = serverRecord.modificationDate else {
            return serverRecord
        }
        
        return localModDate > serverModDate ? localRecord : serverRecord
    }
    
    // MARK: - Network Reachability
    
    func canSync() async -> Bool {
        return await cloudKit.isCloudKitAvailable()
    }
}

// MARK: - Sync Errors

enum CloudKitSyncError: LocalizedError {
    case cloudKitNotAvailable
    case syncInProgress
    case networkError
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .cloudKitNotAvailable:
            return "CloudKit недоступен. Проверьте подключение к iCloud"
        case .syncInProgress:
            return "Синхронизация уже выполняется"
        case .networkError:
            return "Ошибка сети. Проверьте подключение к интернету"
        case .authenticationRequired:
            return "Необходимо войти в iCloud"
        }
    }
}

// MARK: - Sync Status

extension CloudKitSyncService {
    var syncStatusText: String {
        if isSyncing {
            return "Синхронизация..."
        } else if let error = syncError {
            return "Ошибка: \(error)"
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Синхронизировано \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Не синхронизировано"
        }
    }
}

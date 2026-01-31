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
    
    // MARK: - User Sync (Private Database)
    
    private func syncUsers() async throws {
        let context = persistence.container.viewContext
        
        // Fetch local users that need syncing
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(fetchRequest)
        
        // Convert to CKRecords and save to Private Database
        let records = users.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .privateDB)
            print("✅ Synced \(records.count) users to Private Database")
        }
    }
    
    // MARK: - PlayerProfile Sync (Private Database)
    
    private func syncPlayerProfiles() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        let profiles = try context.fetch(fetchRequest)
        
        let records = profiles.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .privateDB)
            print("✅ Synced \(records.count) player profiles to Private Database")
        }
    }
    
    // MARK: - PlayerAlias Sync (Public Database)
    
    private func syncPlayerAliases() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        let aliases = try context.fetch(fetchRequest)
        
        let records = aliases.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ Synced \(records.count) player aliases to Public Database")
        }
    }
    
    // MARK: - Game Sync (Public Database)
    
    private func syncGames() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "softDeleted == NO")
        let games = try context.fetch(fetchRequest)
        
        let records = games.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ Synced \(records.count) games to Public Database")
        }
    }
    
    // MARK: - PlayerClaim Sync (Private Database)
    
    private func syncPlayerClaims() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        let claims = try context.fetch(fetchRequest)
        
        let records = claims.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .privateDB)
            print("✅ Synced \(records.count) player claims to Private Database")
        }
    }
    
    // MARK: - Pull Changes from CloudKit
    
    func pullChanges() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        // Fetch changes from CloudKit (Private Database)
        let users = try await cloudKit.fetchRecords(withType: .user, from: .privateDB)
        let profiles = try await cloudKit.fetchRecords(withType: .playerProfile, from: .privateDB)
        
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
    
    // MARK: - Full Sync (Push local + Pull public)
    
    func performFullSync() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        print("🚀 Starting full sync...")
        
        // 1. Fetch public data from CloudKit
        try await fetchPublicGames()
        try await fetchPublicPlayerAliases()
        
        // 2. Push local changes to CloudKit
        try await sync()
        
        print("✅ Full sync completed")
    }
    
    // MARK: - Fetch Public Games
    
    func fetchPublicGames() async throws {
        let predicate = NSPredicate(format: "softDeleted == NO OR softDeleted == nil")
        let records = try await cloudKit.fetchRecords(
            withType: .game,
            from: .publicDB,
            predicate: predicate,
            limit: 500
        )
        
        if records.isEmpty {
            print("ℹ️ No public games found in CloudKit")
            return
        }
        
        print("📥 Fetched \(records.count) public games from CloudKit")
        
        // Merge with local data
        await mergeGamesWithLocal(records)
    }
    
    // MARK: - Fetch Public Player Aliases
    
    private func fetchPublicPlayerAliases() async throws {
        let records = try await cloudKit.fetchRecords(
            withType: .playerAlias,
            from: .publicDB,
            limit: 500
        )
        
        if !records.isEmpty {
            print("📥 Fetched \(records.count) public player aliases from CloudKit")
            // TODO: Implement merge logic for aliases if needed
        }
    }
    
    // MARK: - Merge Games with Local
    
    @MainActor
    private func mergeGamesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        for record in cloudRecords {
            let gameIdString = record.recordID.recordName
            guard let gameId = UUID(uuidString: gameIdString) else {
                print("⚠️ Invalid game ID in CloudKit record: \(gameIdString)")
                continue
            }
            
            // Search for local game
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
            
            do {
                if let localGame = try context.fetch(fetchRequest).first {
                    // Game exists locally - check if CloudKit version is newer
                    if let cloudModDate = record.modificationDate,
                       let localTimestamp = localGame.timestamp {
                        if cloudModDate > localTimestamp {
                            // CloudKit is newer - update local
                            localGame.updateFromCKRecord(record)
                            print("🔄 Updated local game: \(gameId)")
                        } else {
                            print("⏭️ Local game is up to date: \(gameId)")
                        }
                    } else {
                        // If no dates, update anyway
                        localGame.updateFromCKRecord(record)
                        print("🔄 Updated local game (no date comparison): \(gameId)")
                    }
                } else {
                    // Game doesn't exist locally - create it
                    if self.createGameFromCKRecord(record, in: context) != nil {
                        print("➕ Created local game: \(gameId)")
                    }
                }
            } catch {
                print("❌ Error processing game \(gameId): \(error)")
            }
        }
        
        // Save all changes
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Merged \(cloudRecords.count) games with local database")
            } catch {
                print("❌ Failed to save merged games: \(error)")
            }
        }
    }
    
    // MARK: - Create Game from CKRecord
    
    @MainActor
    private func createGameFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> Game? {
        let gameIdString = record.recordID.recordName
        guard let gameId = UUID(uuidString: gameIdString) else {
            print("⚠️ Invalid game ID in CloudKit record: \(gameIdString)")
            return nil
        }
        
        let game = Game(context: context)
        game.gameId = gameId
        game.updateFromCKRecord(record)
        
        return game
    }
    
    // MARK: - Fetch Single Game by ID
    
    func fetchGame(byId gameId: UUID) async throws -> Game? {
        let recordID = CKRecord.ID(recordName: gameId.uuidString)
        
        do {
            let record = try await cloudKit.fetch(recordID: recordID, from: .publicDB)
            
            // Create or update local copy
            return await MainActor.run {
                let context = persistence.container.viewContext
                let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
                
                if let existingGame = try? context.fetch(fetchRequest).first {
                    existingGame.updateFromCKRecord(record)
                    try? context.save()
                    return existingGame
                } else {
                    let newGame = self.createGameFromCKRecord(record, in: context)
                    try? context.save()
                    return newGame
                }
            }
        } catch {
            print("❌ Failed to fetch game \(gameId) from CloudKit: \(error)")
            throw CloudKitSyncError.gameNotFound
        }
    }
    
    // MARK: - Incremental Sync (Delta Sync)
    
    func performIncrementalSync() async throws {
        // TODO: Implement incremental sync with CKServerChangeToken
        // For now, fallback to full sync
        print("ℹ️ Incremental sync not yet implemented, using full sync")
        try await performFullSync()
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
    case gameNotFound
    
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
        case .gameNotFound:
            return "Игра не найдена в CloudKit"
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

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
            // Private Database sync
            try await syncPlayerProfiles()
            
            // Public Database sync
            try await syncPlayerClaims()
            try await syncGames()
            try await syncGameWithPlayers()
            try await syncPlayerAliases()
            
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
    // DEPRECATED: User should NOT be synced to CloudKit
    // Each device has its own local User for authentication
    // Use PlayerProfile for cross-device user data instead
    
    @available(*, deprecated, message: "Use quickSyncUser() instead. Bulk sync is not needed for User.")
    private func syncUsers() async throws {
        let context = persistence.container.viewContext
        
        // Fetch local users that need syncing
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(fetchRequest)
        
        // Convert to CKRecords and save to Public Database
        // NOTE: passwordHash is NOT included in sync (local only)
        let records = users.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ Synced \(records.count) users to Public Database")
        }
    }
    
    // MARK: - PlayerProfile Sync (Private Database)
    
    private func syncPlayerProfiles() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        let profiles = try context.fetch(fetchRequest)
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let records = Array(profiles).map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .privateDB)
            print("✅ Synced \(records.count) player profiles to Private Database")
        }
    }
    
    // MARK: - PlayerAlias Sync (Public Database)
    
    func syncPlayerAliases() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        let aliases = try context.fetch(fetchRequest)
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let records = Array(aliases).map { $0.toCKRecord() }
        
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
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let records = Array(games).map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ Synced \(records.count) games to Public Database")
        }
    }
    
    // MARK: - GameWithPlayer Sync (Public Database)
    
    private func syncGameWithPlayers() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        // Только для не удалённых игр
        fetchRequest.predicate = NSPredicate(format: "game.softDeleted == NO")
        
        let gameWithPlayers = try context.fetch(fetchRequest)
        
        print("🔄 [SYNC_GWP] Found \(gameWithPlayers.count) GameWithPlayer records to sync")
        
        // Конвертируем в records безопасно, без изменения коллекции во время итерации
        var records: [CKRecord] = []
        records.reserveCapacity(gameWithPlayers.count)
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let gwpArray = Array(gameWithPlayers)
        
        for (index, gwp) in gwpArray.enumerated() {
            let record = gwp.toCKRecord()
            records.append(record)
            
            if (index + 1) % 100 == 0 {
                print("📦 [SYNC_GWP] Converted \(index + 1)/\(gwpArray.count) records")
            }
        }
        
        if !records.isEmpty {
            print("☁️ [SYNC_GWP] Saving \(records.count) records to CloudKit...")
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ [SYNC_GWP] Synced \(records.count) game-player records to Public Database")
        } else {
            print("ℹ️ [SYNC_GWP] No valid records to sync")
        }
    }
    
    // MARK: - PlayerClaim Sync (Public Database - changed from Private)
    
    func syncPlayerClaims() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        let claims = try context.fetch(fetchRequest)
        
        print("🔄 [SYNC_CLAIMS] Found \(claims.count) claims to sync")
        
        // Фильтруем и конвертируем claims в CKRecords с обработкой ошибок
        var records: [CKRecord] = []
        for (index, claim) in claims.enumerated() {
            do {
                print("📦 [SYNC_CLAIMS] Converting claim \(index + 1)/\(claims.count): \(claim.claimId)")
                let record = claim.toCKRecord()
                records.append(record)
            } catch {
                print("❌ [SYNC_CLAIMS] Failed to convert claim \(claim.claimId) to CKRecord: \(error)")
                print("   - playerName: \(claim.playerName)")
                print("   - gameId: \(claim.gameId)")
                print("   - status: \(claim.status)")
                // Пропускаем проблемную запись и продолжаем
                continue
            }
        }
        
        if !records.isEmpty {
            print("☁️ [SYNC_CLAIMS] Saving \(records.count) claims to CloudKit Public Database...")
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ [SYNC_CLAIMS] Synced \(records.count) player claims to Public Database")
        } else {
            print("ℹ️ [SYNC_CLAIMS] No valid claims to sync")
        }
    }
    
    // MARK: - Pull Changes from CloudKit
    
    func pullChanges() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        print("🔄 [PULL] Fetching changes from CloudKit...")
        
        // Fetch changes from CloudKit
        let users = try await cloudKit.fetchRecords(withType: .user, from: .publicDB)
        let profiles = try await cloudKit.fetchRecords(withType: .playerProfile, from: .privateDB)
        let claims = try await cloudKit.fetchRecords(withType: .playerClaim, from: .publicDB)
        let games = try await cloudKit.fetchRecords(withType: .game, from: .publicDB)
        let gameWithPlayers = try await cloudKit.fetchRecords(withType: .gameWithPlayer, from: .publicDB)
        let aliases = try await cloudKit.fetchRecords(withType: .playerAlias, from: .publicDB)
        
        print("📥 [PULL] Fetched: \(users.count) users, \(profiles.count) profiles, \(claims.count) claims, \(games.count) games, \(gameWithPlayers.count) gameWithPlayers, \(aliases.count) aliases")
        
        // Update local CoreData
        let context = persistence.container.viewContext
        
        // CloudKit = Source of Truth: собираем ID из CloudKit
        var cloudUserIds = Set<UUID>()
        var cloudProfileIds = Set<UUID>()
        var cloudClaimIds = Set<UUID>()
        var cloudGameIds = Set<UUID>()
        var cloudAliasIds = Set<UUID>()
        
        // Process users
        for record in users {
            if let userId = UUID(uuidString: record.recordID.recordName) {
                cloudUserIds.insert(userId)
                
                if let existingUser = persistence.fetchUser(byId: userId) {
                    // CloudKit = Source of Truth: всегда обновляем
                    existingUser.updateFromCKRecord(record)
                } else {
                    // Создаем нового пользователя из CloudKit
                    let newUser = User(context: context)
                    newUser.userId = userId
                    newUser.updateFromCKRecord(record)
                    newUser.passwordHash = "remote_user_no_auth" // Placeholder
                    print("➕ [PULL] Created user from CloudKit: \(newUser.username)")
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные users, которых нет в CloudKit
        // ВАЖНО: НЕ удаляем текущего залогиненного пользователя (может быть офлайн регистрация)
        do {
            let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
            let allLocalUsers = try context.fetch(fetchRequest)
            
            // Получаем текущего пользователя (если есть)
            let currentUserId = UserDefaults.standard.string(forKey: "currentUserId")
                .flatMap { UUID(uuidString: $0) }
            
            var deletedCount = 0
            for localUser in allLocalUsers {
                // НЕ удаляем текущего пользователя
                if let currentUserId = currentUserId, localUser.userId == currentUserId {
                    print("🔒 [PULL] Skipping current user (logged in): \(localUser.username)")
                    continue
                }
                
                // Удаляем если нет в CloudKit
                if !cloudUserIds.contains(localUser.userId) {
                    print("🗑️ [PULL] Deleting local user not in CloudKit: \(localUser.username) (remote user)")
                    context.delete(localUser)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [PULL] Deleted \(deletedCount) remote users not found in CloudKit")
            }
        } catch {
            print("❌ [PULL] Error fetching local users for cleanup: \(error)")
        }
        
        // Process profiles
        for record in profiles {
            if let profileId = UUID(uuidString: record.recordID.recordName) {
                cloudProfileIds.insert(profileId)
                
                if let existingProfile = persistence.fetchPlayerProfile(byProfileId: profileId) {
                    // CloudKit = Source of Truth: всегда обновляем
                    existingProfile.updateFromCKRecord(record)
                } else {
                    // Создаем новый профиль из CloudKit
                    let newProfile = PlayerProfile(context: context)
                    newProfile.profileId = profileId
                    newProfile.updateFromCKRecord(record)
                    print("➕ [PULL] Created PlayerProfile from CloudKit: \(newProfile.displayName)")
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные профили, которых нет в CloudKit (Private DB)
        do {
            let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
            let allLocalProfiles = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localProfile in allLocalProfiles {
                if !cloudProfileIds.contains(localProfile.profileId) {
                    print("🗑️ [PULL] Deleting local profile not in CloudKit: \(localProfile.displayName)")
                    context.delete(localProfile)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [PULL] Deleted \(deletedCount) local profiles not found in CloudKit")
            }
        } catch {
            print("❌ [PULL] Error fetching local profiles for cleanup: \(error)")
        }
        
        // Process claims (с merge логикой)
        if !claims.isEmpty {
            print("🔄 [PULL] Merging \(claims.count) claims with local database...")
            await mergePlayerClaimsWithLocal(claims)
        }
        
        // Собираем cloudClaimIds для удаления
        for record in claims {
            if let claimId = UUID(uuidString: record.recordID.recordName) {
                cloudClaimIds.insert(claimId)
            }
        }
        
        // Process games (с удалением)
        for record in games {
            if let gameId = UUID(uuidString: record.recordID.recordName) {
                cloudGameIds.insert(gameId)
                
                if let existingGame = persistence.fetchGame(byId: gameId) {
                    existingGame.updateFromCKRecord(record)
                } else {
                    let newGame = Game(context: context)
                    newGame.gameId = gameId
                    newGame.updateFromCKRecord(record)
                    print("➕ [PULL] Created game from CloudKit: \(gameId)")
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные игры, которых нет в CloudKit
        // НО: НЕ удаляем данные, которые еще не успели синхронизироваться (pending)
        do {
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            let allLocalGames = try context.fetch(fetchRequest)
            let pendingGames = PendingSyncTracker.shared.getPendingGames()
            
            var deletedCount = 0
            for localGame in allLocalGames {
                // Проверяем: нет в CloudKit И нет в pending списке
                if !cloudGameIds.contains(localGame.gameId) && !pendingGames.contains(localGame.gameId) {
                    print("🗑️ [PULL] Deleting local game not in CloudKit: \(localGame.gameId)")
                    context.delete(localGame)
                    deletedCount += 1
                } else if !cloudGameIds.contains(localGame.gameId) && pendingGames.contains(localGame.gameId) {
                    print("📌 [PULL] Keeping pending game (not yet synced): \(localGame.gameId)")
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [PULL] Deleted \(deletedCount) local games not found in CloudKit")
            }
        } catch {
            print("❌ [PULL] Error fetching local games for cleanup: \(error)")
        }
        
        // Process gameWithPlayers - используем merge логику (с удалением внутри)
        if !gameWithPlayers.isEmpty {
            print("🔄 [PULL] Merging \(gameWithPlayers.count) GameWithPlayer records...")
            await mergeGameWithPlayersWithLocal(gameWithPlayers)
        } else {
            // Если в CloudKit нет GWP, удаляем все локальные
            print("🗑️ [PULL] CloudKit has 0 GameWithPlayer - deleting all local GWP")
            do {
                let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
                let allLocalGWP = try context.fetch(fetchRequest)
                for gwp in allLocalGWP {
                    context.delete(gwp)
                }
                if !allLocalGWP.isEmpty {
                    print("🗑️ [PULL] Deleted \(allLocalGWP.count) local GameWithPlayer")
                }
            } catch {
                print("❌ [PULL] Error deleting local GWP: \(error)")
            }
        }
        
        // Process aliases
        for record in aliases {
            if let aliasId = UUID(uuidString: record.recordID.recordName) {
                cloudAliasIds.insert(aliasId)
                
                if let existingAlias = persistence.fetchAlias(byId: aliasId) {
                    existingAlias.updateFromCKRecord(record)
                } else {
                    let newAlias = PlayerAlias(context: context)
                    newAlias.aliasId = aliasId
                    newAlias.updateFromCKRecord(record)
                    
                    if let profile = persistence.fetchPlayerProfile(byProfileId: newAlias.profileId) {
                        newAlias.profile = profile
                        print("➕ [PULL] Created PlayerAlias: \(newAlias.aliasName) for profile \(profile.displayName)")
                    } else {
                        print("⚠️ [PULL] PlayerProfile \(newAlias.profileId) not found for alias \(newAlias.aliasName)")
                    }
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные алиасы, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
            let allLocalAliases = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localAlias in allLocalAliases {
                if !cloudAliasIds.contains(localAlias.aliasId) {
                    print("🗑️ [PULL] Deleting local alias not in CloudKit: \(localAlias.aliasName)")
                    context.delete(localAlias)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [PULL] Deleted \(deletedCount) local aliases not found in CloudKit")
            }
        } catch {
            print("❌ [PULL] Error fetching local aliases for cleanup: \(error)")
        }
        
        // CloudKit = Source of Truth: удаляем локальные claims, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
            let allLocalClaims = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localClaim in allLocalClaims {
                if !cloudClaimIds.contains(localClaim.claimId) {
                    print("🗑️ [PULL] Deleting local claim not in CloudKit: \(localClaim.claimId)")
                    context.delete(localClaim)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [PULL] Deleted \(deletedCount) local claims not found in CloudKit")
            }
        } catch {
            print("❌ [PULL] Error fetching local claims for cleanup: \(error)")
        }
        
        // Save context
        if context.hasChanges {
            try context.save()
        }
        
        print("✅ [PULL] CloudKit sync completed - local database matches CloudKit (Source of Truth)")
    }
    
    // MARK: - Full Sync (Push local + Pull public)
    
    func performFullSync() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        print("🚀 Starting full sync (PULL ONLY - CloudKit is Source of Truth)...")
        
        // ТОЛЬКО PULL: Скачиваем данные из CloudKit
        // 1. Fetch public data from CloudKit
        try await fetchPublicGames()
        try await fetchPublicPlayerAliases()
        try await fetchPublicGameWithPlayers()
        
        // 2. Fetch private data from CloudKit
        try await fetchPlayerClaims()
        
        // ПРИМЕЧАНИЕ: PUSH (sync()) НЕ вызывается!
        // Данные загружаются в CloudKit ТОЛЬКО в момент их создания:
        // - Импорт игры → quickSyncGame()
        // - Создание заявки → syncPlayerClaims()
        // - Одобрение заявки → синхронизация в PlayerClaimService
        
        print("✅ Full sync completed (CloudKit data pulled)")
    }
    
    // MARK: - Fetch Public Games
    
    func fetchPublicGames() async throws {
        // CloudKit doesn't support OR in predicates
        // We fetch all games and filter softDeleted locally
        let predicate = NSPredicate(value: true)
        let records = try await cloudKit.fetchRecords(
            withType: .game,
            from: .publicDB,
            predicate: predicate,
            limit: 500
        )
        
        if records.isEmpty {
            print("ℹ️ [FETCH_GAMES] No public games found in CloudKit")
            print("☁️ [FETCH_GAMES] CloudKit = Source of Truth: will delete all local games (except pending)")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных игр
            await mergeGamesWithLocal([])
        } else {
            print("📥 [FETCH_GAMES] Fetched \(records.count) public games from CloudKit")
            // Merge with local data
            await mergeGamesWithLocal(records)
        }
    }
    
    // MARK: - Fetch Public Player Aliases
    
    private func fetchPublicPlayerAliases() async throws {
        let records = try await cloudKit.fetchRecords(
            withType: .playerAlias,
            from: .publicDB,
            limit: 500
        )
        
        if !records.isEmpty {
            print("📥 [FETCH_ALIASES] Fetched \(records.count) public player aliases from CloudKit")
            await mergePlayerAliasesWithLocal(records)
        } else {
            print("ℹ️ [FETCH_ALIASES] No aliases found in CloudKit")
            // CloudKit = Source of Truth: если в CloudKit нет алиасов, удаляем все локальные
            await deleteAllLocalAliases()
        }
    }
    
    // MARK: - Merge Aliases with Local
    
    @MainActor
    private func mergePlayerAliasesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        print("🔄 [MERGE_ALIASES] Starting merge: \(cloudRecords.count) aliases from CloudKit")
        
        var cloudAliasIds = Set<UUID>()
        
        for record in cloudRecords {
            guard let aliasId = UUID(uuidString: record.recordID.recordName) else {
                print("⚠️ [MERGE_ALIASES] Invalid alias ID: \(record.recordID.recordName)")
                continue
            }
            
            cloudAliasIds.insert(aliasId)
            
            if let existingAlias = persistence.fetchAlias(byId: aliasId) {
                // CloudKit = Source of Truth: всегда обновляем
                existingAlias.updateFromCKRecord(record)
                print("🔄 [MERGE_ALIASES] Updated alias: \(existingAlias.aliasName)")
            } else {
                let newAlias = PlayerAlias(context: context)
                newAlias.aliasId = aliasId
                newAlias.updateFromCKRecord(record)
                
                if let profile = persistence.fetchPlayerProfile(byProfileId: newAlias.profileId) {
                    newAlias.profile = profile
                    print("➕ [MERGE_ALIASES] Created alias: \(newAlias.aliasName) for profile \(profile.displayName)")
                } else {
                    print("⚠️ [MERGE_ALIASES] PlayerProfile \(newAlias.profileId) not found for alias \(newAlias.aliasName)")
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные алиасы, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
            let allLocalAliases = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localAlias in allLocalAliases {
                if !cloudAliasIds.contains(localAlias.aliasId) {
                    print("🗑️ [MERGE_ALIASES] Deleting local alias not in CloudKit: \(localAlias.aliasName)")
                    context.delete(localAlias)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [MERGE_ALIASES] Deleted \(deletedCount) local aliases not found in CloudKit")
            }
        } catch {
            print("❌ [MERGE_ALIASES] Error fetching local aliases for cleanup: \(error)")
        }
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [MERGE_ALIASES] Successfully merged aliases with local database")
            } catch {
                print("❌ [MERGE_ALIASES] Failed to save merged aliases: \(error)")
            }
        }
    }
    
    @MainActor
    private func deleteAllLocalAliases() async {
        let context = persistence.container.viewContext
        
        do {
            let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
            let allLocalAliases = try context.fetch(fetchRequest)
            
            if !allLocalAliases.isEmpty {
                print("🗑️ [DELETE_ALIASES] CloudKit has 0 aliases - deleting all \(allLocalAliases.count) local aliases")
                for alias in allLocalAliases {
                    context.delete(alias)
                }
                
                try context.save()
                print("✅ [DELETE_ALIASES] Deleted all local aliases")
            }
        } catch {
            print("❌ [DELETE_ALIASES] Error deleting local aliases: \(error)")
        }
    }
    
    // MARK: - Fetch Public GameWithPlayer
    
    private func fetchPublicGameWithPlayers() async throws {
        // CloudKit limit: 400 records per request
        // Fetch in batches if needed
        var allRecords: [CKRecord] = []
        var hasMore = true
        var cursor: CKQueryOperation.Cursor? = nil
        
        print("🔄 [FETCH_ALL_PLAYERS] Starting to fetch all GameWithPlayer records...")
        
        while hasMore && allRecords.count < 400 {
            let records = try await cloudKit.fetchRecords(
                withType: .gameWithPlayer,
                from: .publicDB,
                limit: 400  // CloudKit maximum
            )
            
            allRecords.append(contentsOf: records)
            print("📥 [FETCH_ALL_PLAYERS] Fetched batch: \(records.count) records (total: \(allRecords.count))")
            
            // For now, just fetch first batch (pagination not implemented)
            hasMore = false
        }
        
        if !allRecords.isEmpty {
            print("✅ [FETCH_ALL_PLAYERS] Total fetched: \(allRecords.count) game-player records from CloudKit")
            await mergeGameWithPlayersWithLocal(allRecords)
        } else {
            print("ℹ️ [FETCH_ALL_PLAYERS] No GameWithPlayer records found in CloudKit")
            print("☁️ [FETCH_ALL_PLAYERS] CloudKit = Source of Truth: will delete all local GameWithPlayer")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных GWP
            await mergeGameWithPlayersWithLocal([])
        }
    }
    
    /// Загружает игроков для конкретной игры из Public Database
    func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
        print("🔍 [FETCH_PLAYERS] Starting fetch for game: \(gameId)")
        
        // Query с фильтром по игре
        let gameRecordID = CKRecord.ID(recordName: gameId.uuidString)
        let gameRef = CKRecord.Reference(recordID: gameRecordID, action: .none)
        let predicate = NSPredicate(format: "game == %@", gameRef)
        
        print("🔍 [FETCH_PLAYERS] Query predicate: \(predicate)")
        print("🔍 [FETCH_PLAYERS] Game reference: \(gameRef.recordID.recordName)")
        
        do {
            let records = try await cloudKit.fetchRecords(
                withType: .gameWithPlayer,
                from: .publicDB,
                predicate: predicate,
                limit: 100
            )
            
            if !records.isEmpty {
                print("✅ [FETCH_PLAYERS] Fetched \(records.count) players for game \(gameId)")
                for (index, record) in records.enumerated() {
                    let playerName = record["playerName"] as? String ?? "Unknown"
                    let buyin = record["buyin"] as? Int16 ?? 0
                    let cashout = record["cashout"] as? Int64 ?? 0
                    print("   Player \(index + 1): \(playerName) (buyin: \(buyin), cashout: \(cashout))")
                }
                await mergeGameWithPlayersWithLocal(records)
            } else {
                print("⚠️ [FETCH_PLAYERS] No players found in CloudKit for game \(gameId)")
                print("⚠️ [FETCH_PLAYERS] This could mean:")
                print("   1. GameWithPlayer records were not synced to CloudKit")
                print("   2. Schema was not deployed to Production")
                print("   3. Records are in Private DB instead of Public DB")
            }
        } catch {
            print("❌ [FETCH_PLAYERS] Error fetching players: \(error)")
            throw error
        }
    }
    
    /// Загружает PlayerClaim из Public Database (changed from Private)
    private func fetchPlayerClaims() async throws {
        print("🔄 [FETCH_CLAIMS] Fetching PlayerClaims from Public Database...")
        
        let records = try await cloudKit.fetchRecords(
            withType: .playerClaim,
            from: .publicDB,
            limit: 400
        )
        
        if !records.isEmpty {
            print("📥 [FETCH_CLAIMS] Fetched \(records.count) claims from CloudKit")
            await mergePlayerClaimsWithLocal(records)
        } else {
            print("ℹ️ [FETCH_CLAIMS] No claims found in CloudKit")
            print("☁️ [FETCH_CLAIMS] CloudKit = Source of Truth: will delete all local claims (except pending)")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных claims
            await mergePlayerClaimsWithLocal([])
        }
    }
    
    /// Очищает невалидные PlayerClaim из CloudKit Public Database (changed from Private)
    func cleanupInvalidClaims() async throws {
        print("🧹 [CLEANUP_CLAIMS] Starting cleanup of invalid claims...")
        
        let records = try await cloudKit.fetchRecords(
            withType: .playerClaim,
            from: .publicDB,
            limit: 400
        )
        
        var invalidClaimIds: [CKRecord.ID] = []
        
        for record in records {
            let claimId = record.recordID.recordName
            
            // Проверяем валидность
            let hasPlayerName = (record["playerName"] as? String)?.isEmpty == false
            let hasGameRef = record["game"] as? CKRecord.Reference != nil
            let hasClaimantRef = record["claimantUser"] as? CKRecord.Reference != nil
            let hasHostRef = record["hostUser"] as? CKRecord.Reference != nil
            let hasStatus = (record["status"] as? String)?.isEmpty == false
            
            if !hasPlayerName || !hasGameRef || !hasClaimantRef || !hasHostRef || !hasStatus {
                print("⚠️ [CLEANUP_CLAIMS] Found invalid claim: \(claimId)")
                print("   - hasPlayerName: \(hasPlayerName), hasGameRef: \(hasGameRef)")
                print("   - hasClaimantRef: \(hasClaimantRef), hasHostRef: \(hasHostRef)")
                print("   - hasStatus: \(hasStatus)")
                invalidClaimIds.append(record.recordID)
            }
        }
        
        if !invalidClaimIds.isEmpty {
            print("🗑️ [CLEANUP_CLAIMS] Deleting \(invalidClaimIds.count) invalid claims from CloudKit...")
            for recordID in invalidClaimIds {
                do {
                    try await cloudKit.delete(recordID: recordID, from: .publicDB)
                    print("✅ [CLEANUP_CLAIMS] Deleted \(recordID.recordName)")
                } catch {
                    print("❌ [CLEANUP_CLAIMS] Failed to delete \(recordID.recordName): \(error)")
                }
            }
            print("✅ [CLEANUP_CLAIMS] Cleanup completed: deleted \(invalidClaimIds.count) invalid claims")
        } else {
            print("✅ [CLEANUP_CLAIMS] No invalid claims found")
        }
    }
    
    // MARK: - Merge Games with Local
    
    @MainActor
    private func mergeGamesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        print("🔄 [MERGE_GAMES] Starting merge: \(cloudRecords.count) games from CloudKit")
        
        // Собираем все gameId из CloudKit
        var cloudGameIds = Set<UUID>()
        
        for record in cloudRecords {
            // Filter out soft-deleted games
            if let softDeleted = record["softDeleted"] as? Int64, softDeleted != 0 {
                continue
            }
            
            let gameIdString = record.recordID.recordName
            guard let gameId = UUID(uuidString: gameIdString) else {
                print("⚠️ Invalid game ID in CloudKit record: \(gameIdString)")
                continue
            }
            
            cloudGameIds.insert(gameId)
            
            // Search for local game
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
            
            do {
                if let localGame = try context.fetch(fetchRequest).first {
                    // Game exists locally - CloudKit is source of truth, always update
                    localGame.updateFromCKRecord(record)
                    print("🔄 [MERGE_GAMES] Updated local game: \(gameId)")
                } else {
                    // Game doesn't exist locally - create it
                    if self.createGameFromCKRecord(record, in: context) != nil {
                        print("➕ [MERGE_GAMES] Created local game: \(gameId)")
                    }
                }
            } catch {
                print("❌ [MERGE_GAMES] Error processing game \(gameId): \(error)")
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные игры, которых нет в CloudKit
        // НО: НЕ удаляем pending данные (еще не синхронизированные)
        do {
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            let allLocalGames = try context.fetch(fetchRequest)
            let pendingGames = PendingSyncTracker.shared.getPendingGames()
            
            var deletedCount = 0
            for localGame in allLocalGames {
                // Проверяем: нет в CloudKit И нет в pending списке
                if !cloudGameIds.contains(localGame.gameId) && !pendingGames.contains(localGame.gameId) {
                    print("🗑️ [MERGE_GAMES] Deleting local game not in CloudKit: \(localGame.gameId)")
                    context.delete(localGame)
                    deletedCount += 1
                } else if !cloudGameIds.contains(localGame.gameId) && pendingGames.contains(localGame.gameId) {
                    print("📌 [MERGE_GAMES] Keeping pending game (not yet synced): \(localGame.gameId)")
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [MERGE_GAMES] Deleted \(deletedCount) local games not found in CloudKit")
            }
        } catch {
            print("❌ [MERGE_GAMES] Error fetching local games for cleanup: \(error)")
        }
        
        // Save all changes
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [MERGE_GAMES] Merged \(cloudRecords.count) games with local database")
            } catch {
                print("❌ [MERGE_GAMES] Failed to save merged games: \(error)")
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
    
    // MARK: - Merge GameWithPlayer with Local
    
    @MainActor
    private func mergeGameWithPlayersWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        print("🔄 [MERGE_GWP] Starting merge: \(cloudRecords.count) GameWithPlayer from CloudKit")
        
        // Собираем все пары (gameId, playerName) из CloudKit
        var cloudGWPKeys = Set<String>() // "gameId|playerName"
        
        for record in cloudRecords {
            // Получаем gameId из reference
            guard let gameRef = record["game"] as? CKRecord.Reference else {
                print("⚠️ [MERGE_GWP] GameWithPlayer record without game reference")
                continue
            }
            let gameIdString = gameRef.recordID.recordName
            guard let gameId = UUID(uuidString: gameIdString) else {
                print("⚠️ [MERGE_GWP] Invalid game ID: \(gameIdString)")
                continue
            }
            
            // Ищем игру локально
            let gameFetch: NSFetchRequest<Game> = Game.fetchRequest()
            gameFetch.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
            
            guard let game = try? context.fetch(gameFetch).first else {
                print("⚠️ [MERGE_GWP] Game \(gameId) not found locally, skipping GameWithPlayer")
                continue
            }
            
            // Ищем PlayerProfile если есть reference
            var playerProfile: PlayerProfile? = nil
            if let profileRef = record["playerProfile"] as? CKRecord.Reference {
                let profileIdString = profileRef.recordID.recordName
                if let profileId = UUID(uuidString: profileIdString) {
                    playerProfile = persistence.fetchPlayerProfile(byProfileId: profileId)
                }
            }
            
            // Получаем имя игрока
            guard let playerName = record["playerName"] as? String else {
                print("⚠️ [MERGE_GWP] GameWithPlayer record without playerName")
                continue
            }
            
            // Добавляем ключ в Set
            let key = "\(gameId.uuidString)|\(playerName)"
            cloudGWPKeys.insert(key)
            
            // Ищем или создаём Player
            let playerFetch: NSFetchRequest<Player> = Player.fetchRequest()
            playerFetch.predicate = NSPredicate(format: "name == %@", playerName)
            let player: Player
            
            if let existingPlayer = try? context.fetch(playerFetch).first {
                player = existingPlayer
            } else {
                let newPlayer = Player(context: context)
                newPlayer.name = playerName
                player = newPlayer
                print("➕ [MERGE_GWP] Created Player: \(playerName)")
            }
            
            // Проверяем не существует ли уже GameWithPlayer
            let gwpFetch: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
            gwpFetch.predicate = NSPredicate(
                format: "game == %@ AND player == %@",
                game as CVarArg,
                player as CVarArg
            )
            
            if let existingGWP = try? context.fetch(gwpFetch).first {
                // CloudKit = Source of Truth: всегда обновляем
                existingGWP.updateFromCKRecord(record)
                existingGWP.playerProfile = playerProfile // Обновляем связь
                print("🔄 [MERGE_GWP] Updated GameWithPlayer for \(playerName) in game \(gameId)")
            } else {
                // Создаём новый
                let gwp = GameWithPlayer(context: context)
                gwp.game = game
                gwp.player = player
                gwp.playerProfile = playerProfile
                gwp.updateFromCKRecord(record)
                print("➕ [MERGE_GWP] Created GameWithPlayer for \(playerName) in game \(gameId)")
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные GWP, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
            let allLocalGWP = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localGWP in allLocalGWP {
                if let game = localGWP.game, let player = localGWP.player, let playerName = player.name {
                    let key = "\(game.gameId.uuidString)|\(playerName)"
                    if !cloudGWPKeys.contains(key) {
                        print("🗑️ [MERGE_GWP] Deleting local GWP not in CloudKit: \(playerName) in game \(game.gameId)")
                        context.delete(localGWP)
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [MERGE_GWP] Deleted \(deletedCount) local GameWithPlayer not found in CloudKit")
            }
        } catch {
            print("❌ [MERGE_GWP] Error fetching local GWP for cleanup: \(error)")
        }
        
        // Сохраняем все изменения
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [MERGE_GWP] Merged GameWithPlayer records with local database")
            } catch {
                print("❌ [MERGE_GWP] Failed to save merged GameWithPlayer: \(error)")
            }
        }
    }
    
    // MARK: - Merge PlayerClaim with Local
    
    @MainActor
    private func mergePlayerClaimsWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        print("🔄 [MERGE_CLAIMS] Starting merge of \(cloudRecords.count) claims...")
        
        var validClaims = 0
        var skippedClaims = 0
        var cloudClaimIds = Set<UUID>() // Source of Truth: собираем ID из CloudKit
        
        for record in cloudRecords {
            let claimIdString = record.recordID.recordName
            guard let claimId = UUID(uuidString: claimIdString) else {
                print("⚠️ [MERGE_CLAIMS] Invalid claim ID: \(claimIdString)")
                skippedClaims += 1
                continue
            }
            
            // ВАЛИДАЦИЯ: проверяем обязательные поля
            guard let playerName = record["playerName"] as? String,
                  !playerName.isEmpty else {
                print("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing playerName")
                skippedClaims += 1
                continue
            }
            
            guard let gameRef = record["game"] as? CKRecord.Reference,
                  let gameIdString = UUID(uuidString: gameRef.recordID.recordName) else {
                print("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid gameId")
                skippedClaims += 1
                continue
            }
            
            guard let claimantRef = record["claimantUser"] as? CKRecord.Reference,
                  let claimantIdString = UUID(uuidString: claimantRef.recordID.recordName) else {
                print("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid claimantUserId")
                skippedClaims += 1
                continue
            }
            
            guard let hostRef = record["hostUser"] as? CKRecord.Reference,
                  let hostIdString = UUID(uuidString: hostRef.recordID.recordName) else {
                print("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid hostUserId")
                skippedClaims += 1
                continue
            }
            
            guard let status = record["status"] as? String,
                  !status.isEmpty else {
                print("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing status")
                skippedClaims += 1
                continue
            }
            
            print("✅ [MERGE_CLAIMS] Claim \(claimId) passed validation")
            cloudClaimIds.insert(claimId) // Добавляем в Set
            
            // Проверяем существует ли claim локально
            let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
            
            if let existingClaim = try? context.fetch(fetchRequest).first {
                // CloudKit = Source of Truth: всегда обновляем
                existingClaim.updateFromCKRecord(record)
                print("🔄 [MERGE_CLAIMS] Updated claim \(claimId)")
                validClaims += 1
            } else {
                // Создаём новый
                let newClaim = PlayerClaim(context: context)
                newClaim.claimId = claimId
                newClaim.updateFromCKRecord(record)
                print("➕ [MERGE_CLAIMS] Created claim \(claimId) (playerName: \(newClaim.playerName), status: \(newClaim.status))")
                validClaims += 1
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные claims, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
            let allLocalClaims = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localClaim in allLocalClaims {
                if !cloudClaimIds.contains(localClaim.claimId) {
                    print("🗑️ [MERGE_CLAIMS] Deleting local claim not in CloudKit: \(localClaim.claimId)")
                    context.delete(localClaim)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ [MERGE_CLAIMS] Deleted \(deletedCount) local claims not found in CloudKit")
            }
        } catch {
            print("❌ [MERGE_CLAIMS] Error fetching local claims for cleanup: \(error)")
        }
        
        print("📊 [MERGE_CLAIMS] Validation results: \(validClaims) valid, \(skippedClaims) skipped")
        
        // Сохраняем все изменения
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [MERGE_CLAIMS] Successfully merged \(validClaims) claims with local database")
            } catch {
                print("❌ [MERGE_CLAIMS] Failed to save merged claims: \(error)")
            }
        } else {
            print("ℹ️ [MERGE_CLAIMS] No valid claims to save")
        }
    }
    
    // MARK: - Fetch Single Game by ID
    
    func fetchGame(byId gameId: UUID) async throws -> Game? {
        let recordID = CKRecord.ID(recordName: gameId.uuidString)
        
        do {
            let record = try await cloudKit.fetch(recordID: recordID, from: .publicDB)
            
            // Проверка публичности игры
            let isPublic = record["isPublic"] as? Int64 ?? 0
            if isPublic == 0 {
                // Игра не публична - проверяем, является ли текущий пользователь создателем
                let keychain = KeychainService.shared
                if let currentUserIdString = keychain.getUserId(),
                   let currentUserId = UUID(uuidString: currentUserIdString),
                   let creatorRef = record["creator"] as? CKRecord.Reference {
                    let creatorId = UUID(uuidString: creatorRef.recordID.recordName)
                    
                    // Если текущий пользователь не создатель - отказываем в доступе
                    if currentUserId != creatorId {
                        print("❌ Game \(gameId) is not public and user is not the creator")
                        throw CloudKitSyncError.gameNotPublic
                    }
                } else {
                    // Нет информации о создателе или текущем пользователе - отказываем
                    print("❌ Game \(gameId) is not public and cannot verify creator")
                    throw CloudKitSyncError.gameNotPublic
                }
            }
            
            // Create or update local copy
            let game = await MainActor.run { () -> Game? in
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
            
            // Загрузить игроков для этой игры - КРИТИЧНО для отображения данных!
            if let unwrappedGame = game {
                print("🔄 [FETCH_GAME] Game found, now fetching players for game \(gameId)...")
                do {
                    try await fetchGameWithPlayers(forGameId: gameId)
                    print("✅ [FETCH_GAME] Players loaded successfully for game \(gameId)")
                } catch {
                    print("❌ [FETCH_GAME] FAILED to load players for game \(gameId): \(error)")
                    print("❌ [FETCH_GAME] Error type: \(type(of: error))")
                    print("❌ [FETCH_GAME] Localized: \(error.localizedDescription)")
                    // НЕ бросаем исключение - игра уже загружена, просто игроков нет
                }
            } else {
                print("⚠️ [FETCH_GAME] Game is nil after fetch, cannot load players")
            }
            
            return game
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
    
    // MARK: - Fetch User from CloudKit (for login recovery)
    
    /// Загружает пользователя из CloudKit Private Database по username
    /// Используется при входе если пользователь не найден локально (например, после переустановки)
    func fetchUser(byUsername username: String) async throws -> User? {
        print("🔍 Trying to fetch user '\(username)' from CloudKit Public Database...")
        
        // Query для поиска пользователя по username в Public DB
        let predicate = NSPredicate(format: "username == %@", username)
        
        let result = try await cloudKit.queryRecords(
            withType: .user,
            from: .publicDB,
            predicate: predicate,
            sortDescriptors: nil,
            resultsLimit: 1
        )
        
        guard let userRecord = result.records.first else {
            print("❌ User '\(username)' not found in CloudKit")
            return nil
        }
        
        print("✅ Found user '\(username)' in CloudKit, creating local copy...")
        
        // Создать локальную копию пользователя из CloudKit
        let user = try await MainActor.run {
            createUserFromCKRecord(userRecord, in: persistence.container.viewContext)
        }
        
        // Также попробовать загрузить PlayerProfile пользователя
        if let user = user {
            await fetchPlayerProfile(forUserId: user.userId)
        }
        
        return user
    }
    
    /// Загружает пользователя из CloudKit Private Database по email
    /// Используется при входе если пользователь не найден локально (например, после переустановки)
    func fetchUser(byEmail email: String) async throws -> User? {
        print("🔍 Trying to fetch user by email '\(email)' from CloudKit Public Database...")
        
        // Query для поиска пользователя по email в Public DB
        let predicate = NSPredicate(format: "email == %@", email)
        
        let result = try await cloudKit.queryRecords(
            withType: .user,
            from: .publicDB,
            predicate: predicate,
            sortDescriptors: nil,
            resultsLimit: 1
        )
        
        guard let userRecord = result.records.first else {
            print("❌ User with email '\(email)' not found in CloudKit")
            return nil
        }
        
        print("✅ Found user by email in CloudKit, creating local copy...")
        
        // Создать локальную копию пользователя из CloudKit
        let user = try await MainActor.run {
            createUserFromCKRecord(userRecord, in: persistence.container.viewContext)
        }
        
        // Также попробовать загрузить PlayerProfile пользователя
        if let user = user {
            await fetchPlayerProfile(forUserId: user.userId)
        }
        
        return user
    }
    
    /// Удаляет пользователя из CloudKit Public Database
    /// Используется для очистки данных при отладке или удалении аккаунта
    func deleteUser(userId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: userId.uuidString)
        
        do {
            try await cloudKit.delete(recordID: recordID, from: .publicDB)
            print("🗑️ Deleted user \(userId) from CloudKit Public Database")
        } catch {
            print("❌ Failed to delete user \(userId) from CloudKit: \(error)")
            throw error
        }
    }
    
    /// Удаляет невалидный PlayerClaim из CloudKit Public Database (changed from Private)
    func deleteInvalidClaim(claimId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: claimId.uuidString)
        
        do {
            try await cloudKit.delete(recordID: recordID, from: .publicDB)
            print("🗑️ [DELETE_CLAIM] Deleted invalid claim \(claimId) from CloudKit Public Database")
        } catch {
            print("❌ [DELETE_CLAIM] Failed to delete claim \(claimId) from CloudKit: \(error)")
            throw error
        }
    }
    
    /// Удаляет локальный PlayerClaim
    @MainActor
    func deleteLocalClaim(claimId: UUID) throws {
        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
        
        if let claim = try context.fetch(fetchRequest).first {
            context.delete(claim)
            try context.save()
            print("🗑️ [DELETE_CLAIM] Deleted local claim \(claimId)")
        } else {
            print("ℹ️ [DELETE_CLAIM] Claim \(claimId) not found locally")
        }
    }
    
    /// Загружает PlayerProfile из CloudKit для пользователя
    private func fetchPlayerProfile(forUserId userId: UUID) async {
        print("🔍 Trying to fetch PlayerProfile for user \(userId)...")
        
        do {
            let predicate = NSPredicate(format: "userId == %@", userId.uuidString)
            let result = try await cloudKit.queryRecords(
                withType: .playerProfile,
                from: .privateDB,
                predicate: predicate,
                sortDescriptors: nil,
                resultsLimit: 1
            )
            
            guard let profileRecord = result.records.first else {
                print("⚠️ PlayerProfile not found in CloudKit")
                return
            }
            
            print("✅ Found PlayerProfile in CloudKit, creating local copy...")
            
            await MainActor.run {
                let context = persistence.container.viewContext
                _ = createPlayerProfileFromCKRecord(profileRecord, in: context)
            }
        } catch {
            print("❌ Failed to fetch PlayerProfile: \(error)")
        }
    }
    
    /// Создает User из CKRecord
    @MainActor
    private func createUserFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> User? {
        // Извлекаем userId из recordName
        guard let userId = UUID(uuidString: record.recordID.recordName) else {
            print("❌ Invalid userId in CKRecord")
            return nil
        }
        
        // Проверяем не существует ли уже локально
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        
        if let existingUser = try? context.fetch(fetchRequest).first {
            print("ℹ️ User already exists locally, returning existing")
            return existingUser
        }
        
        // Извлекаем обязательные поля
        guard let username = record["username"] as? String,
              let passwordHash = record["passwordHash"] as? String,
              let subscriptionStatus = record["subscriptionStatus"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            print("❌ Missing required fields in User CKRecord")
            return nil
        }
        
        // Создаем нового пользователя
        let user = User(context: context)
        user.userId = userId
        user.username = username
        user.passwordHash = passwordHash
        user.subscriptionStatus = subscriptionStatus
        user.createdAt = createdAt
        user.email = record["email"] as? String
        user.isSuperAdmin = (record["isSuperAdmin"] as? Int64 == 1)
        user.lastLoginAt = record["lastLoginAt"] as? Date
        user.subscriptionExpiresAt = record["subscriptionExpiresAt"] as? Date
        
        do {
            try context.save()
            print("✅ User created locally from CloudKit")
            return user
        } catch {
            print("❌ Failed to save user: \(error)")
            return nil
        }
    }
    
    /// Создает PlayerProfile из CKRecord
    @MainActor
    private func createPlayerProfileFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> PlayerProfile? {
        // Извлекаем profileId из recordName
        guard let profileId = UUID(uuidString: record.recordID.recordName) else {
            print("❌ Invalid profileId in CKRecord")
            return nil
        }
        
        // Проверяем не существует ли уже локально
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profileId == %@", profileId as CVarArg)
        
        if let existingProfile = try? context.fetch(fetchRequest).first {
            print("ℹ️ PlayerProfile already exists locally, returning existing")
            return existingProfile
        }
        
        // Создаем новый профиль
        let profile = PlayerProfile(context: context)
        profile.profileId = profileId
        profile.displayName = (record["displayName"] as? String) ?? ""
        profile.isAnonymous = (record["isAnonymous"] as? Int64 == 1)
        profile.createdAt = (record["createdAt"] as? Date) ?? Date()
        
        // Преобразуем Int64 → Int32
        if let gamesPlayed = record["totalGamesPlayed"] as? Int64 {
            profile.totalGamesPlayed = Int32(min(gamesPlayed, Int64(Int32.max)))
        } else {
            profile.totalGamesPlayed = 0
        }
        
        // Преобразуем Double → NSDecimalNumber
        if let buyins = record["totalBuyins"] as? Double {
            profile.totalBuyins = NSDecimalNumber(value: buyins)
        } else {
            profile.totalBuyins = NSDecimalNumber.zero
        }
        
        if let cashouts = record["totalCashouts"] as? Double {
            profile.totalCashouts = NSDecimalNumber(value: cashouts)
        } else {
            profile.totalCashouts = NSDecimalNumber.zero
        }
        
        // Связываем с пользователем если есть userId
        if let userIdString = record["userId"] as? String,
           let userId = UUID(uuidString: userIdString) {
            let userFetchRequest: NSFetchRequest<User> = User.fetchRequest()
            userFetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
            if let user = try? context.fetch(userFetchRequest).first {
                profile.user = user
            }
        }
        
        do {
            try context.save()
            print("✅ PlayerProfile created locally from CloudKit")
            return profile
        } catch {
            print("❌ Failed to save PlayerProfile: \(error)")
            return nil
        }
    }
    
    // MARK: - Quick Sync (автоматическая синхронизация после создания)
    
    /// Быстрая синхронизация User после создания/изменения
    /// DEPRECATED: User should NOT be synced to CloudKit - use PlayerProfile instead
    @available(*, deprecated, message: "User sync is disabled. User is local authentication data only.")
    func quickSyncUser(_ user: User) async {
        print("🔄 [QUICK_SYNC_USER] Starting sync for user: \(user.username)")
        
        let isAvailable = await cloudKit.isCloudKitAvailable()
        print("☁️ [QUICK_SYNC_USER] CloudKit available: \(isAvailable)")
        
        guard isAvailable else {
            print("❌ [QUICK_SYNC_USER] CloudKit NOT available - skipping sync")
            return
        }
        
        do {
            print("📦 [QUICK_SYNC_USER] Creating CKRecord for user \(user.userId)")
            let record = user.toCKRecord()
            print("📦 [QUICK_SYNC_USER] Record created: \(record.recordType), recordID: \(record.recordID.recordName)")
            print("📦 [QUICK_SYNC_USER] Record fields: username=\(record["username"] ?? "nil"), email=\(record["email"] ?? "nil")")
            print("📦 [QUICK_SYNC_USER] NOTE: passwordHash is NOT included (local only)")
            
            print("☁️ [QUICK_SYNC_USER] Saving to CloudKit Public Database...")
            let savedRecord = try await cloudKit.save(record: record, to: .publicDB)
            print("✅ [QUICK_SYNC_USER] SUCCESS! User synced to CloudKit Public Database")
            print("✅ [QUICK_SYNC_USER] Saved record ID: \(savedRecord.recordID.recordName)")
            print("✅ [QUICK_SYNC_USER] Username: \(user.username)")
        } catch {
            print("❌ [QUICK_SYNC_USER] FAILED to sync User")
            print("❌ [QUICK_SYNC_USER] Error type: \(type(of: error))")
            print("❌ [QUICK_SYNC_USER] Error description: \(error)")
            print("❌ [QUICK_SYNC_USER] Localized: \(error.localizedDescription)")
        }
    }
    
    /// Быстрая синхронизация Game после создания/изменения
    func quickSyncGame(_ game: Game) async {
        guard await cloudKit.isCloudKitAvailable() else { return }
        
        do {
            let record = game.toCKRecord()
            _ = try await cloudKit.save(record: record, to: .publicDB)
            print("✅ Quick synced Game: \(game.gameId)")
        } catch {
            print("❌ Failed to quick sync Game: \(error)")
        }
    }
    
    /// Быстрая синхронизация GameWithPlayer после создания/изменения
    func quickSyncGameWithPlayers(_ gameWithPlayers: [GameWithPlayer]) async {
        print("🔄 [QUICK_SYNC] Starting quick sync for \(gameWithPlayers.count) GameWithPlayer records")
        
        guard await cloudKit.isCloudKitAvailable() else {
            print("❌ [QUICK_SYNC] CloudKit not available")
            return
        }
        guard !gameWithPlayers.isEmpty else {
            print("⚠️ [QUICK_SYNC] No records to sync")
            return
        }
        
        do {
            let records = gameWithPlayers.map { $0.toCKRecord() }
            print("📤 [QUICK_SYNC] Converted to \(records.count) CKRecords")
            
            for (index, record) in records.enumerated() {
                if let game = gameWithPlayers[index].game {
                    let playerName = gameWithPlayers[index].player?.name ?? "Unknown"
                    print("   Record \(index + 1): \(playerName) for game \(game.gameId)")
                }
            }
            
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ [QUICK_SYNC] Successfully synced \(records.count) GameWithPlayer records to Public DB")
        } catch {
            print("❌ [QUICK_SYNC] Failed to quick sync GameWithPlayers: \(error)")
            print("❌ [QUICK_SYNC] Error details: \(error.localizedDescription)")
        }
    }
    
    /// Быстрая синхронизация PlayerProfile после создания/изменения
    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        guard await cloudKit.isCloudKitAvailable() else { return }
        
        do {
            let record = profile.toCKRecord()
            _ = try await cloudKit.save(record: record, to: .privateDB)
            print("✅ Quick synced PlayerProfile: \(profile.displayName)")
        } catch {
            print("❌ Failed to quick sync PlayerProfile: \(error)")
        }
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
    case gameNotPublic
    
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
        case .gameNotPublic:
            return "Игра недоступна. Создатель ещё не сделал её публичной."
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
    
    // MARK: - Push Pending Data
    
    /// Отправляет данные, которые не удалось синхронизировать ранее
    func pushPendingData() async throws {
        let tracker = PendingSyncTracker.shared
        let context = persistence.container.viewContext
        
        print("🔄 [PUSH_PENDING] Starting to push pending data...")
        
        // 1. Push pending games
        let pendingGameIds = tracker.getPendingGames()
        if !pendingGameIds.isEmpty {
            print("📤 [PUSH_PENDING] Found \(pendingGameIds.count) pending games")
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId IN %@", Array(pendingGameIds))
            
            if let games = try? context.fetch(fetchRequest), !games.isEmpty {
                let records = games.map { $0.toCKRecord() }
                _ = try await cloudKit.saveRecords(records, to: .publicDB)
                print("✅ [PUSH_PENDING] Pushed \(games.count) games")
                
                // Remove from pending
                for game in games {
                    tracker.removePendingGame(game.gameId)
                }
            }
        }
        
        // 2. Push pending GameWithPlayer
        let pendingGWPIds = tracker.getPendingGameWithPlayers()
        if !pendingGWPIds.isEmpty {
            print("📤 [PUSH_PENDING] Found \(pendingGWPIds.count) pending GameWithPlayer")
            // GameWithPlayer doesn't have gameWithPlayerId, so we sync all
            try await syncGameWithPlayers()
            tracker.getPendingGameWithPlayers().forEach { tracker.removePendingGameWithPlayer($0) }
        }
        
        // 3. Push pending PlayerAliases
        let pendingAliasIds = tracker.getPendingPlayerAliases()
        if !pendingAliasIds.isEmpty {
            print("📤 [PUSH_PENDING] Found \(pendingAliasIds.count) pending PlayerAliases")
            let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "aliasId IN %@", Array(pendingAliasIds))
            
            if let aliases = try? context.fetch(fetchRequest), !aliases.isEmpty {
                let records = aliases.map { $0.toCKRecord() }
                _ = try await cloudKit.saveRecords(records, to: .publicDB)
                print("✅ [PUSH_PENDING] Pushed \(aliases.count) aliases")
                
                // Remove from pending
                for alias in aliases {
                    tracker.removePendingPlayerAlias(alias.aliasId)
                }
            }
        }
        
        // 4. Push pending PlayerClaims
        let pendingClaimIds = tracker.getPendingPlayerClaims()
        if !pendingClaimIds.isEmpty {
            print("📤 [PUSH_PENDING] Found \(pendingClaimIds.count) pending PlayerClaims")
            try await syncPlayerClaims()
            tracker.getPendingPlayerClaims().forEach { tracker.removePendingPlayerClaim($0) }
        }
        
        print("✅ [PUSH_PENDING] All pending data pushed successfully")
    }
}


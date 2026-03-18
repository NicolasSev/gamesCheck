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

/// Protocol for auth-related CloudKit operations — enables mocking in tests
protocol AuthCloudKitSyncProtocol: AnyObject {
    func fetchUser(byEmail email: String) async throws -> User?
    func quickSyncUser(_ user: User) async
    func quickSyncPlayerProfile(_ profile: PlayerProfile) async
}

/// Service to synchronize CoreData with CloudKit
class CloudKitSyncService: ObservableObject, AuthCloudKitSyncProtocol, SyncServiceProtocol {
    static let shared = CloudKitSyncService()
    
    @Published var isSyncing = false
    @Published var isBackgroundSyncing = false
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
            debugLog("Sync already in progress")
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
            
            debugLog("✅ CloudKit sync completed successfully")
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
            debugLog("✅ Synced \(records.count) users to Public Database")
        }
    }
    
    // MARK: - PlayerProfile Sync (Public Database - для cross-user visibility)
    
    private func syncPlayerProfiles() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        let profiles = try context.fetch(fetchRequest)
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let records = Array(profiles).map { $0.toCKRecord() }
        
        if !records.isEmpty {
            _ = try await cloudKit.saveRecords(records, to: .publicDB)  // ИЗМЕНЕНО: Public DB
            debugLog("✅ Synced \(records.count) player profiles to Private Database")
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
            debugLog("✅ Synced \(records.count) player aliases to Public Database")
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
            debugLog("✅ Synced \(records.count) games to Public Database")
        }
    }
    
    // MARK: - GameWithPlayer Sync (Public Database)
    
    private func syncGameWithPlayers() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        // Только для не удалённых игр
        fetchRequest.predicate = NSPredicate(format: "game.softDeleted == NO")
        
        let gameWithPlayers = try context.fetch(fetchRequest)
        
        debugLog("🔄 [SYNC_GWP] Found \(gameWithPlayers.count) GameWithPlayer records to sync")
        
        // Конвертируем в records безопасно, без изменения коллекции во время итерации
        var records: [CKRecord] = []
        records.reserveCapacity(gameWithPlayers.count)
        
        // Создаем копию массива чтобы избежать mutation during enumeration
        let gwpArray = Array(gameWithPlayers)
        
        for (index, gwp) in gwpArray.enumerated() {
            let record = gwp.toCKRecord()
            records.append(record)
            
            if (index + 1) % 100 == 0 {
                debugLog("📦 [SYNC_GWP] Converted \(index + 1)/\(gwpArray.count) records")
            }
        }
        
        if !records.isEmpty {
            debugLog("☁️ [SYNC_GWP] Saving \(records.count) records to CloudKit...")
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            debugLog("✅ [SYNC_GWP] Synced \(records.count) game-player records to Public Database")
        } else {
            debugLog("ℹ️ [SYNC_GWP] No valid records to sync")
        }
    }
    
    // MARK: - PlayerClaim Sync (Public Database - changed from Private)
    
    func syncPlayerClaims() async throws {
        let context = persistence.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        let claims = try context.fetch(fetchRequest)
        
        debugLog("🔄 [SYNC_CLAIMS] Found \(claims.count) claims to sync")
        
        // Фильтруем и конвертируем claims в CKRecords с обработкой ошибок
        var records: [CKRecord] = []
        for (index, claim) in claims.enumerated() {
            do {
                debugLog("📦 [SYNC_CLAIMS] Converting claim \(index + 1)/\(claims.count): \(claim.claimId)")
                let record = claim.toCKRecord()
                records.append(record)
            } catch {
                debugLog("❌ [SYNC_CLAIMS] Failed to convert claim \(claim.claimId) to CKRecord: \(error)")
                debugLog("   - playerName: \(claim.playerName)")
                debugLog("   - gameId: \(claim.gameId)")
                debugLog("   - status: \(claim.status)")
                // Пропускаем проблемную запись и продолжаем
                continue
            }
        }
        
        if !records.isEmpty {
            debugLog("☁️ [SYNC_CLAIMS] Saving \(records.count) claims to CloudKit Public Database...")
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            debugLog("✅ [SYNC_CLAIMS] Synced \(records.count) player claims to Public Database")
        } else {
            debugLog("ℹ️ [SYNC_CLAIMS] No valid claims to sync")
        }
    }
    
    // MARK: - Pull Changes from CloudKit
    
    func pullChanges() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        debugLog("🔄 [PULL] Fetching changes from CloudKit...")
        
        // Fetch changes from CloudKit
        let users = try await cloudKit.fetchRecords(withType: .user, from: .publicDB)
        let profiles = try await cloudKit.fetchRecords(withType: .playerProfile, from: .publicDB)  // ИЗМЕНЕНО: Public DB
        let claims = try await cloudKit.fetchRecords(withType: .playerClaim, from: .publicDB)
        let games = try await cloudKit.fetchRecords(withType: .game, from: .publicDB)
        let gameWithPlayers = try await cloudKit.fetchRecords(withType: .gameWithPlayer, from: .publicDB)
        let aliases = try await cloudKit.fetchRecords(withType: .playerAlias, from: .publicDB)
        
        debugLog("📥 [PULL] Fetched: \(users.count) users, \(profiles.count) profiles, \(claims.count) claims, \(games.count) games, \(gameWithPlayers.count) gameWithPlayers, \(aliases.count) aliases")
        
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
                    debugLog("➕ [PULL] Created user from CloudKit: \(newUser.username)")
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
                    debugLog("🔒 [PULL] Skipping current user (logged in): \(localUser.username)")
                    continue
                }
                
                // Удаляем если нет в CloudKit
                if !cloudUserIds.contains(localUser.userId) {
                    debugLog("🗑️ [PULL] Deleting local user not in CloudKit: \(localUser.username) (remote user)")
                    context.delete(localUser)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [PULL] Deleted \(deletedCount) remote users not found in CloudKit")
            }
        } catch {
            debugLog("❌ [PULL] Error fetching local users for cleanup: \(error)")
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
                    debugLog("➕ [PULL] Created PlayerProfile from CloudKit: \(newProfile.displayName)")
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
                    debugLog("🗑️ [PULL] Deleting local profile not in CloudKit: \(localProfile.displayName)")
                    context.delete(localProfile)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [PULL] Deleted \(deletedCount) local profiles not found in CloudKit")
            }
        } catch {
            debugLog("❌ [PULL] Error fetching local profiles for cleanup: \(error)")
        }
        
        // Process claims (с merge логикой)
        if !claims.isEmpty {
            debugLog("🔄 [PULL] Merging \(claims.count) claims with local database...")
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
                    debugLog("➕ [PULL] Created game from CloudKit: \(gameId)")
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
                    debugLog("🗑️ [PULL] Deleting local game not in CloudKit: \(localGame.gameId)")
                    context.delete(localGame)
                    deletedCount += 1
                } else if !cloudGameIds.contains(localGame.gameId) && pendingGames.contains(localGame.gameId) {
                    debugLog("📌 [PULL] Keeping pending game (not yet synced): \(localGame.gameId)")
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [PULL] Deleted \(deletedCount) local games not found in CloudKit")
            }
        } catch {
            debugLog("❌ [PULL] Error fetching local games for cleanup: \(error)")
        }
        
        // Process gameWithPlayers - используем merge логику (с удалением внутри)
        if !gameWithPlayers.isEmpty {
            debugLog("🔄 [PULL] Merging \(gameWithPlayers.count) GameWithPlayer records...")
            await mergeGameWithPlayersWithLocal(gameWithPlayers)
        } else {
            // Если в CloudKit нет GWP, удаляем все локальные
            debugLog("🗑️ [PULL] CloudKit has 0 GameWithPlayer - deleting all local GWP")
            do {
                let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
                let allLocalGWP = try context.fetch(fetchRequest)
                for gwp in allLocalGWP {
                    context.delete(gwp)
                }
                if !allLocalGWP.isEmpty {
                    debugLog("🗑️ [PULL] Deleted \(allLocalGWP.count) local GameWithPlayer")
                }
            } catch {
                debugLog("❌ [PULL] Error deleting local GWP: \(error)")
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
                    
                    // Ищем PlayerProfile для этого алиаса
                    if let profile = persistence.fetchPlayerProfile(byProfileId: newAlias.profileId) {
                        newAlias.profile = profile
                        debugLog("➕ [PULL] Created PlayerAlias: \(newAlias.aliasName) for profile \(profile.displayName)")
                    } else {
                        // Профиль не найден - удаляем созданный алиас
                        context.delete(newAlias)
                        debugLog("⚠️ [PULL] Skipping PlayerAlias \(newAlias.aliasName) - PlayerProfile \(newAlias.profileId) not found locally (will sync when profile arrives)")
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
                    debugLog("🗑️ [PULL] Deleting local alias not in CloudKit: \(localAlias.aliasName)")
                    context.delete(localAlias)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [PULL] Deleted \(deletedCount) local aliases not found in CloudKit")
            }
        } catch {
            debugLog("❌ [PULL] Error fetching local aliases for cleanup: \(error)")
        }
        
        // CloudKit = Source of Truth: удаляем локальные claims, которых нет в CloudKit
        do {
            let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
            let allLocalClaims = try context.fetch(fetchRequest)
            
            var deletedCount = 0
            for localClaim in allLocalClaims {
                if !cloudClaimIds.contains(localClaim.claimId) {
                    debugLog("🗑️ [PULL] Deleting local claim not in CloudKit: \(localClaim.claimId)")
                    context.delete(localClaim)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [PULL] Deleted \(deletedCount) local claims not found in CloudKit")
            }
        } catch {
            debugLog("❌ [PULL] Error fetching local claims for cleanup: \(error)")
        }
        
        // Save context
        if context.hasChanges {
            try context.save()
        }
        
        debugLog("✅ [PULL] CloudKit sync completed - local database matches CloudKit (Source of Truth)")
    }
    
    // MARK: - Full Sync (Push local + Pull public)
    
    func performFullSync() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        debugLog("🚀 Starting full sync (PULL ONLY - CloudKit is Source of Truth)...")
        
        // ТОЛЬКО PULL: Скачиваем данные из CloudKit
        // 1. Fetch PlayerProfiles FIRST (needed for aliases and GWP)
        // ВАЖНО: PlayerProfile теперь в PUBLIC DB для видимости cross-user
        try await fetchPlayerProfiles()
        
        // 2. Fetch public data from CloudKit
        try await fetchPublicGames()
        try await fetchPublicPlayerAliases()
        try await fetchPublicGameWithPlayers()
        
        // 3. Fetch private data from CloudKit
        try await fetchPlayerClaims()
        
        // 4. Пересобрать materialized views после pull (актуализирует GameSummaryRecord)
        try? await MaterializedViewsService.shared.rebuildAllGameSummaries()

        // ПРИМЕЧАНИЕ: PUSH (sync()) НЕ вызывается!
        // Данные загружаются в CloudKit ТОЛЬКО в момент их создания:
        // - Импорт игры → quickSyncGame()
        // - Создание заявки → syncPlayerClaims()
        // - Одобрение заявки → синхронизация в PlayerClaimService

        debugLog("✅ Full sync completed (CloudKit data pulled)")
    }

    // MARK: - Phase 2: Two-Phase Loading

    /// Быстрая загрузка для показа UI (< 2 сек). Загружает только данные текущего пользователя.
    func performMinimalSync() async throws {
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }

        let start = Date()
        debugLog("🚀 Phase 1: Minimal sync for fast app launch...")

        let userId = getCurrentUserId()

        // 1. Профиль текущего пользователя (ТОЛЬКО СВОЙ)
        if let userId = userId {
            try await fetchMyPlayerProfile(userId: userId)
        }

        // 2. Последние 20 игр (без GWP - тяжёлая часть)
        try await fetchRecentGames(limit: 20)

        // 3. Заявки (для badge count) - только pending для текущего хоста
        if let userId = userId {
            try await fetchPendingClaimsForHost(userId: userId)
        }

        // 4. UserStatisticsSummary - если есть в CloudKit (опционально)
        if let userId = userId {
            try? await fetchUserStatisticsSummary(userId: userId)
        }

        let duration = Date().timeIntervalSince(start)
        debugLog("✅ Phase 1 completed in \(String(format: "%.2f", duration))s - app can show UI now")
    }

    /// Фоновая загрузка остальных данных (без GWP - они загружаются по требованию).
    func performBackgroundSync() async throws {
        guard await cloudKit.isCloudKitAvailable() else { return }

        await MainActor.run { isBackgroundSyncing = true }
        defer { Task { @MainActor in isBackgroundSyncing = false } }

        debugLog("🔄 Phase 2: Background sync (full data, no GWP)...")

        do {
            // Параллельная загрузка
            try await fetchPlayerProfiles()
            try await fetchPublicGames()
            try await fetchPublicPlayerAliases()
            try await fetchPlayerClaims()

            // GWP НЕ загружаем - они будут загружены по требованию при открытии игры

            let now = Date()
            await MainActor.run { lastSyncDate = now }
            UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")

            debugLog("✅ Phase 2 completed - all data synced (GWP excluded, lazy load)")
        } catch {
            debugLog("❌ Phase 2 sync error: \(error)")
            throw error
        }
    }

    // MARK: - Phase 3: Smart Sync (витринная синхронизация)

    /// Быстрая загрузка только GameSummary из CloudKit (без Game, GWP и т.д.)
    private func fetchSummariesOnly() async throws -> [CKRecord] {
        let result = try await cloudKit.queryRecords(
            withType: .gameSummary,
            from: .publicDB,
            predicate: NSPredicate(value: true),
            sortDescriptors: nil,
            resultsLimit: 1000
        )
        debugLog("📊 [SMART_SYNC] Fetched \(result.records.count) GameSummary from CloudKit")
        return result.records
    }

    /// Сравнить checksums CloudKit с локальными GameSummaryRecord. true = синхронизировано, false = нужна полная синхронизация.
    private func compareSummariesWithLocal(_ cloudRecords: [CKRecord]) -> Bool {
        let context = persistence.container.viewContext
        let localRequest: NSFetchRequest<GameSummaryRecord> = GameSummaryRecord.fetchRequest()
        guard let localSummaries = try? context.fetch(localRequest) else { return false }

        var cloudMap: [UUID: String] = [:]
        for record in cloudRecords {
            guard let gameIdStr = record["gameId"] as? String,
                  let gameId = UUID(uuidString: gameIdStr) else { continue }
            cloudMap[gameId] = record["checksum"] as? String ?? ""
        }

        for local in localSummaries {
            let ckChecksum = cloudMap[local.gameId]
            let localChecksum = local.checksum ?? ""
            if ckChecksum != localChecksum {
                debugLog("📊 [SMART_SYNC] Mismatch for game \(local.gameId): cloud=\(ckChecksum ?? "nil") local=\(localChecksum)")
                return false
            }
        }
        if cloudMap.count != localSummaries.count {
            debugLog("📊 [SMART_SYNC] Count mismatch: cloud=\(cloudMap.count) local=\(localSummaries.count)")
            return false
        }
        debugLog("📊 [SMART_SYNC] Summaries match - no full sync needed")
        return true
    }

    /// Двухфазная умная синхронизация: Phase 1 — минимальная загрузка, Phase 2 — проверка витрин, при расхождении полная синхронизация
    func smartSync() async throws {
        let start = Date()
        debugLog("🚀 [SMART_SYNC] Starting...")

        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }

        // Phase 1: Минимальная загрузка для быстрого показа UI
        try await performMinimalSync()
        let phase1Duration = Date().timeIntervalSince(start)
        debugLog("✅ [SMART_SYNC] Phase 1 completed in \(String(format: "%.2f", phase1Duration))s")

        // Phase 2: Фоновая проверка витрин и при необходимости полная синхронизация
        Task {
            do {
                let cloudSummaries = try await fetchSummariesOnly()
                let needsFullSync = !compareSummariesWithLocal(cloudSummaries)

                if needsFullSync {
                    debugLog("🔄 [SMART_SYNC] Summaries differ, starting full background sync...")
                    await MainActor.run { isBackgroundSyncing = true }
                    defer { Task { @MainActor in isBackgroundSyncing = false } }
                    try await performBackgroundSync()
                    try? await MaterializedViewsService.shared.rebuildAllGameSummaries()
                    let now = Date()
                    await MainActor.run { lastSyncDate = now }
                    UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")
                    NotificationCenter.default.post(name: .syncCompletedSuccessfully, object: nil)
                    debugLog("✅ [SMART_SYNC] Full sync completed successfully")
                } else {
                    let now = Date()
                    await MainActor.run { lastSyncDate = now }
                    UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")
                    debugLog("✅ [SMART_SYNC] No full sync needed")
                }
            } catch {
                debugLog("❌ [SMART_SYNC] Phase 2 error: \(error)")
                NotificationCenter.default.post(name: .syncCompletedWithError, object: error)
            }
        }
    }

    private func getCurrentUserId() -> UUID? {
        KeychainService.shared.getUserId().flatMap { UUID(uuidString: $0) }
    }

    private func fetchMyPlayerProfile(userId: UUID) async throws {
        debugLog("☁️ [MINIMAL] Fetching my PlayerProfile for user \(userId)...")

        let userRecordID = CKRecord.ID(recordName: userId.uuidString)
        let userReference = CKRecord.Reference(recordID: userRecordID, action: .none)
        let predicate = NSPredicate(format: "user == %@", userReference)

        let result = try await cloudKit.queryRecords(
            withType: .playerProfile,
            from: .publicDB,
            predicate: predicate,
            sortDescriptors: nil,
            resultsLimit: 5
        )

        if !result.records.isEmpty {
            debugLog("📥 [MINIMAL] Fetched \(result.records.count) profile(s) for current user")
            await mergePlayerProfilesWithLocal(result.records)
        } else {
            debugLog("ℹ️ [MINIMAL] No profile found in CloudKit for user (may not exist yet)")
        }
    }

    private func fetchRecentGames(limit: Int) async throws {
        debugLog("☁️ [MINIMAL] Fetching \(limit) most recent games...")

        let predicate = NSPredicate(format: "softDeleted == NO")
        let sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let result = try await cloudKit.queryRecords(
                withType: .game,
                from: .publicDB,
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                resultsLimit: limit
            )

            if !result.records.isEmpty {
                debugLog("📥 [MINIMAL] Fetched \(result.records.count) recent games")
                await mergeGamesWithLocal(result.records)
            } else {
                debugLog("ℹ️ [MINIMAL] No games found in CloudKit")
                await mergeGamesWithLocal([])
            }
        } catch {
            // Fallback: если timestamp не индексирован, загружаем без сортировки
            debugLog("⚠️ [MINIMAL] Sorted fetch failed, trying without sort: \(error.localizedDescription)")
            let result = try await cloudKit.queryRecords(
                withType: .game,
                from: .publicDB,
                predicate: predicate,
                sortDescriptors: nil,
                resultsLimit: limit
            )
            if !result.records.isEmpty {
                await mergeGamesWithLocal(result.records)
            } else {
                await mergeGamesWithLocal([])
            }
        }
    }

    private func fetchPendingClaimsForHost(userId: UUID) async throws {
        debugLog("☁️ [MINIMAL] Fetching pending claims for host \(userId)...")

        let hostRecordID = CKRecord.ID(recordName: userId.uuidString)
        let hostReference = CKRecord.Reference(recordID: hostRecordID, action: .none)
        let predicate = NSPredicate(format: "hostUser == %@ AND status == %@", hostReference, "pending")

        let result = try await cloudKit.queryRecords(
            withType: .playerClaim,
            from: .publicDB,
            predicate: predicate,
            sortDescriptors: nil,
            resultsLimit: 100
        )

        if !result.records.isEmpty {
            debugLog("📥 [MINIMAL] Fetched \(result.records.count) pending claims")
            await mergePlayerClaimsWithLocal(result.records, deleteMissing: false)
        }
        // Полная загрузка claims будет в Phase 2 (performBackgroundSync)
    }

    private func fetchUserStatisticsSummary(userId: UUID) async throws {
        debugLog("☁️ [MINIMAL] Fetching UserStatisticsSummary for user \(userId)...")

        let predicate = NSPredicate(format: "userId == %@", userId.uuidString)
        let result = try await cloudKit.queryRecords(
            withType: .userStatisticsSummary,
            from: .publicDB,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "lastUpdated", ascending: false)],
            resultsLimit: 1
        )

        if let record = result.records.first {
            await mergeUserStatisticsSummaryWithLocal([record])
        }
    }

    @MainActor
    private func mergeUserStatisticsSummaryWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        for record in cloudRecords {
            guard let userIdString = record["userId"] as? String,
                  let userId = UUID(uuidString: userIdString) else { continue }

            let fetchRequest: NSFetchRequest<UserStatisticsSummary> = UserStatisticsSummary.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)

            if let existing = try? context.fetch(fetchRequest).first {
                existing.updateFromCKRecord(record)
            } else {
                let newSummary = UserStatisticsSummary(context: context)
                newSummary.userId = userId
                newSummary.updateFromCKRecord(record)
            }
        }
        if context.hasChanges { try? context.save() }
    }

    // MARK: - Fetch Public Games

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async throws {
        debugLog("☁️ [FETCH_PROFILES] Fetching PlayerProfiles from CloudKit PUBLIC DB...")
        
        let predicate = NSPredicate(value: true)
        let records = try await cloudKit.fetchRecords(
            withType: .playerProfile,
            from: .publicDB,  // ИЗМЕНЕНО: Public DB для cross-user visibility
            predicate: predicate,
            limit: 400
        )
        
        if records.isEmpty {
            debugLog("ℹ️ [FETCH_PROFILES] No profiles found in CloudKit")
            // Не удаляем локальные профили, т.к. это может быть текущий пользователь
        } else {
            debugLog("📥 [FETCH_PROFILES] Fetched \(records.count) profiles from CloudKit PUBLIC DB")
            await mergePlayerProfilesWithLocal(records, notifyOnNewPublic: notifyOnNewPublic)
        }
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
            debugLog("ℹ️ [FETCH_GAMES] No public games found in CloudKit")
            debugLog("☁️ [FETCH_GAMES] CloudKit = Source of Truth: will delete all local games (except pending)")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных игр
            await mergeGamesWithLocal([])
        } else {
            debugLog("📥 [FETCH_GAMES] Fetched \(records.count) public games from CloudKit")
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
            debugLog("📥 [FETCH_ALIASES] Fetched \(records.count) public player aliases from CloudKit")
            await mergePlayerAliasesWithLocal(records)
        } else {
            debugLog("ℹ️ [FETCH_ALIASES] No aliases found in CloudKit")
            // CloudKit = Source of Truth: если в CloudKit нет алиасов, удаляем все локальные
            await deleteAllLocalAliases()
        }
    }
    
    // MARK: - Merge PlayerProfiles with Local
    
    @MainActor
    private func mergePlayerProfilesWithLocal(_ cloudRecords: [CKRecord], notifyOnNewPublic: Bool = false) async {
        let context = persistence.container.viewContext
        
        debugLog("🔄 [MERGE_PROFILES] Starting merge: \(cloudRecords.count) profiles from CloudKit")
        
        let currentUserId = UserDefaults.standard.string(forKey: "currentUserId")
            .flatMap { UUID(uuidString: $0) }
            ?? KeychainService.shared.getUserId().flatMap { UUID(uuidString: $0) }
        
        var cloudProfileIds = Set<UUID>()
        
        for record in cloudRecords {
            guard let profileId = UUID(uuidString: record.recordID.recordName) else {
                debugLog("⚠️ [MERGE_PROFILES] Invalid profile ID: \(record.recordID.recordName)")
                continue
            }
            
            cloudProfileIds.insert(profileId)
            
            if let existingProfile = persistence.fetchPlayerProfile(byProfileId: profileId) {
                // CloudKit = Source of Truth: всегда обновляем
                let wasPublic = existingProfile.isPublic
                existingProfile.updateFromCKRecord(record)
                debugLog("🔄 [MERGE_PROFILES] Updated profile: \(existingProfile.displayName)")
                // Уведомление: профиль только что стал публичным (только при push)
                if notifyOnNewPublic, existingProfile.isPublic, !wasPublic,
                   existingProfile.userId != currentUserId {
                    Task {
                        await NotificationService.shared.notifyProfileBecamePublic(displayName: existingProfile.displayName)
                    }
                }
            } else {
                // Создаём новый профиль из CloudKit
                let newProfile = PlayerProfile(context: context)
                newProfile.profileId = profileId
                newProfile.updateFromCKRecord(record)
                
                // Пытаемся найти связанного пользователя
                if let userId = newProfile.userId,
                   let user = persistence.fetchUser(byId: userId) {
                    newProfile.user = user
                    debugLog("➕ [MERGE_PROFILES] Created profile: \(newProfile.displayName) linked to user \(user.username)")
                } else {
                    debugLog("➕ [MERGE_PROFILES] Created profile: \(newProfile.displayName) (no user link)")
                }
                // Уведомление: новый публичный профиль (только при push)
                if notifyOnNewPublic, newProfile.isPublic, newProfile.userId != currentUserId {
                    Task {
                        await NotificationService.shared.notifyProfileBecamePublic(displayName: newProfile.displayName)
                    }
                }
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные профили, которых нет в CloudKit
        // ВАЖНО: НЕ удаляем профиль текущего пользователя
        do {
            let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
            let allLocalProfiles = try context.fetch(fetchRequest)
            
            // Получаем userId текущего пользователя
            let currentUserId = UserDefaults.standard.string(forKey: "currentUserId")
                .flatMap { UUID(uuidString: $0) }
            
            var deletedCount = 0
            for localProfile in allLocalProfiles {
                // НЕ удаляем профиль текущего пользователя
                if let currentUserId = currentUserId, localProfile.userId == currentUserId {
                    debugLog("🔒 [MERGE_PROFILES] Skipping current user's profile: \(localProfile.displayName)")
                    continue
                }
                
                // Удаляем если нет в CloudKit
                if !cloudProfileIds.contains(localProfile.profileId) {
                    debugLog("🗑️ [MERGE_PROFILES] Deleting local profile not in CloudKit: \(localProfile.displayName)")
                    context.delete(localProfile)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [MERGE_PROFILES] Deleted \(deletedCount) local profiles not found in CloudKit")
            }
        } catch {
            debugLog("❌ [MERGE_PROFILES] Error fetching local profiles for cleanup: \(error)")
        }
        
        if context.hasChanges {
            do {
                try context.save()
                debugLog("✅ [MERGE_PROFILES] Successfully merged profiles with local database")
            } catch {
                debugLog("❌ [MERGE_PROFILES] Failed to save merged profiles: \(error)")
            }
        }
    }
    
    // MARK: - Merge Aliases with Local
    
    @MainActor
    private func mergePlayerAliasesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        debugLog("🔄 [MERGE_ALIASES] Starting merge: \(cloudRecords.count) aliases from CloudKit")
        
        var cloudAliasIds = Set<UUID>()
        
        for record in cloudRecords {
            guard let aliasId = UUID(uuidString: record.recordID.recordName) else {
                debugLog("⚠️ [MERGE_ALIASES] Invalid alias ID: \(record.recordID.recordName)")
                continue
            }
            
            cloudAliasIds.insert(aliasId)
            
            if let existingAlias = persistence.fetchAlias(byId: aliasId) {
                // CloudKit = Source of Truth: всегда обновляем
                existingAlias.updateFromCKRecord(record)
                debugLog("🔄 [MERGE_ALIASES] Updated alias: \(existingAlias.aliasName)")
            } else {
                let newAlias = PlayerAlias(context: context)
                newAlias.aliasId = aliasId
                newAlias.updateFromCKRecord(record)
                
                // Ищем PlayerProfile для этого алиаса
                if let profile = persistence.fetchPlayerProfile(byProfileId: newAlias.profileId) {
                    newAlias.profile = profile
                    debugLog("➕ [MERGE_ALIASES] Created alias: \(newAlias.aliasName) for profile \(profile.displayName)")
                } else {
                    // Профиль не найден локально - нужно удалить созданный алиас
                    context.delete(newAlias)
                    debugLog("⚠️ [MERGE_ALIASES] Skipping alias \(newAlias.aliasName) - PlayerProfile \(newAlias.profileId) not found locally (will sync when profile arrives)")
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
                    debugLog("🗑️ [MERGE_ALIASES] Deleting local alias not in CloudKit: \(localAlias.aliasName)")
                    context.delete(localAlias)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [MERGE_ALIASES] Deleted \(deletedCount) local aliases not found in CloudKit")
            }
        } catch {
            debugLog("❌ [MERGE_ALIASES] Error fetching local aliases for cleanup: \(error)")
        }
        
        if context.hasChanges {
            do {
                try context.save()
                debugLog("✅ [MERGE_ALIASES] Successfully merged aliases with local database")
            } catch {
                debugLog("❌ [MERGE_ALIASES] Failed to save merged aliases: \(error)")
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
                debugLog("🗑️ [DELETE_ALIASES] CloudKit has 0 aliases - deleting all \(allLocalAliases.count) local aliases")
                for alias in allLocalAliases {
                    context.delete(alias)
                }
                
                try context.save()
                debugLog("✅ [DELETE_ALIASES] Deleted all local aliases")
            }
        } catch {
            debugLog("❌ [DELETE_ALIASES] Error deleting local aliases: \(error)")
        }
    }
    
    // MARK: - Fetch Public GameWithPlayer
    
    private func fetchPublicGameWithPlayers() async throws {
        // PAGINATION: Fetch ВСЕ GameWithPlayer records с автоматической пагинацией
        debugLog("🔄 [FETCH_ALL_PLAYERS] Starting paginated fetch for ALL GameWithPlayer records...")
        
        let allRecords = try await cloudKit.fetchAllRecords(
            withType: .gameWithPlayer,
            from: .publicDB,
            batchSize: 400
        )
        
        if !allRecords.isEmpty {
            debugLog("✅ [FETCH_ALL_PLAYERS] Total fetched: \(allRecords.count) game-player records from CloudKit (with pagination)")
            await mergeGameWithPlayersWithLocal(allRecords)
        } else {
            debugLog("ℹ️ [FETCH_ALL_PLAYERS] No GameWithPlayer records found in CloudKit")
            debugLog("☁️ [FETCH_ALL_PLAYERS] CloudKit = Source of Truth: will delete all local GameWithPlayer")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных GWP
            await mergeGameWithPlayersWithLocal([])
        }
    }
    
    /// Загружает игроков для конкретной игры из Public Database
    func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
        debugLog("🔍 [FETCH_PLAYERS] Starting fetch for game: \(gameId)")
        
        // Query с фильтром по игре
        let gameRecordID = CKRecord.ID(recordName: gameId.uuidString)
        let gameRef = CKRecord.Reference(recordID: gameRecordID, action: .none)
        let predicate = NSPredicate(format: "game == %@", gameRef)
        
        debugLog("🔍 [FETCH_PLAYERS] Query predicate: \(predicate)")
        debugLog("🔍 [FETCH_PLAYERS] Game reference: \(gameRef.recordID.recordName)")
        
        do {
            let records = try await cloudKit.fetchRecords(
                withType: .gameWithPlayer,
                from: .publicDB,
                predicate: predicate,
                limit: 100
            )
            
            if !records.isEmpty {
                debugLog("✅ [FETCH_PLAYERS] Fetched \(records.count) players for game \(gameId)")
                for (index, record) in records.enumerated() {
                    let playerName = record["playerName"] as? String ?? "Unknown"
                    let buyin = record["buyin"] as? Int16 ?? 0
                    let cashout = record["cashout"] as? Int64 ?? 0
                    debugLog("   Player \(index + 1): \(playerName) (buyin: \(buyin), cashout: \(cashout))")
                }
                await mergeGameWithPlayersWithLocal(records)
            } else {
                debugLog("⚠️ [FETCH_PLAYERS] No players found in CloudKit for game \(gameId)")
                debugLog("⚠️ [FETCH_PLAYERS] This could mean:")
                debugLog("   1. GameWithPlayer records were not synced to CloudKit")
                debugLog("   2. Schema was not deployed to Production")
                debugLog("   3. Records are in Private DB instead of Public DB")
            }
        } catch {
            debugLog("❌ [FETCH_PLAYERS] Error fetching players: \(error)")
            throw error
        }
    }
    
    /// Загружает PlayerClaim из Public Database (changed from Private)
    private func fetchPlayerClaims() async throws {
        debugLog("🔄 [FETCH_CLAIMS] Fetching PlayerClaims from Public Database...")
        
        let records = try await cloudKit.fetchRecords(
            withType: .playerClaim,
            from: .publicDB,
            limit: 400
        )
        
        if !records.isEmpty {
            debugLog("📥 [FETCH_CLAIMS] Fetched \(records.count) claims from CloudKit")
            await mergePlayerClaimsWithLocal(records)
        } else {
            debugLog("ℹ️ [FETCH_CLAIMS] No claims found in CloudKit")
            debugLog("☁️ [FETCH_CLAIMS] CloudKit = Source of Truth: will delete all local claims (except pending)")
            // ВАЖНО: Вызываем merge с пустым массивом для удаления локальных claims
            await mergePlayerClaimsWithLocal([])
        }
    }
    
    /// Очищает невалидные PlayerClaim из CloudKit Public Database (changed from Private)
    func cleanupInvalidClaims() async throws {
        debugLog("🧹 [CLEANUP_CLAIMS] Starting cleanup of invalid claims...")
        
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
                debugLog("⚠️ [CLEANUP_CLAIMS] Found invalid claim: \(claimId)")
                debugLog("   - hasPlayerName: \(hasPlayerName), hasGameRef: \(hasGameRef)")
                debugLog("   - hasClaimantRef: \(hasClaimantRef), hasHostRef: \(hasHostRef)")
                debugLog("   - hasStatus: \(hasStatus)")
                invalidClaimIds.append(record.recordID)
            }
        }
        
        if !invalidClaimIds.isEmpty {
            debugLog("🗑️ [CLEANUP_CLAIMS] Deleting \(invalidClaimIds.count) invalid claims from CloudKit...")
            for recordID in invalidClaimIds {
                do {
                    try await cloudKit.delete(recordID: recordID, from: .publicDB)
                    debugLog("✅ [CLEANUP_CLAIMS] Deleted \(recordID.recordName)")
                } catch {
                    debugLog("❌ [CLEANUP_CLAIMS] Failed to delete \(recordID.recordName): \(error)")
                }
            }
            debugLog("✅ [CLEANUP_CLAIMS] Cleanup completed: deleted \(invalidClaimIds.count) invalid claims")
        } else {
            debugLog("✅ [CLEANUP_CLAIMS] No invalid claims found")
        }
    }
    
    // MARK: - Merge Games with Local
    
    @MainActor
    private func mergeGamesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        debugLog("🔄 [MERGE_GAMES] Starting merge: \(cloudRecords.count) games from CloudKit")
        
        // Собираем все gameId из CloudKit
        var cloudGameIds = Set<UUID>()
        
        for record in cloudRecords {
            // Filter out soft-deleted games
            if let softDeleted = record["softDeleted"] as? Int64, softDeleted != 0 {
                continue
            }
            
            let gameIdString = record.recordID.recordName
            guard let gameId = UUID(uuidString: gameIdString) else {
                debugLog("⚠️ Invalid game ID in CloudKit record: \(gameIdString)")
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
                    debugLog("🔄 [MERGE_GAMES] Updated local game: \(gameId)")
                } else {
                    // Game doesn't exist locally - create it
                    if self.createGameFromCKRecord(record, in: context) != nil {
                        debugLog("➕ [MERGE_GAMES] Created local game: \(gameId)")
                    }
                }
            } catch {
                debugLog("❌ [MERGE_GAMES] Error processing game \(gameId): \(error)")
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
                    debugLog("🗑️ [MERGE_GAMES] Deleting local game not in CloudKit: \(localGame.gameId)")
                    context.delete(localGame)
                    deletedCount += 1
                } else if !cloudGameIds.contains(localGame.gameId) && pendingGames.contains(localGame.gameId) {
                    debugLog("📌 [MERGE_GAMES] Keeping pending game (not yet synced): \(localGame.gameId)")
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [MERGE_GAMES] Deleted \(deletedCount) local games not found in CloudKit")
            }
        } catch {
            debugLog("❌ [MERGE_GAMES] Error fetching local games for cleanup: \(error)")
        }
        
        // Save all changes
        if context.hasChanges {
            do {
                try context.save()
                debugLog("✅ [MERGE_GAMES] Merged \(cloudRecords.count) games with local database")
            } catch {
                debugLog("❌ [MERGE_GAMES] Failed to save merged games: \(error)")
            }
        }
    }
    
    // MARK: - Create Game from CKRecord
    
    @MainActor
    private func createGameFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> Game? {
        let gameIdString = record.recordID.recordName
        guard let gameId = UUID(uuidString: gameIdString) else {
            debugLog("⚠️ Invalid game ID in CloudKit record: \(gameIdString)")
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
        
        debugLog("🔄 [MERGE_GWP] Starting merge: \(cloudRecords.count) GameWithPlayer from CloudKit")
        
        // Собираем все пары (gameId, playerName) из CloudKit
        var cloudGWPKeys = Set<String>() // "gameId|playerName"
        
        for record in cloudRecords {
            // Получаем gameId из reference
            guard let gameRef = record["game"] as? CKRecord.Reference else {
                debugLog("⚠️ [MERGE_GWP] GameWithPlayer record without game reference")
                continue
            }
            let gameIdString = gameRef.recordID.recordName
            guard let gameId = UUID(uuidString: gameIdString) else {
                debugLog("⚠️ [MERGE_GWP] Invalid game ID: \(gameIdString)")
                continue
            }
            
            // Ищем игру локально
            let gameFetch: NSFetchRequest<Game> = Game.fetchRequest()
            gameFetch.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
            
            guard let game = try? context.fetch(gameFetch).first else {
                debugLog("⚠️ [MERGE_GWP] Game \(gameId) not found locally, skipping GameWithPlayer")
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
                debugLog("⚠️ [MERGE_GWP] GameWithPlayer record without playerName")
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
                debugLog("➕ [MERGE_GWP] Created Player: \(playerName)")
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
                
                // ВАЖНО: Обновляем playerProfile только если:
                // 1. Новый профиль не nil (появилась привязка)
                // 2. ИЛИ локальный профиль nil (ещё не было привязки)
                if playerProfile != nil {
                    // Появилась новая привязка - всегда обновляем
                    existingGWP.playerProfile = playerProfile
                    debugLog("🔄 [MERGE_GWP] Updated GameWithPlayer for \(playerName) in game \(gameId) - linked to profile \(playerProfile!.displayName)")
                } else if existingGWP.playerProfile == nil {
                    // Оба nil - ничего не меняем
                    debugLog("🔄 [MERGE_GWP] Updated GameWithPlayer for \(playerName) in game \(gameId) - no profile (unclaimed)")
                } else {
                    // CloudKit говорит nil, но локально есть профиль - оставляем локальный!
                    debugLog("⚠️ [MERGE_GWP] Updated GameWithPlayer for \(playerName) in game \(gameId) - keeping local profile (CloudKit has nil)")
                }
            } else {
                // Создаём новый
                let gwp = GameWithPlayer(context: context)
                gwp.game = game
                gwp.player = player
                gwp.playerProfile = playerProfile
                gwp.updateFromCKRecord(record)
                debugLog("➕ [MERGE_GWP] Created GameWithPlayer for \(playerName) in game \(gameId)")
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
                        debugLog("🗑️ [MERGE_GWP] Deleting local GWP not in CloudKit: \(playerName) in game \(game.gameId)")
                        context.delete(localGWP)
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                debugLog("🗑️ [MERGE_GWP] Deleted \(deletedCount) local GameWithPlayer not found in CloudKit")
            }
        } catch {
            debugLog("❌ [MERGE_GWP] Error fetching local GWP for cleanup: \(error)")
        }
        
        // Сохраняем все изменения
        if context.hasChanges {
            do {
                try context.save()
                debugLog("✅ [MERGE_GWP] Merged GameWithPlayer records with local database")
            } catch {
                debugLog("❌ [MERGE_GWP] Failed to save merged GameWithPlayer: \(error)")
            }
        }
    }
    
    // MARK: - Merge PlayerClaim with Local
    
    @MainActor
    private func mergePlayerClaimsWithLocal(_ cloudRecords: [CKRecord], deleteMissing: Bool = true) async {
        let context = persistence.container.viewContext
        
        debugLog("🔄 [MERGE_CLAIMS] Starting merge of \(cloudRecords.count) claims (deleteMissing: \(deleteMissing))...")
        
        var validClaims = 0
        var skippedClaims = 0
        var cloudClaimIds = Set<UUID>() // Source of Truth: собираем ID из CloudKit
        
        for record in cloudRecords {
            let claimIdString = record.recordID.recordName
            guard let claimId = UUID(uuidString: claimIdString) else {
                debugLog("⚠️ [MERGE_CLAIMS] Invalid claim ID: \(claimIdString)")
                skippedClaims += 1
                continue
            }
            
            // ВАЛИДАЦИЯ: проверяем обязательные поля
            guard let playerName = record["playerName"] as? String,
                  !playerName.isEmpty else {
                debugLog("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing playerName")
                skippedClaims += 1
                continue
            }
            
            guard let gameRef = record["game"] as? CKRecord.Reference,
                  let gameIdString = UUID(uuidString: gameRef.recordID.recordName) else {
                debugLog("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid gameId")
                skippedClaims += 1
                continue
            }
            
            guard let claimantRef = record["claimantUser"] as? CKRecord.Reference,
                  let claimantIdString = UUID(uuidString: claimantRef.recordID.recordName) else {
                debugLog("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid claimantUserId")
                skippedClaims += 1
                continue
            }
            
            guard let hostRef = record["hostUser"] as? CKRecord.Reference,
                  let hostIdString = UUID(uuidString: hostRef.recordID.recordName) else {
                debugLog("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing or invalid hostUserId")
                skippedClaims += 1
                continue
            }
            
            guard let status = record["status"] as? String,
                  !status.isEmpty else {
                debugLog("⚠️ [MERGE_CLAIMS] Skipping claim \(claimId): missing status")
                skippedClaims += 1
                continue
            }
            
            debugLog("✅ [MERGE_CLAIMS] Claim \(claimId) passed validation")
            cloudClaimIds.insert(claimId) // Добавляем в Set
            
            // Проверяем существует ли claim локально
            let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
            
            if let existingClaim = try? context.fetch(fetchRequest).first {
                // CloudKit = Source of Truth: всегда обновляем
                existingClaim.updateFromCKRecord(record)
                debugLog("🔄 [MERGE_CLAIMS] Updated claim \(claimId)")
                validClaims += 1
            } else {
                // Создаём новый
                let newClaim = PlayerClaim(context: context)
                newClaim.claimId = claimId
                newClaim.updateFromCKRecord(record)
                debugLog("➕ [MERGE_CLAIMS] Created claim \(claimId) (playerName: \(newClaim.playerName), status: \(newClaim.status))")
                validClaims += 1
            }
        }
        
        // CloudKit = Source of Truth: удаляем локальные claims, которых нет в CloudKit (если deleteMissing)
        if deleteMissing {
            do {
                let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
                let allLocalClaims = try context.fetch(fetchRequest)
                
                var deletedCount = 0
                for localClaim in allLocalClaims {
                    if !cloudClaimIds.contains(localClaim.claimId) {
                        debugLog("🗑️ [MERGE_CLAIMS] Deleting local claim not in CloudKit: \(localClaim.claimId)")
                        context.delete(localClaim)
                        deletedCount += 1
                    }
                }
                
                if deletedCount > 0 {
                    debugLog("🗑️ [MERGE_CLAIMS] Deleted \(deletedCount) local claims not found in CloudKit")
                }
            } catch {
                debugLog("❌ [MERGE_CLAIMS] Error fetching local claims for cleanup: \(error)")
            }
        }
        
        debugLog("📊 [MERGE_CLAIMS] Validation results: \(validClaims) valid, \(skippedClaims) skipped")
        
        // Сохраняем все изменения
        if context.hasChanges {
            do {
                try context.save()
                debugLog("✅ [MERGE_CLAIMS] Successfully merged \(validClaims) claims with local database")
            } catch {
                debugLog("❌ [MERGE_CLAIMS] Failed to save merged claims: \(error)")
            }
        } else {
            debugLog("ℹ️ [MERGE_CLAIMS] No valid claims to save")
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
                        debugLog("❌ Game \(gameId) is not public and user is not the creator")
                        throw CloudKitSyncError.gameNotPublic
                    }
                } else {
                    // Нет информации о создателе или текущем пользователе - отказываем
                    debugLog("❌ Game \(gameId) is not public and cannot verify creator")
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
                debugLog("🔄 [FETCH_GAME] Game found, now fetching players for game \(gameId)...")
                do {
                    try await fetchGameWithPlayers(forGameId: gameId)
                    debugLog("✅ [FETCH_GAME] Players loaded successfully for game \(gameId)")
                } catch {
                    debugLog("❌ [FETCH_GAME] FAILED to load players for game \(gameId): \(error)")
                    debugLog("❌ [FETCH_GAME] Error type: \(type(of: error))")
                    debugLog("❌ [FETCH_GAME] Localized: \(error.localizedDescription)")
                    // НЕ бросаем исключение - игра уже загружена, просто игроков нет
                }
            } else {
                debugLog("⚠️ [FETCH_GAME] Game is nil after fetch, cannot load players")
            }
            
            return game
        } catch {
            debugLog("❌ Failed to fetch game \(gameId) from CloudKit: \(error)")
            throw CloudKitSyncError.gameNotFound
        }
    }
    
    // MARK: - Incremental Sync (Delta Sync)

    /// Phase 2: Улучшенный incremental sync - не загружает GWP, использует minimal при недавней синхронизации
    func performIncrementalSync() async throws {
        debugLog("🔄 Starting incremental sync...")

        let lastSync = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date

        // Если синхронизация была недавно (< 2 мин), делаем только minimal sync
        if let lastSync = lastSync, Date().timeIntervalSince(lastSync) < 120 {
            debugLog("ℹ️ Recent sync (\(Int(Date().timeIntervalSince(lastSync)))s ago), using minimal sync")
            try await performMinimalSync()
            return
        }

        // Иначе - фоновая синхронизация (без GWP, быстрее чем full)
        debugLog("🔄 Running background sync (no GWP)...")
        try await performBackgroundSync()
    }
    
    // MARK: - Fetch User from CloudKit (for login recovery)
    
    /// Загружает пользователя из CloudKit Private Database по username
    /// Используется при входе если пользователь не найден локально (например, после переустановки)
    func fetchUser(byUsername username: String) async throws -> User? {
        debugLog("🔍 Trying to fetch user '\(username)' from CloudKit Public Database...")
        
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
            debugLog("❌ User '\(username)' not found in CloudKit")
            return nil
        }
        
        debugLog("✅ Found user '\(username)' in CloudKit, creating local copy...")
        
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
        debugLog("🔍 Trying to fetch user by email '\(email)' from CloudKit Public Database...")
        
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
            debugLog("❌ User with email '\(email)' not found in CloudKit")
            return nil
        }
        
        debugLog("✅ Found user by email in CloudKit, creating local copy...")
        
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
            debugLog("🗑️ Deleted user \(userId) from CloudKit Public Database")
        } catch {
            debugLog("❌ Failed to delete user \(userId) from CloudKit: \(error)")
            throw error
        }
    }
    
    /// Удаляет невалидный PlayerClaim из CloudKit Public Database (changed from Private)
    func deleteInvalidClaim(claimId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: claimId.uuidString)
        
        do {
            try await cloudKit.delete(recordID: recordID, from: .publicDB)
            debugLog("🗑️ [DELETE_CLAIM] Deleted invalid claim \(claimId) from CloudKit Public Database")
        } catch {
            debugLog("❌ [DELETE_CLAIM] Failed to delete claim \(claimId) from CloudKit: \(error)")
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
            debugLog("🗑️ [DELETE_CLAIM] Deleted local claim \(claimId)")
        } else {
            debugLog("ℹ️ [DELETE_CLAIM] Claim \(claimId) not found locally")
        }
    }
    
    /// Загружает PlayerProfile из CloudKit для пользователя
    private func fetchPlayerProfile(forUserId userId: UUID) async {
        debugLog("🔍 Trying to fetch PlayerProfile for user \(userId)...")
        
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
                debugLog("⚠️ PlayerProfile not found in CloudKit")
                return
            }
            
            debugLog("✅ Found PlayerProfile in CloudKit, creating local copy...")
            
            await MainActor.run {
                let context = persistence.container.viewContext
                _ = createPlayerProfileFromCKRecord(profileRecord, in: context)
            }
        } catch {
            debugLog("❌ Failed to fetch PlayerProfile: \(error)")
        }
    }
    
    /// Создает User из CKRecord
    @MainActor
    private func createUserFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> User? {
        // Извлекаем userId из recordName
        guard let userId = UUID(uuidString: record.recordID.recordName) else {
            debugLog("❌ Invalid userId in CKRecord")
            return nil
        }
        
        // Проверяем не существует ли уже локально
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        
        if let existingUser = try? context.fetch(fetchRequest).first {
            debugLog("ℹ️ User already exists locally, returning existing")
            return existingUser
        }
        
        // Извлекаем обязательные поля
        guard let username = record["username"] as? String,
              let passwordHash = record["passwordHash"] as? String,
              let subscriptionStatus = record["subscriptionStatus"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            debugLog("❌ Missing required fields in User CKRecord")
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
            debugLog("✅ User created locally from CloudKit")
            return user
        } catch {
            debugLog("❌ Failed to save user: \(error)")
            return nil
        }
    }
    
    /// Создает PlayerProfile из CKRecord
    @MainActor
    private func createPlayerProfileFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> PlayerProfile? {
        // Извлекаем profileId из recordName
        guard let profileId = UUID(uuidString: record.recordID.recordName) else {
            debugLog("❌ Invalid profileId in CKRecord")
            return nil
        }
        
        // Проверяем не существует ли уже локально
        let fetchRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profileId == %@", profileId as CVarArg)
        
        if let existingProfile = try? context.fetch(fetchRequest).first {
            debugLog("ℹ️ PlayerProfile already exists locally, returning existing")
            return existingProfile
        }
        
        // Создаем новый профиль
        let profile = PlayerProfile(context: context)
        profile.profileId = profileId
        profile.displayName = (record["displayName"] as? String) ?? ""
        profile.isAnonymous = (record["isAnonymous"] as? Int64 == 1)
        profile.isPublic = (record["isPublic"] as? Int64 == 1)
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
            debugLog("✅ PlayerProfile created locally from CloudKit")
            return profile
        } catch {
            debugLog("❌ Failed to save PlayerProfile: \(error)")
            return nil
        }
    }
    
    // MARK: - Quick Sync (автоматическая синхронизация после создания)
    
    /// Быстрая синхронизация User после создания/изменения
    /// DEPRECATED: User should NOT be synced to CloudKit - use PlayerProfile instead
    @available(*, deprecated, message: "User sync is disabled. User is local authentication data only.")
    func quickSyncUser(_ user: User) async {
        debugLog("🔄 [QUICK_SYNC_USER] Starting sync for user: \(user.username)")
        
        let isAvailable = await cloudKit.isCloudKitAvailable()
        debugLog("☁️ [QUICK_SYNC_USER] CloudKit available: \(isAvailable)")
        
        guard isAvailable else {
            debugLog("❌ [QUICK_SYNC_USER] CloudKit NOT available - skipping sync")
            return
        }
        
        do {
            debugLog("📦 [QUICK_SYNC_USER] Creating CKRecord for user \(user.userId)")
            let record = user.toCKRecord()
            debugLog("📦 [QUICK_SYNC_USER] Record created: \(record.recordType), recordID: \(record.recordID.recordName)")
            debugLog("📦 [QUICK_SYNC_USER] Record fields: username=\(record["username"] ?? "nil"), email=\(record["email"] ?? "nil")")
            debugLog("📦 [QUICK_SYNC_USER] NOTE: passwordHash is NOT included (local only)")
            
            debugLog("☁️ [QUICK_SYNC_USER] Saving to CloudKit Public Database...")
            let savedRecord = try await cloudKit.save(record: record, to: .publicDB)
            debugLog("✅ [QUICK_SYNC_USER] SUCCESS! User synced to CloudKit Public Database")
            debugLog("✅ [QUICK_SYNC_USER] Saved record ID: \(savedRecord.recordID.recordName)")
            debugLog("✅ [QUICK_SYNC_USER] Username: \(user.username)")
        } catch {
            debugLog("❌ [QUICK_SYNC_USER] FAILED to sync User")
            debugLog("❌ [QUICK_SYNC_USER] Error type: \(type(of: error))")
            debugLog("❌ [QUICK_SYNC_USER] Error description: \(error)")
            debugLog("❌ [QUICK_SYNC_USER] Localized: \(error.localizedDescription)")
        }
    }
    
    /// Быстрая синхронизация Game после создания/изменения
    func quickSyncGame(_ game: Game) async {
        guard await cloudKit.isCloudKitAvailable() else { return }
        
        do {
            let record = game.toCKRecord()
            _ = try await cloudKit.save(record: record, to: .publicDB)
            debugLog("✅ Quick synced Game: \(game.gameId)")
        } catch {
            debugLog("❌ Failed to quick sync Game: \(error)")
        }
    }
    
    /// Быстрая синхронизация GameWithPlayer после создания/изменения
    func quickSyncGameWithPlayers(_ gameWithPlayers: [GameWithPlayer]) async {
        debugLog("🔄 [QUICK_SYNC] Starting quick sync for \(gameWithPlayers.count) GameWithPlayer records")
        
        guard await cloudKit.isCloudKitAvailable() else {
            debugLog("❌ [QUICK_SYNC] CloudKit not available")
            return
        }
        guard !gameWithPlayers.isEmpty else {
            debugLog("⚠️ [QUICK_SYNC] No records to sync")
            return
        }
        
        do {
            let records = gameWithPlayers.map { $0.toCKRecord() }
            debugLog("📤 [QUICK_SYNC] Converted to \(records.count) CKRecords")
            
            for (index, record) in records.enumerated() {
                if let game = gameWithPlayers[index].game {
                    let playerName = gameWithPlayers[index].player?.name ?? "Unknown"
                    debugLog("   Record \(index + 1): \(playerName) for game \(game.gameId)")
                }
            }
            
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            debugLog("✅ [QUICK_SYNC] Successfully synced \(records.count) GameWithPlayer records to Public DB")
        } catch {
            debugLog("❌ [QUICK_SYNC] Failed to quick sync GameWithPlayers: \(error)")
            debugLog("❌ [QUICK_SYNC] Error details: \(error.localizedDescription)")
        }
    }
    
    /// Быстрая синхронизация PlayerProfile после создания/изменения
    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        guard await cloudKit.isCloudKitAvailable() else { return }
        
        do {
            let record = profile.toCKRecord()
            _ = try await cloudKit.save(record: record, to: .publicDB)  // ИЗМЕНЕНО: Public DB
            debugLog("✅ Quick synced PlayerProfile: \(profile.displayName) to PUBLIC DB")
        } catch {
            debugLog("❌ Failed to quick sync PlayerProfile: \(error)")
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
        
        debugLog("🔄 [PUSH_PENDING] Starting to push pending data...")
        
        // 1. Push pending games
        let pendingGameIds = tracker.getPendingGames()
        if !pendingGameIds.isEmpty {
            debugLog("📤 [PUSH_PENDING] Found \(pendingGameIds.count) pending games")
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId IN %@", Array(pendingGameIds))
            
            if let games = try? context.fetch(fetchRequest), !games.isEmpty {
                let records = games.map { $0.toCKRecord() }
                _ = try await cloudKit.saveRecords(records, to: .publicDB)
                debugLog("✅ [PUSH_PENDING] Pushed \(games.count) games")
                
                // Remove from pending
                for game in games {
                    tracker.removePendingGame(game.gameId)
                }
            }
        }
        
        // 2. Push pending GameWithPlayer
        let pendingGWPIds = tracker.getPendingGameWithPlayers()
        if !pendingGWPIds.isEmpty {
            debugLog("📤 [PUSH_PENDING] Found \(pendingGWPIds.count) pending GameWithPlayer")
            // GameWithPlayer doesn't have gameWithPlayerId, so we sync all
            try await syncGameWithPlayers()
            tracker.getPendingGameWithPlayers().forEach { tracker.removePendingGameWithPlayer($0) }
        }
        
        // 3. Push pending PlayerAliases
        let pendingAliasIds = tracker.getPendingPlayerAliases()
        if !pendingAliasIds.isEmpty {
            debugLog("📤 [PUSH_PENDING] Found \(pendingAliasIds.count) pending PlayerAliases")
            let fetchRequest: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "aliasId IN %@", Array(pendingAliasIds))
            
            if let aliases = try? context.fetch(fetchRequest), !aliases.isEmpty {
                let records = aliases.map { $0.toCKRecord() }
                _ = try await cloudKit.saveRecords(records, to: .publicDB)
                debugLog("✅ [PUSH_PENDING] Pushed \(aliases.count) aliases")
                
                // Remove from pending
                for alias in aliases {
                    tracker.removePendingPlayerAlias(alias.aliasId)
                }
            }
        }
        
        // 4. Push pending PlayerClaims
        let pendingClaimIds = tracker.getPendingPlayerClaims()
        if !pendingClaimIds.isEmpty {
            debugLog("📤 [PUSH_PENDING] Found \(pendingClaimIds.count) pending PlayerClaims")
            try await syncPlayerClaims()
            tracker.getPendingPlayerClaims().forEach { tracker.removePendingPlayerClaim($0) }
        }
        
        debugLog("✅ [PUSH_PENDING] All pending data pushed successfully")
    }
}

// MARK: - Sync Completion Notifications

extension Notification.Name {
    static let syncCompletedSuccessfully = Notification.Name("syncCompletedSuccessfully")
    static let syncCompletedWithError = Notification.Name("syncCompletedWithError")
    static let openNotificationsTab = Notification.Name("openNotificationsTab")
    static let openGameFromNotification = Notification.Name("openGameFromNotification")
}


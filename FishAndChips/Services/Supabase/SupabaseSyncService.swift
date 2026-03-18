import Foundation
import CoreData
import Combine

/// Сервис синхронизации Core Data <-> Supabase
/// Замена CloudKitSyncService (~2165 строк) на Supabase REST API
@MainActor
class SupabaseSyncService: ObservableObject, SyncServiceProtocol {
    static let shared = SupabaseSyncService()

    @Published var isSyncing = false
    @Published var isBackgroundSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let supabase: SupabaseService
    private let persistence: PersistenceController
    private let pendingTracker: PendingSyncTracker

    private let syncQueue = DispatchQueue(label: "com.nicolascooper.FishAndChips.supabase-sync", qos: .userInitiated)

    // MARK: - Init

    nonisolated private init(
        supabase: SupabaseService = .shared,
        persistence: PersistenceController = .shared,
        pendingTracker: PendingSyncTracker = .shared
    ) {
        self.supabase = supabase
        self.persistence = persistence
        self.pendingTracker = pendingTracker
    }

    // MARK: - Main Sync

    func sync() async throws {
        guard !isSyncing else {
            debugLog("Supabase sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            try await pushAllChanges()
            try await pullAllChanges()

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSupabaseSyncDate")
            debugLog("Supabase sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Smart Sync

    /// Phase 1: быстрая загрузка профиля и последних игр
    /// Phase 2 (фон): проверка checksums, при расхождении — полная загрузка
    func smartSync() async throws {
        try await performMinimalSync()

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let hasChanges = try await self.checkServerChecksums()
                if hasChanges {
                    debugLog("Checksum mismatch — starting background sync")
                    await MainActor.run { self.isBackgroundSyncing = true }
                    try await self.performBackgroundSync()
                    await MainActor.run { self.isBackgroundSyncing = false }
                }
            } catch {
                debugLog("Smart sync phase 2 error: \(error)")
                await MainActor.run { self.isBackgroundSyncing = false }
            }
        }
    }

    // MARK: - Minimal Sync

    func performMinimalSync() async throws {
        guard let userId = await supabase.currentUserId() else { return }

        let profile: ProfileDTO? = try await supabase.fetchById(table: "profiles", id: userId)
        if let profile {
            await mergeProfile(profile)
        }

        let recentGames: [GameDTO] = try await supabase.fetchByFilter(table: "games") { query in
            query
                .eq("creator_id", value: userId)
                .eq("soft_deleted", value: false)
                .order("timestamp", ascending: false)
                .limit(20)
        }
        await mergeGames(recentGames)

        let pendingClaims: [PlayerClaimDTO] = try await supabase.fetchByFilter(table: "player_claims") { query in
            query
                .eq("host_id", value: userId)
                .eq("status", value: "pending")
        }
        await mergeClaims(pendingClaims)
    }

    // MARK: - Incremental Sync

    func performIncrementalSync() async throws {
        guard let lastSync = lastSyncDate else {
            try await performFullSync()
            return
        }

        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        if timeSinceLastSync < 120 {
            try await performMinimalSync()
        } else {
            try await performBackgroundSync()
        }

        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSupabaseSyncDate")
    }

    // MARK: - Full Sync

    func performFullSync() async throws {
        guard let userId = await supabase.currentUserId() else { return }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let profiles: [ProfileDTO] = try await supabase.fetchAll(table: "profiles")
            for profile in profiles {
                await mergeProfile(profile)
            }

            let games: [GameDTO] = try await supabase.fetchByFilter(table: "games") { query in
                query.eq("soft_deleted", value: false)
            }
            await mergeGames(games)

            for game in games {
                let players: [GamePlayerDTO] = try await supabase.fetchByColumn(
                    table: "game_players",
                    column: "game_id",
                    value: game.id
                )
                await mergeGamePlayers(players, forGameId: game.id)
            }

            let aliases: [PlayerAliasDTO] = try await supabase.fetchAll(table: "player_aliases")
            await mergeAliases(aliases)

            let claims: [PlayerClaimDTO] = try await supabase.fetchByFilter(table: "player_claims") { query in
                query.or("claimant_id.eq.\(userId),host_id.eq.\(userId)")
            }
            await mergeClaims(claims)

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSupabaseSyncDate")
            debugLog("Supabase full sync completed")
        } catch {
            syncError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Background Sync

    func performBackgroundSync() async throws {
        let since = lastSyncDate ?? Date.distantPast

        let profiles: [ProfileDTO] = try await supabase.fetchAll(table: "profiles")
        for profile in profiles {
            await mergeProfile(profile)
        }

        let games: [GameDTO] = try await supabase.fetchSince(table: "games", since: since)
        await mergeGames(games)

        let aliases: [PlayerAliasDTO] = try await supabase.fetchAll(table: "player_aliases")
        await mergeAliases(aliases)

        guard let userId = await supabase.currentUserId() else { return }
        let claims: [PlayerClaimDTO] = try await supabase.fetchByFilter(table: "player_claims") { query in
            query.or("claimant_id.eq.\(userId),host_id.eq.\(userId)")
        }
        await mergeClaims(claims)
    }

    // MARK: - Push Methods

    func pushGame(_ game: Game) async throws {
        let dto = game.toGameDTO()
        let _: GameDTO = try await supabase.upsert(table: "games", values: dto)
        debugLog("Pushed game \(game.gameId) to Supabase")
    }

    func pushGamePlayers(_ gamePlayers: [GameWithPlayer]) async throws {
        let dtos = gamePlayers.compactMap { $0.toGamePlayerDTO() }
        guard !dtos.isEmpty else { return }
        let _: [GamePlayerDTO] = try await supabase.batchUpsert(table: "game_players", values: dtos)
        debugLog("Pushed \(dtos.count) game players to Supabase")
    }

    func pushProfile(_ profile: PlayerProfile) async throws {
        let dto = profile.toProfileDTO()
        let _: ProfileDTO = try await supabase.upsert(table: "profiles", values: dto)
        debugLog("Pushed profile \(profile.profileId) to Supabase")
    }

    func pushAliases(_ aliases: [PlayerAlias]) async throws {
        let dtos = aliases.map { $0.toPlayerAliasDTO() }
        guard !dtos.isEmpty else { return }
        let _: [PlayerAliasDTO] = try await supabase.batchUpsert(table: "player_aliases", values: dtos)
        debugLog("Pushed \(dtos.count) aliases to Supabase")
    }

    func pushClaims(_ claims: [PlayerClaim]) async throws {
        let dtos = claims.map { $0.toPlayerClaimDTO() }
        guard !dtos.isEmpty else { return }
        let _: [PlayerClaimDTO] = try await supabase.batchUpsert(table: "player_claims", values: dtos)
        debugLog("Pushed \(dtos.count) claims to Supabase")
    }

    // MARK: - Pull Single Game (for DeepLink / lazy load)

    func pullGame(byId gameId: UUID) async throws -> GameDTO? {
        try await supabase.fetchById(table: "games", id: gameId)
    }

    func pullGamePlayers(forGameId gameId: UUID) async throws -> [GamePlayerDTO] {
        try await supabase.fetchByColumn(table: "game_players", column: "game_id", value: gameId)
    }

    func pullProfiles() async throws -> [ProfileDTO] {
        try await supabase.fetchByFilter(table: "profiles") { query in
            query.eq("is_public", value: true)
        }
    }

    // MARK: - Push Pending Data

    func pushPendingData() async throws {
        let pendingGameIds = pendingTracker.getPendingGames()
        let pendingAliasIds = pendingTracker.getPendingPlayerAliases()
        let pendingClaimIds = pendingTracker.getPendingPlayerClaims()

        for gameId in pendingGameIds {
            if let game = persistence.fetchGame(byId: gameId) {
                do {
                    try await pushGame(game)
                    pendingTracker.removePendingGame(gameId)
                } catch {
                    debugLog("Failed to push pending game \(gameId): \(error)")
                }
            }
        }

        for aliasId in pendingAliasIds {
            if let alias = persistence.fetchAlias(byId: aliasId) {
                do {
                    try await pushAliases([alias])
                    pendingTracker.removePendingPlayerAlias(aliasId)
                } catch {
                    debugLog("Failed to push pending alias \(aliasId): \(error)")
                }
            }
        }

        for claimId in pendingClaimIds {
            if let claim = persistence.fetchPlayerClaim(byId: claimId) {
                do {
                    try await pushClaims([claim])
                    pendingTracker.removePendingPlayerClaim(claimId)
                } catch {
                    debugLog("Failed to push pending claim \(claimId): \(error)")
                }
            }
        }

        debugLog("Push pending data completed")
    }

    // MARK: - SyncServiceProtocol conformance wrappers

    func quickSyncGame(_ game: Game) async {
        do { try await pushGame(game) }
        catch { debugLog("SupabaseSyncService: quickSyncGame failed: \(error)") }
    }

    func quickSyncGameWithPlayers(_ gwp: [GameWithPlayer]) async {
        do { try await pushGamePlayers(gwp) }
        catch { debugLog("SupabaseSyncService: quickSyncGameWithPlayers failed: \(error)") }
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        do { try await pushProfile(profile) }
        catch { debugLog("SupabaseSyncService: quickSyncPlayerProfile failed: \(error)") }
    }

    func syncPlayerClaims() async throws {
        let context = persistence.container.viewContext
        let request = PlayerClaim.fetchRequest()
        guard let claims = try? context.fetch(request) as? [PlayerClaim] else { return }
        try await pushClaims(claims)
    }

    func syncPlayerAliases() async throws {
        let context = persistence.container.viewContext
        let request = PlayerAlias.fetchRequest()
        guard let aliases = try? context.fetch(request) as? [PlayerAlias] else { return }
        try await pushAliases(aliases)
    }

    func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
        let players = try await pullGamePlayers(forGameId: gameId)
        await mergeGamePlayers(players, forGameId: gameId)
    }

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async throws {
        let profiles = try await pullProfiles()
        for p in profiles { await mergeProfile(p) }
    }

    func fetchGame(byId gameId: UUID) async throws -> Game? {
        guard let dto = try await pullGame(byId: gameId) else { return nil }
        await mergeGames([dto])
        return persistence.fetchGame(byId: gameId)
    }

    func cleanupInvalidClaims() async throws {
        debugLog("SupabaseSyncService: cleanup not needed (DB constraints handle this)")
    }

    // MARK: - Checksums (Smart Sync)

    private func checkServerChecksums() async throws -> Bool {
        guard let userId = await supabase.currentUserId() else { return false }

        struct Params: Codable, Sendable {
            let p_user_id: UUID
        }

        let serverChecksums: [GameChecksumDTO] = try await supabase.rpc(
            "get_game_checksums",
            params: Params(p_user_id: userId)
        )

        let localGames = persistence.fetchAllActiveGames()
        let localChecksumMap = Dictionary(uniqueKeysWithValues: localGames.compactMap { game -> (UUID, String)? in
            let gwpCount = (game.gameWithPlayers as? Set<GameWithPlayer>)?.count ?? 0
            let totalBuyins = (game.gameWithPlayers as? Set<GameWithPlayer>)?.reduce(0) { $0 + Int($1.buyin) } ?? 0
            let timestamp = game.timestamp.map { String($0.timeIntervalSince1970) } ?? ""
            let checksum = "\(game.gameId)_\(timestamp)_\(gwpCount)_\(totalBuyins)".md5Hash
            return (game.gameId, checksum)
        })

        let serverChecksumMap = Dictionary(uniqueKeysWithValues: serverChecksums.map { ($0.gameId, $0.checksum) })

        if localChecksumMap.count != serverChecksumMap.count { return true }

        for (gameId, localChecksum) in localChecksumMap {
            if serverChecksumMap[gameId] != localChecksum { return true }
        }

        return false
    }

    // MARK: - Merge Logic (Server Wins on pull — authoritative source)
    //
    // On pull, Supabase is the source of truth. We always overwrite local data
    // with server data. For push conflicts (offline queue replay), the server-side
    // function `upsert_with_conflict` compares `updated_at` timestamps.

    private func mergeProfile(_ dto: ProfileDTO) async {
        let context = persistence.container.viewContext
        if let existing = persistence.fetchPlayerProfile(byProfileId: dto.id) {
            existing.updateFromProfileDTO(dto)
        } else {
            _ = PlayerProfile.createFromProfileDTO(dto, context: context)
        }
        saveContextIfNeeded(context)
    }

    private func mergeGames(_ dtos: [GameDTO]) async {
        let context = persistence.container.viewContext
        for dto in dtos {
            if let existing = persistence.fetchGame(byId: dto.id) {
                existing.updateFromGameDTO(dto)
            } else {
                _ = Game.createFromGameDTO(dto, context: context)
            }
        }
        saveContextIfNeeded(context)
    }

    private func mergeGamePlayers(_ dtos: [GamePlayerDTO], forGameId gameId: UUID) async {
        let context = persistence.container.viewContext
        guard let game = persistence.fetchGame(byId: gameId) else { return }

        for dto in dtos {
            let profile = dto.profileId.flatMap { persistence.fetchPlayerProfile(byProfileId: $0) }
            _ = GameWithPlayer.createFromGamePlayerDTO(dto, game: game, profile: profile, context: context)
        }
        saveContextIfNeeded(context)
    }

    private func mergeAliases(_ dtos: [PlayerAliasDTO]) async {
        let context = persistence.container.viewContext
        for dto in dtos {
            if let existing = persistence.fetchAlias(byId: dto.id) {
                existing.updateFromPlayerAliasDTO(dto)
            } else if let profile = persistence.fetchPlayerProfile(byProfileId: dto.profileId) {
                _ = PlayerAlias.createFromPlayerAliasDTO(dto, profile: profile, context: context)
            }
        }
        saveContextIfNeeded(context)
    }

    private func mergeClaims(_ dtos: [PlayerClaimDTO]) async {
        let context = persistence.container.viewContext
        for dto in dtos {
            if let existing = persistence.fetchPlayerClaim(byId: dto.id) {
                existing.updateFromPlayerClaimDTO(dto)
            } else {
                _ = PlayerClaim.createFromPlayerClaimDTO(dto, context: context)
            }
        }
        saveContextIfNeeded(context)
    }

    // MARK: - Helpers

    func canSync() async -> Bool {
        await supabase.isAvailable()
    }

    private func saveContextIfNeeded(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            debugLog("Core Data save error: \(error)")
        }
    }

    private func pushAllChanges() async throws {
        guard let userId = await supabase.currentUserId() else { return }

        let profile = persistence.fetchPlayerProfile(byUserId: userId)
        if let profile {
            try await pushProfile(profile)
        }

        let games = persistence.fetchGames(createdBy: userId)
        for game in games where !game.softDeleted {
            try await pushGame(game)
            let gwps = (game.gameWithPlayers as? Set<GameWithPlayer>) ?? []
            if !gwps.isEmpty {
                try await pushGamePlayers(Array(gwps))
            }
        }

        if let profile {
            let aliases = (profile.aliases as? Set<PlayerAlias>) ?? []
            if !aliases.isEmpty {
                try await pushAliases(Array(aliases))
            }
        }
    }

    private func pullAllChanges() async throws {
        try await performFullSync()
    }
}

// MARK: - String MD5 helper

import CryptoKit

private extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

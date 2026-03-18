import Foundation
import Combine

/// Central sync coordinator — replaces SyncRouter.
/// Routes operations: Supabase (online/primary), CloudKit (offline fallback + secondary mirror).
/// On reconnect, replays OfflineSyncQueue and pulls fresh Supabase data.
@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    @Published var isSyncing = false
    @Published var isBackgroundSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published private(set) var isOnline: Bool = true

    let networkMonitor: NetworkMonitor
    private let supabaseSync: SupabaseSyncService
    private let cloudKitSync: CloudKitSyncService
    private let offlineQueue: OfflineSyncQueue

    private var cancellables = Set<AnyCancellable>()

    private init(
        networkMonitor: NetworkMonitor = .shared,
        supabaseSync: SupabaseSyncService = .shared,
        cloudKitSync: CloudKitSyncService = .shared,
        offlineQueue: OfflineSyncQueue = .shared
    ) {
        self.networkMonitor = networkMonitor
        self.supabaseSync = supabaseSync
        self.cloudKitSync = cloudKitSync
        self.offlineQueue = offlineQueue

        setupBindings()
        setupReconnectHandler()
    }

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

    // MARK: - Bindings (forward published state from active backend)

    private func setupBindings() {
        networkMonitor.$isOnline
            .receive(on: RunLoop.main)
            .assign(to: &$isOnline)

        supabaseSync.$isSyncing
            .combineLatest(cloudKitSync.$isSyncing)
            .map { $0 || $1 }
            .receive(on: RunLoop.main)
            .assign(to: &$isSyncing)

        supabaseSync.$isBackgroundSyncing
            .combineLatest(cloudKitSync.$isBackgroundSyncing)
            .map { $0 || $1 }
            .receive(on: RunLoop.main)
            .assign(to: &$isBackgroundSyncing)

        supabaseSync.$lastSyncDate
            .receive(on: RunLoop.main)
            .assign(to: &$lastSyncDate)

        supabaseSync.$syncError
            .receive(on: RunLoop.main)
            .assign(to: &$syncError)
    }

    private func setupReconnectHandler() {
        networkMonitor.onReconnect = { [weak self] in
            guard let self else { return }
            await self.handleReconnect()
        }
    }

    // MARK: - Reconnect

    private func handleReconnect() async {
        debugLog("SyncCoordinator: reconnected — processing offline queue + pull")
        do {
            await offlineQueue.processQueue()

            if offlineQueue.needsFullSync {
                debugLog("SyncCoordinator: full sync required after offline period")
                try await supabaseSync.performFullSync()
            } else {
                try await supabaseSync.performIncrementalSync()
            }
        } catch {
            debugLog("SyncCoordinator: reconnect sync error: \(error)")
        }
    }

    // MARK: - Full / Smart / Incremental Sync

    func sync() async throws {
        if isOnline {
            try await supabaseSync.sync()
            Task { try? await cloudKitSync.sync() }
        } else {
            try await cloudKitSync.sync()
            offlineQueue.enqueueFullSync()
        }
    }

    func smartSync() async throws {
        if isOnline {
            try await supabaseSync.smartSync()
            Task { try? await cloudKitSync.smartSync() }
        } else {
            try await cloudKitSync.smartSync()
            offlineQueue.enqueueFullSync()
        }
    }

    func performFullSync() async throws {
        if isOnline {
            try await supabaseSync.performFullSync()
            Task { try? await cloudKitSync.performFullSync() }
        } else {
            try await cloudKitSync.performFullSync()
            offlineQueue.enqueueFullSync()
        }
    }

    func performIncrementalSync() async throws {
        if isOnline {
            try await supabaseSync.performIncrementalSync()
            Task { try? await cloudKitSync.performIncrementalSync() }
        } else {
            try await cloudKitSync.performIncrementalSync()
        }
    }

    func pushPendingData() async throws {
        if isOnline {
            try await supabaseSync.pushPendingData()
        } else {
            try await cloudKitSync.pushPendingData()
        }
    }

    func canSync() async -> Bool {
        if isOnline {
            return await supabaseSync.canSync()
        } else {
            return await cloudKitSync.canSync()
        }
    }

    // MARK: - Quick Sync

    func quickSyncGame(_ game: Game) async {
        if isOnline {
            await supabaseSync.quickSyncGame(game)
            Task { await cloudKitSync.quickSyncGame(game) }
        } else {
            await cloudKitSync.quickSyncGame(game)
            offlineQueue.enqueue(table: "games", operation: .upsert, item: game.toGameDTO())
        }
    }

    func quickSyncGameWithPlayers(_ gwp: [GameWithPlayer]) async {
        if isOnline {
            await supabaseSync.quickSyncGameWithPlayers(gwp)
            Task { await cloudKitSync.quickSyncGameWithPlayers(gwp) }
        } else {
            await cloudKitSync.quickSyncGameWithPlayers(gwp)
            for player in gwp {
                if let dto = player.toGamePlayerDTO() {
                    offlineQueue.enqueue(table: "game_players", operation: .upsert, item: dto)
                }
            }
        }
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        if isOnline {
            await supabaseSync.quickSyncPlayerProfile(profile)
            Task { await cloudKitSync.quickSyncPlayerProfile(profile) }
        } else {
            await cloudKitSync.quickSyncPlayerProfile(profile)
            offlineQueue.enqueue(table: "profiles", operation: .upsert, item: profile.toProfileDTO())
        }
    }

    // MARK: - Entity Sync

    func syncPlayerClaims() async throws {
        if isOnline {
            try await supabaseSync.syncPlayerClaims()
            Task { try? await cloudKitSync.syncPlayerClaims() }
        } else {
            try await cloudKitSync.syncPlayerClaims()
        }
    }

    func syncPlayerAliases() async throws {
        if isOnline {
            try await supabaseSync.syncPlayerAliases()
            Task { try? await cloudKitSync.syncPlayerAliases() }
        } else {
            try await cloudKitSync.syncPlayerAliases()
        }
    }

    // MARK: - Fetch / Pull

    func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
        if isOnline {
            try await supabaseSync.fetchGameWithPlayers(forGameId: gameId)
        } else {
            try await cloudKitSync.fetchGameWithPlayers(forGameId: gameId)
        }
    }

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async throws {
        if isOnline {
            try await supabaseSync.fetchPlayerProfiles(notifyOnNewPublic: notifyOnNewPublic)
        } else {
            try await cloudKitSync.fetchPlayerProfiles(notifyOnNewPublic: notifyOnNewPublic)
        }
    }

    func fetchGame(byId gameId: UUID) async throws -> Game? {
        if isOnline {
            return try await supabaseSync.fetchGame(byId: gameId)
        } else {
            return try await cloudKitSync.fetchGame(byId: gameId)
        }
    }

    func cleanupInvalidClaims() async throws {
        if isOnline {
            try await supabaseSync.cleanupInvalidClaims()
        } else {
            try await cloudKitSync.cleanupInvalidClaims()
        }
    }
}

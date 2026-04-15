import Foundation
import Combine

/// Central sync coordinator — replaces SyncRouter.
/// **Supabase** — единственный серверный бэкенд. Офлайн: Core Data + `OfflineSyncQueue`, при reconnect — проигрывание очереди и pull с Supabase.
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
    private let offlineQueue: OfflineSyncQueue
    private let persistence: PersistenceController

    private var cancellables = Set<AnyCancellable>()

    private init(
        networkMonitor: NetworkMonitor = .shared,
        supabaseSync: SupabaseSyncService = .shared,
        offlineQueue: OfflineSyncQueue = .shared,
        persistence: PersistenceController = .shared
    ) {
        self.networkMonitor = networkMonitor
        self.supabaseSync = supabaseSync
        self.offlineQueue = offlineQueue
        self.persistence = persistence

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

    // MARK: - Bindings (forward published state from Supabase)

    private func setupBindings() {
        networkMonitor.$isOnline
            .receive(on: RunLoop.main)
            .assign(to: &$isOnline)

        supabaseSync.$isSyncing
            .receive(on: RunLoop.main)
            .assign(to: &$isSyncing)

        supabaseSync.$isBackgroundSyncing
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
        } else {
            offlineQueue.enqueueFullSync()
        }
    }

    func smartSync() async throws {
        if isOnline {
            try await supabaseSync.smartSync()
        } else {
            offlineQueue.enqueueFullSync()
        }
    }

    func performFullSync() async throws {
        if isOnline {
            try await supabaseSync.performFullSync()
        } else {
            offlineQueue.enqueueFullSync()
        }
    }

    func performIncrementalSync() async throws {
        if isOnline {
            try await supabaseSync.performIncrementalSync()
        } else {
            debugLog("SyncCoordinator: offline — пропуск incremental (данные из Core Data)")
        }
    }

    func pushPendingData() async throws {
        if isOnline {
            try await supabaseSync.pushPendingData()
        } else {
            debugLog("SyncCoordinator: offline — pushPendingData пропущен (сервер недоступен)")
        }
    }

    func canSync() async -> Bool {
        if isOnline {
            return await supabaseSync.canSync()
        }
        return true
    }

    // MARK: - Quick Sync

    func quickSyncGame(_ game: Game) async {
        if isOnline {
            await supabaseSync.quickSyncGame(game)
        } else {
            offlineQueue.enqueue(table: "games", operation: .upsert, item: game.toGameDTO())
        }
    }

    func quickSyncGameWithPlayers(_ gwp: [GameWithPlayer]) async {
        if isOnline {
            await supabaseSync.quickSyncGameWithPlayers(gwp)
        } else {
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
        } else {
            offlineQueue.enqueue(table: "profiles", operation: .upsert, item: profile.toProfileDTO())
        }
    }

    // MARK: - Entity Sync

    func syncPlayerClaims() async throws {
        if isOnline {
            try await supabaseSync.syncPlayerClaims()
        } else {
            debugLog("SyncCoordinator: offline — syncPlayerClaims отложен до сети")
        }
    }

    func syncPlayerAliases() async throws {
        if isOnline {
            try await supabaseSync.syncPlayerAliases()
        } else {
            debugLog("SyncCoordinator: offline — syncPlayerAliases отложен до сети")
        }
    }

    // MARK: - Fetch / Pull

    func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
        if isOnline {
            try await supabaseSync.fetchGameWithPlayers(forGameId: gameId)
        } else {
            debugLog("SyncCoordinator: offline — fetchGameWithPlayers без сети (кэш Core Data)")
        }
    }

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async throws {
        if isOnline {
            try await supabaseSync.fetchPlayerProfiles(notifyOnNewPublic: notifyOnNewPublic)
        } else {
            debugLog("SyncCoordinator: offline — fetchPlayerProfiles без сети (кэш Core Data)")
        }
    }

    func fetchGame(byId gameId: UUID) async throws -> Game? {
        if isOnline {
            return try await supabaseSync.fetchGame(byId: gameId)
        }
        return persistence.fetchGame(byId: gameId)
    }

    func cleanupInvalidClaims() async throws {
        try await supabaseSync.cleanupInvalidClaims()
    }
}

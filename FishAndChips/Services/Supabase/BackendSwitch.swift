import Foundation

/// Feature flag для переключения между CloudKit и Supabase
/// Позволяет постепенную миграцию без одновременного изменения всех Views
enum BackendSwitch {
    enum Backend: String {
        case cloudKit
        case supabase
    }

    private static let key = "activeBackend"

    /// Текущий активный бэкенд
    static var active: Backend {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let backend = Backend(rawValue: raw) else {
                return .cloudKit
            }
            return backend
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var isSupabase: Bool { active == .supabase }
    static var isCloudKit: Bool { active == .cloudKit }

    /// Переключить на Supabase
    static func switchToSupabase() {
        active = .supabase
        debugLog("Backend switched to Supabase")
    }

    /// Переключить обратно на CloudKit
    static func switchToCloudKit() {
        active = .cloudKit
        debugLog("Backend switched to CloudKit")
    }
}

// MARK: - Sync Service Router

/// Единая точка доступа к sync-сервису
/// Views и другие сервисы вызывают SyncRouter вместо конкретного сервиса
@MainActor
final class SyncRouter: ObservableObject {
    static let shared = SyncRouter()

    @Published var isSyncing = false
    @Published var isBackgroundSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let cloudKitSync = CloudKitSyncService.shared
    private let supabaseSync = SupabaseSyncService.shared

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        if BackendSwitch.isSupabase {
            bindToSupabase()
        } else {
            bindToCloudKit()
        }
    }

    private func bindToCloudKit() {
        cloudKitSync.$isSyncing.assign(to: &$isSyncing)
        cloudKitSync.$isBackgroundSyncing.assign(to: &$isBackgroundSyncing)
        cloudKitSync.$lastSyncDate.assign(to: &$lastSyncDate)
        cloudKitSync.$syncError.assign(to: &$syncError)
    }

    private func bindToSupabase() {
        supabaseSync.$isSyncing.assign(to: &$isSyncing)
        supabaseSync.$isBackgroundSyncing.assign(to: &$isBackgroundSyncing)
        supabaseSync.$lastSyncDate.assign(to: &$lastSyncDate)
        supabaseSync.$syncError.assign(to: &$syncError)
    }

    // MARK: - Sync Methods (delegate to active backend)

    func sync() async throws {
        if BackendSwitch.isSupabase {
            try await supabaseSync.sync()
        } else {
            try await cloudKitSync.sync()
        }
    }

    func smartSync() async throws {
        if BackendSwitch.isSupabase {
            try await supabaseSync.smartSync()
        } else {
            try await cloudKitSync.smartSync()
        }
    }

    func performFullSync() async throws {
        if BackendSwitch.isSupabase {
            try await supabaseSync.performFullSync()
        } else {
            try await cloudKitSync.performFullSync()
        }
    }

    func performIncrementalSync() async throws {
        if BackendSwitch.isSupabase {
            try await supabaseSync.performIncrementalSync()
        } else {
            try await cloudKitSync.performIncrementalSync()
        }
    }

    func pushPendingData() async throws {
        if BackendSwitch.isSupabase {
            try await supabaseSync.pushPendingData()
        } else {
            try await cloudKitSync.pushPendingData()
        }
    }

    func canSync() async -> Bool {
        if BackendSwitch.isSupabase {
            return await supabaseSync.canSync()
        } else {
            return await cloudKitSync.canSync()
        }
    }

    // MARK: - Quick Push Methods

    func quickSyncGame(_ game: Game) async {
        if BackendSwitch.isSupabase {
            do { try await supabaseSync.pushGame(game) }
            catch { debugLog("SyncRouter: pushGame failed: \(error)") }
        } else {
            await cloudKitSync.quickSyncGame(game)
        }
    }

    func quickSyncGameWithPlayers(_ players: [GameWithPlayer]) async {
        if BackendSwitch.isSupabase {
            do { try await supabaseSync.pushGamePlayers(players) }
            catch { debugLog("SyncRouter: pushGamePlayers failed: \(error)") }
        } else {
            await cloudKitSync.quickSyncGameWithPlayers(players)
        }
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        if BackendSwitch.isSupabase {
            do { try await supabaseSync.pushProfile(profile) }
            catch { debugLog("SyncRouter: pushProfile failed: \(error)") }
        } else {
            await cloudKitSync.quickSyncPlayerProfile(profile)
        }
    }

    func syncPlayerClaims() async {
        if BackendSwitch.isSupabase {
            let context = PersistenceController.shared.container.viewContext
            let request = PlayerClaim.fetchRequest()
            guard let claims = try? context.fetch(request) as? [PlayerClaim] else { return }
            do { try await supabaseSync.pushClaims(claims) }
            catch { debugLog("SyncRouter: pushClaims failed: \(error)") }
        } else {
            try? await cloudKitSync.syncPlayerClaims()
        }
    }

    func syncPlayerAliases() async {
        if BackendSwitch.isSupabase {
            let context = PersistenceController.shared.container.viewContext
            let request = PlayerAlias.fetchRequest()
            guard let aliases = try? context.fetch(request) as? [PlayerAlias] else { return }
            do { try await supabaseSync.pushAliases(aliases) }
            catch { debugLog("SyncRouter: pushAliases failed: \(error)") }
        } else {
            try? await cloudKitSync.syncPlayerAliases()
        }
    }

    func fetchGameWithPlayers(forGameId gameId: UUID) async {
        if BackendSwitch.isSupabase {
            do {
                let players = try await supabaseSync.pullGamePlayers(forGameId: gameId)
                // Merge into Core Data handled by SyncService
            } catch {
                debugLog("SyncRouter: fetchGameWithPlayers failed: \(error)")
            }
        } else {
            try? await cloudKitSync.fetchGameWithPlayers(forGameId: gameId)
        }
    }

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async {
        if BackendSwitch.isSupabase {
            do {
                let _ = try await supabaseSync.pullProfiles()
            } catch {
                debugLog("SyncRouter: fetchPlayerProfiles failed: \(error)")
            }
        } else {
            try? await cloudKitSync.fetchPlayerProfiles(notifyOnNewPublic: notifyOnNewPublic)
        }
    }

    func fetchGame(byId gameId: UUID) async throws {
        if BackendSwitch.isSupabase {
            let _ = try await supabaseSync.pullGame(byId: gameId)
        } else {
            try await cloudKitSync.fetchGame(byId: gameId)
        }
    }

    func cleanupInvalidClaims() async {
        if BackendSwitch.isSupabase {
            debugLog("SyncRouter: cleanup not needed with Supabase (DB constraints handle this)")
        } else {
            try? await cloudKitSync.cleanupInvalidClaims()
        }
    }
}

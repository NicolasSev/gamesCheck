import Foundation
import Combine

/// Legacy feature flag (AccountDeletion и тесты). **Синк данных** — только `SyncCoordinator` → Supabase.
enum BackendSwitch {
    enum Backend: String {
        case cloudKit
        case supabase
    }

    private static let key = "activeBackend"

    static var active: Backend {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let backend = Backend(rawValue: raw) else {
                return .supabase
            }
            return backend
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var isSupabase: Bool { active == .supabase }
    static var isCloudKit: Bool { active == .cloudKit }

    /// Супер-админ: при `false` не показывать опциональный админ-UI (RLS 026 «видеть всё» на сервере не отключается).
    private static let adminViewEnabledKey = "adminViewEnabled"
    static var adminViewEnabled: Bool {
        get { UserDefaults.standard.object(forKey: adminViewEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: adminViewEnabledKey) }
    }

    static func switchToSupabase() {
        active = .supabase
        debugLog("Backend switched to Supabase")
    }

    /// Оставлено для совместимости тестов; маршрутизация синка CloudKit удалена.
    static func switchToCloudKit() {
        active = .cloudKit
        debugLog("Backend flag set to cloudKit (sync still uses Supabase via SyncCoordinator)")
    }
}

// MARK: - SyncRouter (legacy, только Supabase)

/// Раньше переключал CloudKit/Supabase. Сейчас всегда делегирует в `SupabaseSyncService`.
@MainActor
final class SyncRouter: ObservableObject {
    static let shared = SyncRouter()

    @Published var isSyncing = false
    @Published var isBackgroundSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let supabaseSync = SupabaseSyncService.shared

    private init() {
        supabaseSync.$isSyncing.assign(to: &$isSyncing)
        supabaseSync.$isBackgroundSyncing.assign(to: &$isBackgroundSyncing)
        supabaseSync.$lastSyncDate.assign(to: &$lastSyncDate)
        supabaseSync.$syncError.assign(to: &$syncError)
    }

    func sync() async throws {
        try await supabaseSync.sync()
    }

    func smartSync() async throws {
        try await supabaseSync.smartSync()
    }

    func performFullSync() async throws {
        try await supabaseSync.performFullSync()
    }

    func performIncrementalSync() async throws {
        try await supabaseSync.performIncrementalSync()
    }

    func pushPendingData() async throws {
        try await supabaseSync.pushPendingData()
    }

    func canSync() async -> Bool {
        await supabaseSync.canSync()
    }

    func quickSyncGame(_ game: Game) async {
        do { try await supabaseSync.pushGame(game) }
        catch { debugLog("SyncRouter: pushGame failed: \(error)") }
    }

    func quickSyncGameWithPlayers(_ players: [GameWithPlayer]) async {
        do { try await supabaseSync.pushGamePlayers(players) }
        catch { debugLog("SyncRouter: pushGamePlayers failed: \(error)") }
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        do { try await supabaseSync.pushProfile(profile) }
        catch { debugLog("SyncRouter: pushProfile failed: \(error)") }
    }

    func syncPlayerClaims() async {
        let context = PersistenceController.shared.container.viewContext
        let request = PlayerClaim.fetchRequest()
        guard let claims = try? context.fetch(request) as? [PlayerClaim] else { return }
        do { try await supabaseSync.pushClaims(claims) }
        catch { debugLog("SyncRouter: pushClaims failed: \(error)") }
    }

    func syncPlayerAliases() async {
        let context = PersistenceController.shared.container.viewContext
        let request = PlayerAlias.fetchRequest()
        guard let aliases = try? context.fetch(request) as? [PlayerAlias] else { return }
        do { try await supabaseSync.pushAliases(aliases) }
        catch { debugLog("SyncRouter: pushAliases failed: \(error)") }
    }

    func fetchGameWithPlayers(forGameId gameId: UUID) async {
        do {
            _ = try await supabaseSync.pullGamePlayers(forGameId: gameId)
        } catch {
            debugLog("SyncRouter: fetchGameWithPlayers failed: \(error)")
        }
    }

    func fetchPlayerProfiles(notifyOnNewPublic: Bool = false) async {
        do {
            _ = try await supabaseSync.pullProfiles()
        } catch {
            debugLog("SyncRouter: fetchPlayerProfiles failed: \(error)")
        }
    }

    func fetchGame(byId gameId: UUID) async throws {
        _ = try await supabaseSync.pullGame(byId: gameId)
    }

    func cleanupInvalidClaims() async {
        debugLog("SyncRouter: cleanup not needed with Supabase (DB constraints handle this)")
    }
}

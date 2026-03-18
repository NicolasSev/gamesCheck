import Foundation

/// Абстракция над бэкендом (CloudKit / Supabase)
/// Позволяет переключаться между бэкендами без изменения верхних слоёв
protocol BackendServiceProtocol: AnyObject, Sendable {

    // MARK: - Availability

    func isAvailable() async -> Bool

    // MARK: - CRUD

    func save<T: Codable & Sendable>(table: String, values: T) async throws -> T
    func upsert<T: Codable & Sendable>(table: String, values: T) async throws -> T
    func fetch<T: Codable & Sendable>(table: String, filter: [String: String]) async throws -> [T]
    func fetchOne<T: Codable & Sendable>(table: String, id: UUID) async throws -> T?
    func update<T: Codable & Sendable>(table: String, id: UUID, values: T) async throws -> T
    func delete(table: String, id: UUID) async throws

    // MARK: - Batch

    func batchUpsert<T: Codable & Sendable>(table: String, values: [T]) async throws -> [T]
}

/// Абстракция над авторизацией (backend-level: Supabase Auth / CloudKit)
protocol AuthServiceProtocol: AnyObject, Sendable {
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func getCurrentUser() async -> AuthUser?
    func resetPassword(email: String) async throws
}

/// Auth protocol used by AuthViewModel — both CloudKit and Supabase auth paths conform to this
protocol AuthSyncProtocol: AnyObject {
    func signUp(email: String, password: String, username: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async
    func fetchUser(byEmail email: String) async throws -> User?
}

/// Общая модель авторизованного пользователя (не привязана к конкретному бэкенду)
struct AuthUser: Sendable {
    let id: UUID
    let email: String?
    let createdAt: Date
}

/// Unified sync protocol — CloudKitSyncService and SupabaseSyncService both conform.
/// SyncCoordinator routes calls based on network state.
@MainActor
protocol SyncServiceProtocol: ObservableObject {
    var isSyncing: Bool { get }
    var isBackgroundSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var syncError: String? { get }

    // Full / smart / incremental
    func sync() async throws
    func smartSync() async throws
    func performFullSync() async throws
    func performIncrementalSync() async throws
    func pushPendingData() async throws
    func canSync() async -> Bool

    // Quick sync (single entity push)
    func quickSyncGame(_ game: Game) async
    func quickSyncGameWithPlayers(_ gwp: [GameWithPlayer]) async
    func quickSyncPlayerProfile(_ profile: PlayerProfile) async

    // Entity sync
    func syncPlayerClaims() async throws
    func syncPlayerAliases() async throws

    // Fetch / pull
    func fetchGameWithPlayers(forGameId gameId: UUID) async throws
    func fetchPlayerProfiles(notifyOnNewPublic: Bool) async throws
    func fetchGame(byId gameId: UUID) async throws -> Game?
    func cleanupInvalidClaims() async throws
}

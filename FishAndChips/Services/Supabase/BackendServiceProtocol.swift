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

/// Абстракция над авторизацией
protocol AuthServiceProtocol: AnyObject, Sendable {
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func getCurrentUser() async -> AuthUser?
    func resetPassword(email: String) async throws
}

/// Общая модель авторизованного пользователя (не привязана к конкретному бэкенду)
struct AuthUser: Sendable {
    let id: UUID
    let email: String?
    let createdAt: Date
}

/// Абстракция над синхронизацией
protocol SyncServiceProtocol: AnyObject {
    var isSyncing: Bool { get }
    var isBackgroundSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var syncError: String? { get }

    func sync() async throws
    func smartSync() async throws
    func performFullSync() async throws
    func performIncrementalSync() async throws
    func pushPendingData() async throws
    func canSync() async -> Bool
}

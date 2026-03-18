import Foundation
import Supabase
import Auth

/// Сервис авторизации через Supabase Auth
/// Заменяет самописную SHA256-авторизацию + CloudKit-хранилище User
final class SupabaseAuthService: @unchecked Sendable {
    static let shared = SupabaseAuthService()

    private let client: SupabaseClient

    private init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    // MARK: - For testing
    init(testClient: SupabaseClient) {
        self.client = testClient
    }

    // MARK: - Sign Up

    /// Регистрация нового пользователя
    /// - Supabase Auth создаёт запись в auth.users
    /// - Триггер handle_new_user() создаёт запись в profiles
    /// - Возвращает AuthUser с id и email
    func signUp(email: String, password: String, username: String, displayName: String? = nil) async throws -> AuthUser {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "username": .string(username),
                "display_name": .string(displayName ?? username)
            ]
        )

        let user = response.user

        return AuthUser(
            id: user.id,
            email: user.email,
            createdAt: user.createdAt
        )
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )

        return AuthUser(
            id: session.user.id,
            email: session.user.email,
            createdAt: session.user.createdAt
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Current Session

    func getCurrentUser() async -> AuthUser? {
        guard let session = try? await client.auth.session else {
            return nil
        }
        return AuthUser(
            id: session.user.id,
            email: session.user.email,
            createdAt: session.user.createdAt
        )
    }

    func getCurrentUserId() async -> UUID? {
        try? await client.auth.session.user.id
    }

    func isAuthenticated() async -> Bool {
        await getCurrentUser() != nil
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    // MARK: - Update Password

    func updatePassword(newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    // MARK: - Update User Metadata

    func updateUsername(_ username: String) async throws {
        try await client.auth.update(user: UserAttributes(
            data: ["username": .string(username)]
        ))
    }

    // MARK: - Delete Account

    /// Удаление аккаунта — cascade удалит все данные через FK + ON DELETE CASCADE
    func deleteAccount() async throws {
        guard let userId = await getCurrentUserId() else {
            throw SupabaseServiceError.notAuthenticated
        }
        try await client.auth.admin.deleteUser(id: userId.uuidString)
    }

    // MARK: - Auth State Listener

    /// Подписка на изменения состояния авторизации
    func onAuthStateChange() -> AsyncStream<(AuthChangeEvent, Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in self.client.auth.authStateChanges {
                    continuation.yield((event, session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Legacy Migration Support

    /// Миграция пользователя из старой системы (SHA256) в Supabase Auth
    /// При первом входе: проверяем старый хеш, создаём аккаунт в Supabase
    func migrateFromLegacy(
        email: String,
        password: String,
        username: String,
        legacyUserId: UUID
    ) async throws -> AuthUser {
        let authUser = try await signUp(
            email: email,
            password: password,
            username: username
        )

        try await SupabaseService.shared.update(
            table: "profiles",
            id: authUser.id,
            values: ProfileDTO(
                id: authUser.id,
                username: username,
                displayName: username,
                isAnonymous: false,
                isPublic: false,
                isSuperAdmin: false,
                subscriptionStatus: "free",
                subscriptionExpiresAt: nil,
                totalGamesPlayed: 0,
                totalBuyins: 0,
                totalCashouts: 0,
                createdAt: Date(),
                lastLoginAt: Date(),
                updatedAt: nil
            )
        )

        return authUser
    }
}

// MARK: - AuthCloudKitSyncProtocol conformance (для обратной совместимости)

extension SupabaseAuthService: AuthCloudKitSyncProtocol {
    func fetchUser(byEmail email: String) async throws -> User? {
        nil
    }

    func quickSyncUser(_ user: User) async {
        // no-op — Supabase Auth управляет пользователями
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        do {
            let dto = profile.toProfileDTO()
            let _: ProfileDTO = try await SupabaseService.shared.upsert(table: "profiles", values: dto)
        } catch {
            debugLog("Failed to sync profile to Supabase: \(error)")
        }
    }
}

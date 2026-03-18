import Foundation
@testable import FishAndChips

/// Mock для SupabaseAuthService — симулирует signUp/signIn/signOut без сети
final class MockSupabaseAuth: AuthCloudKitSyncProtocol {
    var registeredUsers: [String: (id: UUID, password: String)] = [:]
    var currentUser: AuthUser?
    var shouldThrowError: Error?

    // MARK: - Tracking

    var signUpCalls: [(email: String, username: String)] = []
    var signInCalls: [String] = []
    var signOutCalls = 0

    func reset() {
        registeredUsers.removeAll()
        currentUser = nil
        shouldThrowError = nil
        signUpCalls.removeAll()
        signInCalls.removeAll()
        signOutCalls = 0
    }

    // MARK: - Auth Operations

    func signUp(email: String, password: String, username: String) throws -> AuthUser {
        if let error = shouldThrowError { throw error }
        if registeredUsers[email] != nil {
            throw SupabaseServiceError.conflict(message: "User already exists")
        }
        let userId = UUID()
        registeredUsers[email] = (id: userId, password: password)
        let user = AuthUser(id: userId, email: email, createdAt: Date())
        currentUser = user
        signUpCalls.append((email: email, username: username))
        return user
    }

    func signIn(email: String, password: String) throws -> AuthUser {
        if let error = shouldThrowError { throw error }
        guard let registered = registeredUsers[email], registered.password == password else {
            throw SupabaseServiceError.notAuthenticated
        }
        let user = AuthUser(id: registered.id, email: email, createdAt: Date())
        currentUser = user
        signInCalls.append(email)
        return user
    }

    func signOut() {
        currentUser = nil
        signOutCalls += 1
    }

    // MARK: - AuthCloudKitSyncProtocol

    func fetchUser(byEmail email: String) async throws -> User? {
        nil
    }

    func quickSyncUser(_ user: User) async {
        // no-op
    }

    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        // no-op
    }
}

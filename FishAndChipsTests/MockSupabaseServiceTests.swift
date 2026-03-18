import Foundation
import Testing
@testable import FishAndChips

struct MockSupabaseServiceTests {

    @Test func mockService_upsertAndFetch() async throws {
        let mock = MockSupabaseService()

        let profileId = UUID()
        let profile = ProfileDTO(
            id: profileId, username: "mock", displayName: "Mock User",
            isAnonymous: false, isPublic: true, isSuperAdmin: false,
            subscriptionStatus: "free", subscriptionExpiresAt: nil,
            totalGamesPlayed: 0, totalBuyins: 0, totalCashouts: 0,
            createdAt: Date(), lastLoginAt: nil, updatedAt: nil
        )

        let _ = try mock.upsertProfile(profile)
        let fetched = try mock.fetchProfile(byId: profileId)

        #expect(fetched != nil)
        #expect(fetched?.username == "mock")
        #expect(mock.upsertCalls.count == 1)
        #expect(mock.fetchCalls.count == 1)
    }

    @Test func mockService_gamesCRUD() async throws {
        let mock = MockSupabaseService()
        let creatorId = UUID()

        let game1 = GameDTO(
            id: UUID(), gameType: "Poker", creatorId: creatorId,
            isPublic: false, softDeleted: false, notes: nil,
            timestamp: Date(), createdAt: nil, updatedAt: nil
        )
        let game2 = GameDTO(
            id: UUID(), gameType: "Billiard", creatorId: creatorId,
            isPublic: true, softDeleted: false, notes: "Test",
            timestamp: Date(), createdAt: nil, updatedAt: nil
        )

        let _ = try mock.upsertGame(game1)
        let _ = try mock.upsertGame(game2)

        let games = try mock.fetchGames(creatorId: creatorId)
        #expect(games.count == 2)

        try mock.deleteGame(id: game1.id)
        let remaining = try mock.fetchGames(creatorId: creatorId)
        #expect(remaining.count == 1)
        #expect(remaining.first?.gameType == "Billiard")
    }

    @Test func mockService_errorThrows() async throws {
        let mock = MockSupabaseService()
        mock.shouldThrowError = .notAuthenticated

        #expect(throws: SupabaseServiceError.self) {
            let _ = try mock.fetchProfile(byId: UUID())
        }
    }

    @Test func mockAuth_signUpAndSignIn() async throws {
        let mock = MockSupabaseAuth()

        let user = try mock.signUp(email: "test@test.com", password: "pass123", username: "tester")
        #expect(user.email == "test@test.com")
        #expect(mock.signUpCalls.count == 1)

        mock.signOut()
        #expect(mock.currentUser == nil)
        #expect(mock.signOutCalls == 1)

        let signedIn = try mock.signIn(email: "test@test.com", password: "pass123")
        #expect(signedIn.id == user.id)
        #expect(mock.signInCalls.count == 1)
    }

    @Test func mockAuth_signInWrongPassword() async throws {
        let mock = MockSupabaseAuth()
        let _ = try mock.signUp(email: "test@test.com", password: "correct", username: "tester")

        #expect(throws: SupabaseServiceError.self) {
            let _ = try mock.signIn(email: "test@test.com", password: "wrong")
        }
    }

    @Test func mockAuth_duplicateSignUp() async throws {
        let mock = MockSupabaseAuth()
        let _ = try mock.signUp(email: "dup@test.com", password: "pass123", username: "dup1")

        #expect(throws: SupabaseServiceError.self) {
            let _ = try mock.signUp(email: "dup@test.com", password: "pass456", username: "dup2")
        }
    }

    @Test func mockService_pendingClaims() async throws {
        let mock = MockSupabaseService()
        let hostId = UUID()
        let claimantId = UUID()

        let pendingClaim = PlayerClaimDTO(
            id: UUID(), playerName: "Test", gameId: UUID(), gamePlayerId: nil,
            claimantId: claimantId, hostId: hostId, status: "pending",
            resolvedAt: nil, resolvedById: nil, notes: nil, createdAt: Date()
        )
        let resolvedClaim = PlayerClaimDTO(
            id: UUID(), playerName: "Resolved", gameId: UUID(), gamePlayerId: nil,
            claimantId: claimantId, hostId: hostId, status: "approved",
            resolvedAt: Date(), resolvedById: hostId, notes: nil, createdAt: Date()
        )

        let _ = try mock.upsertClaims([pendingClaim, resolvedClaim])
        let pending = try mock.fetchPendingClaims(hostId: hostId)

        #expect(pending.count == 1)
        #expect(pending.first?.playerName == "Test")
    }
}

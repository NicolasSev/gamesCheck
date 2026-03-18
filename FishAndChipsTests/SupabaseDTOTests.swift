import Foundation
import Testing
@testable import FishAndChips

@MainActor
struct SupabaseDTOTests {

    // MARK: - User -> ProfileDTO

    @Test func userToProfileDTO_mapsAllFields() async throws {
        let persistence = PersistenceController(inMemory: true)
        let user = persistence.createUser(username: "dtotest", passwordHash: "hash")!
        user.email = "dto@test.com"
        user.isSuperAdmin = true
        user.subscriptionStatus = "premium"

        let profile = persistence.createPlayerProfile(displayName: "DTO Test", userId: user.userId)
        profile.isPublic = true
        profile.totalGamesPlayed = 5
        profile.totalBuyins = NSDecimalNumber(value: 1000)
        profile.totalCashouts = NSDecimalNumber(value: 1500)
        try persistence.container.viewContext.save()

        let dto = user.toProfileDTO()

        #expect(dto.id == user.userId)
        #expect(dto.username == "dtotest")
        #expect(dto.displayName == "DTO Test")
        #expect(dto.isSuperAdmin == true)
        #expect(dto.subscriptionStatus == "premium")
        #expect(dto.isPublic == true)
        #expect(dto.totalGamesPlayed == 5)
        #expect(dto.totalBuyins == 1000)
        #expect(dto.totalCashouts == 1500)
        #expect(dto.balance == 500)
    }

    // MARK: - Game -> GameDTO

    @Test func gameToGameDTO_roundTrip() async throws {
        let persistence = PersistenceController(inMemory: true)
        let user = persistence.createUser(username: "gameDto", passwordHash: "hash")!
        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        game.isPublic = true
        game.notes = "Test notes"
        game.timestamp = Date(timeIntervalSince1970: 1000000)
        try persistence.container.viewContext.save()

        let dto = game.toGameDTO()

        #expect(dto.id == game.gameId)
        #expect(dto.gameType == "Poker")
        #expect(dto.creatorId == user.userId)
        #expect(dto.isPublic == true)
        #expect(dto.softDeleted == false)
        #expect(dto.notes == "Test notes")
        #expect(dto.timestamp == Date(timeIntervalSince1970: 1000000))
    }

    @Test func gameDTO_createFromDTO() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let gameId = UUID()
        let creatorId = UUID()

        let dto = GameDTO(
            id: gameId,
            gameType: "Billiard",
            creatorId: creatorId,
            isPublic: false,
            softDeleted: false,
            notes: "Created from DTO",
            timestamp: Date(),
            createdAt: nil,
            updatedAt: nil
        )

        let game = Game.createFromGameDTO(dto, context: context)
        try context.save()

        #expect(game.gameId == gameId)
        #expect(game.gameType == "Billiard")
        #expect(game.creatorUserId == creatorId)
        #expect(game.notes == "Created from DTO")
    }

    // MARK: - PlayerAlias -> PlayerAliasDTO

    @Test func playerAliasDTO_roundTrip() async throws {
        let persistence = PersistenceController(inMemory: true)
        let user = persistence.createUser(username: "aliasDto", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Alias Test", userId: user.userId)
        let alias = persistence.createAlias(aliasName: "Ace", forProfile: profile)!
        alias.gamesCount = 10
        try persistence.container.viewContext.save()

        let dto = alias.toPlayerAliasDTO()

        #expect(dto.id == alias.aliasId)
        #expect(dto.profileId == profile.profileId)
        #expect(dto.aliasName == "Ace")
        #expect(dto.gamesCount == 10)
    }

    // MARK: - PlayerClaim -> PlayerClaimDTO

    @Test func playerClaimDTO_statusHelpers() async throws {
        let pending = PlayerClaimDTO(
            id: UUID(), playerName: "Test", gameId: UUID(), gamePlayerId: nil,
            claimantId: UUID(), hostId: UUID(), status: "pending",
            resolvedAt: nil, resolvedById: nil, notes: nil, createdAt: Date()
        )
        #expect(pending.isPending == true)
        #expect(pending.isApproved == false)
        #expect(pending.isRejected == false)

        let approved = PlayerClaimDTO(
            id: UUID(), playerName: "Test", gameId: UUID(), gamePlayerId: nil,
            claimantId: UUID(), hostId: UUID(), status: "approved",
            resolvedAt: Date(), resolvedById: UUID(), notes: nil, createdAt: Date()
        )
        #expect(approved.isPending == false)
        #expect(approved.isApproved == true)
    }

    // MARK: - GamePlayerDTO

    @Test func gamePlayerDTO_profitCalculation() async throws {
        let dto = GamePlayerDTO(
            id: UUID(), gameId: UUID(), profileId: nil,
            playerName: "Test", buyin: 100, cashout: 250, createdAt: nil
        )
        #expect(dto.profit == 150)

        let losing = GamePlayerDTO(
            id: UUID(), gameId: UUID(), profileId: nil,
            playerName: "Loser", buyin: 200, cashout: 50, createdAt: nil
        )
        #expect(losing.profit == -150)
    }

    // MARK: - ProfileDTO

    @Test func profileDTO_balanceCalculation() async throws {
        let dto = ProfileDTO(
            id: UUID(), username: "test", displayName: "Test",
            isAnonymous: false, isPublic: true, isSuperAdmin: false,
            subscriptionStatus: "free", subscriptionExpiresAt: nil,
            totalGamesPlayed: 10, totalBuyins: 5000, totalCashouts: 7500,
            createdAt: Date(), lastLoginAt: nil, updatedAt: nil
        )
        #expect(dto.balance == 2500)
    }
}

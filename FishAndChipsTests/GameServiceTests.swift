//
//  GameServiceTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.6: GameService tests
//

import Foundation
import Testing
@testable import FishAndChips

@MainActor
struct GameServiceTests {
    @Test func getGamesCreatedByUser_returnsOnlyCreatorsGames() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "testuser", passwordHash: "hash")!
        _ = persistence.createPlayerProfile(displayName: "Test User", userId: user.userId)

        let game1 = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        let game2 = persistence.createGame(gameType: "Покер", creatorUserId: user.userId)

        let other = persistence.createUser(username: "other", passwordHash: "hash")!
        _ = persistence.createPlayerProfile(displayName: "Other", userId: other.userId)
        let game3 = persistence.createGame(gameType: "Poker", creatorUserId: other.userId)

        let games = service.getGamesCreatedByUser(user.userId)
        #expect(games.contains(game1) == true)
        #expect(games.contains(game2) == true)
        #expect(games.contains(game3) == false)
    }

    @Test func getUserStatistics_calculatesTotals() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "stats", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Stats", userId: user.userId)

        // Формула: profit = cashout - (buyin * 2000). buyin=1 → 2000 тенге, cashout=2050 → profit=50
        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        try addParticipation(persistence: persistence, game: game, profile: profile, buyin: 1, cashout: 2050)

        let stats = service.getUserStatistics(user.userId)
        #expect(stats.totalBuyins == 1)
        #expect(stats.totalCashouts == 2050)
        #expect(stats.currentBalance == 50)
        #expect(stats.winRate == 1.0)
        #expect(stats.totalSessions == 1)
    }

    @Test func gameTypeStatistics_groupsByType() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "types", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Types", userId: user.userId)

        // profit = cashout - (buyin * 2000)
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 2050)  // +50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 1980)   // -20
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 2020) // +20

        let stats = service.getGameTypeStatistics(user.userId)
        let poker = stats.first { $0.gameType == "Poker" }

        #expect(poker != nil)
        #expect(poker?.gamesCount == 3)
        #expect(poker?.totalProfit == 50) // 50 - 20 + 20
        #expect(poker?.winRate == 2.0 / 3.0)
    }

    @Test func gameFiltering_profitableAndLosing() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "filter", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Filter", userId: user.userId)

        // profit = cashout - (buyin * 2000)
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 2050)  // +50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 1950)   // -50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 1, cashout: 2020) // +20

        let profitable = service.getGames(filter: .profitable, forUser: user.userId)
        let losing = service.getGames(filter: .losing, forUser: user.userId)

        #expect(profitable.count == 2)
        #expect(losing.count == 1)

        let pokerGames = service.getGames(filter: .byType("Poker"), forUser: user.userId)
        #expect(pokerGames.count == 3)
    }

    // MARK: - Helpers
    private func createGameWithProfit(
        persistence: PersistenceController,
        user: User,
        profile: PlayerProfile,
        type: String,
        buyin: Int16,
        cashout: Int64
    ) throws {
        let game = persistence.createGame(gameType: type, creatorUserId: user.userId)
        try addParticipation(persistence: persistence, game: game, profile: profile, buyin: buyin, cashout: cashout)
    }

    private func addParticipation(
        persistence: PersistenceController,
        game: Game,
        profile: PlayerProfile,
        buyin: Int16,
        cashout: Int64
    ) throws {
        let context = persistence.container.viewContext
        let participation = GameWithPlayer(context: context)
        participation.game = game
        participation.playerProfile = profile
        participation.buyin = buyin
        participation.cashout = cashout
        try context.save()
    }
}


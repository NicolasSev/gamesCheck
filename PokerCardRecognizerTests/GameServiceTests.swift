//
//  GameServiceTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.6: GameService tests
//

import Foundation
import Testing
@testable import PokerCardRecognizer

struct GameServiceTests {
    @Test func getGamesCreatedByUser_returnsOnlyCreatorsGames() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "testuser", passwordHash: "hash")!
        _ = persistence.createPlayerProfile(displayName: "Test User", userId: user.userId)

        let game1 = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        let game2 = persistence.createGame(gameType: "Billiard", creatorUserId: user.userId)

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

        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        try addParticipation(persistence: persistence, game: game, profile: profile, buyin: 100, cashout: 150)

        let stats = service.getUserStatistics(user.userId)
        #expect(stats.totalBuyins == 100)
        #expect(stats.totalCashouts == 150)
        #expect(stats.currentBalance == 50)
        #expect(stats.winRate == 1.0)
        #expect(stats.totalSessions == 1)
    }

    @Test func gameTypeStatistics_groupsByType() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "types", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Types", userId: user.userId)

        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 100, cashout: 150) // +50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 100, cashout: 80)  // -20
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Billiard", buyin: 50, cashout: 70) // +20

        let stats = service.getGameTypeStatistics(user.userId)
        let poker = stats.first { $0.gameType == "Poker" }

        #expect(poker != nil)
        #expect(poker?.gamesCount == 2)
        #expect(poker?.totalProfit == 30) // 50 - 20
        #expect(poker?.winRate == 0.5)
    }

    @Test func gameFiltering_profitableAndLosing() async throws {
        let persistence = PersistenceController(inMemory: true)
        let service = GameService(persistence: persistence)

        let user = persistence.createUser(username: "filter", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Filter", userId: user.userId)

        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 100, cashout: 150) // +50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Poker", buyin: 100, cashout: 50)  // -50
        try createGameWithProfit(persistence: persistence, user: user, profile: profile, type: "Billiard", buyin: 50, cashout: 70) // +20

        let profitable = service.getGames(filter: .profitable, forUser: user.userId)
        let losing = service.getGames(filter: .losing, forUser: user.userId)

        #expect(profitable.count == 2)
        #expect(losing.count == 1)

        let pokerGames = service.getGames(filter: .byType("Poker"), forUser: user.userId)
        #expect(pokerGames.count == 2)
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


//
//  GameModelTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.2: Game model extension tests
//

import Foundation
import Testing
@testable import FishAndChips

struct GameModelTests {
    @Test func createGame_withCreator_setsRelationship() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(username: "testuser", passwordHash: "hash")!
        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)

        #expect(game.gameId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(game.creatorUserId == user.userId)
        #expect(game.creator?.userId == user.userId)
        #expect(game.isDeleted == false)
    }

    @Test func createGame_withoutCreator_allowsLegacy() async throws {
        let persistence = PersistenceController(inMemory: true)

        let game = persistence.createGame(gameType: "Billiard", creatorUserId: nil)

        #expect(game.creatorUserId == nil)
        #expect(game.creator == nil)
    }

    @Test func fetchGamesCreatedByUser_excludesSoftDeleted() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(username: "creator", passwordHash: "hash")!
        let game1 = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)
        let game2 = persistence.createGame(gameType: "Billiard", creatorUserId: user.userId)

        // soft delete one
        persistence.softDeleteGame(game2)

        let games = persistence.fetchGames(createdBy: user.userId)
        #expect(games.contains(game1) == true)
        #expect(games.contains(game2) == false)
    }

    @Test func updateGameNotes_setsNotes() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(username: "notes", passwordHash: "hash")!
        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)

        let notes = "Great session! Had AA vs KK"
        persistence.updateGameNotes(game, notes: notes)

        #expect(game.notes == notes)
    }

    @Test func migrateExistingGames_assignsGameIdIfZero() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext

        // Создать "старую" игру с нулевым gameId
        let legacy = Game(context: context)
        legacy.timestamp = Date()
        legacy.gameType = "Poker"
        legacy.gameId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        legacy.isDeleted = false
        try context.save()

        persistence.migrateExistingGames()

        #expect(legacy.gameId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
}


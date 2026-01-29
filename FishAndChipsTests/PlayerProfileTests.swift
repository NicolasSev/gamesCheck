//
//  PlayerProfileTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.3: PlayerProfile tests
//

import Foundation
import Testing
@testable import FishAndChips

struct PlayerProfileTests {
    @Test func createAnonymousProfile_setsDefaults() async throws {
        let persistence = PersistenceController(inMemory: true)

        let profile = persistence.createPlayerProfile(displayName: "Антон")

        #expect(profile.profileId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(profile.displayName == "Антон")
        #expect(profile.isAnonymous == true)
        #expect(profile.userId == nil)
        #expect(profile.totalGamesPlayed == 0)
    }

    @Test func createLinkedProfile_setsUserRelationship() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(username: "testuser", passwordHash: "hash")!
        let profile = persistence.createPlayerProfile(displayName: "Test User", userId: user.userId)

        #expect(profile.isAnonymous == false)
        #expect(profile.userId == user.userId)
        #expect(profile.user?.userId == user.userId)
        #expect(user.playerProfile == profile)
    }

    @Test func linkAnonymousProfileToUser_updatesFlags() async throws {
        let persistence = PersistenceController(inMemory: true)

        let profile = persistence.createPlayerProfile(displayName: "Mysterious Player")
        #expect(profile.isAnonymous == true)

        let user = persistence.createUser(username: "revealed", passwordHash: "hash")!
        persistence.linkProfileToUser(profile: profile, userId: user.userId)

        #expect(profile.isAnonymous == false)
        #expect(profile.userId == user.userId)
        #expect(profile.user?.userId == user.userId)
    }

    @Test func addGameStatistics_updatesCachedTotals() async throws {
        let persistence = PersistenceController(inMemory: true)

        let profile = persistence.createPlayerProfile(displayName: "Stats Test")

        profile.addGameStatistics(buyin: 100, cashout: 150)
        profile.addGameStatistics(buyin: 200, cashout: 180)

        #expect(profile.totalGamesPlayed == 2)
        #expect(profile.totalBuyins as Decimal == 300)
        #expect(profile.totalCashouts as Decimal == 330)
        #expect(profile.balance == 30)
        #expect(profile.averageProfit == 15)
    }

    @Test func fetchAnonymousProfiles_filtersLinkedOnes() async throws {
        let persistence = PersistenceController(inMemory: true)

        let anonymous = persistence.createPlayerProfile(displayName: "Anonymous")

        let user = persistence.createUser(username: "linked", passwordHash: "hash")!
        let linked = persistence.createPlayerProfile(displayName: "Linked", userId: user.userId)

        let anonymousProfiles = persistence.fetchAnonymousProfiles()

        #expect(anonymousProfiles.contains(anonymous) == true)
        #expect(anonymousProfiles.contains(linked) == false)
    }
}


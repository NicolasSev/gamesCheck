//
//  PlayerAliasTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.4: PlayerAlias + fuzzy matching tests
//

import Foundation
import Testing
@testable import FishAndChips

struct PlayerAliasTests {
    @Test func createAlias_setsFieldsAndLinksProfile() async throws {
        let persistence = PersistenceController(inMemory: true)
        let profile = persistence.createPlayerProfile(displayName: "Test Player")

        let alias = persistence.createAlias(aliasName: "Антон", forProfile: profile)

        #expect(alias != nil)
        #expect(alias?.aliasName == "Антон")
        #expect(alias?.profileId == profile.profileId)
        #expect(alias?.gamesCount == 0)
        #expect(alias?.profile.profileId == profile.profileId)
    }

    @Test func createAlias_rejectsDuplicates_caseInsensitive() async throws {
        let persistence = PersistenceController(inMemory: true)
        let profile = persistence.createPlayerProfile(displayName: "P1")
        let _ = persistence.createAlias(aliasName: "Duplicate", forProfile: profile)

        let otherProfile = persistence.createPlayerProfile(displayName: "P2")
        let duplicate = persistence.createAlias(aliasName: "duplicate", forProfile: otherProfile)

        #expect(duplicate == nil)
    }

    @Test func fetchAliases_forProfile_returnsAll() async throws {
        let persistence = PersistenceController(inMemory: true)
        let profile = persistence.createPlayerProfile(displayName: "Test Player")

        _ = persistence.createAlias(aliasName: "Anton", forProfile: profile)
        _ = persistence.createAlias(aliasName: "Антон", forProfile: profile)
        _ = persistence.createAlias(aliasName: "Tosha", forProfile: profile)

        let aliases = persistence.fetchAliases(forProfile: profile)
        #expect(aliases.count == 3)
    }

    @Test func stringSimilarity_basicCases() async throws {
        #expect("Anton".similarity(to: "Anton") == 1.0)
        #expect("Anton".similarity(to: "Антон") > 0.0)
        #expect("Anton".similarity(to: "Antony") > 0.8)
    }

    @Test func findSimilarNames_filtersByThreshold() async throws {
        let names = ["Anton", "Антон", "Antony", "John", "Антоха"]
        let similar = "Anton".findSimilar(in: names, threshold: 0.6)

        #expect(similar.contains("Anton") == true)
        #expect(similar.contains("Antony") == true)
        #expect(similar.contains("John") == false)
    }

    @Test func suggestSimilarNames_prefersExactAndPrefix() async throws {
        let allNames = ["Anton", "Антон", "ANTON", "Antony", "John"]
        let suggestions = PlayerNameMatcher.suggestSimilarNames(for: "anton", from: allNames)

        #expect(suggestions.contains("Anton") == true)
        #expect(suggestions.contains("ANTON") == true)
        // fuzzy может вернуть и "Антон" (зависит от метрики), но точные совпадения обязаны быть
    }
}


//
//  PendingSyncTrackerTests.swift
//  FishAndChipsTests
//
//  Unit tests for PendingSyncTracker
//

import Foundation
import Testing
@testable import FishAndChips

@Suite(.serialized)
struct PendingSyncTrackerTests {

    private var tracker: PendingSyncTracker { PendingSyncTracker.shared }

    // MARK: - 1. addPendingGame / removePendingGame / getPendingGames

    @Test func addPendingGame_removePendingGame_getPendingGames() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let gameId = UUID()
        #expect(tracker.getPendingGames().isEmpty == true)

        tracker.addPendingGame(gameId)
        #expect(tracker.getPendingGames().contains(gameId) == true)
        #expect(tracker.getPendingGames().count == 1)

        tracker.removePendingGame(gameId)
        #expect(tracker.getPendingGames().isEmpty == true)
    }

    @Test func addPendingGame_multipleGames() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let id1 = UUID()
        let id2 = UUID()
        tracker.addPendingGame(id1)
        tracker.addPendingGame(id2)

        let pending = tracker.getPendingGames()
        #expect(pending.count == 2)
        #expect(pending.contains(id1) == true)
        #expect(pending.contains(id2) == true)

        tracker.removePendingGame(id1)
        #expect(tracker.getPendingGames().contains(id2) == true)
        #expect(tracker.getPendingGames().contains(id1) == false)
    }

    // MARK: - 2. addPendingGameWithPlayer / removePendingGameWithPlayer / getPendingGameWithPlayers

    @Test func addPendingGameWithPlayer_removePendingGameWithPlayer_getPendingGameWithPlayers() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let gwpId = UUID()
        #expect(tracker.getPendingGameWithPlayers().isEmpty == true)

        tracker.addPendingGameWithPlayer(gwpId)
        #expect(tracker.getPendingGameWithPlayers().contains(gwpId) == true)
        #expect(tracker.getPendingGameWithPlayers().count == 1)

        tracker.removePendingGameWithPlayer(gwpId)
        #expect(tracker.getPendingGameWithPlayers().isEmpty == true)
    }

    @Test func addPendingGameWithPlayer_multiple() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let id1 = UUID()
        let id2 = UUID()
        tracker.addPendingGameWithPlayer(id1)
        tracker.addPendingGameWithPlayer(id2)

        let pending = tracker.getPendingGameWithPlayers()
        #expect(pending.count == 2)
        #expect(pending.contains(id1) == true)
        #expect(pending.contains(id2) == true)

        tracker.removePendingGameWithPlayer(id1)
        #expect(tracker.getPendingGameWithPlayers().contains(id2) == true)
    }

    // MARK: - 3. addPendingPlayerAlias / removePendingPlayerAlias / getPendingPlayerAliases

    @Test func addPendingPlayerAlias_removePendingPlayerAlias_getPendingPlayerAliases() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let aliasId = UUID()
        #expect(tracker.getPendingPlayerAliases().isEmpty == true)

        tracker.addPendingPlayerAlias(aliasId)
        #expect(tracker.getPendingPlayerAliases().contains(aliasId) == true)
        #expect(tracker.getPendingPlayerAliases().count == 1)

        tracker.removePendingPlayerAlias(aliasId)
        #expect(tracker.getPendingPlayerAliases().isEmpty == true)
    }

    @Test func addPendingPlayerAlias_multiple() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let id1 = UUID()
        let id2 = UUID()
        tracker.addPendingPlayerAlias(id1)
        tracker.addPendingPlayerAlias(id2)

        let pending = tracker.getPendingPlayerAliases()
        #expect(pending.count == 2)
        #expect(pending.contains(id1) == true)
        #expect(pending.contains(id2) == true)

        tracker.removePendingPlayerAlias(id1)
        #expect(tracker.getPendingPlayerAliases().contains(id2) == true)
    }

    // MARK: - 4. addPendingPlayerClaim / removePendingPlayerClaim / getPendingPlayerClaims

    @Test func addPendingPlayerClaim_removePendingPlayerClaim_getPendingPlayerClaims() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let claimId = UUID()
        #expect(tracker.getPendingPlayerClaims().isEmpty == true)

        tracker.addPendingPlayerClaim(claimId)
        #expect(tracker.getPendingPlayerClaims().contains(claimId) == true)
        #expect(tracker.getPendingPlayerClaims().count == 1)

        tracker.removePendingPlayerClaim(claimId)
        #expect(tracker.getPendingPlayerClaims().isEmpty == true)
    }

    @Test func addPendingPlayerClaim_multiple() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let id1 = UUID()
        let id2 = UUID()
        tracker.addPendingPlayerClaim(id1)
        tracker.addPendingPlayerClaim(id2)

        let pending = tracker.getPendingPlayerClaims()
        #expect(pending.count == 2)
        #expect(pending.contains(id1) == true)
        #expect(pending.contains(id2) == true)

        tracker.removePendingPlayerClaim(id1)
        #expect(tracker.getPendingPlayerClaims().contains(id2) == true)
    }

    // MARK: - 5. hasPendingData

    @Test func hasPendingData_returnsFalseWhenEmpty() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        #expect(tracker.hasPendingData() == false)
    }

    @Test func hasPendingData_returnsTrueWhenGamesExist() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingGame(UUID())
        #expect(tracker.hasPendingData() == true)
    }

    @Test func hasPendingData_returnsTrueWhenGameWithPlayersExist() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingGameWithPlayer(UUID())
        #expect(tracker.hasPendingData() == true)
    }

    @Test func hasPendingData_returnsTrueWhenAliasesExist() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingPlayerAlias(UUID())
        #expect(tracker.hasPendingData() == true)
    }

    @Test func hasPendingData_returnsTrueWhenClaimsExist() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingPlayerClaim(UUID())
        #expect(tracker.hasPendingData() == true)
    }

    // MARK: - 6. getPendingSummary

    @Test func getPendingSummary_returnsEmptyWhenNoData() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let summary = tracker.getPendingSummary()
        #expect(summary == "Нет незалитых данных")
    }

    @Test func getPendingSummary_returnsNonEmptyWhenDataExists() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingGame(UUID())
        let summary = tracker.getPendingSummary()
        #expect(summary.isEmpty == false)
        #expect(summary.contains("Игры") == true)
    }

    @Test func getPendingSummary_includesAllCategories() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingGame(UUID())
        tracker.addPendingGameWithPlayer(UUID())
        tracker.addPendingPlayerAlias(UUID())
        tracker.addPendingPlayerClaim(UUID())

        let summary = tracker.getPendingSummary()
        #expect(summary.contains("Игры") == true)
        #expect(summary.contains("Игроки") == true)
        #expect(summary.contains("Алиасы") == true)
        #expect(summary.contains("Заявки") == true)
    }

    // MARK: - 7. clearAll

    @Test func clearAll_removesAllPendingData() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        tracker.addPendingGame(UUID())
        tracker.addPendingGameWithPlayer(UUID())
        tracker.addPendingPlayerAlias(UUID())
        tracker.addPendingPlayerClaim(UUID())

        #expect(tracker.hasPendingData() == true)

        tracker.clearAll()

        #expect(tracker.getPendingGames().isEmpty == true)
        #expect(tracker.getPendingGameWithPlayers().isEmpty == true)
        #expect(tracker.getPendingPlayerAliases().isEmpty == true)
        #expect(tracker.getPendingPlayerClaims().isEmpty == true)
        #expect(tracker.hasPendingData() == false)
        #expect(tracker.getPendingSummary() == "Нет незалитых данных")
    }

    @Test func removeNonExistent_doesNotCrash() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let randomId = UUID()
        tracker.removePendingGame(randomId)
        tracker.removePendingGameWithPlayer(randomId)
        tracker.removePendingPlayerAlias(randomId)
        tracker.removePendingPlayerClaim(randomId)

        #expect(tracker.hasPendingData() == false)
    }

    @Test func addDuplicate_preservesSingleEntry() {
        tracker.clearAll()
        defer { tracker.clearAll() }

        let id = UUID()
        tracker.addPendingGame(id)
        tracker.addPendingGame(id)

        #expect(tracker.getPendingGames().count == 1)
        #expect(tracker.getPendingGames().contains(id) == true)
    }
}

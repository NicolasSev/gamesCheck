//
//  PlayerClaimServiceTests.swift
//

import XCTest
import CoreData
@testable import FishAndChips

final class PlayerClaimServiceTests: XCTestCase {
    var persistence: PersistenceController!
    var context: NSManagedObjectContext!
    var hostUser: User!
    var claimantUser: User!
    var testGame: Game!
    var testPlayer: Player!
    var gwp: GameWithPlayer!

    override func setUp() async throws {
        try await super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext

        claimantUser = persistence.createUser(
            username: "claimant",
            passwordHash: "h1",
            email: "c@example.com"
        )
        hostUser = persistence.createUser(username: "host", passwordHash: "h2", email: "h@example.com")

        testGame = persistence.createGame(
            gameType: "Poker",
            creatorUserId: hostUser.userId,
            timestamp: Date()
        )

        testPlayer = Player(context: context)
        testPlayer.name = "Seat1"

        gwp = GameWithPlayer(context: context)
        gwp.buyin = 100
        gwp.cashout = 150
        gwp.game = testGame
        gwp.player = testPlayer

        try context.save()
    }

    override func tearDown() async throws {
        gwp = nil
        testPlayer = nil
        testGame = nil
        hostUser = nil
        claimantUser = nil
        context = nil
        persistence = nil
        try await super.tearDown()
    }

    private func insertPendingClaim() throws -> PlayerClaim {
        guard let pc = persistence.createPlayerClaim(gameWithPlayer: gwp, claimantUserId: claimantUser.userId) else {
            XCTFail("createPlayerClaim failed")
            preconditionFailure()
        }
        try context.save()
        return pc
    }

    func testApproveClaim_success() async throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(
            persistence: persistence,
            hostResolveRpc: { cid, action, _ in
                XCTAssertEqual(cid, claim.claimId)
                XCTAssertEqual(action, "approve")
                self.context.performAndWait {
                    claim.status = "approved"
                    claim.resolvedAt = Date()
                    claim.resolvedByUserId = self.hostUser.userId
                }
                return [HostResolveResult(status: "approved", blockReason: nil, conflictProfileIds: nil)]
            },
            afterClaimMutationSync: {}
        )

        try await sut.approveClaim(claimId: claim.claimId, resolverUserId: hostUser.userId, notes: "ok")
        XCTAssertEqual(claim.status, "approved")
    }

    func testApproveClaim_blocked() async throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(
            persistence: persistence,
            hostResolveRpc: { _, _, _ in
                [HostResolveResult(status: "blocked", blockReason: "conflict", conflictProfileIds: [UUID()])]
            },
            afterClaimMutationSync: {}
        )

        do {
            try await sut.approveClaim(claimId: claim.claimId, resolverUserId: hostUser.userId, notes: nil)
            XCTFail("expected blocked")
        } catch let e as ClaimError {
            if case let .claimBlocked(reason) = e {
                XCTAssertEqual(reason, "conflict")
            } else {
                XCTFail("\(e)")
            }
        }
    }

    func testApproveClaim_blocked_serverConflictReason() async throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(
            persistence: persistence,
            hostResolveRpc: { _, _, _ in
                [
                    HostResolveResult(
                        status: "blocked",
                        blockReason: "conflict_with_existing_profiles",
                        conflictProfileIds: [UUID()],
                    ),
                ]
            },
            afterClaimMutationSync: {}
        )

        do {
            try await sut.approveClaim(claimId: claim.claimId, resolverUserId: hostUser.userId, notes: nil)
            XCTFail("expected blocked")
        } catch let e as ClaimError {
            if case let .claimBlocked(reason) = e {
                XCTAssertEqual(reason, "conflict_with_existing_profiles")
            } else {
                XCTFail("\(e)")
            }
        }
    }

    func testApproveClaim_unauthorized() async throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(
            persistence: persistence,
            hostResolveRpc: { _, _, _ in
                XCTFail("RPC must not run")
                preconditionFailure()
            },
            afterClaimMutationSync: {}
        )

        do {
            try await sut.approveClaim(claimId: claim.claimId, resolverUserId: claimantUser.userId, notes: nil)
            XCTFail("expected unauthorized")
        } catch let e as ClaimError {
            XCTAssertEqual(e, ClaimError.unauthorized)
        }
    }

    func testApprove_claimAlreadyResolved() async throws {
        let claim = try insertPendingClaim()
        claim.status = "approved"
        try context.save()

        let sut = PlayerClaimService(persistence: persistence)

        do {
            try await sut.approveClaim(claimId: claim.claimId, resolverUserId: hostUser.userId, notes: nil)
            XCTFail("expected claimAlreadyResolved")
        } catch let e as ClaimError {
            XCTAssertEqual(e, ClaimError.claimAlreadyResolved)
        }
    }

    func testReject_success() async throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(
            persistence: persistence,
            hostResolveRpc: { cid, action, _ in
                XCTAssertEqual(cid, claim.claimId)
                XCTAssertEqual(action, "reject")
                self.context.performAndWait {
                    claim.status = "rejected"
                    claim.resolvedAt = Date()
                    claim.resolvedByUserId = self.hostUser.userId
                }
                return [HostResolveResult(status: "rejected", blockReason: nil, conflictProfileIds: nil)]
            },
            afterClaimMutationSync: {}
        )

        try await sut.rejectClaim(claimId: claim.claimId, resolverUserId: hostUser.userId, notes: nil)
        XCTAssertEqual(claim.status, "rejected")
    }

    func testGetClaimById() throws {
        let claim = try insertPendingClaim()
        let sut = PlayerClaimService(persistence: persistence)
        XCTAssertEqual(sut.getClaim(byId: claim.claimId)?.claimId, claim.claimId)
    }
}

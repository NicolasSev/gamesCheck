//
//  PlayerClaimServiceTests.swift
//  PokerCardRecognizerTests
//
//  Created for Phase 5: Testing & Quality Assurance
//

import XCTest
import CoreData
@testable import FishAndChips

@MainActor
final class PlayerClaimServiceTests: XCTestCase {
    var sut: PlayerClaimService!
    var persistence: PersistenceController!
    var context: NSManagedObjectContext!
    
    // Test data
    var testUser: User!
    var hostUser: User!
    var testGame: Game!
    var testPlayer: Player!
    var testGameWithPlayer: GameWithPlayer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use in-memory persistence for testing
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        sut = PlayerClaimService(persistence: persistence)
        
        // Create test data
        try await createTestData()
    }
    
    override func tearDown() async throws {
        testGameWithPlayer = nil
        testPlayer = nil
        testGame = nil
        testUser = nil
        hostUser = nil
        sut = nil
        context = nil
        persistence = nil
        try await super.tearDown()
    }
    
    private func createTestData() async throws {
        // Create claimant user
        testUser = persistence.createUser(
            username: "testuser",
            passwordHash: "hash123",
            email: "test@example.com"
        )
        
        // Create host user
        hostUser = persistence.createUser(
            username: "hostuser",
            passwordHash: "hash456",
            email: "host@example.com"
        )
        
        // Create game
        testGame = persistence.createGame(
            gameType: "Poker",
            creatorUserId: hostUser.userId,
            timestamp: Date()
        )
        
        // Create player
        testPlayer = Player(context: context)
        testPlayer.name = "TestPlayer"
        
        // Create GameWithPlayer
        testGameWithPlayer = GameWithPlayer(context: context)
        testGameWithPlayer.buyin = 100
        testGameWithPlayer.cashout = 150
        testGameWithPlayer.game = testGame
        testGameWithPlayer.player = testPlayer
        
        try context.save()
    }
    
    // MARK: - Submit Claim Tests
    
    func testSubmitClaim_Success() throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        XCTAssertNotNil(claim)
        XCTAssertEqual(claim.playerName, "TestPlayer")
        XCTAssertEqual(claim.claimantUserId, testUser.userId)
        XCTAssertEqual(claim.hostUserId, hostUser.userId)
        XCTAssertEqual(claim.status, "pending")
        XCTAssertTrue(claim.isPending)
    }
    
    func testSubmitClaim_CannotClaimOwnGame() {
        XCTAssertThrowsError(
            try sut.submitClaim(
                gameWithPlayer: testGameWithPlayer,
                claimantUserId: hostUser.userId
            )
        ) { error in
            XCTAssertEqual(error as? ClaimError, ClaimError.cannotClaimOwnGame)
        }
    }
    
    func testSubmitClaim_DuplicateClaim() throws {
        // Submit first claim
        _ = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        // Try to submit duplicate
        XCTAssertThrowsError(
            try sut.submitClaim(
                gameWithPlayer: testGameWithPlayer,
                claimantUserId: testUser.userId
            )
        ) { error in
            XCTAssertEqual(error as? ClaimError, ClaimError.claimAlreadyExists)
        }
    }
    
    // MARK: - Get Claims Tests
    
    func testGetMyClaims() throws {
        _ = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        let claims = sut.getMyClaims(userId: testUser.userId)
        
        XCTAssertEqual(claims.count, 1)
        XCTAssertEqual(claims.first?.playerName, "TestPlayer")
    }
    
    func testGetPendingClaimsForHost() throws {
        _ = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        let claims = sut.getPendingClaimsForHost(hostUserId: hostUser.userId)
        
        XCTAssertEqual(claims.count, 1)
        XCTAssertEqual(claims.first?.status, "pending")
    }
    
    func testGetClaimById() throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        let fetchedClaim = sut.getClaim(byId: claim.claimId)
        
        XCTAssertNotNil(fetchedClaim)
        XCTAssertEqual(fetchedClaim?.claimId, claim.claimId)
    }
    
    // MARK: - Approve Claim Tests
    
    func testApproveClaim_Success() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        try await sut.approveClaim(
            claimId: claim.claimId,
            resolverUserId: hostUser.userId,
            notes: "Approved"
        )
        
        let updatedClaim = sut.getClaim(byId: claim.claimId)
        XCTAssertEqual(updatedClaim?.status, "approved")
        XCTAssertNotNil(updatedClaim?.resolvedAt)
        XCTAssertEqual(updatedClaim?.resolvedByUserId, hostUser.userId)
        XCTAssertEqual(updatedClaim?.notes, "Approved")
    }
    
    func testApproveClaim_Unauthorized() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        do {
            try await sut.approveClaim(
                claimId: claim.claimId,
                resolverUserId: testUser.userId // Not the host
            )
            XCTFail("Should throw unauthorized")
        } catch let error as ClaimError {
            XCTAssertEqual(error, ClaimError.unauthorized)
        }
    }
    
    func testApproveClaim_AlreadyResolved() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        try await sut.approveClaim(
            claimId: claim.claimId,
            resolverUserId: hostUser.userId
        )
        
        do {
            try await sut.approveClaim(
                claimId: claim.claimId,
                resolverUserId: hostUser.userId
            )
            XCTFail("Should throw claimAlreadyResolved")
        } catch let error as ClaimError {
            XCTAssertEqual(error, ClaimError.claimAlreadyResolved)
        }
    }
    
    // MARK: - Reject Claim Tests
    
    func testRejectClaim_Success() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        try await sut.rejectClaim(
            claimId: claim.claimId,
            resolverUserId: hostUser.userId,
            notes: "Not valid"
        )
        
        let updatedClaim = sut.getClaim(byId: claim.claimId)
        XCTAssertEqual(updatedClaim?.status, "rejected")
        XCTAssertNotNil(updatedClaim?.resolvedAt)
        XCTAssertEqual(updatedClaim?.notes, "Not valid")
    }
    
    func testRejectClaim_Unauthorized() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        do {
            try await sut.rejectClaim(
                claimId: claim.claimId,
                resolverUserId: testUser.userId // Not the host
            )
            XCTFail("Should throw unauthorized")
        } catch let error as ClaimError {
            XCTAssertEqual(error, ClaimError.unauthorized)
        }
    }
    
    // MARK: - PlayerProfile Integration Tests
    
    func testApproveClaim_CreatesPlayerProfile() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        try await sut.approveClaim(
            claimId: claim.claimId,
            resolverUserId: hostUser.userId
        )
        
        // Check that PlayerProfile was created or updated
        let profile = persistence.fetchPlayerProfile(byUserId: testUser.userId)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.userId, testUser.userId)
        XCTAssertEqual(profile?.displayName, testUser.username)
    }
    
    func testApproveClaim_LinksGameWithPlayerToProfile() async throws {
        let claim = try sut.submitClaim(
            gameWithPlayer: testGameWithPlayer,
            claimantUserId: testUser.userId
        )
        
        try await sut.approveClaim(
            claimId: claim.claimId,
            resolverUserId: hostUser.userId
        )
        
        // Check that GameWithPlayer is linked to PlayerProfile
        XCTAssertNotNil(testGameWithPlayer.playerProfile)
        XCTAssertEqual(testGameWithPlayer.playerProfile?.userId, testUser.userId)
    }
}

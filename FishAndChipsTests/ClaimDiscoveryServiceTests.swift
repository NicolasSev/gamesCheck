//
//  ClaimDiscoveryServiceTests.swift
//

import XCTest
@testable import FishAndChips

@MainActor
final class ClaimDiscoveryServiceTests: XCTestCase {
    func testRefresh_decodesAllStatusesFromRpc() async throws {
        let host = UUID()
        let free = ClaimableRow(
            hostId: host,
            hostUsername: "Host",
            placeId: nil,
            placeName: "Без места",
            playerName: "A",
            playerKey: "a",
            totalGames: 1,
            totalBalance: 0,
            lastGameAt: nil,
            status: "free",
            takenByUsername: nil,
            claimId: nil,
            blockReason: nil,
        )
        let pending = ClaimableRow(
            hostId: host,
            hostUsername: "Host",
            placeId: nil,
            placeName: "Без места",
            playerName: "B",
            playerKey: "b",
            totalGames: 2,
            totalBalance: 0,
            lastGameAt: nil,
            status: "my_pending",
            takenByUsername: nil,
            claimId: nil,
            blockReason: nil,
        )
        let blocked = ClaimableRow(
            hostId: host,
            hostUsername: "Host",
            placeId: nil,
            placeName: "Без места",
            playerName: "C",
            playerKey: "c",
            totalGames: 3,
            totalBalance: 0,
            lastGameAt: nil,
            status: "blocked",
            takenByUsername: nil,
            claimId: nil,
            blockReason: "x",
        )
        let expected = [free, pending, blocked]

        let uid = UUID()
        let sut = ClaimDiscoveryService { _ in expected }

        await sut.refresh(userId: uid)
        XCTAssertEqual(sut.rows.count, 3)
        XCTAssertEqual(sut.rows.map(\.status), ["free", "my_pending", "blocked"])
        XCTAssertNil(sut.lastError)
        XCTAssertFalse(sut.isLoading)
    }

    func testRefresh_recordsError() async {
        let uid = UUID()
        struct Dummy: Error {}

        let sut = ClaimDiscoveryService { _ in
            throw Dummy()
        }

        await sut.refresh(userId: uid)
        XCTAssertTrue(sut.rows.isEmpty)
        XCTAssertNotNil(sut.lastError)
    }
}

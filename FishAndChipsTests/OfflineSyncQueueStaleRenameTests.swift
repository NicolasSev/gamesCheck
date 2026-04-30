import Foundation
import Testing
@testable import FishAndChips

/// Phase 13 (bulk-claim): после admin merge офлайн-очередь сбрасывает pending upsert `game_players` (MVP).
@MainActor
struct OfflineSyncQueueStaleRenameTests {

    @Test func discardPendingGamePlayerUpserts_removes_only_game_players_upserts() async throws {
        let queue = OfflineSyncQueue.shared
        queue.clearAll()
        defer { queue.clearAll() }

        let gDto = GamePlayerDTO(
            id: UUID(),
            gameId: UUID(),
            profileId: nil,
            playerName: "Test",
            buyin: 0,
            cashout: 0,
            createdAt: nil
        )
        queue.enqueue(table: "game_players", operation: .upsert, item: gDto)

        let pId = UUID()
        let profileDto = ProfileDTO(
            id: pId,
            username: "u",
            displayName: "U",
            isAnonymous: false,
            isPublic: false,
            isSuperAdmin: false,
            subscriptionStatus: "free",
            subscriptionExpiresAt: nil,
            totalGamesPlayed: 0,
            totalBuyins: 0,
            totalCashouts: 0,
            createdAt: Date(),
            lastLoginAt: nil,
            updatedAt: nil
        )
        queue.enqueue(table: "profiles", operation: .upsert, item: profileDto)

        #expect(queue.pendingCount == 2)

        queue.discardPendingGamePlayerUpserts()

        #expect(queue.pendingCount == 1)
    }
}

import Foundation
import Testing
@testable import FishAndChips

@MainActor
struct GamePlayerMergeCoreDataTests {

    @Test func createFromGamePlayerDTO_links_Player_by_playerName() async throws {
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.container.viewContext

        guard let user = persistence.createUser(username: "gwpm", passwordHash: "hash") else {
            Issue.record("could not seed user")
            return
        }
        let game = persistence.createGame(gameType: "Poker", creatorUserId: user.userId)

        try ctx.save()

        let dto = GamePlayerDTO(
            id: UUID(),
            gameId: game.gameId,
            profileId: nil,
            playerName: "Руслан",
            buyin: 100,
            cashout: 100,
            createdAt: nil
        )

        let gwp = GameWithPlayer.createFromGamePlayerDTO(dto, game: game, profile: nil, context: ctx)

        try ctx.save()

        #expect(gwp.player?.name == "Руслан")
        #expect(gwp.game?.gameId == game.gameId)
    }
}

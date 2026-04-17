#if DEBUG
import Foundation

/// Сид локальной сессии для UI-тестов скриншотов Figma без FC_TEST_EMAIL / FC_TEST_PASSWORD.
/// Запускается только при `--uitesting-bypass-auth` (см. FigmaScreenshotsUITests).
enum UITestSessionSeeder {
    private static let seedUsername = "uitest_figma"
    private static let seedEmail = "uitest_figma@local.local"

    static func seedIfNeeded(persistence: PersistenceController) {
        guard ProcessInfo.processInfo.arguments.contains("--uitesting-bypass-auth") else { return }

        let keychain = KeychainService.shared
        _ = keychain.setBiometricEnabled(false)

        if let uidString = keychain.getUserId(),
           let uid = UUID(uuidString: uidString),
           let user = persistence.fetchUser(byId: uid) {
            ensureSeedGames(for: user.userId, persistence: persistence)
            return
        }

        if keychain.getUserId() != nil {
            _ = keychain.deleteUserId()
        }

        if let user = persistence.fetchUser(byUsername: seedUsername) {
            _ = keychain.saveUserId(user.userId.uuidString)
            ensureSeedGames(for: user.userId, persistence: persistence)
            return
        }

        guard let user = persistence.createUser(
            username: seedUsername,
            passwordHash: "uitest",
            email: seedEmail
        ) else { return }
        _ = keychain.saveUserId(user.userId.uuidString)
        ensureSeedGames(for: user.userId, persistence: persistence)
    }

    private static func ensureSeedGames(for userId: UUID, persistence: PersistenceController) {
        if persistence.fetchGames(createdBy: userId).isEmpty {
            _ = persistence.createGame(gameType: "poker", creatorUserId: userId)
            _ = persistence.createGame(gameType: "Покер", creatorUserId: userId)
        }
    }
}
#endif

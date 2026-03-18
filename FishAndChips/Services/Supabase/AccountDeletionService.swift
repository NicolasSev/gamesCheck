import Foundation
import CoreData

/// GDPR — полное удаление аккаунта
/// 1. Серверная функция delete_user_account() удаляет profile, auth.user, каскадно aliases/claims/tokens
/// 2. Клиент очищает Core Data, Keychain, UserDefaults
final class AccountDeletionService {

    private let persistence: PersistenceController
    private let keychain: KeychainServiceProtocol

    init(persistence: PersistenceController, keychain: KeychainServiceProtocol) {
        self.persistence = persistence
        self.keychain = keychain
    }

    /// Полное удаление аккаунта — сервер + клиент
    func deleteAccount(userId: UUID) async throws {
        // 1. Серверное удаление через RPC
        if BackendSwitch.isSupabase {
            try await deleteServerAccount(userId: userId)
        }

        // 2. Локальная очистка
        try await clearLocalData(userId: userId)
    }

    // MARK: - Server

    private func deleteServerAccount(userId: UUID) async throws {
        struct DeleteParams: Codable, Sendable {
            let p_user_id: String
        }
        let params = DeleteParams(p_user_id: userId.uuidString)

        try await SupabaseService.shared.rpc("delete_user_account", params: params)

        try await SupabaseConfig.client.auth.signOut()
    }

    // MARK: - Local

    private func clearLocalData(userId: UUID) async throws {
        let context = persistence.container.viewContext

        try await context.perform {
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
            let users = try context.fetch(userRequest)

            for user in users {
                if let profile = user.playerProfile {
                    context.delete(profile)
                }
                context.delete(user)
            }

            let gameRequest: NSFetchRequest<Game> = Game.fetchRequest()
            gameRequest.predicate = NSPredicate(format: "creatorUserId == %@", userId as CVarArg)
            let games = try context.fetch(gameRequest)
            for game in games {
                context.delete(game)
            }

            try context.save()
        }

        _ = keychain.clearAll()

        UserDefaults.standard.removeObject(forKey: "activeBackend")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        UserDefaults.standard.removeObject(forKey: "dataMigrationCompleted")
        UserDefaults.standard.removeObject(forKey: "offlineSyncQueue")

        OfflineSyncQueue.shared.clearAll()
    }
}

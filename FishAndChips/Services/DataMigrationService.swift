//
//  DataMigrationService.swift
//  FishAndChips
//
//  Phase 2: Миграция - генерация materialized views для существующих данных
//

import Foundation
import CoreData

class DataMigrationService {
    private let persistence: PersistenceController
    private let materializedViews: MaterializedViewsService

    init(
        persistence: PersistenceController = .shared,
        materializedViews: MaterializedViewsService = .shared
    ) {
        self.persistence = persistence
        self.materializedViews = materializedViews
    }

    /// Одноразовая миграция: создать materialized views для всех пользователей и игр
    func generateMaterializedViews() async throws {
        debugLog("🔄 [MIGRATION] Generating materialized views...")

        let context = persistence.container.viewContext

        // 1. Все пользователи
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = (try? context.fetch(userRequest)) ?? []

        for user in users {
            do {
                try await materializedViews.updateUserStatisticsSummary(userId: user.userId)
                debugLog("  ✓ UserStatisticsSummary for \(user.username)")
            } catch {
                debugLog("  ⚠️ Failed for user \(user.userId): \(error)")
            }
        }

        // 2. Все игры
        let games = persistence.fetchAllActiveGames()
        for game in games {
            do {
                try await materializedViews.updateGameSummary(gameId: game.gameId)
            } catch {
                debugLog("  ⚠️ Failed for game \(game.gameId): \(error)")
            }
        }

        debugLog("✅ [MIGRATION] Materialized views generated: \(users.count) users, \(games.count) games")
    }
}

//
//  MaterializedViewsService.swift
//  FishAndChips
//
//  Phase 2: Автоматическое обновление materialized views при изменениях данных
//

import Foundation
import CoreData
import CloudKit

class MaterializedViewsService {
    static let shared = MaterializedViewsService()

    private let persistence: PersistenceController
    private let gameService: GameService
    private let cloudKit: CloudKitService

    init(
        persistence: PersistenceController = .shared,
        gameService: GameService = GameService(),
        cloudKit: CloudKitService = .shared
    ) {
        self.persistence = persistence
        self.gameService = gameService
        self.cloudKit = cloudKit
    }

    /// Обновить предрассчитанную статистику пользователя
    func updateUserStatisticsSummary(userId: UUID) async throws {
        let context = persistence.container.viewContext
        let stats = gameService.getUserStatistics(userId)

        let totalBuyins = (stats.totalBuyins as NSDecimalNumber).doubleValue
        let totalCashouts = (stats.totalCashouts as NSDecimalNumber).doubleValue
        let balance = (stats.currentBalance as NSDecimalNumber).doubleValue
        let lastGame = stats.recentGames.first?.timestamp ?? Date()
        let winRate = stats.winRate
        let avgProfit = (stats.averageProfit as NSDecimalNumber).doubleValue

        let fetchRequest: NSFetchRequest<UserStatisticsSummary> = UserStatisticsSummary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)

        let summary: UserStatisticsSummary
        if let existing = try? context.fetch(fetchRequest).first {
            summary = existing
        } else {
            summary = UserStatisticsSummary(context: context)
            summary.userId = userId
        }

        summary.totalGamesPlayed = Int64(stats.totalSessions)
        summary.totalBuyins = totalBuyins
        summary.totalCashouts = totalCashouts
        summary.balance = balance
        summary.lastGameDate = lastGame
        summary.winRate = winRate
        summary.avgProfit = avgProfit
        summary.lastUpdated = Date()

        try context.save()

        // Синхронизация в CloudKit (опционально)
        if await cloudKit.isCloudKitAvailable() {
            let record = summary.toCKRecord()
            _ = try? await cloudKit.save(record: record, to: .publicDB)
        }
    }

    /// Обновить краткую информацию об игре (GameSummaryRecord)
    func updateGameSummary(gameId: UUID) async throws {
        guard let game = persistence.fetchGame(byId: gameId) else { return }

        let context = persistence.container.viewContext
        let totalPlayers = Int64(game.gameWithPlayers?.count ?? 0)
        let totalBuyins = (game.totalBuyins as NSDecimalNumber).doubleValue

        let fetchRequest: NSFetchRequest<GameSummaryRecord> = GameSummaryRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)

        let summary: GameSummaryRecord
        if let existing = try? context.fetch(fetchRequest).first {
            summary = existing
        } else {
            summary = GameSummaryRecord(context: context)
            summary.gameId = gameId
        }

        summary.creatorUserId = game.creatorUserId
        summary.gameType = game.gameType
        summary.timestamp = game.timestamp
        summary.totalPlayers = totalPlayers
        summary.totalBuyins = totalBuyins
        summary.isPublic = game.isPublic
        summary.lastModified = Date()
        summary.checksum = computeGameSummaryChecksum(gameId: gameId, timestamp: game.timestamp, totalPlayers: totalPlayers, totalBuyins: totalBuyins)

        try context.save()

        if await cloudKit.isCloudKitAvailable() {
            let record = summary.toCKRecord()
            _ = try? await cloudKit.save(record: record, to: .publicDB)
        }
    }

    private func computeGameSummaryChecksum(gameId: UUID, timestamp: Date?, totalPlayers: Int64, totalBuyins: Double) -> String {
        let ts = timestamp?.timeIntervalSince1970 ?? 0
        return "\(gameId.uuidString)_\(Int(ts))_\(totalPlayers)_\(totalBuyins)"
    }

    /// Пересоздать все GameSummaryRecord для всех игр. Вызывать после pull из CloudKit,
    /// чтобы materialized views были актуальны (в т.ч. после смены имён игроков).
    func rebuildAllGameSummaries() async throws {
        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "softDeleted == NO")
        let games = (try? context.fetch(fetchRequest)) ?? []

        for game in games {
            try? await updateGameSummary(gameId: game.gameId)
        }
        debugLog("📊 [MaterializedViews] Rebuilt \(games.count) GameSummary records")
    }
}

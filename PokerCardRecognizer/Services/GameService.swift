import Foundation
import CoreData

final class GameService {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Fetch Games
    func getGamesCreatedByUser(_ userId: UUID) -> [Game] {
        persistence.fetchGames(createdBy: userId)
    }

    func getGamesParticipatedByUser(_ userId: UUID) -> [Game] {
        let context = persistence.container.viewContext

        // Найти профиль пользователя
        guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else {
            return []
        }

        let request: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        request.predicate = NSPredicate(format: "playerProfile == %@", profile)

        do {
            let participations = try context.fetch(request)
            let games = participations.compactMap { $0.game }
            return games
                .filter { !$0.isDeleted }
                .sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
        } catch {
            print("Error fetching participated games: \(error)")
            return []
        }
    }

    func getGames(filter: GameFilter, forUser userId: UUID) -> [Game] {
        switch filter {
        case .all:
            return getAllGamesForUser(userId)
        case .created:
            return getGamesCreatedByUser(userId)
        case .participated:
            return getGamesParticipatedByUser(userId)
        case .byType(let type):
            return getAllGamesForUser(userId).filter { $0.gameType == type }
        case .dateRange(let from, let to):
            return getAllGamesForUser(userId).filter {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= from && timestamp <= to
            }
        case .profitable:
            return getAllGamesForUser(userId).filter { gameProfit(for: $0, userId: userId) > 0 }
        case .losing:
            return getAllGamesForUser(userId).filter { gameProfit(for: $0, userId: userId) < 0 }
        }
    }

    private func getAllGamesForUser(_ userId: UUID) -> [Game] {
        let created = Set(getGamesCreatedByUser(userId))
        let participated = Set(getGamesParticipatedByUser(userId))
        return Array(created.union(participated))
            .sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
    }

    // MARK: - Statistics
    func getUserStatistics(_ userId: UUID) -> UserStatistics {
        let createdGames = getGamesCreatedByUser(userId)
        let participatedGames = getGamesParticipatedByUser(userId)
        let allGames = Set(createdGames).union(Set(participatedGames)).filter { !$0.isDeleted }

        guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else {
            return emptyStatistics()
        }

        var totalBuyins: Decimal = 0
        var totalCashouts: Decimal = 0
        var wins = 0
        var profitByType: [String: Decimal] = [:]
        var sessionProfits: [Decimal] = []

        for game in allGames {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            guard let myParticipation = participations.first(where: { $0.playerProfile == profile }) else {
                continue
            }

            let buyin = Decimal(Int(myParticipation.buyin))
            let cashout = Decimal(Int(myParticipation.cashout))
            let profit = cashout - buyin

            totalBuyins += buyin
            totalCashouts += cashout
            sessionProfits.append(profit)

            if profit > 0 { wins += 1 }

            if let gameType = game.gameType {
                profitByType[gameType, default: 0] += profit
            }
        }

        let balance = totalCashouts - totalBuyins
        let totalSessions = allGames.count
        let winRate = totalSessions == 0 ? 0 : Double(wins) / Double(totalSessions)
        let averageProfit = totalSessions == 0 ? 0 : balance / Decimal(totalSessions)
        let bestSession = sessionProfits.max() ?? 0
        let worstSession = sessionProfits.min() ?? 0

        let recentGames = Array(allGames)
            .sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
            .prefix(10)
            .map { createGameSummary(from: $0, userId: userId, profile: profile) }

        return UserStatistics(
            totalGamesCreated: createdGames.count,
            totalGamesParticipated: participatedGames.count,
            totalBuyins: totalBuyins,
            totalCashouts: totalCashouts,
            currentBalance: balance,
            winRate: winRate,
            profitByGameType: profitByType,
            recentGames: recentGames,
            bestSession: bestSession,
            worstSession: worstSession,
            averageProfit: averageProfit,
            totalSessions: totalSessions
        )
    }

    func getGameTypeStatistics(_ userId: UUID) -> [GameTypeStatistics] {
        let allGames = getAllGamesForUser(userId).filter { !$0.isDeleted }
        let gameTypes = Set(allGames.compactMap { $0.gameType })

        return gameTypes.map { type in
            let gamesOfType = allGames.filter { $0.gameType == type }

            var totalProfit: Decimal = 0
            var wins = 0
            var sessionProfits: [Decimal] = []

            for game in gamesOfType {
                let profit = gameProfit(for: game, userId: userId)
                totalProfit += profit
                sessionProfits.append(profit)
                if profit > 0 { wins += 1 }
            }

            let count = gamesOfType.count
            let winRate = count == 0 ? 0 : Double(wins) / Double(count)
            let averageProfit = count == 0 ? 0 : totalProfit / Decimal(count)
            let bestSession = sessionProfits.max() ?? 0

            return GameTypeStatistics(
                gameType: type,
                gamesCount: count,
                totalProfit: totalProfit,
                winRate: winRate,
                averageProfit: averageProfit,
                bestSession: bestSession
            )
        }
        .sorted { $0.gamesCount > $1.gamesCount }
    }

    // MARK: - Helpers
    private func gameProfit(for game: Game, userId: UUID) -> Decimal {
        guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else { return 0 }

        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        guard let myParticipation = participations.first(where: { $0.playerProfile == profile }) else {
            return 0
        }

        return Decimal(Int(myParticipation.cashout)) - Decimal(Int(myParticipation.buyin))
    }

    private func createGameSummary(from game: Game, userId: UUID, profile: PlayerProfile) -> GameSummary {
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let myParticipation = participations.first(where: { $0.playerProfile == profile })

        let buyin = Decimal(Int(myParticipation?.buyin ?? 0))
        let cashout = Decimal(Int(myParticipation?.cashout ?? 0))

        return GameSummary(
            gameId: game.gameId,
            gameType: game.gameType ?? "Unknown",
            timestamp: game.timestamp ?? Date(),
            totalPlayers: participations.count,
            myBuyin: buyin,
            myCashout: cashout,
            profit: cashout - buyin,
            isCreator: game.creatorUserId == userId
        )
    }

    private func emptyStatistics() -> UserStatistics {
        UserStatistics(
            totalGamesCreated: 0,
            totalGamesParticipated: 0,
            totalBuyins: 0,
            totalCashouts: 0,
            currentBalance: 0,
            winRate: 0,
            profitByGameType: [:],
            recentGames: [],
            bestSession: 0,
            worstSession: 0,
            averageProfit: 0,
            totalSessions: 0
        )
    }
}

// MARK: - Convenience
extension GameService {
    func getRecentGames(_ userId: UUID, limit: Int = 10) -> [GameSummary] {
        Array(getUserStatistics(userId).recentGames.prefix(limit))
    }

    func getTotalBalance(_ userId: UUID) -> Decimal {
        getUserStatistics(userId).currentBalance
    }

    func getWinRate(_ userId: UUID) -> Double {
        getUserStatistics(userId).winRate
    }
}


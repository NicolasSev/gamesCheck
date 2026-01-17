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
                .filter { !$0.softDeleted }
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
        case .allGames:
            return getAllGames()
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
    
    // Получить все игры независимо от пользователя (для просмотра всех игр на устройстве)
    func getAllGames() -> [Game] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "softDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all games: \(error)")
            return []
        }
    }

    private func getAllGamesForUser(_ userId: UUID) -> [Game] {
        let created = Set(getGamesCreatedByUser(userId))
        let participated = Set(getGamesParticipatedByUser(userId))
        return Array(created.union(participated))
            .sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
    }

    // MARK: - Statistics
    func getUserStatistics(byPlayerName playerName: String) -> UserStatistics {
        // Получаем все игры
        let allGames = getAllGames()
        
        var totalBuyins: Decimal = 0
        var totalCashouts: Decimal = 0
        var wins = 0
        var profitByType: [String: Decimal] = [:]
        var sessionProfits: [Decimal] = []
        var sessionsWithParticipation = 0
        var mvpCount = 0
        var gamesCreated = 0
        var gamesParticipated = 0
        
        for game in allGames {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            
            // Ищем участие игрока по имени (без учета регистра)
            guard let myParticipation = participations.first(where: { gwp in
                guard let player = gwp.player, let name = player.name else { return false }
                return name.lowercased() == playerName.lowercased()
            }) else {
                continue // Пропускаем игры, где игрок не участвовал
            }
            
            gamesParticipated += 1
            sessionsWithParticipation += 1
            
            let buyin = Decimal(Int(myParticipation.buyin))
            let cashout = Decimal(Int(myParticipation.cashout))
            let profit = cashout - (buyin * 2000)
            
            totalBuyins += buyin
            totalCashouts += cashout
            sessionProfits.append(profit)
            
            if profit > 0 { wins += 1 }
            
            if let gameType = game.gameType {
                profitByType[gameType, default: 0] += profit
            }
            
            // Проверяем, был ли игрок MVP в этой игре
            let playersWithProfit = participations.compactMap { gwp -> (playerName: String, profit: Decimal)? in
                guard let player = gwp.player, let name = player.name else { return nil }
                let buyin = Decimal(Int(gwp.buyin))
                let cashout = Decimal(Int(gwp.cashout))
                let profit = cashout - (buyin * 2000)
                return (playerName: name, profit: profit)
            }
            
            if let maxProfit = playersWithProfit.max(by: { $0.profit < $1.profit }),
               maxProfit.playerName.lowercased() == playerName.lowercased() {
                mvpCount += 1
            }
        }
        
        let totalSessions = sessionsWithParticipation
        let currentBalance = totalCashouts - (totalBuyins * 2000)
        let winRate = totalSessions > 0 ? Double(wins) / Double(totalSessions) : 0
        let averageProfit = totalSessions > 0 ? currentBalance / Decimal(totalSessions) : 0
        let bestSession = sessionProfits.max() ?? 0
        let worstSession = sessionProfits.min() ?? 0
        
        // Получаем последние игры
        let recentGames = allGames
            .filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
            }
            .sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
            .prefix(10)
            .map { game -> GameSummary in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                let myParticipation = participations.first { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
                let buyin = Decimal(Int(myParticipation?.buyin ?? 0))
                let cashout = Decimal(Int(myParticipation?.cashout ?? 0))
                let profit = cashout - (buyin * 2000)
                
                return GameSummary(
                    gameId: game.gameId,
                    gameType: game.gameType ?? "Unknown",
                    timestamp: game.timestamp ?? Date(),
                    totalPlayers: participations.count,
                    myBuyin: buyin,
                    myCashout: cashout,
                    profit: profit,
                    isCreator: false // Для игроков по имени не определяем создателя
                )
            }
        
        return UserStatistics(
            totalGamesCreated: gamesCreated,
            totalGamesParticipated: gamesParticipated,
            totalBuyins: totalBuyins,
            totalCashouts: totalCashouts,
            currentBalance: currentBalance,
            winRate: winRate,
            profitByGameType: profitByType,
            recentGames: Array(recentGames),
            bestSession: bestSession,
            worstSession: worstSession,
            averageProfit: averageProfit,
            totalSessions: totalSessions,
            mvpCount: mvpCount
        )
    }
    
    func getUserStatistics(_ userId: UUID) -> UserStatistics {
        let createdGames = getGamesCreatedByUser(userId)
        let participatedGames = getGamesParticipatedByUser(userId)
        let allGames = Set(createdGames).union(Set(participatedGames)).filter { !$0.softDeleted }

        guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else {
            return emptyStatistics()
        }

        var totalBuyins: Decimal = 0
        var totalCashouts: Decimal = 0
        var wins = 0
        var profitByType: [String: Decimal] = [:]
        var sessionProfits: [Decimal] = []
        var sessionsWithParticipation = 0 // Считаем только игры, где пользователь участвовал
        var mvpCount = 0 // Считаем сколько раз пользователь был MVP

        for game in allGames {
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            guard let myParticipation = participations.first(where: { $0.playerProfile == profile }) else {
                continue // Пропускаем игры, где пользователь не участвовал
            }

            sessionsWithParticipation += 1 // Учитываем только игры с участием
            
            let buyin = Decimal(Int(myParticipation.buyin))
            let cashout = Decimal(Int(myParticipation.cashout))
            // Конвертируем байин в тенге: 1 байин = 2000 тенге
            let profit = cashout - (buyin * 2000)

            totalBuyins += buyin
            totalCashouts += cashout
            sessionProfits.append(profit)

            if profit > 0 { wins += 1 }

            if let gameType = game.gameType {
                profitByType[gameType, default: 0] += profit
            }
            
            // Проверяем, был ли пользователь MVP в этой игре
            let playersWithProfit = participations.compactMap { gwp -> (playerProfile: PlayerProfile?, profit: Decimal)? in
                let buyin = Decimal(Int(gwp.buyin))
                let cashout = Decimal(Int(gwp.cashout))
                let profit = cashout - (buyin * 2000)
                return (gwp.playerProfile, profit)
            }
            
            if let mvp = playersWithProfit.max(by: { $0.profit < $1.profit }),
               mvp.playerProfile == profile {
                mvpCount += 1
            }
        }

        // Конвертируем байины в тенге: 1 байин = 2000 тенге
        let balance = totalCashouts - (totalBuyins * 2000)
        let totalSessions = sessionsWithParticipation // Используем только игры с участием
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
            totalSessions: totalSessions,
            mvpCount: mvpCount
        )
    }

    func getGameTypeStatistics(_ userId: UUID) -> [GameTypeStatistics] {
        let allGames = getAllGamesForUser(userId).filter { !$0.softDeleted }
        let gameTypes = Set(allGames.compactMap { $0.gameType })

        return gameTypes.map { type in
            let gamesOfType = allGames.filter { $0.gameType == type }

            var totalProfit: Decimal = 0
            var wins = 0
            var sessionProfits: [Decimal] = []
            var sessionsWithParticipation = 0 // Считаем только игры, где пользователь участвовал

            for game in gamesOfType {
                // gameProfit уже учитывает конвертацию байина в тенге (buyin * 2000)
                // gameProfit возвращает 0, если пользователь не участвовал в игре
                let profit = gameProfit(for: game, userId: userId)
                
                // Учитываем только игры, где пользователь действительно участвовал (profit != 0 или есть участие)
                // Проверяем наличие участия через playerProfile
                guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else { continue }
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                let hasParticipation = participations.contains(where: { $0.playerProfile == profile })
                
                if hasParticipation {
                    sessionsWithParticipation += 1
                    totalProfit += profit
                    sessionProfits.append(profit)
                    if profit > 0 { wins += 1 }
                }
            }

            let count = sessionsWithParticipation // Используем только игры с участием
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

        // Конвертируем байин в тенге: 1 байин = 2000 тенге
        let buyin = Decimal(Int(myParticipation.buyin))
        let cashout = Decimal(Int(myParticipation.cashout))
        return cashout - (buyin * 2000)
    }

    private func createGameSummary(from game: Game, userId: UUID, profile: PlayerProfile) -> GameSummary {
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let myParticipation = participations.first(where: { $0.playerProfile == profile })

        let buyin = Decimal(Int(myParticipation?.buyin ?? 0))
        let cashout = Decimal(Int(myParticipation?.cashout ?? 0))
        // Конвертируем байин в тенге: 1 байин = 2000 тенге
        let profit = cashout - (buyin * 2000)

        return GameSummary(
            gameId: game.gameId,
            gameType: game.gameType ?? "Unknown",
            timestamp: game.timestamp ?? Date(),
            totalPlayers: participations.count,
            myBuyin: buyin,
            myCashout: cashout,
            profit: profit,
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
            totalSessions: 0,
            mvpCount: 0
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
    
    // MARK: - Chart Data
    func getChartData(forUser userId: UUID) -> [(date: Date, buyin: Decimal, gameId: UUID)] {
        let allGames = getAllGamesForUser(userId)
        
        return allGames.compactMap { game -> (date: Date, buyin: Decimal, gameId: UUID)? in
            guard let timestamp = game.timestamp else { return nil }
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            
            // Сумма всех байинов за игру (не только пользователя)
            let totalBuyin = participations.reduce(Decimal(0)) { $0 + Decimal(Int($1.buyin)) }
            return (date: timestamp, buyin: totalBuyin, gameId: game.gameId)
        }.sorted { $0.date < $1.date }
    }
    
    func getChartData(byPlayerName playerName: String) -> [(date: Date, buyin: Decimal, gameId: UUID)] {
        let allGames = getAllGames()
        
        return allGames.compactMap { game -> (date: Date, buyin: Decimal, gameId: UUID)? in
            guard let timestamp = game.timestamp else { return nil }
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            
            // Проверяем участие игрока по имени
            let playerParticipated = participations.contains { gwp in
                guard let player = gwp.player, let name = player.name else { return false }
                return name.lowercased() == playerName.lowercased()
            }
            
            // Если игрок участвовал, считаем сумму всех байинов за игру
            guard playerParticipated else { return nil }
            let totalBuyin = participations.reduce(Decimal(0)) { $0 + Decimal(Int($1.buyin)) }
            return (date: timestamp, buyin: totalBuyin, gameId: game.gameId)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Top Analytics
    func getTopAnalytics() -> TopAnalytics {
        let allGames = getAllGames()
        var biggestWin: TopRecord?
        var biggestLoss: TopRecord?
        var maxBuyins: TopRecord?
        var mostExpensiveGame: TopRecord?
        var longestWinStreak: StreakRecord?
        var longestLoseStreak: StreakRecord?
        
        var winningProfits: [Decimal] = []
        var losingProfits: [Decimal] = []
        var totalWinningGames = 0
        var totalLosingGames = 0
        
        // Словарь для отслеживания винстриков по каждому игроку
        struct PlayerStreak {
            var currentLength: Int = 0
            var maxLength: Int = 0
            var startDate: Date?
            var endDate: Date?
            var currentStartDate: Date?
        }
        
        var playerWinStreaks: [String: PlayerStreak] = [:]
        var playerLoseStreaks: [String: PlayerStreak] = [:]
        
        // Проходим по всем играм, отсортированным по дате
        let sortedGames = allGames.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        for game in sortedGames {
            guard let gameDate = game.timestamp else { continue }
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            
            // Находим максимальный выигрыш/проигрыш и максимальные байины в игре
            for participation in participations {
                guard let player = participation.player,
                      let playerName = player.name else { continue }
                
                let buyin = Decimal(Int(participation.buyin))
                let cashout = Decimal(Int(participation.cashout))
                let profit = cashout - (buyin * 2000)
                
                // Самый большой выигрыш
                if profit > 0 {
                    if biggestWin == nil || profit > biggestWin!.value {
                        biggestWin = TopRecord(
                            value: profit,
                            playerName: playerName,
                            gameDate: gameDate,
                            gameId: game.gameId,
                            buyinInTenge: nil
                        )
                    }
                    winningProfits.append(profit)
                }
                
                // Самый большой проигрыш
                if profit < 0 {
                    if biggestLoss == nil || profit < biggestLoss!.value {
                        biggestLoss = TopRecord(
                            value: profit,
                            playerName: playerName,
                            gameDate: gameDate,
                            gameId: game.gameId,
                            buyinInTenge: nil
                        )
                    }
                    losingProfits.append(profit)
                }
                
                // Самое большое количество байинов
                let buyinInTenge = buyin * 2000
                if maxBuyins == nil || buyinInTenge > maxBuyins!.value {
                    maxBuyins = TopRecord(
                        value: buyinInTenge,
                        playerName: playerName,
                        gameDate: gameDate,
                        gameId: game.gameId,
                        buyinInTenge: nil
                    )
                }
                
                // Отслеживаем винстрики по игрокам
                if profit > 0 {
                    // Выигрыш - увеличиваем винстрик, сбрасываем лоузстрик
                    if var winStreak = playerWinStreaks[playerName] {
                        winStreak.currentLength += 1
                        if winStreak.currentStartDate == nil {
                            winStreak.currentStartDate = gameDate
                        }
                        if winStreak.currentLength > winStreak.maxLength {
                            winStreak.maxLength = winStreak.currentLength
                            winStreak.startDate = winStreak.currentStartDate
                            winStreak.endDate = gameDate
                        }
                        playerWinStreaks[playerName] = winStreak
                    } else {
                        playerWinStreaks[playerName] = PlayerStreak(
                            currentLength: 1,
                            maxLength: 1,
                            startDate: gameDate,
                            endDate: gameDate,
                            currentStartDate: gameDate
                        )
                    }
                    
                    // Сбрасываем лоузстрик
                    if var loseStreak = playerLoseStreaks[playerName] {
                        loseStreak.currentLength = 0
                        loseStreak.currentStartDate = nil
                        playerLoseStreaks[playerName] = loseStreak
                    }
                } else if profit < 0 {
                    // Проигрыш - увеличиваем лоузстрик, сбрасываем винстрик
                    if var loseStreak = playerLoseStreaks[playerName] {
                        loseStreak.currentLength += 1
                        if loseStreak.currentStartDate == nil {
                            loseStreak.currentStartDate = gameDate
                        }
                        if loseStreak.currentLength > loseStreak.maxLength {
                            loseStreak.maxLength = loseStreak.currentLength
                            loseStreak.startDate = loseStreak.currentStartDate
                            loseStreak.endDate = gameDate
                        }
                        playerLoseStreaks[playerName] = loseStreak
                    } else {
                        playerLoseStreaks[playerName] = PlayerStreak(
                            currentLength: 1,
                            maxLength: 1,
                            startDate: gameDate,
                            endDate: gameDate,
                            currentStartDate: gameDate
                        )
                    }
                    
                    // Сбрасываем винстрик
                    if var winStreak = playerWinStreaks[playerName] {
                        winStreak.currentLength = 0
                        winStreak.currentStartDate = nil
                        playerWinStreaks[playerName] = winStreak
                    }
                } else {
                    // Нулевой результат - сбрасываем оба стрика
                    if var winStreak = playerWinStreaks[playerName] {
                        winStreak.currentLength = 0
                        winStreak.currentStartDate = nil
                        playerWinStreaks[playerName] = winStreak
                    }
                    if var loseStreak = playerLoseStreaks[playerName] {
                        loseStreak.currentLength = 0
                        loseStreak.currentStartDate = nil
                        playerLoseStreaks[playerName] = loseStreak
                    }
                }
            }
            
            // Находим самую дорогую игру (максимальная сумма байинов всех участников)
            let gameTotalBuyins = game.totalBuyins * 2000 // В тенге
            if mostExpensiveGame == nil || gameTotalBuyins > mostExpensiveGame!.value {
                mostExpensiveGame = TopRecord(
                    value: gameTotalBuyins,
                    playerName: "Все участники",
                    gameDate: gameDate,
                    gameId: game.gameId,
                    buyinInTenge: nil
                )
            }
            
            // Подсчитываем общее количество выигрышных/проигрышных игр
            let gameMaxProfit = participations.map { participation -> Decimal in
                let buyin = Decimal(Int(participation.buyin))
                let cashout = Decimal(Int(participation.cashout))
                return cashout - (buyin * 2000)
            }.max() ?? 0
            
            if gameMaxProfit > 0 {
                totalWinningGames += 1
            } else if gameMaxProfit < 0 {
                totalLosingGames += 1
            }
        }
        
        // Находим игрока с самым длинным винстриком
        var maxWinStreakPlayer: (name: String, streak: PlayerStreak)?
        for (playerName, streak) in playerWinStreaks {
            if streak.maxLength > 0 {
                if maxWinStreakPlayer == nil || streak.maxLength > maxWinStreakPlayer!.streak.maxLength {
                    maxWinStreakPlayer = (playerName, streak)
                }
            }
        }
        
        if let player = maxWinStreakPlayer, let start = player.streak.startDate, let end = player.streak.endDate {
            longestWinStreak = StreakRecord(
                length: player.streak.maxLength,
                startDate: start,
                endDate: end,
                playerName: player.name
            )
        }
        
        // Находим игрока с самым длинным лоузстриком
        var maxLoseStreakPlayer: (name: String, streak: PlayerStreak)?
        for (playerName, streak) in playerLoseStreaks {
            if streak.maxLength > 0 {
                if maxLoseStreakPlayer == nil || streak.maxLength > maxLoseStreakPlayer!.streak.maxLength {
                    maxLoseStreakPlayer = (playerName, streak)
                }
            }
        }
        
        if let player = maxLoseStreakPlayer, let start = player.streak.startDate, let end = player.streak.endDate {
            longestLoseStreak = StreakRecord(
                length: player.streak.maxLength,
                startDate: start,
                endDate: end,
                playerName: player.name
            )
        }
        
        // Вычисляем средние значения
        let averageWin = winningProfits.isEmpty ? 0 : winningProfits.reduce(0, +) / Decimal(winningProfits.count)
        let averageLoss = losingProfits.isEmpty ? 0 : losingProfits.reduce(0, +) / Decimal(losingProfits.count)
        
        return TopAnalytics(
            biggestWin: biggestWin,
            biggestLoss: biggestLoss,
            maxBuyins: maxBuyins,
            mostExpensiveGame: mostExpensiveGame,
            longestWinStreak: longestWinStreak,
            longestLoseStreak: longestLoseStreak,
            averageWin: averageWin,
            averageLoss: averageLoss,
            totalWinningGames: totalWinningGames,
            totalLosingGames: totalLosingGames,
            mostEfficientPlayer: nil,
            leastEfficientPlayer: nil
        )
    }
}


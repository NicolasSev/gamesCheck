# Task 1.6: Создание GameService

**Приоритет:** 🟠 Высокий  
**Срок:** 2-3 дня  
**Статус:** 🟩 DONE  
**Исполнитель:** Cursor Agent  
**Начато:** 2025-12-21  
**Завершено:** 2025-12-21  
**Результат:** см. git log: `feat: добавлен GameService (Task 1.6)`  

---

## Описание

Создать сервис для бизнес-логики работы с играми, статистики и фильтрации.

---

## Предусловия

- ✅ Task 1.1-1.5 завершены
- Модели User, Game, PlayerProfile готовы

---

## Задачи

### 1. Создать структуры для статистики

Создайте файл `GameStatistics.swift`:

```swift
import Foundation

struct UserStatistics {
    let totalGamesCreated: Int
    let totalGamesParticipated: Int
    let totalBuyins: Decimal
    let totalCashouts: Decimal
    let currentBalance: Decimal
    let winRate: Double
    let profitByGameType: [String: Decimal]
    let recentGames: [GameSummary]
    let bestSession: Decimal
    let worstSession: Decimal
    let averageProfit: Decimal
    let totalSessions: Int
    
    var isPositive: Bool {
        currentBalance > 0
    }
}

struct GameSummary {
    let gameId: UUID
    let gameType: String
    let timestamp: Date
    let totalPlayers: Int
    let myBuyin: Decimal
    let myCashout: Decimal
    let profit: Decimal
    let isCreator: Bool
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedProfit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: profit)) ?? "$0"
    }
}

struct GameTypeStatistics {
    let gameType: String
    let gamesCount: Int
    let totalProfit: Decimal
    let winRate: Double
    let averageProfit: Decimal
    let bestSession: Decimal
}

enum GameFilter {
    case all
    case created
    case participated
    case byType(String)
    case dateRange(from: Date, to: Date)
    case profitable
    case losing
}
```

### 2. Создать GameService

Создайте файл `GameService.swift`:

```swift
import Foundation
import CoreData

class GameService {
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
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        
        // Найти все игры где пользователь участвовал через PlayerProfile
        let profileRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        
        do {
            guard let profile = try context.fetch(profileRequest).first else {
                return []
            }
            
            // Получить все игры через GameWithPlayer
            let gamePlayerRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
            gamePlayerRequest.predicate = NSPredicate(format: "playerProfile == %@", profile)
            
            let gameParticipations = try context.fetch(gamePlayerRequest)
            let games = gameParticipations.compactMap { $0.game }
            
            // Отфильтровать удаленные и отсортировать
            return games.filter { !$0.isDeleted }
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
        let allGames = Set(createdGames).union(Set(participatedGames))
        
        // Получить профиль пользователя
        guard let profile = persistence.fetchPlayerProfile(byUserId: userId) else {
            return emptyStatistics()
        }
        
        // Подсчитать статистику
        var totalBuyins: Decimal = 0
        var totalCashouts: Decimal = 0
        var wins = 0
        var profitByType: [String: Decimal] = [:]
        var sessionProfits: [Decimal] = []
        
        for game in allGames {
            guard let participations = game.players as? Set<GameWithPlayer>,
                  let myParticipation = participations.first(where: { $0.playerProfile == profile }) else {
                continue
            }
            
            let buyin = myParticipation.buyin as Decimal? ?? 0
            let cashout = myParticipation.cashout as Decimal? ?? 0
            let profit = cashout - buyin
            
            totalBuyins += buyin
            totalCashouts += cashout
            sessionProfits.append(profit)
            
            if profit > 0 {
                wins += 1
            }
            
            // По типам игр
            if let gameType = game.gameType {
                profitByType[gameType, default: 0] += profit
            }
        }
        
        let balance = totalCashouts - totalBuyins
        let winRate = allGames.isEmpty ? 0 : Double(wins) / Double(allGames.count)
        let averageProfit = allGames.isEmpty ? 0 : balance / Decimal(allGames.count)
        let bestSession = sessionProfits.max() ?? 0
        let worstSession = sessionProfits.min() ?? 0
        
        // Последние игры
        let recentGames = Array(allGames.prefix(10)).map { game -> GameSummary in
            createGameSummary(from: game, userId: userId, profile: profile)
        }
        
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
            totalSessions: allGames.count
        )
    }
    
    func getGameTypeStatistics(_ userId: UUID) -> [GameTypeStatistics] {
        let allGames = getAllGamesForUser(userId)
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
                if profit > 0 {
                    wins += 1
                }
            }
            
            let winRate = gamesOfType.isEmpty ? 0 : Double(wins) / Double(gamesOfType.count)
            let averageProfit = gamesOfType.isEmpty ? 0 : totalProfit / Decimal(gamesOfType.count)
            let bestSession = sessionProfits.max() ?? 0
            
            return GameTypeStatistics(
                gameType: type,
                gamesCount: gamesOfType.count,
                totalProfit: totalProfit,
                winRate: winRate,
                averageProfit: averageProfit,
                bestSession: bestSession
            )
        }.sorted { $0.gamesCount > $1.gamesCount }
    }
    
    // MARK: - Helpers
    
    private func gameProfit(for game: Game, userId: UUID) -> Decimal {
        guard let profile = persistence.fetchPlayerProfile(byUserId: userId),
              let participations = game.players as? Set<GameWithPlayer>,
              let myParticipation = participations.first(where: { $0.playerProfile == profile }) else {
            return 0
        }
        
        let buyin = myParticipation.buyin as Decimal? ?? 0
        let cashout = myParticipation.cashout as Decimal? ?? 0
        return cashout - buyin
    }
    
    private func createGameSummary(from game: Game, userId: UUID, profile: PlayerProfile) -> GameSummary {
        let participations = game.players as? Set<GameWithPlayer> ?? []
        let myParticipation = participations.first(where: { $0.playerProfile == profile })
        
        let buyin = myParticipation?.buyin as Decimal? ?? 0
        let cashout = myParticipation?.cashout as Decimal? ?? 0
        
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

// MARK: - Convenience Extensions
extension GameService {
    func getRecentGames(_ userId: UUID, limit: Int = 10) -> [GameSummary] {
        let stats = getUserStatistics(userId)
        return Array(stats.recentGames.prefix(limit))
    }
    
    func getTotalBalance(_ userId: UUID) -> Decimal {
        getUserStatistics(userId).currentBalance
    }
    
    func getWinRate(_ userId: UUID) -> Double {
        getUserStatistics(userId).winRate
    }
}
```

---

## Тестирование

### Unit тесты

`GameServiceTests.swift`:

```swift
import XCTest
import CoreData
@testable import PokerCardRecognizer

final class GameServiceTests: XCTestCase {
    var persistence: PersistenceController!
    var gameService: GameService!
    var testUser: User!
    var testProfile: PlayerProfile!
    
    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        gameService = GameService(persistence: persistence)
        
        testUser = persistence.createUser(username: "testuser", passwordHash: "hash")
        testProfile = persistence.createPlayerProfile(
            displayName: "Test User",
            userId: testUser.userId
        )
    }
    
    override func tearDown() {
        testUser = nil
        testProfile = nil
        gameService = nil
        persistence = nil
        super.tearDown()
    }
    
    func testGetGamesCreatedByUser() {
        // Создать несколько игр
        let game1 = persistence.createGame(gameType: "Poker", creatorUserId: testUser.userId)
        let game2 = persistence.createGame(gameType: "Billiard", creatorUserId: testUser.userId)
        
        let games = gameService.getGamesCreatedByUser(testUser.userId)
        
        XCTAssertEqual(games.count, 2)
        XCTAssertTrue(games.contains(game1))
        XCTAssertTrue(games.contains(game2))
    }
    
    func testGetUserStatistics() {
        // Создать игру
        let game = persistence.createGame(gameType: "Poker", creatorUserId: testUser.userId)
        
        // Добавить участие
        let context = persistence.container.viewContext
        let participation = GameWithPlayer(context: context)
        participation.game = game
        participation.playerProfile = testProfile
        participation.buyin = NSDecimalNumber(value: 100)
        participation.cashout = NSDecimalNumber(value: 150)
        
        try? context.save()
        
        // Получить статистику
        let stats = gameService.getUserStatistics(testUser.userId)
        
        XCTAssertEqual(stats.totalBuyins, 100)
        XCTAssertEqual(stats.totalCashouts, 150)
        XCTAssertEqual(stats.currentBalance, 50)
        XCTAssertEqual(stats.winRate, 1.0)
    }
    
    func testGameTypeStatistics() {
        // Создать игры разных типов
        createGameWithProfit(type: "Poker", buyin: 100, cashout: 150)
        createGameWithProfit(type: "Poker", buyin: 100, cashout: 80)
        createGameWithProfit(type: "Billiard", buyin: 50, cashout: 70)
        
        let stats = gameService.getGameTypeStatistics(testUser.userId)
        
        let pokerStats = stats.first { $0.gameType == "Poker" }
        XCTAssertNotNil(pokerStats)
        XCTAssertEqual(pokerStats?.gamesCount, 2)
        XCTAssertEqual(pokerStats?.totalProfit, 30) // 50 - 20
        XCTAssertEqual(pokerStats?.winRate, 0.5)
    }
    
    func testGameFiltering() {
        // Создать игры
        createGameWithProfit(type: "Poker", buyin: 100, cashout: 150)
        createGameWithProfit(type: "Poker", buyin: 100, cashout: 50)
        createGameWithProfit(type: "Billiard", buyin: 50, cashout: 70)
        
        // Тест фильтра по типу
        let pokerGames = gameService.getGames(filter: .byType("Poker"), forUser: testUser.userId)
        XCTAssertEqual(pokerGames.count, 2)
        
        // Тест фильтра profitable
        let profitableGames = gameService.getGames(filter: .profitable, forUser: testUser.userId)
        XCTAssertEqual(profitableGames.count, 2)
        
        // Тест фильтра losing
        let losingGames = gameService.getGames(filter: .losing, forUser: testUser.userId)
        XCTAssertEqual(losingGames.count, 1)
    }
    
    // MARK: - Helper
    
    private func createGameWithProfit(type: String, buyin: Decimal, cashout: Decimal) {
        let game = persistence.createGame(gameType: type, creatorUserId: testUser.userId)
        
        let context = persistence.container.viewContext
        let participation = GameWithPlayer(context: context)
        participation.game = game
        participation.playerProfile = testProfile
        participation.buyin = NSDecimalNumber(decimal: buyin)
        participation.cashout = NSDecimalNumber(decimal: cashout)
        
        try? context.save()
    }
}
```

---

## Критерии приемки

- [ ] GameService создан со всеми методами
- [ ] Статистические структуры определены
- [ ] Фильтрация игр работает корректно
- [ ] Подсчет статистики точный
- [ ] Unit тесты проходят
- [ ] Нет performance issues

---

## Следующие шаги

- **Task 1.7:** Реализация фильтрации в MainView
- **Task 5.1:** Улучшение UI Dashboard (Phase 5)

---

## Заметки

- GameService - слой бизнес-логики
- Отделяет UI от данных
- Легко тестируется
- Можно расширять новыми метриками

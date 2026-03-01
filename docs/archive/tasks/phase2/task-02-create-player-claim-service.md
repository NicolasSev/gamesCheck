# Task 2.2: Создание PlayerClaimService

**Приоритет:** 🟡 Средний  
**Срок:** 2-3 дня  
**Статус:** ⬜ TODO

---

## Описание

Реализовать сервис для присвоения анонимных игроков и миграции данных.

---

## Задачи

### Создать PlayerClaimService.swift

```swift
import Foundation
import CoreData

class PlayerClaimService {
    private let persistence: PersistenceController
    
    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }
    
    // MARK: - Claim Player
    
    func claimPlayer(_ playerName: String, forUserId userId: UUID) throws {
        let context = persistence.container.viewContext
        
        // 1. Получить или создать PlayerProfile
        var profile = persistence.fetchPlayerProfile(byUserId: userId)
        if profile == nil {
            guard let user = persistence.fetchUser(byId: userId) else {
                throw ClaimError.userNotFound
            }
            profile = persistence.createPlayerProfile(
                displayName: user.username,
                userId: userId
            )
        }
        
        guard let profile = profile else {
            throw ClaimError.profileCreationFailed
        }
        
        // 2. Создать alias
        guard persistence.createAlias(aliasName: playerName, forProfile: profile) != nil else {
            throw ClaimError.aliasAlreadyExists
        }
        
        // 3. Мигрировать игры
        try migrateGames(playerName: playerName, toProfile: profile, context: context)
        
        // 4. Пересчитать статистику
        profile.recalculateStatistics()
        
        try context.save()
    }
    
    private func migrateGames(
        playerName: String,
        toProfile profile: PlayerProfile,
        context: NSManagedObjectContext
    ) throws {
        // Найти все GameWithPlayer с этим именем
        let request: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        request.predicate = NSPredicate(format: "player.name ==[c] %@", playerName)
        
        let gameParticipations = try context.fetch(request)
        
        for participation in gameParticipations {
            participation.playerProfile = profile
        }
    }
    
    // MARK: - Statistics
    
    func getPlayerStatistics(_ playerName: String) -> PlayerStatistics {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        request.predicate = NSPredicate(format: "player.name ==[c] %@", playerName)
        
        do {
            let participations = try context.fetch(request)
            
            let gamesCount = participations.count
            let totalBuyins = participations.reduce(Decimal(0)) {
                $0 + ($1.buyin as Decimal? ?? 0)
            }
            let totalCashouts = participations.reduce(Decimal(0)) {
                $0 + ($1.cashout as Decimal? ?? 0)
            }
            
            return PlayerStatistics(
                gamesCount: gamesCount,
                totalBuyins: totalBuyins,
                totalCashouts: totalCashouts,
                balance: totalCashouts - totalBuyins
            )
        } catch {
            return PlayerStatistics(gamesCount: 0, totalBuyins: 0, totalCashouts: 0, balance: 0)
        }
    }
}

// MARK: - Models

struct PlayerStatistics {
    let gamesCount: Int
    let totalBuyins: Decimal
    let totalCashouts: Decimal
    let balance: Decimal
}

enum ClaimError: LocalizedError {
    case userNotFound
    case profileCreationFailed
    case aliasAlreadyExists
    case migrationFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound: return "Пользователь не найден"
        case .profileCreationFailed: return "Не удалось создать профиль"
        case .aliasAlreadyExists: return "Это имя уже присвоено"
        case .migrationFailed: return "Ошибка миграции данных"
        }
    }
}
```

---

## Unit тесты

```swift
import XCTest
@testable import PokerCardRecognizer

final class PlayerClaimServiceTests: XCTestCase {
    var persistence: PersistenceController!
    var service: PlayerClaimService!
    var testUser: User!
    
    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        service = PlayerClaimService(persistence: persistence)
        testUser = persistence.createUser(username: "test", passwordHash: "hash")
    }
    
    func testClaimPlayer() throws {
        // Создать старые данные
        let context = persistence.container.viewContext
        let player = Player(context: context)
        player.name = "Антон"
        
        let game = persistence.createGame(gameType: "Poker", creatorUserId: nil)
        let participation = GameWithPlayer(context: context)
        participation.game = game
        participation.player = player
        participation.buyin = 100
        participation.cashout = 150
        
        try context.save()
        
        // Присвоить
        try service.claimPlayer("Антон", forUserId: testUser.userId)
        
        // Проверить
        let profile = persistence.fetchPlayerProfile(byUserId: testUser.userId)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.totalGamesPlayed, 1)
        XCTAssertEqual(profile?.balance, 50)
    }
}
```

---

## Критерии приемки

- [ ] PlayerClaimService создан
- [ ] Миграция данных работает
- [ ] Статистика обновляется
- [ ] Unit тесты проходят
- [ ] Обработка ошибок реализована

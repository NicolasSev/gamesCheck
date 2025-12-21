# Task 1.2: Расширение модели Game

**Приоритет:** 🔴 Критический  
**Срок:** 1-2 дня  
**Статус:** 🟩 DONE  
**Исполнитель:** Cursor Agent  
**Начато:** 2025-12-21  
**Завершено:** 2025-12-21  
**Результат:** см. git log: `feat: расширена модель Game (Task 1.2)`  

---

## Описание

Расширить существующую модель Game для добавления связи с пользователем-создателем и дополнительных полей для трекинга.

---

## Предусловия

- ✅ Task 1.1 завершена (модель User создана)
- Существующая модель Game в CoreData

---

## Задачи

### 1. Изучить текущую модель Game

Найдите существующую сущность Game в `.xcdatamodeld` файле и посмотрите текущие атрибуты.

### 2. Добавить новые атрибуты к Game

Добавьте следующие атрибуты:

| Атрибут | Тип | Optional | Описание |
|---------|-----|----------|----------|
| `creatorUserId` | UUID | YES | ID пользователя-создателя (nullable для существующих игр) |
| `gameId` | UUID | NO | Уникальный ID игры (если еще не существует) |
| `notes` | String | YES | Заметки к игре |
| `isDeleted` | Boolean | NO | Мягкое удаление (soft delete) |

**Важно:** `creatorUserId` делаем optional, чтобы не сломать существующие данные.

### 3. Создать relationship с User

В Entity Editor для Game:
- Добавьте relationship `creator` → User (To-One)
- Type: To One
- Destination: User
- Inverse: createdGames (это будет в User)

В Entity Editor для User:
- Добавьте relationship `createdGames` → Game (To-Many)
- Type: To Many
- Destination: Game
- Inverse: creator
- Delete Rule: Nullify (при удалении пользователя игры остаются)

### 4. Обновить Game+CoreDataProperties.swift

```swift
import Foundation
import CoreData

extension Game {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    // Существующие атрибуты (не удаляйте их)
    @NSManaged public var timestamp: Date?
    @NSManaged public var gameType: String?
    // ... другие существующие атрибуты ...
    
    // НОВЫЕ атрибуты
    @NSManaged public var gameId: UUID
    @NSManaged public var creatorUserId: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var isDeleted: Bool
    
    // НОВЫЕ relationships
    @NSManaged public var creator: User?
    
    // Существующие relationships
    @NSManaged public var players: NSSet?
}

// MARK: - Computed Properties
extension Game {
    var isOwnedByCurrentUser: Bool {
        // Будет реализовано позже при добавлении currentUser
        guard let currentUserId = UserDefaults.standard.string(forKey: "currentUserId"),
              let currentUUID = UUID(uuidString: currentUserId) else {
            return false
        }
        return creatorUserId == currentUUID
    }
    
    var displayTimestamp: String {
        guard let timestamp = timestamp else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var totalBuyins: Decimal {
        guard let players = players as? Set<GameWithPlayer> else { return 0 }
        return players.reduce(0) { $0 + ($1.buyin as Decimal? ?? 0) }
    }
    
    var totalCashouts: Decimal {
        guard let players = players as? Set<GameWithPlayer> else { return 0 }
        return players.reduce(0) { $0 + ($1.cashout as Decimal? ?? 0) }
    }
    
    var isBalanced: Bool {
        totalBuyins == totalCashouts
    }
}

// MARK: - Players Helpers
extension Game {
    @objc(addPlayersObject:)
    @NSManaged public func addToPlayers(_ value: GameWithPlayer)

    @objc(removePlayersObject:)
    @NSManaged public func removeFromPlayers(_ value: GameWithPlayer)

    @objc(addPlayers:)
    @NSManaged public func addToPlayers(_ values: NSSet)

    @objc(removePlayers:)
    @NSManaged public func removeFromPlayers(_ values: NSSet)
}
```

### 5. Обновить Persistence.swift

Добавьте методы для работы с играми:

```swift
extension PersistenceController {
    // MARK: - Game Management
    
    func createGame(
        gameType: String,
        creatorUserId: UUID?,
        timestamp: Date = Date(),
        notes: String? = nil
    ) -> Game {
        let context = container.viewContext
        let game = Game(context: context)
        game.gameId = UUID()
        game.gameType = gameType
        game.timestamp = timestamp
        game.creatorUserId = creatorUserId
        game.notes = notes
        game.isDeleted = false
        
        // Установить relationship если пользователь существует
        if let userId = creatorUserId,
           let creator = fetchUser(byId: userId) {
            game.creator = creator
        }
        
        saveContext()
        return game
    }
    
    func fetchGames(createdBy userId: UUID) -> [Game] {
        let context = container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(
            format: "creatorUserId == %@ AND isDeleted == NO",
            userId as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching games: \(error)")
            return []
        }
    }
    
    func fetchAllActiveGames() -> [Game] {
        let context = container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "isDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching games: \(error)")
            return []
        }
    }
    
    func softDeleteGame(_ game: Game) {
        game.isDeleted = true
        saveContext()
    }
    
    func updateGameNotes(_ game: Game, notes: String) {
        game.notes = notes
        saveContext()
    }
}
```

### 6. Создать миграцию для существующих данных

Если у вас есть существующие игры, создайте утилиту для миграции:

```swift
extension PersistenceController {
    /// Мигрировать существующие игры (без creatorUserId)
    /// Вызывать один раз при первом запуске после обновления
    func migrateExistingGames() {
        let context = container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "creatorUserId == nil")
        
        do {
            let games = try context.fetch(request)
            
            for game in games {
                // Добавить gameId если отсутствует
                if game.gameId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    game.gameId = UUID()
                }
                
                // Установить isDeleted в false
                game.isDeleted = false
                
                // creatorUserId оставляем nil - это легаси игры
            }
            
            try context.save()
            print("Migrated \(games.count) existing games")
        } catch {
            print("Error migrating games: \(error)")
        }
    }
}
```

### 7. Обновить AppDelegate или App struct

Добавьте вызов миграции при первом запуске:

```swift
// В инициализации приложения
init() {
    let hasMigratedGames = UserDefaults.standard.bool(forKey: "hasMigratedGamesToV2")
    
    if !hasMigratedGames {
        PersistenceController.shared.migrateExistingGames()
        UserDefaults.standard.set(true, forKey: "hasMigratedGamesToV2")
    }
}
```

---

## Тестирование

### Unit тесты

Создайте файл `GameModelTests.swift`:

```swift
import XCTest
import CoreData
@testable import PokerCardRecognizer

final class GameModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    var testUser: User!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        
        // Создать тестового пользователя
        testUser = persistenceController.createUser(
            username: "testuser",
            passwordHash: "hash"
        )
    }
    
    override func tearDown() {
        testUser = nil
        persistenceController = nil
        super.tearDown()
    }
    
    func testCreateGameWithCreator() {
        let game = persistenceController.createGame(
            gameType: "Texas Hold'em",
            creatorUserId: testUser.userId
        )
        
        XCTAssertNotNil(game.gameId)
        XCTAssertEqual(game.creatorUserId, testUser.userId)
        XCTAssertEqual(game.creator?.userId, testUser.userId)
        XCTAssertFalse(game.isDeleted)
    }
    
    func testCreateGameWithoutCreator() {
        // Для легаси игр
        let game = persistenceController.createGame(
            gameType: "Billiard",
            creatorUserId: nil
        )
        
        XCTAssertNil(game.creatorUserId)
        XCTAssertNil(game.creator)
    }
    
    func testFetchGamesCreatedByUser() {
        // Создать несколько игр
        let game1 = persistenceController.createGame(
            gameType: "Poker",
            creatorUserId: testUser.userId
        )
        let game2 = persistenceController.createGame(
            gameType: "Billiard",
            creatorUserId: testUser.userId
        )
        
        // Создать игру другого пользователя
        let otherUser = persistenceController.createUser(
            username: "otheruser",
            passwordHash: "hash"
        )
        let game3 = persistenceController.createGame(
            gameType: "Poker",
            creatorUserId: otherUser?.userId
        )
        
        // Получить только игры testUser
        let userGames = persistenceController.fetchGames(createdBy: testUser.userId)
        
        XCTAssertEqual(userGames.count, 2)
        XCTAssertTrue(userGames.contains(game1))
        XCTAssertTrue(userGames.contains(game2))
        XCTAssertFalse(userGames.contains(game3))
    }
    
    func testSoftDeleteGame() {
        let game = persistenceController.createGame(
            gameType: "Poker",
            creatorUserId: testUser.userId
        )
        
        persistenceController.softDeleteGame(game)
        
        XCTAssertTrue(game.isDeleted)
        
        // Проверить что игра не возвращается в активных
        let activeGames = persistenceController.fetchAllActiveGames()
        XCTAssertFalse(activeGames.contains(game))
    }
    
    func testGameNotes() {
        let game = persistenceController.createGame(
            gameType: "Poker",
            creatorUserId: testUser.userId
        )
        
        let testNotes = "Great session! Had AA vs KK"
        persistenceController.updateGameNotes(game, notes: testNotes)
        
        XCTAssertEqual(game.notes, testNotes)
    }
}
```

---

## Критерии приемки

- [ ] Атрибуты `gameId`, `creatorUserId`, `notes`, `isDeleted` добавлены
- [ ] Relationship между Game и User настроен (двусторонний)
- [ ] Computed properties работают корректно
- [ ] Helper методы добавлены в `Persistence.swift`
- [ ] Миграция существующих данных реализована
- [ ] Unit тесты написаны и проходят
- [ ] Существующие игры в приложении не сломались
- [ ] Нет compiler errors

---

## Возможные проблемы

### Проблема: Crash при открытии существующих игр

**Решение:**
- Убедитесь что новые атрибуты optional или имеют default values
- Запустите миграцию данных
- Используйте lightweight migration в CoreData

### Проблема: Relationship не работает

**Решение:**
- Проверьте что inverse relationship установлен
- Delete rule должен быть Nullify
- Regenerate NSManagedObject subclasses

---

## Следующие шаги

После завершения переходите к:
- **Task 1.3:** Создание модели PlayerProfile
- **Task 1.6:** Создание GameService для бизнес-логики

---

## Заметки

- `creatorUserId` optional для обратной совместимости
- Используем soft delete (`isDeleted`) вместо реального удаления для аудита
- В будущем добавим поле `updatedAt` для синхронизации с backend

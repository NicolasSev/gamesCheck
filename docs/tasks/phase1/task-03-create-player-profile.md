# Task 1.3: Создание модели PlayerProfile

**Приоритет:** 🔴 Критический  
**Срок:** 2-3 дня  
**Статус:** 🟩 DONE  
**Исполнитель:** Cursor Agent  
**Начато:** 2025-12-21  
**Завершено:** 2025-12-21  
**Результат:** см. git log: `feat: добавлена модель PlayerProfile (Task 1.3)`  

---

## Описание

Создать модель PlayerProfile для унификации игроков в системе. Это позволит связывать анонимных игроков с зарегистрированными пользователями и агрегировать статистику.

---

## Предусловия

- ✅ Task 1.1 завершена (модель User создана)
- ✅ Task 1.2 завершена (модель Game расширена)

---

## Концепция

```
User (зарегистрированный) ──┐
                             ├─→ PlayerProfile ←─→ GameWithPlayer
Anonymous Player ────────────┘
```

**PlayerProfile** - это унифицированное представление игрока:
- Может быть связан с User (зарегистрированным пользователем)
- Может быть анонимным (просто имя)
- Имеет один или несколько псевдонимов (aliases)

---

## Задачи

### 1. Создать сущность PlayerProfile в CoreData

Откройте `.xcdatamodeld` и создайте новую Entity `PlayerProfile`.

### 2. Добавить атрибуты

| Атрибут | Тип | Optional | Default | Описание |
|---------|-----|----------|---------|----------|
| `profileId` | UUID | NO | UUID | Уникальный ID профиля |
| `userId` | UUID | YES | - | Связь с User (null = анонимный) |
| `displayName` | String | NO | - | Отображаемое имя |
| `isAnonymous` | Boolean | NO | true | Анонимный ли профиль |
| `createdAt` | Date | NO | current | Дата создания |
| `totalGamesPlayed` | Int32 | NO | 0 | Кеш: всего игр |
| `totalBuyins` | Decimal | NO | 0 | Кеш: сумма buyins |
| `totalCashouts` | Decimal | NO | 0 | Кеш: сумма cashouts |

**Примечание:** Поля с префиксом "Кеш" будут обновляться автоматически для производительности.

### 3. Создать relationships

**PlayerProfile relationships:**
- `user` → User (To-One, optional)
  - Inverse: `playerProfile`
  - Delete Rule: Nullify
  
- `aliases` → PlayerAlias (To-Many)
  - Inverse: `profile`
  - Delete Rule: Cascade
  
- `gameParticipations` → GameWithPlayer (To-Many)
  - Inverse: `playerProfile`
  - Delete Rule: Nullify

**User relationship (добавить к существующим):**
- `playerProfile` → PlayerProfile (To-One, optional)
  - Inverse: `user`
  - Delete Rule: Nullify

### 4. Создать Swift класс

Создайте `PlayerProfile+CoreDataClass.swift`:

```swift
import Foundation
import CoreData

@objc(PlayerProfile)
public class PlayerProfile: NSManagedObject {
    // Managed object subclass
}
```

### 5. Создать расширение с properties

Создайте `PlayerProfile+CoreDataProperties.swift`:

```swift
import Foundation
import CoreData

extension PlayerProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerProfile> {
        return NSFetchRequest<PlayerProfile>(entityName: "PlayerProfile")
    }

    @NSManaged public var profileId: UUID
    @NSManaged public var userId: UUID?
    @NSManaged public var displayName: String
    @NSManaged public var isAnonymous: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var totalGamesPlayed: Int32
    @NSManaged public var totalBuyins: NSDecimalNumber
    @NSManaged public var totalCashouts: NSDecimalNumber
    
    // Relationships
    @NSManaged public var user: User?
    @NSManaged public var aliases: NSSet?
    @NSManaged public var gameParticipations: NSSet?
}

// MARK: - Computed Properties
extension PlayerProfile {
    var balance: Decimal {
        (totalCashouts as Decimal) - (totalBuyins as Decimal)
    }
    
    var winRate: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        let wins = gameParticipationsArray.filter { $0.profit > 0 }.count
        return Double(wins) / Double(totalGamesPlayed)
    }
    
    var averageBuyin: Decimal {
        guard totalGamesPlayed > 0 else { return 0 }
        return (totalBuyins as Decimal) / Decimal(totalGamesPlayed)
    }
    
    var averageProfit: Decimal {
        guard totalGamesPlayed > 0 else { return 0 }
        return balance / Decimal(totalGamesPlayed)
    }
    
    var gameParticipationsArray: [GameWithPlayer] {
        let set = gameParticipations as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.game?.timestamp ?? Date()) > ($1.game?.timestamp ?? Date()) }
    }
    
    var aliasesArray: [PlayerAlias] {
        let set = aliases as? Set<PlayerAlias> ?? []
        return set.sorted { $0.aliasName < $1.aliasName }
    }
    
    var allKnownNames: [String] {
        var names = [displayName]
        names.append(contentsOf: aliasesArray.map { $0.aliasName })
        return Array(Set(names)) // Убрать дубликаты
    }
}

// MARK: - Statistics Update
extension PlayerProfile {
    /// Пересчитать статистику из игр
    func recalculateStatistics() {
        let participations = gameParticipationsArray
        
        totalGamesPlayed = Int32(participations.count)
        
        let buyinsSum = participations.reduce(Decimal(0)) { $0 + ($1.buyin as Decimal? ?? 0) }
        totalBuyins = NSDecimalNumber(decimal: buyinsSum)
        
        let cashoutsSum = participations.reduce(Decimal(0)) { $0 + ($1.cashout as Decimal? ?? 0) }
        totalCashouts = NSDecimalNumber(decimal: cashoutsSum)
    }
    
    /// Обновить статистику при добавлении игры
    func addGameStatistics(buyin: Decimal, cashout: Decimal) {
        totalGamesPlayed += 1
        totalBuyins = NSDecimalNumber(decimal: (totalBuyins as Decimal) + buyin)
        totalCashouts = NSDecimalNumber(decimal: (totalCashouts as Decimal) + cashout)
    }
}

// MARK: - Collection Helpers
extension PlayerProfile {
    @objc(addAliasesObject:)
    @NSManaged public func addToAliases(_ value: PlayerAlias)

    @objc(removeAliasesObject:)
    @NSManaged public func removeFromAliases(_ value: PlayerAlias)

    @objc(addAliases:)
    @NSManaged public func addToAliases(_ values: NSSet)

    @objc(removeAliases:)
    @NSManaged public func removeFromAliases(_ values: NSSet)
    
    @objc(addGameParticipationsObject:)
    @NSManaged public func addToGameParticipations(_ value: GameWithPlayer)

    @objc(removeGameParticipationsObject:)
    @NSManaged public func removeFromGameParticipations(_ value: GameWithPlayer)

    @objc(addGameParticipations:)
    @NSManaged public func addToGameParticipations(_ values: NSSet)

    @objc(removeGameParticipations:)
    @NSManaged public func removeFromGameParticipations(_ values: NSSet)
}

// MARK: - GameWithPlayer Extension
extension GameWithPlayer {
    var profit: Decimal {
        (cashout as Decimal? ?? 0) - (buyin as Decimal? ?? 0)
    }
}
```

### 6. Добавить методы в Persistence.swift

```swift
extension PersistenceController {
    // MARK: - PlayerProfile Management
    
    func createPlayerProfile(
        displayName: String,
        userId: UUID? = nil
    ) -> PlayerProfile {
        let context = container.viewContext
        let profile = PlayerProfile(context: context)
        profile.profileId = UUID()
        profile.displayName = displayName
        profile.userId = userId
        profile.isAnonymous = (userId == nil)
        profile.createdAt = Date()
        profile.totalGamesPlayed = 0
        profile.totalBuyins = 0
        profile.totalCashouts = 0
        
        // Связать с пользователем если указан
        if let userId = userId,
           let user = fetchUser(byId: userId) {
            profile.user = user
            user.playerProfile = profile
        }
        
        saveContext()
        return profile
    }
    
    func fetchPlayerProfile(byUserId userId: UUID) -> PlayerProfile? {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching player profile: \(error)")
            return nil
        }
    }
    
    func fetchPlayerProfile(byProfileId profileId: UUID) -> PlayerProfile? {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        request.predicate = NSPredicate(format: "profileId == %@", profileId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching player profile: \(error)")
            return nil
        }
    }
    
    func fetchAllPlayerProfiles() -> [PlayerProfile] {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerProfile.displayName, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching profiles: \(error)")
            return []
        }
    }
    
    func fetchAnonymousProfiles() -> [PlayerProfile] {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        request.predicate = NSPredicate(format: "isAnonymous == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerProfile.totalGamesPlayed, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching anonymous profiles: \(error)")
            return []
        }
    }
    
    func linkProfileToUser(profile: PlayerProfile, userId: UUID) {
        guard let user = fetchUser(byId: userId) else {
            print("User not found")
            return
        }
        
        profile.userId = userId
        profile.user = user
        profile.isAnonymous = false
        user.playerProfile = profile
        
        saveContext()
    }
}
```

---

## Тестирование

### Unit тесты

Создайте `PlayerProfileTests.swift`:

```swift
import XCTest
import CoreData
@testable import PokerCardRecognizer

final class PlayerProfileTests: XCTestCase {
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testCreateAnonymousProfile() {
        let profile = persistenceController.createPlayerProfile(
            displayName: "Антон"
        )
        
        XCTAssertNotNil(profile.profileId)
        XCTAssertEqual(profile.displayName, "Антон")
        XCTAssertTrue(profile.isAnonymous)
        XCTAssertNil(profile.userId)
        XCTAssertEqual(profile.totalGamesPlayed, 0)
    }
    
    func testCreateLinkedProfile() {
        let user = persistenceController.createUser(
            username: "testuser",
            passwordHash: "hash"
        )
        
        let profile = persistenceController.createPlayerProfile(
            displayName: "Test User",
            userId: user?.userId
        )
        
        XCTAssertFalse(profile.isAnonymous)
        XCTAssertEqual(profile.userId, user?.userId)
        XCTAssertEqual(profile.user?.userId, user?.userId)
    }
    
    func testLinkAnonymousProfileToUser() {
        // Создать анонимный профиль
        let profile = persistenceController.createPlayerProfile(
            displayName: "Mysterious Player"
        )
        XCTAssertTrue(profile.isAnonymous)
        
        // Создать пользователя
        let user = persistenceController.createUser(
            username: "revealed",
            passwordHash: "hash"
        )!
        
        // Связать
        persistenceController.linkProfileToUser(
            profile: profile,
            userId: user.userId
        )
        
        XCTAssertFalse(profile.isAnonymous)
        XCTAssertEqual(profile.userId, user.userId)
    }
    
    func testCalculateStatistics() {
        let profile = persistenceController.createPlayerProfile(
            displayName: "Stats Test"
        )
        
        // Добавить игровую статистику
        profile.addGameStatistics(buyin: 100, cashout: 150)
        profile.addGameStatistics(buyin: 200, cashout: 180)
        
        XCTAssertEqual(profile.totalGamesPlayed, 2)
        XCTAssertEqual(profile.totalBuyins as Decimal, 300)
        XCTAssertEqual(profile.totalCashouts as Decimal, 330)
        XCTAssertEqual(profile.balance, 30)
        XCTAssertEqual(profile.averageProfit, 15)
    }
    
    func testFetchAnonymousProfiles() {
        // Создать анонимный
        let anonymous = persistenceController.createPlayerProfile(
            displayName: "Anonymous"
        )
        
        // Создать связанный
        let user = persistenceController.createUser(
            username: "linked",
            passwordHash: "hash"
        )
        let linked = persistenceController.createPlayerProfile(
            displayName: "Linked",
            userId: user?.userId
        )
        
        let anonymousProfiles = persistenceController.fetchAnonymousProfiles()
        
        XCTAssertTrue(anonymousProfiles.contains(anonymous))
        XCTAssertFalse(anonymousProfiles.contains(linked))
    }
}
```

---

## Критерии приемки

- [ ] Сущность PlayerProfile создана в CoreData
- [ ] Все атрибуты добавлены с правильными типами
- [ ] Relationships настроены (User, PlayerAlias, GameWithPlayer)
- [ ] Computed properties для статистики работают
- [ ] Helper методы добавлены в Persistence.swift
- [ ] Unit тесты написаны и проходят
- [ ] Нет compiler errors

---

## Возможные проблемы

### Проблема: Decimal operations не работают

**Решение:**
- Используйте `as Decimal` для NSDecimalNumber
- Импортируйте Foundation

### Проблема: Relationship не синхронизируется

**Решение:**
- Проверьте inverse relationships
- Убедитесь что save() вызывается

---

## Следующие шаги

После завершения переходите к:
- **Task 1.4:** Создание модели PlayerAlias
- **Task 2.1:** UI для связывания профилей (Phase 2)

---

## Заметки

- PlayerProfile - центральная концепция для унификации игроков
- Кеширование статистики улучшает производительность
- В Phase 2 будем создавать PlayerAlias для разных имен одного профиля

# Task 1.4: Создание модели PlayerAlias

**Приоритет:** 🟠 Высокий  
**Срок:** 1-2 дня  
**Статус:** ⬜ TODO  

---

## Описание

Создать модель PlayerAlias для хранения различных псевдонимов одного игрока. Это позволит связывать игры с разными именами ("Антон", "Anton", "Антоха") в один профиль.

---

## Предусловия

- ✅ Task 1.3 завершена (модель PlayerProfile создана)

---

## Концепция

```
PlayerProfile
    ├─ Alias: "Антон" (claimed 2024-01-15)
    ├─ Alias: "Anton" (claimed 2024-01-20)
    └─ Alias: "Антоха" (claimed 2024-02-01)
```

---

## Задачи

### 1. Создать сущность PlayerAlias в CoreData

Откройте `.xcdatamodeld` и создайте Entity `PlayerAlias`.

### 2. Добавить атрибуты

| Атрибут | Тип | Optional | Default | Описание |
|---------|-----|----------|---------|----------|
| `aliasId` | UUID | NO | UUID | Уникальный ID |
| `profileId` | UUID | NO | - | ID профиля |
| `aliasName` | String | NO | - | Имя псевдонима |
| `claimedAt` | Date | NO | current | Когда присвоен |
| `gamesCount` | Int32 | NO | 0 | Количество игр с этим именем |

### 3. Создать relationships

**PlayerAlias → PlayerProfile:**
- `profile` (To-One, required)
- Inverse: `aliases` (в PlayerProfile)
- Delete Rule: Nullify

### 4. Добавить constraints

В Entity Inspector добавьте constraint:
- Unique constraint на `aliasName` - каждое имя может быть присвоено только одному профилю

### 5. Создать Swift файлы

`PlayerAlias+CoreDataClass.swift`:

```swift
import Foundation
import CoreData

@objc(PlayerAlias)
public class PlayerAlias: NSManagedObject {
    // Managed object subclass
}
```

`PlayerAlias+CoreDataProperties.swift`:

```swift
import Foundation
import CoreData

extension PlayerAlias {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerAlias> {
        return NSFetchRequest<PlayerAlias>(entityName: "PlayerAlias")
    }

    @NSManaged public var aliasId: UUID
    @NSManaged public var profileId: UUID
    @NSManaged public var aliasName: String
    @NSManaged public var claimedAt: Date
    @NSManaged public var gamesCount: Int32
    
    // Relationships
    @NSManaged public var profile: PlayerProfile
}

// MARK: - Computed Properties
extension PlayerAlias {
    var formattedClaimedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: claimedAt)
    }
    
    var displayText: String {
        "\(aliasName) (\(gamesCount) игр)"
    }
}

// MARK: - Validation
extension PlayerAlias {
    func validateAliasName() -> Bool {
        !aliasName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

### 6. Добавить методы в Persistence.swift

```swift
extension PersistenceController {
    // MARK: - PlayerAlias Management
    
    func createAlias(
        aliasName: String,
        forProfile profile: PlayerProfile
    ) -> PlayerAlias? {
        // Проверить что имя еще не занято
        if fetchAlias(byName: aliasName) != nil {
            print("Alias '\(aliasName)' already exists")
            return nil
        }
        
        let context = container.viewContext
        let alias = PlayerAlias(context: context)
        alias.aliasId = UUID()
        alias.profileId = profile.profileId
        alias.aliasName = aliasName.trimmingCharacters(in: .whitespacesAndNewlines)
        alias.claimedAt = Date()
        alias.gamesCount = 0
        alias.profile = profile
        
        saveContext()
        return alias
    }
    
    func fetchAlias(byName name: String) -> PlayerAlias? {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        request.predicate = NSPredicate(format: "aliasName ==[c] %@", name)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching alias: \(error)")
            return nil
        }
    }
    
    func fetchAliases(forProfile profile: PlayerProfile) -> [PlayerAlias] {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        request.predicate = NSPredicate(format: "profileId == %@", profile.profileId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerAlias.claimedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching aliases: \(error)")
            return []
        }
    }
    
    func fetchAllUniquePlayerNames() -> [String] {
        // Получить все уникальные имена из Player (старая модель)
        // Это будет использоваться для UI "Claim player"
        let context = container.viewContext
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        
        do {
            let players = try context.fetch(request)
            let names = players.compactMap { $0.name }
            return Array(Set(names)).sorted()
        } catch {
            print("Error fetching player names: \(error)")
            return []
        }
    }
    
    func fetchUnclaimedPlayerNames() -> [String] {
        // Получить имена игроков, которые еще не присвоены
        let allNames = fetchAllUniquePlayerNames()
        
        // Получить уже присвоенные имена
        let context = container.viewContext
        let request: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        
        do {
            let aliases = try context.fetch(request)
            let claimedNames = Set(aliases.map { $0.aliasName })
            
            return allNames.filter { !claimedNames.contains($0) }
        } catch {
            print("Error fetching unclaimed names: \(error)")
            return allNames
        }
    }
    
    func updateAliasGamesCount(_ alias: PlayerAlias) {
        // Подсчитать игры с этим именем из старых Player записей
        let context = container.viewContext
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", alias.aliasName)
        
        do {
            let count = try context.count(for: request)
            alias.gamesCount = Int32(count)
            saveContext()
        } catch {
            print("Error counting games: \(error)")
        }
    }
}
```

### 7. Добавить утилиты для fuzzy matching

Создайте новый файл `StringSimilarity.swift`:

```swift
import Foundation

extension String {
    /// Вычислить расстояние Левенштейна между строками
    func levenshteinDistance(to other: String) -> Int {
        let m = self.count
        let n = other.count
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let cost = self[self.index(self.startIndex, offsetBy: i - 1)] == 
                          other[other.index(other.startIndex, offsetBy: j - 1)] ? 0 : 1
                
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
    
    /// Проверить схожесть с другой строкой (0.0 - 1.0)
    func similarity(to other: String) -> Double {
        let distance = levenshteinDistance(to: other)
        let maxLength = max(self.count, other.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Найти похожие строки из массива
    func findSimilar(in strings: [String], threshold: Double = 0.7) -> [String] {
        strings.filter { similarity(to: $0) >= threshold }
    }
}

// MARK: - Player Name Suggestions
struct PlayerNameMatcher {
    static func suggestSimilarNames(for name: String, from allNames: [String]) -> [String] {
        let lowercasedName = name.lowercased()
        
        // 1. Точное совпадение (case-insensitive)
        let exactMatches = allNames.filter { $0.lowercased() == lowercasedName }
        if !exactMatches.isEmpty {
            return exactMatches
        }
        
        // 2. Начинается с...
        let prefixMatches = allNames.filter { $0.lowercased().hasPrefix(lowercasedName) }
        if !prefixMatches.isEmpty {
            return prefixMatches
        }
        
        // 3. Fuzzy matching
        let similarNames = allNames.filter { name.similarity(to: $0) >= 0.7 }
        return similarNames.sorted { name.similarity(to: $0) > name.similarity(to: $1) }
    }
}
```

---

## Тестирование

### Unit тесты

`PlayerAliasTests.swift`:

```swift
import XCTest
import CoreData
@testable import PokerCardRecognizer

final class PlayerAliasTests: XCTestCase {
    var persistenceController: PersistenceController!
    var testProfile: PlayerProfile!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        testProfile = persistenceController.createPlayerProfile(displayName: "Test Player")
    }
    
    override func tearDown() {
        testProfile = nil
        persistenceController = nil
        super.tearDown()
    }
    
    func testCreateAlias() {
        let alias = persistenceController.createAlias(
            aliasName: "Антон",
            forProfile: testProfile
        )
        
        XCTAssertNotNil(alias)
        XCTAssertEqual(alias?.aliasName, "Антон")
        XCTAssertEqual(alias?.profileId, testProfile.profileId)
        XCTAssertEqual(alias?.gamesCount, 0)
    }
    
    func testDuplicateAlias() {
        // Создать первый alias
        let alias1 = persistenceController.createAlias(
            aliasName: "Duplicate",
            forProfile: testProfile
        )
        XCTAssertNotNil(alias1)
        
        // Попытаться создать дубликат
        let otherProfile = persistenceController.createPlayerProfile(displayName: "Other")
        let alias2 = persistenceController.createAlias(
            aliasName: "Duplicate",
            forProfile: otherProfile
        )
        
        XCTAssertNil(alias2, "Duplicate alias should not be created")
    }
    
    func testFetchAliases() {
        // Создать несколько aliases
        let _ = persistenceController.createAlias(aliasName: "Anton", forProfile: testProfile)
        let _ = persistenceController.createAlias(aliasName: "Антон", forProfile: testProfile)
        let _ = persistenceController.createAlias(aliasName: "Tosha", forProfile: testProfile)
        
        let aliases = persistenceController.fetchAliases(forProfile: testProfile)
        
        XCTAssertEqual(aliases.count, 3)
    }
    
    func testStringSimilarity() {
        XCTAssertEqual("Anton".similarity(to: "Anton"), 1.0)
        XCTAssertGreaterThan("Anton".similarity(to: "Антон"), 0.0)
        XCTAssertGreaterThan("Anton".similarity(to: "Antony"), 0.8)
    }
    
    func testFindSimilarNames() {
        let names = ["Anton", "Антон", "Antony", "John", "Антоха"]
        let similar = "Anton".findSimilar(in: names, threshold: 0.6)
        
        XCTAssertTrue(similar.contains("Anton"))
        XCTAssertTrue(similar.contains("Antony"))
        XCTAssertFalse(similar.contains("John"))
    }
    
    func testSuggestSimilarNames() {
        let allNames = ["Anton", "Антон", "ANTON", "Antony", "John"]
        let suggestions = PlayerNameMatcher.suggestSimilarNames(for: "anton", from: allNames)
        
        XCTAssertTrue(suggestions.contains("Anton"))
        XCTAssertTrue(suggestions.contains("ANTON"))
        XCTAssertTrue(suggestions.contains("Антон"))
    }
}
```

---

## Критерии приемки

- [ ] Сущность PlayerAlias создана
- [ ] Атрибуты добавлены с unique constraint
- [ ] Relationship с PlayerProfile настроен
- [ ] Helper методы в Persistence.swift работают
- [ ] StringSimilarity утилиты реализованы
- [ ] Unit тесты проходят
- [ ] Нет compiler errors

---

## Возможные проблемы

### Проблема: Duplicate alias создается несмотря на constraint

**Решение:**
- Проверьте что constraint добавлен в CoreData модели
- Добавьте программную проверку в `createAlias`

### Проблема: Case-sensitive сравнение

**Решение:**
- Используйте `==[c]` в NSPredicate для case-insensitive

---

## Следующие шаги

После завершения переходите к:
- **Task 2.1:** Создание UI для связывания профилей (Phase 2)
- **Task 1.5:** Обновление AuthViewModel

---

## Заметки

- Fuzzy matching поможет найти похожие имена автоматически
- В будущем можно добавить ML для улучшения suggestions
- Case-insensitive сравнение важно для русских имен

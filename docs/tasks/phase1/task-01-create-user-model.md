# Task 1.1: Создание модели User в CoreData

**Приоритет:** 🔴 Критический  
**Срок:** 2-3 дня  
**Статус:** 🟩 DONE  

---

## Описание

Создать новую сущность User в CoreData для управления пользователями приложения. Это базовая модель для всей системы аутентификации и персонализации.

---

## Предусловия

- Текущий проект PokerCardRecognizer открыт в Xcode
- Файл `Persistence.swift` существует
- CoreData model файл (`.xcdatamodeld`) доступен

---

## Задачи

### 1. Создать сущность User в CoreData модели

Откройте `.xcdatamodeld` файл и создайте новую Entity с именем `User`.

### 2. Добавить атрибуты

Добавьте следующие атрибуты к сущности User:

| Атрибут | Тип | Optional | Описание |
|---------|-----|----------|----------|
| `userId` | UUID | NO | Primary key, уникальный идентификатор |
| `username` | String | NO | Имя пользователя для входа |
| `email` | String | YES | Email (опционально) |
| `passwordHash` | String | NO | Хеш пароля |
| `createdAt` | Date | NO | Дата создания аккаунта |
| `lastLoginAt` | Date | YES | Последний вход |
| `subscriptionStatus` | String | NO | Статус подписки: "free" или "premium" |
| `subscriptionExpiresAt` | Date | YES | Дата окончания подписки |

### 3. Настроить атрибуты

- `userId`: установить "Default Value" = UUID
- `username`: установить "Unique" constraint
- `subscriptionStatus`: установить "Default Value" = "free"
- `createdAt`: установить "Default Value" = current date

### 4. Создать Swift класс для User entity

Создайте новый файл `User+CoreDataClass.swift`:

```swift
import Foundation
import CoreData

@objc(User)
public class User: NSManagedObject {
    // Managed object subclass
}
```

### 5. Создать расширение с computed properties

Создайте файл `User+CoreDataProperties.swift`:

```swift
import Foundation
import CoreData

extension User {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var userId: UUID
    @NSManaged public var username: String
    @NSManaged public var email: String?
    @NSManaged public var passwordHash: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastLoginAt: Date?
    @NSManaged public var subscriptionStatus: String
    @NSManaged public var subscriptionExpiresAt: Date?
    
    // Relationships (будут добавлены позже)
    @NSManaged public var createdGames: NSSet?
}

// MARK: - Computed Properties
extension User {
    var isPremium: Bool {
        guard subscriptionStatus == "premium" else { return false }
        guard let expiresAt = subscriptionExpiresAt else { return false }
        return expiresAt > Date()
    }
    
    var isSubscriptionExpired: Bool {
        guard let expiresAt = subscriptionExpiresAt else { return false }
        return expiresAt <= Date()
    }
    
    var displayName: String {
        username
    }
}

// MARK: - Collection Helpers
extension User {
    @objc(addCreatedGamesObject:)
    @NSManaged public func addToCreatedGames(_ value: Game)

    @objc(removeCreatedGamesObject:)
    @NSManaged public func removeFromCreatedGames(_ value: Game)

    @objc(addCreatedGames:)
    @NSManaged public func addToCreatedGames(_ values: NSSet)

    @objc(removeCreatedGames:)
    @NSManaged public func removeFromCreatedGames(_ values: NSSet)
}
```

### 6. Обновить Persistence.swift

Добавьте helper методы для работы с User:

```swift
extension PersistenceController {
    // MARK: - User Management
    
    func createUser(username: String, passwordHash: String, email: String? = nil) -> User? {
        let context = container.viewContext
        let user = User(context: context)
        user.userId = UUID()
        user.username = username
        user.passwordHash = passwordHash
        user.email = email
        user.createdAt = Date()
        user.subscriptionStatus = "free"
        
        do {
            try context.save()
            return user
        } catch {
            print("Error creating user: \(error)")
            return nil
        }
    }
    
    func fetchUser(byUsername username: String) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", username)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
    func fetchUser(byId userId: UUID) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
    func updateUserLastLogin(_ user: User) {
        user.lastLoginAt = Date()
        saveContext()
    }
    
    func updateUserSubscription(_ user: User, status: String, expiresAt: Date?) {
        user.subscriptionStatus = status
        user.subscriptionExpiresAt = expiresAt
        saveContext()
    }
    
    private func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}
```

### 7. Создать миграционную политику (если нужно)

Если в приложении уже есть данные, создайте mapping model для миграции.

---

## Тестирование

### Ручное тестирование

```swift
// В любом месте где есть доступ к PersistenceController
let persistence = PersistenceController.shared

// Создать тестового пользователя
let testUser = persistence.createUser(
    username: "testuser",
    passwordHash: "hashedpassword123",
    email: "test@example.com"
)

// Проверить что пользователь создан
if let user = testUser {
    print("User created: \(user.username)")
    print("User ID: \(user.userId)")
    print("Is premium: \(user.isPremium)")
}

// Получить пользователя
if let fetchedUser = persistence.fetchUser(byUsername: "testuser") {
    print("User found: \(fetchedUser.username)")
    
    // Обновить последний вход
    persistence.updateUserLastLogin(fetchedUser)
}
```

### Unit тесты

Создайте файл `UserModelTests.swift`:

```swift
import XCTest
import CoreData
@testable import PokerCardRecognizer

final class UserModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        // Используем in-memory store для тестов
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testCreateUser() {
        let user = persistenceController.createUser(
            username: "testuser",
            passwordHash: "hash123"
        )
        
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.username, "testuser")
        XCTAssertEqual(user?.subscriptionStatus, "free")
        XCTAssertFalse(user?.isPremium ?? true)
    }
    
    func testFetchUser() {
        // Создать
        let createdUser = persistenceController.createUser(
            username: "fetchtest",
            passwordHash: "hash"
        )
        XCTAssertNotNil(createdUser)
        
        // Получить
        let fetchedUser = persistenceController.fetchUser(byUsername: "fetchtest")
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.userId, createdUser?.userId)
    }
    
    func testUserPremiumStatus() {
        let user = persistenceController.createUser(
            username: "premiumuser",
            passwordHash: "hash"
        )
        
        XCTAssertFalse(user?.isPremium ?? true)
        
        // Установить премиум
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        persistenceController.updateUserSubscription(
            user!,
            status: "premium",
            expiresAt: futureDate
        )
        
        XCTAssertTrue(user?.isPremium ?? false)
    }
    
    func testUserSubscriptionExpiration() {
        let user = persistenceController.createUser(
            username: "expireduser",
            passwordHash: "hash"
        )
        
        // Установить истекшую подписку
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        persistenceController.updateUserSubscription(
            user!,
            status: "premium",
            expiresAt: pastDate
        )
        
        XCTAssertTrue(user?.isSubscriptionExpired ?? false)
        XCTAssertFalse(user?.isPremium ?? true)
    }
}
```

---

## Критерии приемки

- [ ] Сущность User создана в CoreData модели
- [ ] Все 8 атрибутов добавлены с правильными типами
- [ ] Файлы `User+CoreDataClass.swift` и `User+CoreDataProperties.swift` созданы
- [ ] Helper методы добавлены в `Persistence.swift`
- [ ] Computed properties `isPremium`, `isSubscriptionExpired` работают корректно
- [ ] Unit тесты написаны и проходят успешно
- [ ] Нет compiler warnings или errors
- [ ] Приложение запускается без crashes

---

## Возможные проблемы

### Проблема: Ошибка миграции существующей БД

**Решение:** 
- Создайте mapping model в Xcode
- Или используйте lightweight migration
- Или удалите существующую БД (только для dev)

### Проблема: Username не unique

**Решение:**
- В CoreData модели добавьте constraint в Entity Editor
- Добавьте проверку в `createUser` перед сохранением

---

## Следующие шаги

После завершения этой задачи переходите к:
- **Task 1.2:** Расширение модели Game для связи с User
- **Task 1.5:** Обновление AuthViewModel для работы с User

---

## Заметки

- Храните passwordHash, а не сам пароль
- В следующих задачах добавим хеширование через CryptoKit
- Subscriptio status будет использоваться в Phase 4 для монетизации

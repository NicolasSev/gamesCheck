import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Добавляем тестовые игры в Core Data
        for _ in 0..<10 {
            let newGame = Game(context: viewContext)
            newGame.timestamp = Date()
            newGame.gameId = UUID()
            newGame.isDeleted = false
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PokerCardRecognizer") // Убедись, что имя совпадает с .xcdatamodeld
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

// MARK: - Convenience Save
extension PersistenceController {
    fileprivate func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

// MARK: - User Management (Task 1.1)
extension PersistenceController {
    func createUser(username: String, passwordHash: String, email: String? = nil) -> User? {
        let context = container.viewContext

        // Быстрая проверка уникальности username (дополнительно к CoreData constraint)
        if fetchUser(byUsername: username) != nil {
            print("Error creating user: username '\(username)' already exists")
            return nil
        }

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
            return try context.fetch(request).first
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
            return try context.fetch(request).first
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
}

// MARK: - Game Management (Task 1.2)
extension PersistenceController {
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

    /// Миграция существующих игр после добавления новых полей (Task 1.2)
    /// Вызывать один раз при первом запуске после обновления.
    func migrateExistingGames() {
        let context = container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()

        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")

        do {
            let games = try context.fetch(request)
            var migratedCount = 0

            for game in games {
                if let zeroUUID, game.gameId == zeroUUID {
                    game.gameId = UUID()
                    migratedCount += 1
                }

                // Установить isDeleted по умолчанию
                // (после миграции он уже должен быть false через defaultValueString)
                if game.isDeleted != true {
                    game.isDeleted = false
                }
            }

            if context.hasChanges {
                try context.save()
            }

            if migratedCount > 0 {
                print("Migrated \(migratedCount) existing games (assigned gameId)")
            }
        } catch {
            print("Error migrating games: \(error)")
        }
    }
}

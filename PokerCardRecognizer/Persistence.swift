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

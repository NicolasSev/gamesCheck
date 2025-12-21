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

// MARK: - PlayerProfile Management (Task 1.3)
extension PersistenceController {
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

// MARK: - PlayerAlias Management (Task 1.4)
extension PersistenceController {
    func createAlias(
        aliasName: String,
        forProfile profile: PlayerProfile
    ) -> PlayerAlias? {
        let trimmed = aliasName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Проверить что имя еще не занято
        if fetchAlias(byName: trimmed) != nil {
            print("Alias '\(trimmed)' already exists")
            return nil
        }

        let context = container.viewContext
        let alias = PlayerAlias(context: context)
        alias.aliasId = UUID()
        alias.profileId = profile.profileId
        alias.aliasName = trimmed
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
        // Подсчитать "использования" имени в старой таблице Player
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

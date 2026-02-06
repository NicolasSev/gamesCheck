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
            newGame.softDeleted = false
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
        container = NSPersistentContainer(name: "FishAndChips") // Убедись, что имя совпадает с .xcdatamodeld
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Включаем lightweight migration для автоматической миграции совместимых изменений
            let description = container.persistentStoreDescriptions.first
            description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: NSError?
        var storeURL: URL?
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                loadError = error
                storeURL = description.url
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        // Если была ошибка миграции схемы (134110), удаляем старую базу и пытаемся загрузить снова
        if let error = loadError, error.code == 134110, let url = storeURL {
            print("Core Data migration error detected (code 134110). Removing old database...")
            removeOldDatabaseFiles(at: url)
            
            // Пытаемся загрузить снова после удаления файлов
            let retrySemaphore = DispatchSemaphore(value: 0)
            var retryError: NSError?
            
            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    retryError = error
                } else {
                    print("Successfully recreated database after migration")
                }
                retrySemaphore.signal()
            }
            
            retrySemaphore.wait()
            
            if let error = retryError {
                fatalError("Failed to recreate database after migration error: \(error), \(error.userInfo)")
            }
        } else if let error = loadError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
    
    private func removeOldDatabaseFiles(at url: URL) {
        let fileManager = FileManager.default
        let storeDirectory = url.deletingLastPathComponent()
        let storeName = url.deletingPathExtension().lastPathComponent
        
        // Удаляем все файлы базы данных (sqlite, sqlite-wal, sqlite-shm)
        do {
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            for file in storeFiles {
                let fileName = file.deletingPathExtension().lastPathComponent
                if fileName == storeName && (file.pathExtension == "sqlite" || file.pathExtension == "sqlite-wal" || file.pathExtension == "sqlite-shm") {
                    try fileManager.removeItem(at: file)
                    print("Removed old database file: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("Warning: Failed to remove some old database files: \(error)")
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
        
        // Проверка уникальности email если указан
        if let email = email, !email.isEmpty {
            if fetchUser(byEmail: email) != nil {
                print("Error creating user: email '\(email)' already exists")
                return nil
            }
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
    
    func fetchUser(byEmail email: String) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email ==[c] %@", email)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching user by email: \(error)")
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
    
    func updateUsername(_ user: User, newUsername: String) -> Bool {
        // Проверить, не занято ли имя
        if let existingUser = fetchUser(byUsername: newUsername),
           existingUser.userId != user.userId {
            return false
        }
        user.username = newUsername
        saveContext()
        return true
    }
    
    func setSuperAdmin(username: String, isSuperAdmin: Bool) {
        guard let user = fetchUser(byUsername: username) else { return }
        user.isSuperAdmin = isSuperAdmin
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

    func fetchAlias(byId aliasId: UUID) -> PlayerAlias? {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()
        request.predicate = NSPredicate(format: "aliasId == %@", aliasId as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching alias by ID: \(error)")
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
    
    // Получаем все уникальные имена игроков (без учета регистра) и информацию о привязке к пользователям
    func fetchAllUniquePlayerNamesWithInfo() -> [(name: String, userId: UUID?, isLinked: Bool)] {
        let context = container.viewContext
        
        // Получаем всех игроков из Player
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.propertiesToFetch = ["name"]
        
        // Получаем все PlayerProfile с userId
        let profileRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "userId != nil")
        
        var uniqueNames: [String: (userId: UUID?, isLinked: Bool)] = [:]
        
        do {
            // Добавляем имена из Player
            let players = try context.fetch(playerRequest)
            for player in players {
                if let name = player.name, !name.isEmpty {
                    let lowercasedName = name.lowercased()
                    if uniqueNames[lowercasedName] == nil {
                        uniqueNames[lowercasedName] = (nil, false)
                    }
                }
            }
            
            // Добавляем имена из PlayerProfile и помечаем как привязанные
            let profiles = try context.fetch(profileRequest)
            for profile in profiles {
                let lowercasedName = profile.displayName.lowercased()
                uniqueNames[lowercasedName] = (profile.userId, true)
            }
            
            // Преобразуем в массив, сохраняя оригинальное имя (первое найденное)
            var nameMap: [String: String] = [:] // lowercase -> original
            
            // Сначала собираем оригинальные имена из Player
            for player in players {
                if let name = player.name, !name.isEmpty {
                    let lowercasedName = name.lowercased()
                    if nameMap[lowercasedName] == nil {
                        nameMap[lowercasedName] = name
                    }
                }
            }
            
            // Затем из PlayerProfile
            for profile in profiles {
                let lowercasedName = profile.displayName.lowercased()
                if nameMap[lowercasedName] == nil {
                    nameMap[lowercasedName] = profile.displayName
                }
            }
            
            // Создаем результат
            return uniqueNames.map { (lowercased, info) in
                (name: nameMap[lowercased] ?? lowercased, userId: info.userId, isLinked: info.isLinked)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        } catch {
            print("Error fetching unique player names with info: \(error)")
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
        game.softDeleted = false

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
            format: "creatorUserId == %@ AND softDeleted == NO",
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
        request.predicate = NSPredicate(format: "softDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching games: \(error)")
            return []
        }
    }

    func fetchGame(byId gameId: UUID) -> Game? {
        let context = container.viewContext
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching game by id: \(error)")
            return nil
        }
    }

    func fetchGameWithPlayer(byId gwpId: UUID) -> GameWithPlayer? {
        let context = container.viewContext
        let request: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        request.predicate = NSPredicate(format: "gameWithPlayerId == %@", gwpId as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching GameWithPlayer by id: \(error)")
            return nil
        }
    }

    func softDeleteGame(_ game: Game) {
        game.softDeleted = true
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

                // Установить softDeleted по умолчанию
                // (после миграции он уже должен быть false через defaultValueString)
                let gameSoftDeleted = game.value(forKey: "softDeleted") as? Bool ?? false
                if !gameSoftDeleted {
                    game.setValue(false, forKey: "softDeleted")
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

// MARK: - PlayerClaim Management
extension PersistenceController {
    func createPlayerClaim(
        gameWithPlayer: GameWithPlayer,
        claimantUserId: UUID
    ) -> PlayerClaim? {
        let context = container.viewContext
        
        guard let game = gameWithPlayer.game,
              let player = gameWithPlayer.player,
              let playerName = player.name,
              let hostUserId = game.creatorUserId else {
            return nil
        }
        
        let claim = PlayerClaim(context: context)
        claim.claimId = UUID()
        claim.playerName = playerName
        claim.gameId = game.gameId
        claim.gameWithPlayerObjectId = gameWithPlayer.objectID.uriRepresentation().absoluteString
        claim.claimantUserId = claimantUserId
        claim.hostUserId = hostUserId
        claim.status = "pending"
        claim.createdAt = Date()
        claim.claimantUser = fetchUser(byId: claimantUserId)
        claim.hostUser = fetchUser(byId: hostUserId)
        claim.game = game
        
        saveContext()
        return claim
    }
    
    func fetchPlayerClaim(byId claimId: UUID) -> PlayerClaim? {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching player claim: \(error)")
            return nil
        }
    }
    
    func fetchPendingClaimsForHost(hostUserId: UUID) -> [PlayerClaim] {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "hostUserId == %@ AND status == %@", hostUserId as CVarArg, "pending")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerClaim.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching pending claims: \(error)")
            return []
        }
    }
    
    func fetchMyClaims(userId: UUID) -> [PlayerClaim] {
        let context = container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimantUserId == %@", userId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerClaim.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching my claims: \(error)")
            return []
        }
    }
}

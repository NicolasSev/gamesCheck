import CoreData

// MARK: - Game Management
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
            debugLog("Error fetching games: \(error)")
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
            debugLog("Error fetching games: \(error)")
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
            debugLog("Error fetching game by id: \(error)")
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
            debugLog("Error fetching GameWithPlayer by id: \(error)")
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

    /// Миграция существующих игр после добавления новых полей.
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

                let gameSoftDeleted = game.value(forKey: "softDeleted") as? Bool ?? false
                if !gameSoftDeleted {
                    game.setValue(false, forKey: "softDeleted")
                }
            }

            if context.hasChanges {
                try context.save()
            }

            if migratedCount > 0 {
                debugLog("Migrated \(migratedCount) existing games (assigned gameId)")
            }
        } catch {
            debugLog("Error migrating games: \(error)")
        }
    }
}

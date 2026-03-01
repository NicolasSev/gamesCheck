import CoreData

// MARK: - PlayerAlias Management
extension PersistenceController {
    func createAlias(
        aliasName: String,
        forProfile profile: PlayerProfile
    ) -> PlayerAlias? {
        let trimmed = aliasName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if fetchAlias(byName: trimmed) != nil {
            debugLog("Alias '\(trimmed)' already exists")
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
            debugLog("Error fetching alias: \(error)")
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
            debugLog("Error fetching alias by ID: \(error)")
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
            debugLog("Error fetching aliases: \(error)")
            return []
        }
    }

    func fetchAllUniquePlayerNames() -> [String] {
        let context = container.viewContext
        let request: NSFetchRequest<Player> = Player.fetchRequest()

        do {
            let players = try context.fetch(request)
            let names = players.compactMap { $0.name }
            return Array(Set(names)).sorted()
        } catch {
            debugLog("Error fetching player names: \(error)")
            return []
        }
    }
    
    func fetchAllUniquePlayerNamesWithInfo() -> [(name: String, userId: UUID?, isLinked: Bool)] {
        let context = container.viewContext
        
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.propertiesToFetch = ["name"]
        
        let profileRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "userId != nil")
        
        var uniqueNames: [String: (userId: UUID?, isLinked: Bool)] = [:]
        
        do {
            let players = try context.fetch(playerRequest)
            for player in players {
                if let name = player.name, !name.isEmpty {
                    let lowercasedName = name.lowercased()
                    if uniqueNames[lowercasedName] == nil {
                        uniqueNames[lowercasedName] = (nil, false)
                    }
                }
            }
            
            let profiles = try context.fetch(profileRequest)
            for profile in profiles {
                let lowercasedName = profile.displayName.lowercased()
                uniqueNames[lowercasedName] = (profile.userId, true)
            }
            
            var nameMap: [String: String] = [:]
            
            for player in players {
                if let name = player.name, !name.isEmpty {
                    let lowercasedName = name.lowercased()
                    if nameMap[lowercasedName] == nil {
                        nameMap[lowercasedName] = name
                    }
                }
            }
            
            for profile in profiles {
                let lowercasedName = profile.displayName.lowercased()
                if nameMap[lowercasedName] == nil {
                    nameMap[lowercasedName] = profile.displayName
                }
            }
            
            return uniqueNames.map { (lowercased, info) in
                (name: nameMap[lowercased] ?? lowercased, userId: info.userId, isLinked: info.isLinked)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        } catch {
            debugLog("Error fetching unique player names with info: \(error)")
            return []
        }
    }

    func fetchUnclaimedPlayerNames() -> [String] {
        let allNames = fetchAllUniquePlayerNames()

        let context = container.viewContext
        let request: NSFetchRequest<PlayerAlias> = PlayerAlias.fetchRequest()

        do {
            let aliases = try context.fetch(request)
            let claimedNames = Set(aliases.map { $0.aliasName })
            return allNames.filter { !claimedNames.contains($0) }
        } catch {
            debugLog("Error fetching unclaimed names: \(error)")
            return allNames
        }
    }

    func updateAliasGamesCount(_ alias: PlayerAlias) {
        let context = container.viewContext
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", alias.aliasName)

        do {
            let count = try context.count(for: request)
            alias.gamesCount = Int32(count)
            saveContext()
        } catch {
            debugLog("Error counting games: \(error)")
        }
    }
}

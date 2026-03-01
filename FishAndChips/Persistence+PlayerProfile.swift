import CoreData

// MARK: - PlayerProfile Management
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
            debugLog("Error fetching player profile: \(error)")
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
            debugLog("Error fetching player profile: \(error)")
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
            debugLog("Error fetching profiles: \(error)")
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
            debugLog("Error fetching anonymous profiles: \(error)")
            return []
        }
    }

    func linkProfileToUser(profile: PlayerProfile, userId: UUID) {
        guard let user = fetchUser(byId: userId) else {
            debugLog("User not found")
            return
        }

        profile.userId = userId
        profile.user = user
        profile.isAnonymous = false
        user.playerProfile = profile

        saveContext()
    }
}

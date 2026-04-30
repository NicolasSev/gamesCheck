import CoreData

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
        claim.scope = "single"
        claim.placeId = game.place?.placeId ?? game.placeId
        claim.playerKey = playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        claim.affectedGamePlayerIdsJson = "[]"
        claim.conflictProfileIdsJson = "[]"
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
            debugLog("Error fetching player claim: \(error)")
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
            debugLog("Error fetching pending claims: \(error)")
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
            debugLog("Error fetching my claims: \(error)")
            return []
        }
    }
}

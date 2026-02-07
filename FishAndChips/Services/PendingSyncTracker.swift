import Foundation

/// Сервис для отслеживания данных, которые не удалось отправить в CloudKit
class PendingSyncTracker {
    static let shared = PendingSyncTracker()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let pendingGames = "pendingCloudKitSync_games"
        static let pendingGameWithPlayers = "pendingCloudKitSync_gameWithPlayers"
        static let pendingPlayerAliases = "pendingCloudKitSync_playerAliases"
        static let pendingPlayerClaims = "pendingCloudKitSync_playerClaims"
    }
    
    // MARK: - Add Pending Items
    
    func addPendingGame(_ gameId: UUID) {
        var pending = getPendingGames()
        pending.insert(gameId)
        savePendingGames(pending)
        print("📌 [PENDING_SYNC] Added pending game: \(gameId)")
    }
    
    func addPendingGameWithPlayer(_ gwpId: UUID) {
        var pending = getPendingGameWithPlayers()
        pending.insert(gwpId)
        savePendingGameWithPlayers(pending)
        print("📌 [PENDING_SYNC] Added pending GameWithPlayer: \(gwpId)")
    }
    
    func addPendingPlayerAlias(_ aliasId: UUID) {
        var pending = getPendingPlayerAliases()
        pending.insert(aliasId)
        savePendingPlayerAliases(pending)
        print("📌 [PENDING_SYNC] Added pending PlayerAlias: \(aliasId)")
    }
    
    func addPendingPlayerClaim(_ claimId: UUID) {
        var pending = getPendingPlayerClaims()
        pending.insert(claimId)
        savePendingPlayerClaims(pending)
        print("📌 [PENDING_SYNC] Added pending PlayerClaim: \(claimId)")
    }
    
    // MARK: - Remove Pending Items (after successful sync)
    
    func removePendingGame(_ gameId: UUID) {
        var pending = getPendingGames()
        pending.remove(gameId)
        savePendingGames(pending)
        print("✅ [PENDING_SYNC] Removed pending game: \(gameId)")
    }
    
    func removePendingGameWithPlayer(_ gwpId: UUID) {
        var pending = getPendingGameWithPlayers()
        pending.remove(gwpId)
        savePendingGameWithPlayers(pending)
        print("✅ [PENDING_SYNC] Removed pending GameWithPlayer: \(gwpId)")
    }
    
    func removePendingPlayerAlias(_ aliasId: UUID) {
        var pending = getPendingPlayerAliases()
        pending.remove(aliasId)
        savePendingPlayerAliases(pending)
        print("✅ [PENDING_SYNC] Removed pending PlayerAlias: \(aliasId)")
    }
    
    func removePendingPlayerClaim(_ claimId: UUID) {
        var pending = getPendingPlayerClaims()
        pending.remove(claimId)
        savePendingPlayerClaims(pending)
        print("✅ [PENDING_SYNC] Removed pending PlayerClaim: \(claimId)")
    }
    
    // MARK: - Get Pending Items
    
    func getPendingGames() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: Keys.pendingGames),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
    
    func getPendingGameWithPlayers() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: Keys.pendingGameWithPlayers),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
    
    func getPendingPlayerAliases() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: Keys.pendingPlayerAliases),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
    
    func getPendingPlayerClaims() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: Keys.pendingPlayerClaims),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
    
    // MARK: - Check if has pending
    
    func hasPendingData() -> Bool {
        return !getPendingGames().isEmpty ||
               !getPendingGameWithPlayers().isEmpty ||
               !getPendingPlayerAliases().isEmpty ||
               !getPendingPlayerClaims().isEmpty
    }
    
    func getPendingSummary() -> String {
        let games = getPendingGames().count
        let gwp = getPendingGameWithPlayers().count
        let aliases = getPendingPlayerAliases().count
        let claims = getPendingPlayerClaims().count
        
        var summary: [String] = []
        if games > 0 { summary.append("Игры: \(games)") }
        if gwp > 0 { summary.append("Игроки: \(gwp)") }
        if aliases > 0 { summary.append("Алиасы: \(aliases)") }
        if claims > 0 { summary.append("Заявки: \(claims)") }
        
        return summary.isEmpty ? "Нет незалитых данных" : summary.joined(separator: ", ")
    }
    
    // MARK: - Private Helpers
    
    private func savePendingGames(_ pending: Set<UUID>) {
        let strings = pending.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            userDefaults.set(data, forKey: Keys.pendingGames)
        }
    }
    
    private func savePendingGameWithPlayers(_ pending: Set<UUID>) {
        let strings = pending.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            userDefaults.set(data, forKey: Keys.pendingGameWithPlayers)
        }
    }
    
    private func savePendingPlayerAliases(_ pending: Set<UUID>) {
        let strings = pending.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            userDefaults.set(data, forKey: Keys.pendingPlayerAliases)
        }
    }
    
    private func savePendingPlayerClaims(_ pending: Set<UUID>) {
        let strings = pending.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            userDefaults.set(data, forKey: Keys.pendingPlayerClaims)
        }
    }
    
    // MARK: - Clear All (for debugging)
    
    func clearAll() {
        userDefaults.removeObject(forKey: Keys.pendingGames)
        userDefaults.removeObject(forKey: Keys.pendingGameWithPlayers)
        userDefaults.removeObject(forKey: Keys.pendingPlayerAliases)
        userDefaults.removeObject(forKey: Keys.pendingPlayerClaims)
        print("🗑️ [PENDING_SYNC] Cleared all pending data")
    }
}

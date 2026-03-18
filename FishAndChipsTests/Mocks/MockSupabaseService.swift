import Foundation
@testable import FishAndChips

/// In-memory mock для SupabaseService — хранит данные в массивах
final class MockSupabaseService {
    var profiles: [UUID: ProfileDTO] = [:]
    var games: [UUID: GameDTO] = [:]
    var gamePlayers: [UUID: GamePlayerDTO] = [:]
    var aliases: [UUID: PlayerAliasDTO] = [:]
    var claims: [UUID: PlayerClaimDTO] = [:]

    var isAvailableResult = true
    var currentUserIdResult: UUID? = UUID()
    var shouldThrowError: SupabaseServiceError?

    // MARK: - Tracking calls

    var insertCalls: [(table: String, count: Int)] = []
    var upsertCalls: [(table: String, count: Int)] = []
    var fetchCalls: [(table: String, count: Int)] = []
    var deleteCalls: [(table: String, id: UUID)] = []

    func reset() {
        profiles.removeAll()
        games.removeAll()
        gamePlayers.removeAll()
        aliases.removeAll()
        claims.removeAll()
        insertCalls.removeAll()
        upsertCalls.removeAll()
        fetchCalls.removeAll()
        deleteCalls.removeAll()
        shouldThrowError = nil
    }

    // MARK: - Simulated Operations

    func upsertProfile(_ dto: ProfileDTO) throws -> ProfileDTO {
        if let error = shouldThrowError { throw error }
        profiles[dto.id] = dto
        upsertCalls.append((table: "profiles", count: 1))
        return dto
    }

    func upsertGame(_ dto: GameDTO) throws -> GameDTO {
        if let error = shouldThrowError { throw error }
        games[dto.id] = dto
        upsertCalls.append((table: "games", count: 1))
        return dto
    }

    func upsertGamePlayers(_ dtos: [GamePlayerDTO]) throws -> [GamePlayerDTO] {
        if let error = shouldThrowError { throw error }
        for dto in dtos { gamePlayers[dto.id] = dto }
        upsertCalls.append((table: "game_players", count: dtos.count))
        return dtos
    }

    func upsertAliases(_ dtos: [PlayerAliasDTO]) throws -> [PlayerAliasDTO] {
        if let error = shouldThrowError { throw error }
        for dto in dtos { aliases[dto.id] = dto }
        upsertCalls.append((table: "player_aliases", count: dtos.count))
        return dtos
    }

    func upsertClaims(_ dtos: [PlayerClaimDTO]) throws -> [PlayerClaimDTO] {
        if let error = shouldThrowError { throw error }
        for dto in dtos { claims[dto.id] = dto }
        upsertCalls.append((table: "player_claims", count: dtos.count))
        return dtos
    }

    func fetchProfile(byId id: UUID) throws -> ProfileDTO? {
        if let error = shouldThrowError { throw error }
        fetchCalls.append((table: "profiles", count: 1))
        return profiles[id]
    }

    func fetchGames(creatorId: UUID) throws -> [GameDTO] {
        if let error = shouldThrowError { throw error }
        let result = games.values.filter { $0.creatorId == creatorId && !$0.softDeleted }
        fetchCalls.append((table: "games", count: result.count))
        return Array(result)
    }

    func fetchGamePlayers(gameId: UUID) throws -> [GamePlayerDTO] {
        if let error = shouldThrowError { throw error }
        let result = gamePlayers.values.filter { $0.gameId == gameId }
        fetchCalls.append((table: "game_players", count: result.count))
        return Array(result)
    }

    func fetchPendingClaims(hostId: UUID) throws -> [PlayerClaimDTO] {
        if let error = shouldThrowError { throw error }
        let result = claims.values.filter { $0.hostId == hostId && $0.isPending }
        fetchCalls.append((table: "player_claims", count: result.count))
        return Array(result)
    }

    func deleteGame(id: UUID) throws {
        if let error = shouldThrowError { throw error }
        games.removeValue(forKey: id)
        deleteCalls.append((table: "games", id: id))
    }
}

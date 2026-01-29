//
//  Repository.swift
//  PokerCardRecognizer
//
//  Created for Phase 6: Refactoring & Architecture
//

import Foundation
import CoreData

/// Protocol defining data repository interface
protocol Repository {
    // MARK: - User Operations
    func createUser(username: String, passwordHash: String, email: String?) async throws -> User
    func fetchUser(byId userId: UUID) async throws -> User?
    func fetchUser(byUsername username: String) async throws -> User?
    func fetchUser(byEmail email: String) async throws -> User?
    func updateUser(_ user: User) async throws
    func deleteUser(_ user: User) async throws
    
    // MARK: - Game Operations
    func createGame(gameType: String, creatorUserId: UUID?, timestamp: Date, notes: String?) async throws -> Game
    func fetchGame(byId gameId: UUID) async throws -> Game?
    func fetchGames(createdBy userId: UUID) async throws -> [Game]
    func fetchAllActiveGames() async throws -> [Game]
    func updateGame(_ game: Game) async throws
    func deleteGame(_ game: Game) async throws
    
    // MARK: - PlayerProfile Operations
    func createPlayerProfile(displayName: String, userId: UUID?) async throws -> PlayerProfile
    func fetchPlayerProfile(byId profileId: UUID) async throws -> PlayerProfile?
    func fetchPlayerProfile(byUserId userId: UUID) async throws -> PlayerProfile?
    func fetchAllPlayerProfiles() async throws -> [PlayerProfile]
    func updatePlayerProfile(_ profile: PlayerProfile) async throws
    func deletePlayerProfile(_ profile: PlayerProfile) async throws
    
    // MARK: - PlayerAlias Operations
    func createAlias(aliasName: String, forProfile profile: PlayerProfile) async throws -> PlayerAlias
    func fetchAlias(byName name: String) async throws -> PlayerAlias?
    func fetchAliases(forProfile profile: PlayerProfile) async throws -> [PlayerAlias]
    func updateAlias(_ alias: PlayerAlias) async throws
    func deleteAlias(_ alias: PlayerAlias) async throws
    
    // MARK: - PlayerClaim Operations
    func createClaim(gameWithPlayer: GameWithPlayer, claimantUserId: UUID) async throws -> PlayerClaim
    func fetchClaim(byId claimId: UUID) async throws -> PlayerClaim?
    func fetchPendingClaims(forHost hostUserId: UUID) async throws -> [PlayerClaim]
    func fetchMyClaims(userId: UUID) async throws -> [PlayerClaim]
    func updateClaim(_ claim: PlayerClaim) async throws
    func deleteClaim(_ claim: PlayerClaim) async throws
    
    // MARK: - Sync Operations
    func sync() async throws
    func canSync() async -> Bool
}

// MARK: - Local Repository Implementation (CoreData)

final class LocalRepository: Repository {
    private let persistence: PersistenceController
    
    @MainActor
    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }
    
    // MARK: - User Operations
    
    func createUser(username: String, passwordHash: String, email: String?) async throws -> User {
        guard let user = persistence.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        ) else {
            throw RepositoryError.creationFailed
        }
        return user
    }
    
    func fetchUser(byId userId: UUID) async throws -> User? {
        return persistence.fetchUser(byId: userId)
    }
    
    func fetchUser(byUsername username: String) async throws -> User? {
        return persistence.fetchUser(byUsername: username)
    }
    
    func fetchUser(byEmail email: String) async throws -> User? {
        return persistence.fetchUser(byEmail: email)
    }
    
    func updateUser(_ user: User) async throws {
        let context = persistence.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func deleteUser(_ user: User) async throws {
        let context = persistence.container.viewContext
        context.delete(user)
        try context.save()
    }
    
    // MARK: - Game Operations
    
    func createGame(gameType: String, creatorUserId: UUID?, timestamp: Date, notes: String?) async throws -> Game {
        return persistence.createGame(
            gameType: gameType,
            creatorUserId: creatorUserId,
            timestamp: timestamp,
            notes: notes
        )
    }
    
    func fetchGame(byId gameId: UUID) async throws -> Game? {
        return persistence.fetchGame(byId: gameId)
    }
    
    func fetchGames(createdBy userId: UUID) async throws -> [Game] {
        return persistence.fetchGames(createdBy: userId)
    }
    
    func fetchAllActiveGames() async throws -> [Game] {
        return persistence.fetchAllActiveGames()
    }
    
    func updateGame(_ game: Game) async throws {
        let context = persistence.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func deleteGame(_ game: Game) async throws {
        persistence.softDeleteGame(game)
    }
    
    // MARK: - PlayerProfile Operations
    
    func createPlayerProfile(displayName: String, userId: UUID?) async throws -> PlayerProfile {
        return persistence.createPlayerProfile(displayName: displayName, userId: userId)
    }
    
    func fetchPlayerProfile(byId profileId: UUID) async throws -> PlayerProfile? {
        return persistence.fetchPlayerProfile(byProfileId: profileId)
    }
    
    func fetchPlayerProfile(byUserId userId: UUID) async throws -> PlayerProfile? {
        return persistence.fetchPlayerProfile(byUserId: userId)
    }
    
    func fetchAllPlayerProfiles() async throws -> [PlayerProfile] {
        return persistence.fetchAllPlayerProfiles()
    }
    
    func updatePlayerProfile(_ profile: PlayerProfile) async throws {
        let context = persistence.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func deletePlayerProfile(_ profile: PlayerProfile) async throws {
        let context = persistence.container.viewContext
        context.delete(profile)
        try context.save()
    }
    
    // MARK: - PlayerAlias Operations
    
    func createAlias(aliasName: String, forProfile profile: PlayerProfile) async throws -> PlayerAlias {
        guard let alias = persistence.createAlias(aliasName: aliasName, forProfile: profile) else {
            throw RepositoryError.creationFailed
        }
        return alias
    }
    
    func fetchAlias(byName name: String) async throws -> PlayerAlias? {
        return persistence.fetchAlias(byName: name)
    }
    
    func fetchAliases(forProfile profile: PlayerProfile) async throws -> [PlayerAlias] {
        return persistence.fetchAliases(forProfile: profile)
    }
    
    func updateAlias(_ alias: PlayerAlias) async throws {
        let context = persistence.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func deleteAlias(_ alias: PlayerAlias) async throws {
        let context = persistence.container.viewContext
        context.delete(alias)
        try context.save()
    }
    
    // MARK: - PlayerClaim Operations
    
    func createClaim(gameWithPlayer: GameWithPlayer, claimantUserId: UUID) async throws -> PlayerClaim {
        guard let claim = persistence.createPlayerClaim(
            gameWithPlayer: gameWithPlayer,
            claimantUserId: claimantUserId
        ) else {
            throw RepositoryError.creationFailed
        }
        return claim
    }
    
    func fetchClaim(byId claimId: UUID) async throws -> PlayerClaim? {
        return persistence.fetchPlayerClaim(byId: claimId)
    }
    
    func fetchPendingClaims(forHost hostUserId: UUID) async throws -> [PlayerClaim] {
        return persistence.fetchPendingClaimsForHost(hostUserId: hostUserId)
    }
    
    func fetchMyClaims(userId: UUID) async throws -> [PlayerClaim] {
        return persistence.fetchMyClaims(userId: userId)
    }
    
    func updateClaim(_ claim: PlayerClaim) async throws {
        let context = persistence.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func deleteClaim(_ claim: PlayerClaim) async throws {
        let context = persistence.container.viewContext
        context.delete(claim)
        try context.save()
    }
    
    // MARK: - Sync Operations
    
    func sync() async throws {
        // Local repository doesn't sync (no remote)
        return
    }
    
    func canSync() async -> Bool {
        return false
    }
}

// MARK: - Sync Repository (CoreData + CloudKit)

final class SyncRepository: Repository {
    private let localRepository: LocalRepository
    private let syncService: CloudKitSyncService
    
    @MainActor
    init(
        localRepository: LocalRepository? = nil,
        syncService: CloudKitSyncService = .shared
    ) {
        self.localRepository = localRepository ?? LocalRepository()
        self.syncService = syncService
    }
    
    // MARK: - User Operations (delegate to local + trigger sync)
    
    func createUser(username: String, passwordHash: String, email: String?) async throws -> User {
        let user = try await localRepository.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        )
        try? await syncService.sync()
        return user
    }
    
    func fetchUser(byId userId: UUID) async throws -> User? {
        return try await localRepository.fetchUser(byId: userId)
    }
    
    func fetchUser(byUsername username: String) async throws -> User? {
        return try await localRepository.fetchUser(byUsername: username)
    }
    
    func fetchUser(byEmail email: String) async throws -> User? {
        return try await localRepository.fetchUser(byEmail: email)
    }
    
    func updateUser(_ user: User) async throws {
        try await localRepository.updateUser(user)
        try? await syncService.sync()
    }
    
    func deleteUser(_ user: User) async throws {
        try await localRepository.deleteUser(user)
        try? await syncService.sync()
    }
    
    // MARK: - Game Operations (delegate to local + trigger sync)
    
    func createGame(gameType: String, creatorUserId: UUID?, timestamp: Date, notes: String?) async throws -> Game {
        let game = try await localRepository.createGame(
            gameType: gameType,
            creatorUserId: creatorUserId,
            timestamp: timestamp,
            notes: notes
        )
        try? await syncService.sync()
        return game
    }
    
    func fetchGame(byId gameId: UUID) async throws -> Game? {
        return try await localRepository.fetchGame(byId: gameId)
    }
    
    func fetchGames(createdBy userId: UUID) async throws -> [Game] {
        return try await localRepository.fetchGames(createdBy: userId)
    }
    
    func fetchAllActiveGames() async throws -> [Game] {
        return try await localRepository.fetchAllActiveGames()
    }
    
    func updateGame(_ game: Game) async throws {
        try await localRepository.updateGame(game)
        try? await syncService.sync()
    }
    
    func deleteGame(_ game: Game) async throws {
        try await localRepository.deleteGame(game)
        try? await syncService.sync()
    }
    
    // MARK: - PlayerProfile Operations (delegate to local + trigger sync)
    
    func createPlayerProfile(displayName: String, userId: UUID?) async throws -> PlayerProfile {
        let profile = try await localRepository.createPlayerProfile(displayName: displayName, userId: userId)
        try? await syncService.sync()
        return profile
    }
    
    func fetchPlayerProfile(byId profileId: UUID) async throws -> PlayerProfile? {
        return try await localRepository.fetchPlayerProfile(byId: profileId)
    }
    
    func fetchPlayerProfile(byUserId userId: UUID) async throws -> PlayerProfile? {
        return try await localRepository.fetchPlayerProfile(byUserId: userId)
    }
    
    func fetchAllPlayerProfiles() async throws -> [PlayerProfile] {
        return try await localRepository.fetchAllPlayerProfiles()
    }
    
    func updatePlayerProfile(_ profile: PlayerProfile) async throws {
        try await localRepository.updatePlayerProfile(profile)
        try? await syncService.sync()
    }
    
    func deletePlayerProfile(_ profile: PlayerProfile) async throws {
        try await localRepository.deletePlayerProfile(profile)
        try? await syncService.sync()
    }
    
    // MARK: - PlayerAlias Operations (delegate to local + trigger sync)
    
    func createAlias(aliasName: String, forProfile profile: PlayerProfile) async throws -> PlayerAlias {
        let alias = try await localRepository.createAlias(aliasName: aliasName, forProfile: profile)
        try? await syncService.sync()
        return alias
    }
    
    func fetchAlias(byName name: String) async throws -> PlayerAlias? {
        return try await localRepository.fetchAlias(byName: name)
    }
    
    func fetchAliases(forProfile profile: PlayerProfile) async throws -> [PlayerAlias] {
        return try await localRepository.fetchAliases(forProfile: profile)
    }
    
    func updateAlias(_ alias: PlayerAlias) async throws {
        try await localRepository.updateAlias(alias)
        try? await syncService.sync()
    }
    
    func deleteAlias(_ alias: PlayerAlias) async throws {
        try await localRepository.deleteAlias(alias)
        try? await syncService.sync()
    }
    
    // MARK: - PlayerClaim Operations (delegate to local + trigger sync)
    
    func createClaim(gameWithPlayer: GameWithPlayer, claimantUserId: UUID) async throws -> PlayerClaim {
        let claim = try await localRepository.createClaim(
            gameWithPlayer: gameWithPlayer,
            claimantUserId: claimantUserId
        )
        try? await syncService.sync()
        return claim
    }
    
    func fetchClaim(byId claimId: UUID) async throws -> PlayerClaim? {
        return try await localRepository.fetchClaim(byId: claimId)
    }
    
    func fetchPendingClaims(forHost hostUserId: UUID) async throws -> [PlayerClaim] {
        return try await localRepository.fetchPendingClaims(forHost: hostUserId)
    }
    
    func fetchMyClaims(userId: UUID) async throws -> [PlayerClaim] {
        return try await localRepository.fetchMyClaims(userId: userId)
    }
    
    func updateClaim(_ claim: PlayerClaim) async throws {
        try await localRepository.updateClaim(claim)
        try? await syncService.sync()
    }
    
    func deleteClaim(_ claim: PlayerClaim) async throws {
        try await localRepository.deleteClaim(claim)
        try? await syncService.sync()
    }
    
    // MARK: - Sync Operations
    
    func sync() async throws {
        try await syncService.sync()
    }
    
    func canSync() async -> Bool {
        return await syncService.canSync()
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case creationFailed
    case updateFailed
    case deleteFailed
    case notFound
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Не удалось создать объект"
        case .updateFailed:
            return "Не удалось обновить объект"
        case .deleteFailed:
            return "Не удалось удалить объект"
        case .notFound:
            return "Объект не найден"
        case .syncFailed:
            return "Ошибка синхронизации"
        }
    }
}

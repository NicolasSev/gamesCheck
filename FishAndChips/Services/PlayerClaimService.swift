//
//  PlayerClaimService.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import Foundation
import CoreData

class PlayerClaimService {
    private let persistence: PersistenceController
    private let notificationService: NotificationService
    
    init(
        persistence: PersistenceController = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.persistence = persistence
        self.notificationService = notificationService
    }
    
    // MARK: - Submit Claim
    
    /// Подать заявку на присвоение игрока в конкретной игре
    func submitClaim(
        gameWithPlayer: GameWithPlayer,
        claimantUserId: UUID
    ) throws -> PlayerClaim {
        let context = persistence.container.viewContext
        
        // Проверка что GameWithPlayer существует
        guard let game = gameWithPlayer.game,
              let player = gameWithPlayer.player,
              let playerName = player.name else {
            throw ClaimError.invalidGameWithPlayer
        }
        
        // Проверка что пользователь существует
        guard let claimantUser = persistence.fetchUser(byId: claimantUserId) else {
            throw ClaimError.userNotFound
        }
        
        // Проверка что это не хост игры
        guard let hostUserId = game.creatorUserId,
              hostUserId != claimantUserId else {
            throw ClaimError.cannotClaimOwnGame
        }
        
        // Проверка что заявка еще не существует
        if let existingClaim = fetchClaim(
            gameWithPlayerObjectId: gameWithPlayer.objectID.uriRepresentation().absoluteString,
            claimantUserId: claimantUserId
        ) {
            if existingClaim.isPending {
                throw ClaimError.claimAlreadyExists
            }
        }
        
        // Создать заявку
        let claim = PlayerClaim(context: context)
        claim.claimId = UUID()
        claim.playerName = playerName
        claim.gameId = game.gameId
        claim.gameWithPlayerObjectId = gameWithPlayer.objectID.uriRepresentation().absoluteString
        claim.claimantUserId = claimantUserId
        claim.hostUserId = hostUserId
        claim.status = "pending"
        claim.createdAt = Date()
        claim.claimantUser = claimantUser
        claim.hostUser = persistence.fetchUser(byId: hostUserId)
        claim.game = game
        
        try context.save()
        
        // Send notification to host
        Task { @MainActor in
            do {
                try await notificationService.notifyNewClaim(
                    claimId: claim.claimId.uuidString,
                    playerName: playerName,
                    gameName: "игра от \(game.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")",
                    hostUserId: hostUserId.uuidString
                )
            } catch {
                print("Failed to send notification: \(error)")
            }
        }
        
        return claim
    }
    
    // MARK: - Get Claims
    
    /// Получить все заявки пользователя
    func getMyClaims(userId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
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
    
    /// Получить все ожидающие заявки для хоста
    func getPendingClaimsForHost(hostUserId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
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
    
    /// Получить заявку по ID
    func getClaim(byId claimId: UUID) -> PlayerClaim? {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching claim: \(error)")
            return nil
        }
    }
    
    /// Найти существующую заявку
    private func fetchClaim(
        gameWithPlayerObjectId: String,
        claimantUserId: UUID
    ) -> PlayerClaim? {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(
            format: "gameWithPlayerObjectId == %@ AND claimantUserId == %@",
            gameWithPlayerObjectId,
            claimantUserId as CVarArg
        )
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            return nil
        }
    }
    
    // MARK: - Approve/Reject Claims
    
    /// Одобрить заявку
    func approveClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) throws {
        let context = persistence.container.viewContext
        
        guard let claim = getClaim(byId: claimId) else {
            throw ClaimError.claimNotFound
        }
        
        // Проверка что это хост игры
        guard claim.hostUserId == resolverUserId else {
            throw ClaimError.unauthorized
        }
        
        // Проверка что заявка еще pending
        guard claim.isPending else {
            throw ClaimError.claimAlreadyResolved
        }
        
        // Найти GameWithPlayer по objectId
        guard let gameWithPlayer = findGameWithPlayer(byObjectId: claim.gameWithPlayerObjectId) else {
            throw ClaimError.gameWithPlayerNotFound
        }
        
        // Получить или создать PlayerProfile для пользователя
        var profile = persistence.fetchPlayerProfile(byUserId: claim.claimantUserId)
        if profile == nil {
            guard let user = persistence.fetchUser(byId: claim.claimantUserId) else {
                throw ClaimError.userNotFound
            }
            profile = persistence.createPlayerProfile(
                displayName: user.username,
                userId: claim.claimantUserId
            )
        }
        
        guard let profile = profile else {
            throw ClaimError.profileCreationFailed
        }
        
        // Создать alias если нужно
        if persistence.fetchAlias(byName: claim.playerName) == nil {
            _ = persistence.createAlias(aliasName: claim.playerName, forProfile: profile)
        }
        
        // Привязать GameWithPlayer к PlayerProfile
        gameWithPlayer.playerProfile = profile
        
        // Обновить статистику профиля
        profile.recalculateStatistics()
        
        // Обновить заявку
        claim.status = "approved"
        claim.resolvedAt = Date()
        claim.resolvedByUserId = resolverUserId
        claim.resolvedByUser = persistence.fetchUser(byId: resolverUserId)
        claim.notes = notes
        
        try context.save()
        
        // Send notification to claimant
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimApproved(
                    claimId: claim.claimId.uuidString,
                    playerName: claim.playerName,
                    gameName: "игра от \(claim.game?.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")"
                )
            } catch {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    /// Отклонить заявку
    func rejectClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) throws {
        let context = persistence.container.viewContext
        
        guard let claim = getClaim(byId: claimId) else {
            throw ClaimError.claimNotFound
        }
        
        // Проверка что это хост игры
        guard claim.hostUserId == resolverUserId else {
            throw ClaimError.unauthorized
        }
        
        // Проверка что заявка еще pending
        guard claim.isPending else {
            throw ClaimError.claimAlreadyResolved
        }
        
        // Обновить заявку
        claim.status = "rejected"
        claim.resolvedAt = Date()
        claim.resolvedByUserId = resolverUserId
        claim.resolvedByUser = persistence.fetchUser(byId: resolverUserId)
        claim.notes = notes
        
        try context.save()
        
        // Send notification to claimant
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimRejected(
                    claimId: claim.claimId.uuidString,
                    playerName: claim.playerName,
                    gameName: "игра от \(claim.game?.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")",
                    reason: notes
                )
            } catch {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Найти GameWithPlayer по objectId строке
    private func findGameWithPlayer(byObjectId objectIdString: String) -> GameWithPlayer? {
        guard let url = URL(string: objectIdString),
              let objectId = persistence.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url) else {
            return nil
        }
        
        let context = persistence.container.viewContext
        
        do {
            return try context.existingObject(with: objectId) as? GameWithPlayer
        } catch {
            print("Error finding GameWithPlayer: \(error)")
            return nil
        }
    }
}

// MARK: - Errors

enum ClaimError: LocalizedError {
    case userNotFound
    case profileCreationFailed
    case invalidGameWithPlayer
    case cannotClaimOwnGame
    case claimAlreadyExists
    case claimNotFound
    case claimAlreadyResolved
    case unauthorized
    case gameWithPlayerNotFound
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Пользователь не найден"
        case .profileCreationFailed:
            return "Не удалось создать профиль"
        case .invalidGameWithPlayer:
            return "Некорректная запись участия в игре"
        case .cannotClaimOwnGame:
            return "Нельзя подать заявку на свою игру"
        case .claimAlreadyExists:
            return "Заявка уже существует"
        case .claimNotFound:
            return "Заявка не найдена"
        case .claimAlreadyResolved:
            return "Заявка уже обработана"
        case .unauthorized:
            return "Нет прав для выполнения операции"
        case .gameWithPlayerNotFound:
            return "Запись участия в игре не найдена"
        }
    }
}


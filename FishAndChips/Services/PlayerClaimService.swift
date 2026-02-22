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
        
        // Синхронизируем заявку с CloudKit сразу после создания
        Task {
            do {
                print("☁️ [SUBMIT_CLAIM] Pushing claim to CloudKit...")
                try await CloudKitSyncService.shared.syncPlayerClaims()
                print("✅ [SUBMIT_CLAIM] Claim synced to CloudKit")
            } catch {
                print("❌ [SUBMIT_CLAIM] Failed to sync claim to CloudKit: \(error)")
                // Помечаем как pending для последующей синхронизации
                PendingSyncTracker.shared.addPendingPlayerClaim(claim.claimId)
            }
        }
        
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
    
    /// Получить все заявки пользователя (сначала pending, потом остальные по дате)
    func getMyClaims(userId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimantUserId == %@", userId as CVarArg)
        // Сначала pending (status = "pending"), потом остальные
        // Внутри каждой группы - по убыванию даты (новые сверху)
        request.sortDescriptors = [
            NSSortDescriptor(key: "status", ascending: true), // pending идет первым (алфавитный порядок)
            NSSortDescriptor(keyPath: \PlayerClaim.createdAt, ascending: false)
        ]
        
        do {
            let allClaims = try context.fetch(request)
            // Дополнительная сортировка: pending сверху, потом approved/rejected по дате
            let pending = allClaims.filter { $0.status == "pending" }
            let resolved = allClaims.filter { $0.status != "pending" }
                .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
            
            return pending + resolved
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
    
    /// Получить все заявки для хоста (сначала pending, потом остальные по дате)
    func getAllClaimsForHost(hostUserId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "hostUserId == %@", hostUserId as CVarArg)
        
        do {
            let allClaims = try context.fetch(request)
            // Сортировка: pending сверху, потом approved/rejected по дате разрешения
            let pending = allClaims.filter { $0.status == "pending" }
                .sorted { $0.createdAt > $1.createdAt }
            let resolved = allClaims.filter { $0.status != "pending" }
                .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
            
            return pending + resolved
        } catch {
            print("Error fetching all claims for host: \(error)")
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
    
    /// Одобрить заявку и автоматически привязать ко всем GWP с таким же playerName
    func approveClaimAndLinkAllGWP(
        claimId: UUID,
        resolverUserId: UUID,
        linkAllGames: Bool = false,
        notes: String? = nil
    ) async throws -> Int {
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
        
        print("🔍 [APPROVE_LINK_ALL] Starting approval for claim \(claim.claimId)")
        print("   - playerName: \(claim.playerName)")
        print("   - claimantUserId: \(claim.claimantUserId)")
        print("   - linkAllGames: \(linkAllGames)")
        
        // Получить или создать PlayerProfile для пользователя
        print("🔍 [APPROVE_LINK_ALL] Looking for PlayerProfile for user \(claim.claimantUserId)...")
        var profile = persistence.fetchPlayerProfile(byUserId: claim.claimantUserId)
        
        if profile == nil {
            print("⚠️ [APPROVE_LINK_ALL] PlayerProfile not found locally, checking CloudKit...")
            
            // Пытаемся загрузить User из CloudKit если его нет локально
            var user = persistence.fetchUser(byId: claim.claimantUserId)
            
            if user == nil {
                print("⚠️ [APPROVE_LINK_ALL] User not found locally, fetching from CloudKit...")
                do {
                    // Загружаем User из CloudKit Public DB
                    let predicate = NSPredicate(format: "TRUEPREDICATE")
                    let records = try await CloudKitService.shared.queryRecords(
                        withType: .user,
                        from: .publicDB,
                        predicate: predicate,
                        sortDescriptors: nil,
                        resultsLimit: 1000
                    )
                    
                    // Ищем пользователя с нужным userId
                    if let userRecord = records.records.first(where: { $0.recordID.recordName == claim.claimantUserId.uuidString }) {
                        print("✅ [APPROVE_LINK_ALL] Found user in CloudKit, creating local copy...")
                        
                        // Создаем локальную копию User
                        let newUser = User(context: context)
                        newUser.userId = claim.claimantUserId
                        newUser.updateFromCKRecord(userRecord)
                        newUser.passwordHash = "remote_user_no_auth"
                        
                        user = newUser
                        print("✅ [APPROVE_LINK_ALL] Created local User: \(newUser.username)")
                    } else {
                        print("❌ [APPROVE_LINK_ALL] User \(claim.claimantUserId) not found in CloudKit")
                        throw ClaimError.userNotFound
                    }
                } catch {
                    print("❌ [APPROVE_LINK_ALL] Failed to fetch user from CloudKit: \(error)")
                    throw ClaimError.userNotFound
                }
            }
            
            guard let user = user else {
                throw ClaimError.userNotFound
            }
            
            print("📝 [APPROVE_LINK_ALL] Creating PlayerProfile for user \(user.username)...")
            profile = persistence.createPlayerProfile(
                displayName: user.username,
                userId: claim.claimantUserId
            )
            print("✅ [APPROVE_LINK_ALL] Created PlayerProfile")
        }
        
        guard let profile = profile else {
            throw ClaimError.profileCreationFailed
        }
        
        print("✅ [APPROVE_LINK_ALL] PlayerProfile ready: \(profile.displayName)")
        
        // Создать alias если нужно
        if persistence.fetchAlias(byName: claim.playerName) == nil {
            _ = persistence.createAlias(aliasName: claim.playerName, forProfile: profile)
            print("✅ [APPROVE_LINK_ALL] Created alias '\(claim.playerName)'")
        }
        
        var linkedCount = 0
        var gwpToSync: [GameWithPlayer] = []
        
        if linkAllGames {
            // МАССОВОЕ ОДОБРЕНИЕ: Найти ВСЕ GWP с таким playerName у хоста
            print("🔍 [APPROVE_LINK_ALL] Searching for ALL GWP with playerName '\(claim.playerName)' from host...")
            
            let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
            // Найти все GWP где:
            // 1. playerName совпадает
            // 2. игра принадлежит хосту (resolverUserId)
            fetchRequest.predicate = NSPredicate(
                format: "player.name == %@ AND game.creatorUserId == %@",
                claim.playerName, resolverUserId as CVarArg
            )
            
            let allMatchingGWP = try context.fetch(fetchRequest)
            print("✅ [APPROVE_LINK_ALL] Found \(allMatchingGWP.count) GWP with playerName '\(claim.playerName)'")
            
            // Привязать каждый GWP к профилю
            for gwp in allMatchingGWP {
                // Пропускаем если уже привязан к профилю
                if gwp.playerProfile == nil {
                    gwp.playerProfile = profile
                    gwpToSync.append(gwp)
                    linkedCount += 1
                    
                    if let game = gwp.game, let gameDate = game.timestamp {
                        print("✅ [APPROVE_LINK_ALL] Linked GWP in game \(gameDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
            }
            
            print("✅ [APPROVE_LINK_ALL] Linked \(linkedCount) GWP to profile '\(profile.displayName)'")
            
        } else {
            // ОБЫЧНОЕ ОДОБРЕНИЕ: Только для одной игры из заявки
            print("🔍 [APPROVE_LINK_ALL] Linking only single game GWP...")
            
            let gameWithPlayer = findGameWithPlayer(gameId: claim.gameId, playerName: claim.playerName)
            
            guard let gameWithPlayer = gameWithPlayer else {
                print("❌ [APPROVE_LINK_ALL] GameWithPlayer not found!")
                throw ClaimError.gameWithPlayerNotFound
            }
            
            gameWithPlayer.playerProfile = profile
            gwpToSync.append(gameWithPlayer)
            linkedCount = 1
            print("✅ [APPROVE_LINK_ALL] Linked single GWP")
        }
        
        // Обновить статистику профиля
        profile.recalculateStatistics()
        
        // Обновить заявку
        claim.status = "approved"
        claim.resolvedAt = Date()
        claim.resolvedByUserId = resolverUserId
        claim.resolvedByUser = persistence.fetchUser(byId: resolverUserId)
        claim.notes = notes
        
        try context.save()
        
        print("☁️ [APPROVE_LINK_ALL] Syncing changes to CloudKit...")
        
        // Синхронизируем изменения в CloudKit
        do {
            // 1. Синхронизируем PlayerClaim (обновленный статус)
            try await CloudKitSyncService.shared.syncPlayerClaims()
            print("✅ [APPROVE_LINK_ALL] PlayerClaim synced")
            
            // 2. Синхронизируем все измененные GameWithPlayer
            if !gwpToSync.isEmpty {
                await CloudKitSyncService.shared.quickSyncGameWithPlayers(gwpToSync)
                print("✅ [APPROVE_LINK_ALL] \(gwpToSync.count) GameWithPlayer synced")
            }
            
            // 3. Синхронизируем PlayerProfile (обновленная статистика)
            await CloudKitSyncService.shared.quickSyncPlayerProfile(profile)
            print("✅ [APPROVE_LINK_ALL] PlayerProfile synced")
            
            // 4. Синхронизируем PlayerAliases
            try await CloudKitSyncService.shared.syncPlayerAliases()
            print("✅ [APPROVE_LINK_ALL] PlayerAliases synced")

            // 5. Phase 2: Обновить materialized views для клаиманта
            try? await MaterializedViewsService.shared.updateUserStatisticsSummary(userId: claim.claimantUserId)

            print("✅ [APPROVE_LINK_ALL] All changes synced to CloudKit")
        } catch {
            print("⚠️ [APPROVE_LINK_ALL] Failed to sync to CloudKit: \(error)")
            // Не бросаем ошибку, т.к. локально все сохранено
        }
        
        // Send notification to claimant
        let claimIdString = claim.claimId.uuidString
        let playerName = claim.playerName
        let gameTimestamp = claim.game?.timestamp
        let claimantUserIdString = claim.claimantUserId.uuidString
        
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimApproved(
                    claimId: claimIdString,
                    playerName: playerName,
                    gameName: "игра от \(gameTimestamp?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")",
                    claimantUserId: claimantUserIdString
                )
            } catch {
                print("Failed to send notification: \(error)")
            }
        }
        
        return linkedCount
    }
    
    /// Одобрить заявку (старый метод, теперь использует новый)
    func approveClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) async throws {
        _ = try await approveClaimAndLinkAllGWP(
            claimId: claimId,
            resolverUserId: resolverUserId,
            linkAllGames: false,
            notes: notes
        )
    }
    
    /// Одобрить все заявки для данного playerName от конкретного клаиманта
    func approveAllClaimsForPlayer(
        playerName: String,
        claimantUserId: UUID,
        hostUserId: UUID,
        notes: String? = nil
    ) async throws -> Int {
        let context = persistence.container.viewContext
        
        // Получить все pending заявки для данного игрока от данного клаиманта
        let fetchRequest: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "playerName == %@ AND claimantUserId == %@ AND hostUserId == %@ AND status == %@",
            playerName, claimantUserId as CVarArg, hostUserId as CVarArg, "pending"
        )
        
        let claims = try context.fetch(fetchRequest)
        
        guard !claims.isEmpty else {
            return 0
        }
        
        print("📋 [APPROVE_ALL] Found \(claims.count) claims for player '\(playerName)' from user \(claimantUserId)")
        
        var approvedCount = 0
        var errors: [Error] = []
        
        // Одобряем каждую заявку
        for claim in claims {
            do {
                print("🔄 [APPROVE_ALL] Approving claim \(claim.claimId)...")
                try await approveClaim(
                    claimId: claim.claimId,
                    resolverUserId: hostUserId,
                    notes: notes
                )
                approvedCount += 1
                print("✅ [APPROVE_ALL] Approved claim \(claim.claimId)")
            } catch {
                print("❌ [APPROVE_ALL] Failed to approve claim \(claim.claimId): \(error)")
                errors.append(error)
            }
        }
        
        print("✅ [APPROVE_ALL] Completed: \(approvedCount)/\(claims.count) claims approved")
        
        // Если есть ошибки, но хотя бы одна заявка одобрена - считаем успехом
        if approvedCount > 0 {
            return approvedCount
        } else if let firstError = errors.first {
            throw firstError
        }
        
        return 0
    }
    
    /// Отклонить заявку
    func rejectClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) async throws {
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

        // Сразу пушим в CloudKit, иначе при следующей синхронизации статус перезапишется обратно на pending
        do {
            try await CloudKitSyncService.shared.syncPlayerClaims()
            print("✅ [REJECT_CLAIM] Claim synced to CloudKit")
        } catch {
            print("❌ [REJECT_CLAIM] Failed to sync claim to CloudKit: \(error)")
            PendingSyncTracker.shared.addPendingPlayerClaim(claimId)
        }

        // Send notification to claimant
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimRejected(
                    claimId: claim.claimId.uuidString,
                    playerName: claim.playerName,
                    gameName: "игра от \(claim.game?.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")",
                    reason: notes,
                    claimantUserId: claim.claimantUserId.uuidString
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
    
    /// Находит GameWithPlayer по стабильным идентификаторам (gameId + playerName)
    private func findGameWithPlayer(gameId: UUID, playerName: String) -> GameWithPlayer? {
        let context = persistence.container.viewContext
        
        // Fetch GameWithPlayer по gameId и playerName
        let gwpFetch: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        gwpFetch.predicate = NSPredicate(
            format: "game.gameId == %@ AND player.name == %@",
            gameId as CVarArg,
            playerName as NSString
        )
        
        do {
            let results = try context.fetch(gwpFetch)
            if results.count > 1 {
                print("⚠️ Found multiple GameWithPlayer for gameId=\(gameId), playerName=\(playerName). Using first.")
            }
            return results.first
        } catch {
            print("❌ Error finding GameWithPlayer: \(error)")
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


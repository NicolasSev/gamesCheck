import Foundation
import CoreData

// MARK: - User -> ProfileDTO

extension User {
    func toProfileDTO() -> ProfileDTO {
        ProfileDTO(
            id: userId,
            username: username,
            displayName: playerProfile?.displayName ?? username,
            isAnonymous: playerProfile?.isAnonymous ?? false,
            isPublic: playerProfile?.isPublic ?? false,
            isSuperAdmin: isSuperAdmin,
            subscriptionStatus: subscriptionStatus,
            subscriptionExpiresAt: subscriptionExpiresAt,
            totalGamesPlayed: Int(playerProfile?.totalGamesPlayed ?? 0),
            totalBuyins: playerProfile?.totalBuyins.doubleValue ?? 0,
            totalCashouts: playerProfile?.totalCashouts.doubleValue ?? 0,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt,
            updatedAt: nil
        )
    }

    func updateFromProfileDTO(_ dto: ProfileDTO, context: NSManagedObjectContext) {
        username = dto.username
        subscriptionStatus = dto.subscriptionStatus
        subscriptionExpiresAt = dto.subscriptionExpiresAt
        isSuperAdmin = dto.isSuperAdmin
        lastLoginAt = dto.lastLoginAt

        if let profile = playerProfile {
            profile.displayName = dto.displayName
            profile.isAnonymous = dto.isAnonymous
            profile.isPublic = dto.isPublic
            profile.totalGamesPlayed = Int32(dto.totalGamesPlayed)
            profile.totalBuyins = NSDecimalNumber(value: dto.totalBuyins)
            profile.totalCashouts = NSDecimalNumber(value: dto.totalCashouts)
        }
    }
}

// MARK: - Game -> GameDTO

extension Game {
    func toGameDTO() -> GameDTO {
        GameDTO(
            id: gameId,
            gameType: gameType ?? "Poker",
            creatorId: creatorUserId,
            isPublic: isPublic,
            softDeleted: softDeleted,
            notes: notes,
            timestamp: timestamp,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func updateFromGameDTO(_ dto: GameDTO) {
        gameType = dto.gameType
        creatorUserId = dto.creatorId
        isPublic = dto.isPublic
        softDeleted = dto.softDeleted
        notes = dto.notes
        timestamp = dto.timestamp
    }

    static func createFromGameDTO(_ dto: GameDTO, context: NSManagedObjectContext) -> Game {
        let game = Game(context: context)
        game.gameId = dto.id
        game.gameType = dto.gameType
        game.creatorUserId = dto.creatorId
        game.isPublic = dto.isPublic
        game.softDeleted = dto.softDeleted
        game.notes = dto.notes
        game.timestamp = dto.timestamp
        return game
    }
}

// MARK: - GameWithPlayer -> GamePlayerDTO

extension GameWithPlayer {
    func toGamePlayerDTO() -> GamePlayerDTO? {
        guard let gameId = game?.gameId else { return nil }
        return GamePlayerDTO(
            id: UUID(),
            gameId: gameId,
            profileId: playerProfile?.profileId,
            playerName: player?.name,
            buyin: Int(buyin),
            cashout: cashout,
            createdAt: nil
        )
    }

    func updateFromGamePlayerDTO(_ dto: GamePlayerDTO) {
        buyin = Int16(dto.buyin)
        cashout = dto.cashout
    }

    static func createFromGamePlayerDTO(
        _ dto: GamePlayerDTO,
        game: Game,
        profile: PlayerProfile?,
        context: NSManagedObjectContext
    ) -> GameWithPlayer {
        let gwp = GameWithPlayer(context: context)
        gwp.buyin = Int16(dto.buyin)
        gwp.cashout = dto.cashout
        gwp.game = game
        gwp.playerProfile = profile
        return gwp
    }
}

// MARK: - PlayerProfile -> ProfileDTO (standalone, без User)

extension PlayerProfile {
    func toProfileDTO() -> ProfileDTO {
        ProfileDTO(
            id: profileId,
            username: user?.username ?? displayName,
            displayName: displayName,
            isAnonymous: isAnonymous,
            isPublic: isPublic,
            isSuperAdmin: user?.isSuperAdmin ?? false,
            subscriptionStatus: user?.subscriptionStatus ?? "free",
            subscriptionExpiresAt: user?.subscriptionExpiresAt,
            totalGamesPlayed: Int(totalGamesPlayed),
            totalBuyins: totalBuyins.doubleValue,
            totalCashouts: totalCashouts.doubleValue,
            createdAt: createdAt,
            lastLoginAt: user?.lastLoginAt,
            updatedAt: nil
        )
    }

    func updateFromProfileDTO(_ dto: ProfileDTO) {
        displayName = dto.displayName
        isAnonymous = dto.isAnonymous
        isPublic = dto.isPublic
        totalGamesPlayed = Int32(dto.totalGamesPlayed)
        totalBuyins = NSDecimalNumber(value: dto.totalBuyins)
        totalCashouts = NSDecimalNumber(value: dto.totalCashouts)
    }

    static func createFromProfileDTO(
        _ dto: ProfileDTO,
        context: NSManagedObjectContext
    ) -> PlayerProfile {
        let profile = PlayerProfile(context: context)
        profile.profileId = dto.id
        profile.userId = dto.id
        profile.displayName = dto.displayName
        profile.isAnonymous = dto.isAnonymous
        profile.isPublic = dto.isPublic
        profile.createdAt = dto.createdAt
        profile.totalGamesPlayed = Int32(dto.totalGamesPlayed)
        profile.totalBuyins = NSDecimalNumber(value: dto.totalBuyins)
        profile.totalCashouts = NSDecimalNumber(value: dto.totalCashouts)
        return profile
    }
}

// MARK: - PlayerAlias -> PlayerAliasDTO

extension PlayerAlias {
    func toPlayerAliasDTO() -> PlayerAliasDTO {
        PlayerAliasDTO(
            id: aliasId,
            profileId: profileId,
            aliasName: aliasName,
            claimedAt: claimedAt,
            gamesCount: Int(gamesCount)
        )
    }

    func updateFromPlayerAliasDTO(_ dto: PlayerAliasDTO) {
        aliasName = dto.aliasName
        gamesCount = Int32(dto.gamesCount)
        claimedAt = dto.claimedAt
    }

    static func createFromPlayerAliasDTO(
        _ dto: PlayerAliasDTO,
        profile: PlayerProfile,
        context: NSManagedObjectContext
    ) -> PlayerAlias {
        let alias = PlayerAlias(context: context)
        alias.aliasId = dto.id
        alias.profileId = dto.profileId
        alias.aliasName = dto.aliasName
        alias.claimedAt = dto.claimedAt
        alias.gamesCount = Int32(dto.gamesCount)
        alias.profile = profile
        return alias
    }
}

// MARK: - PlayerClaim -> PlayerClaimDTO

extension PlayerClaim {
    func toPlayerClaimDTO() -> PlayerClaimDTO {
        PlayerClaimDTO(
            id: claimId,
            playerName: playerName,
            gameId: gameId,
            gamePlayerId: nil,
            claimantId: claimantUserId,
            hostId: hostUserId,
            status: status,
            resolvedAt: resolvedAt,
            resolvedById: resolvedByUserId,
            notes: notes,
            createdAt: createdAt
        )
    }

    func updateFromPlayerClaimDTO(_ dto: PlayerClaimDTO) {
        playerName = dto.playerName
        status = dto.status
        resolvedAt = dto.resolvedAt
        resolvedByUserId = dto.resolvedById
        notes = dto.notes
    }

    static func createFromPlayerClaimDTO(
        _ dto: PlayerClaimDTO,
        context: NSManagedObjectContext
    ) -> PlayerClaim {
        let claim = PlayerClaim(context: context)
        claim.claimId = dto.id
        claim.playerName = dto.playerName
        claim.gameId = dto.gameId
        claim.gameWithPlayerObjectId = dto.gamePlayerId?.uuidString ?? ""
        claim.claimantUserId = dto.claimantId
        claim.hostUserId = dto.hostId
        claim.status = dto.status
        claim.createdAt = dto.createdAt ?? Date()
        claim.resolvedAt = dto.resolvedAt
        claim.resolvedByUserId = dto.resolvedById
        claim.notes = dto.notes
        return claim
    }
}


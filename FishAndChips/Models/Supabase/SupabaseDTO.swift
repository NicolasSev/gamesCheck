import Foundation

// MARK: - Profile (User + PlayerProfile)

struct ProfileDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var username: String
    var displayName: String
    var isAnonymous: Bool
    var isPublic: Bool
    var isSuperAdmin: Bool
    var subscriptionStatus: String
    var subscriptionExpiresAt: Date?
    var totalGamesPlayed: Int
    var totalBuyins: Double
    var totalCashouts: Double
    var createdAt: Date
    var lastLoginAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case isAnonymous = "is_anonymous"
        case isPublic = "is_public"
        case isSuperAdmin = "is_super_admin"
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case totalGamesPlayed = "total_games_played"
        case totalBuyins = "total_buyins"
        case totalCashouts = "total_cashouts"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case updatedAt = "updated_at"
    }

    var balance: Double { totalCashouts - totalBuyins }
}

// MARK: - Game

struct GameDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var gameType: String
    var creatorId: UUID?
    var isPublic: Bool
    var softDeleted: Bool
    var notes: String?
    var timestamp: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case gameType = "game_type"
        case creatorId = "creator_id"
        case isPublic = "is_public"
        case softDeleted = "soft_deleted"
        case notes
        case timestamp
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GamePlayer (GameWithPlayer)

struct GamePlayerDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var gameId: UUID
    var profileId: UUID?
    var playerName: String?
    var buyin: Int
    var cashout: Int64
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case profileId = "profile_id"
        case playerName = "player_name"
        case buyin
        case cashout
        case createdAt = "created_at"
    }

    var profit: Int64 { cashout - Int64(buyin) }
}

// MARK: - PlayerAlias

struct PlayerAliasDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var profileId: UUID
    var aliasName: String
    var claimedAt: Date
    var gamesCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case aliasName = "alias_name"
        case claimedAt = "claimed_at"
        case gamesCount = "games_count"
    }
}

// MARK: - PlayerClaim

struct PlayerClaimDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var playerName: String
    var gameId: UUID
    var gamePlayerId: UUID?
    var claimantId: UUID
    var hostId: UUID
    var status: String
    var resolvedAt: Date?
    var resolvedById: UUID?
    var notes: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case playerName = "player_name"
        case gameId = "game_id"
        case gamePlayerId = "game_player_id"
        case claimantId = "claimant_id"
        case hostId = "host_id"
        case status
        case resolvedAt = "resolved_at"
        case resolvedById = "resolved_by_id"
        case notes
        case createdAt = "created_at"
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isRejected: Bool { status == "rejected" }
}

// MARK: - BilliardBatch

struct BilliardBatchDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var gameId: UUID
    var scorePlayer1: Int16
    var scorePlayer2: Int16
    var timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case scorePlayer1 = "score_player1"
        case scorePlayer2 = "score_player2"
        case timestamp
    }
}

// MARK: - Materialized Views (read-only)

struct GameSummaryDTO: Codable, Identifiable, Sendable {
    let gameId: UUID
    let creatorId: UUID?
    let gameType: String?
    let timestamp: Date?
    let totalPlayers: Int
    let totalBuyins: Double
    let isPublic: Bool
    let lastModified: Date?
    let checksum: String?

    var id: UUID { gameId }

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case creatorId = "creator_id"
        case gameType = "game_type"
        case timestamp
        case totalPlayers = "total_players"
        case totalBuyins = "total_buyins"
        case isPublic = "is_public"
        case lastModified = "last_modified"
        case checksum
    }
}

struct UserStatisticsDTO: Codable, Identifiable, Sendable {
    let userId: UUID
    let totalGamesPlayed: Int
    let totalBuyins: Double
    let totalCashouts: Double
    let balance: Double
    let lastGameDate: Date?
    let winRate: Double
    let avgProfit: Double
    let lastUpdated: Date?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalGamesPlayed = "total_games_played"
        case totalBuyins = "total_buyins"
        case totalCashouts = "total_cashouts"
        case balance
        case lastGameDate = "last_game_date"
        case winRate = "win_rate"
        case avgProfit = "avg_profit"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Device Token

struct DeviceTokenDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var token: String
    var platform: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case token
        case platform
        case createdAt = "created_at"
    }
}

// MARK: - Game Checksum (для smart sync)

struct GameChecksumDTO: Codable, Sendable {
    let gameId: UUID
    let checksum: String

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case checksum
    }
}

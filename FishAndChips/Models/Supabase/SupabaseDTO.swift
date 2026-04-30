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

    /// ₸: cashout сумма в тенге, buyin — чипы (×`ChipValue.tengePerChip`), как GameService / веб.
    var balance: Double { totalCashouts - ChipValue.chipsToTenge(totalBuyins) }
}

// MARK: - Game

struct GameDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var gameType: String
    var creatorId: UUID?
    var isPublic: Bool
    var softDeleted: Bool
    var notes: String?
    var placeId: UUID?
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
        case placeId = "place_id"
        case timestamp
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Place

struct PlaceDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var createdBy: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
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

    var profit: Int64 { cashout - ChipValue.chipsToTenge(buyin) }
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
    /// Для bulk-заявок в БД может быть NULL.
    var gameId: UUID?
    var gamePlayerId: UUID?
    var claimantId: UUID
    var hostId: UUID
    var status: String
    var resolvedAt: Date?
    var resolvedById: UUID?
    var notes: String?
    var createdAt: Date?
    /// `single` | `bulk`; по умолчанию сервер ставит для старых записей через миграции.
    var scope: String
    var placeId: UUID?
    var playerKey: String?
    var affectedGamePlayerIds: [UUID]?
    var blockReason: String?
    var conflictProfileIds: [UUID]?

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
        case scope
        case placeId = "place_id"
        case playerKey = "player_key"
        case affectedGamePlayerIds = "affected_game_player_ids"
        case blockReason = "block_reason"
        case conflictProfileIds = "conflict_profile_ids"
    }

    init(
        id: UUID,
        playerName: String,
        gameId: UUID?,
        gamePlayerId: UUID?,
        claimantId: UUID,
        hostId: UUID,
        status: String,
        resolvedAt: Date?,
        resolvedById: UUID?,
        notes: String?,
        createdAt: Date?,
        scope: String = "single",
        placeId: UUID? = nil,
        playerKey: String? = nil,
        affectedGamePlayerIds: [UUID]? = nil,
        blockReason: String? = nil,
        conflictProfileIds: [UUID]? = nil
    ) {
        self.id = id
        self.playerName = playerName
        self.gameId = gameId
        self.gamePlayerId = gamePlayerId
        self.claimantId = claimantId
        self.hostId = hostId
        self.status = status
        self.resolvedAt = resolvedAt
        self.resolvedById = resolvedById
        self.notes = notes
        self.createdAt = createdAt
        self.scope = scope
        self.placeId = placeId
        self.playerKey = playerKey
        self.affectedGamePlayerIds = affectedGamePlayerIds
        self.blockReason = blockReason
        self.conflictProfileIds = conflictProfileIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        playerName = try c.decode(String.self, forKey: .playerName)
        gameId = try c.decodeIfPresent(UUID.self, forKey: .gameId)
        gamePlayerId = try c.decodeIfPresent(UUID.self, forKey: .gamePlayerId)
        claimantId = try c.decode(UUID.self, forKey: .claimantId)
        hostId = try c.decode(UUID.self, forKey: .hostId)
        status = try c.decode(String.self, forKey: .status)
        resolvedAt = try c.decodeIfPresent(Date.self, forKey: .resolvedAt)
        resolvedById = try c.decodeIfPresent(UUID.self, forKey: .resolvedById)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        scope = try c.decodeIfPresent(String.self, forKey: .scope) ?? "single"
        placeId = try c.decodeIfPresent(UUID.self, forKey: .placeId)
        playerKey = try c.decodeIfPresent(String.self, forKey: .playerKey)
        affectedGamePlayerIds = try Self.decodeUuidArrayOptional(forKey: .affectedGamePlayerIds, from: c)
        blockReason = try c.decodeIfPresent(String.self, forKey: .blockReason)
        conflictProfileIds = try Self.decodeUuidArrayOptional(forKey: .conflictProfileIds, from: c)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(playerName, forKey: .playerName)
        try c.encodeIfPresent(gameId, forKey: .gameId)
        try c.encodeIfPresent(gamePlayerId, forKey: .gamePlayerId)
        try c.encode(claimantId, forKey: .claimantId)
        try c.encode(hostId, forKey: .hostId)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(resolvedAt, forKey: .resolvedAt)
        try c.encodeIfPresent(resolvedById, forKey: .resolvedById)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encode(scope, forKey: .scope)
        try c.encodeIfPresent(placeId, forKey: .placeId)
        try c.encodeIfPresent(playerKey, forKey: .playerKey)
        try PlayerClaimDTO.encodeUuidArrayOptional(affectedGamePlayerIds, to: &c, key: .affectedGamePlayerIds)
        try c.encodeIfPresent(blockReason, forKey: .blockReason)
        try PlayerClaimDTO.encodeUuidArrayOptional(conflictProfileIds, to: &c, key: .conflictProfileIds)
    }

    private static func decodeUuidArrayOptional(
        forKey key: CodingKeys,
        from c: KeyedDecodingContainer<CodingKeys>
    ) throws -> [UUID]? {
        guard c.contains(key), try !c.decodeNil(forKey: key) else {
            return nil
        }
        if let uuids = try? c.decode([UUID].self, forKey: key) {
            return uuids
        }
        if let strings = try? c.decode([String].self, forKey: key) {
            return strings.compactMap { UUID(uuidString: $0) }
        }
        return []
    }

    private static func encodeUuidArrayOptional(
        _ value: [UUID]?,
        to c: inout KeyedEncodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws {
        guard let value else {
            try c.encodeNil(forKey: key)
            return
        }
        try c.encode(value, forKey: key)
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isRejected: Bool { status == "rejected" }
}
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

// MARK: - RangeChart

struct RangeChartDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var position: String        // UTG/MP/CO/BTN/SB/BB
    var selectedHands: [String]
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case position
        case selectedHands = "selected_hands"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

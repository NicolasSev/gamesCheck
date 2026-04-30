import Foundation
import Combine

/// Ответ строки функции `get_claimable_players`.
struct ClaimableRow: Codable, Identifiable, Sendable {
    let hostId: UUID
    let hostUsername: String
    let placeId: UUID?
    let placeName: String
    let playerName: String
    let playerKey: String
    let totalGames: Int
    let totalBalance: Int64
    let lastGameAt: Date?
    let status: String
    let takenByUsername: String?
    let claimId: UUID?
    let blockReason: String?

    var id: String { "\(hostId.uuidString)-\(placeId?.uuidString ?? "∅")-\(playerKey)" }

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case hostUsername = "host_username"
        case placeId = "place_id"
        case placeName = "place_name"
        case playerName = "player_name"
        case playerKey = "player_key"
        case totalGames = "total_games"
        case totalBalance = "total_balance"
        case lastGameAt = "last_game_at"
        case status
        case takenByUsername = "taken_by_username"
        case claimId = "claim_id"
        case blockReason = "block_reason"
    }
}

@MainActor
final class ClaimDiscoveryService: ObservableObject {
    @Published private(set) var rows: [ClaimableRow] = []
    @Published private(set) var isLoading = false
    @Published var lastError: Error?

    private let fetchClaimableRows: (UUID) async throws -> [ClaimableRow]

    init(fetchClaimableRows: @escaping (UUID) async throws -> [ClaimableRow]) {
        self.fetchClaimableRows = fetchClaimableRows
    }

    private static func liveFetchClaimableRows(userId: UUID) async throws -> [ClaimableRow] {
        struct Params: Codable, Sendable {
            let p_user_id: UUID
        }
        return try await SupabaseService.shared.rpc(
            "get_claimable_players",
            params: Params(p_user_id: userId),
        )
    }

    static let shared = ClaimDiscoveryService(
        fetchClaimableRows: { userId in
            try await liveFetchClaimableRows(userId: userId)
        }
    )

    func refresh(userId: UUID) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            rows = try await fetchClaimableRows(userId)
        } catch {
            lastError = error
        }
    }

    /// Возвращает id созданной строки заявки в `player_claims`.
    func submitBulk(hostId: UUID, placeId: UUID?, playerName: String) async throws -> UUID {
        struct Params: Codable, Sendable {
            let p_host_id: UUID
            let p_place_id: UUID?
            let p_player_name: String
        }

        let id: UUID = try await SupabaseService.shared.rpc(
            "submit_bulk_claim",
            params: Params(p_host_id: hostId, p_place_id: placeId, p_player_name: playerName.trimmingCharacters(in: .whitespacesAndNewlines)),
        )
        return id
    }

    func cancelBulk(claimId: UUID) async throws {
        struct Params: Codable, Sendable {
            let p_claim_id: UUID
        }

        try await SupabaseService.shared.rpc("cancel_bulk_claim", params: Params(p_claim_id: claimId))
    }
}

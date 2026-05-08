import Foundation
import Combine

private let kActivePlaceId = "fishchips:activePlaceId"
private let kActivePlaceName = "fishchips:activePlaceName"

/// Holds the user's venue context: which place is active and which places they belong to.
/// Analogous to the web admin's PlaceContext.
@MainActor
final class PlaceSessionManager: ObservableObject {
    static let shared = PlaceSessionManager()

    @Published private(set) var memberships: [PlaceMembershipDTO] = []
    @Published private(set) var activePlaceId: UUID?
    @Published private(set) var activePlaceName: String?
    @Published private(set) var isLoading = false
    /// Первый успешный fetchMemberships завершён. Используется gate'ом, чтобы не
    /// мерцать onboarding-экраном до прихода данных.
    @Published private(set) var hasLoaded = false
    /// Map placeId → place_player.id, если у user есть привязка в этом месте.
    /// Используется gate'ом «найди себя в списке» (PostAccessPlayerLinkView).
    @Published private(set) var linkedPlacePlayerIdsByPlace: [UUID: UUID] = [:]
    /// Состояние первой проверки link'а в активном месте: установлен после первого
    /// успешного `refreshLinkInActivePlace`. До этого gate ждёт, чтобы не мерцать.
    @Published private(set) var linkCheckDone = false

    var activeMembership: PlaceMembershipDTO? {
        memberships.first { $0.placeId == activePlaceId }
    }

    private let supabase = SupabaseService.shared

    private init() {
        if let stored = UserDefaults.standard.string(forKey: kActivePlaceId),
           let id = UUID(uuidString: stored) {
            activePlaceId = id
            activePlaceName = UserDefaults.standard.string(forKey: kActivePlaceName)
        }
    }

    // MARK: - Fetch memberships from Supabase

    func fetchMemberships() async {
        guard await supabase.currentUserId() != nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            struct NoParams: Codable {}
            let rows: [PlaceMembershipDTO] = try await supabase.rpc("get_my_place_memberships", params: NoParams())
            memberships = rows
            reconcileActivePlace()
            hasLoaded = true
        } catch {
            debugLog("PlaceSessionManager: fetchMemberships error: \(error)")
        }
    }

    // MARK: - Active place selection

    func setActivePlace(_ membership: PlaceMembershipDTO) {
        activePlaceId = membership.placeId
        activePlaceName = membership.placeName
        UserDefaults.standard.set(membership.placeId.uuidString, forKey: kActivePlaceId)
        UserDefaults.standard.set(membership.placeName, forKey: kActivePlaceName)
    }

    func clearActivePlace() {
        activePlaceId = nil
        activePlaceName = nil
        UserDefaults.standard.removeObject(forKey: kActivePlaceId)
        UserDefaults.standard.removeObject(forKey: kActivePlaceName)
    }

    // MARK: - Request access to a place

    func requestAccess(placeId: UUID, message: String?) async throws {
        struct Params: Codable {
            let p_place_id: UUID
            let p_message: String?
        }
        try await supabase.rpc("request_place_access", params: Params(p_place_id: placeId, p_message: message))
    }

    // MARK: - Request to link profile to a place_player

    func requestPlayerLink(placePlayerId: UUID, message: String?) async throws {
        struct Params: Codable {
            let p_place_player_id: UUID
            let p_message: String?
        }
        try await supabase.rpc("request_place_link", params: Params(p_place_player_id: placePlayerId, p_message: message))
    }

    // MARK: - Request to create a new place

    func requestCreatePlace(proposedName: String, message: String?) async throws {
        struct Params: Codable {
            let p_proposed_name: String
            let p_message: String?
        }
        try await supabase.rpc("request_create_place", params: Params(p_proposed_name: proposedName, p_message: message))
    }

    // MARK: - Fetch available places (for access request flow)

    func fetchAllActivePlaces() async throws -> [PlaceDTO] {
        struct NoParams: Codable {}
        return try await supabase.rpc("get_all_active_places", params: NoParams())
    }

    // MARK: - Fetch unlinked place_players for link request flow

    func fetchPlacePlayers(placeId: UUID) async throws -> [PlacePlayerDTO] {
        struct Params: Codable { let p_place_id: UUID }
        return try await supabase.rpc("get_place_players_for_link", params: Params(p_place_id: placeId))
    }

    // MARK: - Onboarding gate (фаза 9)

    /// Каталог активных мест для onboarding-экрана. Доступен любому authenticated.
    /// Вью `places_directory` возвращает каждому пользователю его статус по месту
    /// (i_am_member / has_pending_access_request_from_me / member_role).
    func fetchPlacesDirectory() async throws -> [PlaceDirectoryEntryDTO] {
        return try await supabase.fetchAll(table: "places_directory")
    }

    /// Имена игроков активного места, без финансов. Доступно только members места
    /// (RLS на `place_players`). Используется в PostAccessPlayerLinkView.
    func fetchPlacePlayersNamesOnly(placeId: UUID) async throws -> [PlacePlayerNameOnlyDTO] {
        return try await supabase.fetchByFilter(table: "place_players_names_only") { q in
            q.eq("place_id", value: placeId).order("display_name", ascending: true)
        }
    }

    /// Проверяет, есть ли у текущего пользователя `place_players` row в активном
    /// месте. Используется gate'ом B.3 (PostAccessPlayerLinkView).
    func refreshLinkInActivePlace() async {
        guard let pid = activePlaceId else {
            linkCheckDone = true
            return
        }
        do {
            let rows = try await fetchPlacePlayersNamesOnly(placeId: pid)
            if let me = rows.first(where: { $0.isMe }) {
                linkedPlacePlayerIdsByPlace[pid] = me.id
            } else {
                linkedPlacePlayerIdsByPlace.removeValue(forKey: pid)
            }
        } catch {
            debugLog("PlaceSessionManager: refreshLinkInActivePlace error: \(error)")
        }
        linkCheckDone = true
    }

    /// True если у user есть привязка к place_player в активном месте.
    var isLinkedInActivePlace: Bool {
        guard let pid = activePlaceId else { return false }
        return linkedPlacePlayerIdsByPlace[pid] != nil
    }

    /// True если активная мембершип имеет роль admin (или user — super_admin —
    /// проверка через role не работает; для super-admin'а это вычисляется отдельно).
    var isAdminInActivePlace: Bool {
        activeMembership?.isAdmin ?? false
    }

    /// Отменить свою заявку на доступ к месту.
    func cancelPlaceAccessRequest(requestId: UUID) async throws {
        struct Params: Codable { let p_request_id: UUID }
        try await supabase.rpc("cancel_place_access_request", params: Params(p_request_id: requestId))
    }

    /// Отменить свою заявку на создание места.
    func cancelPlaceCreateRequest(requestId: UUID) async throws {
        struct Params: Codable { let p_request_id: UUID }
        try await supabase.rpc("cancel_place_create_request", params: Params(p_request_id: requestId))
    }

    // MARK: - Helpers

    private func reconcileActivePlace() {
        guard let current = activePlaceId else {
            let preferred = memberships.first(where: { $0.isAdmin }) ?? memberships.first
            if let m = preferred { setActivePlace(m) }
            return
        }
        if let match = memberships.first(where: { $0.placeId == current }) {
            activePlaceName = match.placeName
            UserDefaults.standard.set(match.placeName, forKey: kActivePlaceName)
        } else if !memberships.isEmpty {
            let preferred = memberships.first(where: { $0.isAdmin }) ?? memberships.first!
            setActivePlace(preferred)
        }
    }
}

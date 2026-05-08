import Foundation
import Supabase
import Realtime

/// Слушает Realtime-обновления, влияющие на onboarding-состояние пользователя:
///   - INSERT/UPDATE `place_members`           → fetch memberships (новый approve)
///   - UPDATE `place_players` (profile_id)     → re-check link в активном месте
///   - UPDATE `place_create_requests` → user'у показать что заявку приняли/отклонили
///
/// Подписка фильтруется через RLS — пользователь получает только свои строки.
/// Триггерит `placeSession.fetchMemberships()` и `refreshLinkInActivePlace()`.
@MainActor
final class PlaceUpdatesListenerService {
    static let shared = PlaceUpdatesListenerService()

    private let client: SupabaseClient
    private var channels: [RealtimeChannelV2] = []
    private var debouncedRefreshTask: Task<Void, Never>?
    private let debounceNs: UInt64 = 600_000_000

    private init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func startListening() async {
        guard channels.isEmpty else { return }

        let mainChannel = client.realtimeV2.channel("place-onboarding-updates")
        let memberInserts = mainChannel.postgresChange(InsertAction.self, table: "place_members")
        let memberUpdates = mainChannel.postgresChange(UpdateAction.self, table: "place_members")
        let playerUpdates = mainChannel.postgresChange(UpdateAction.self, table: "place_players")
        let createReqUpdates = mainChannel.postgresChange(UpdateAction.self, table: "place_create_requests")

        Task { [weak self] in
            for await _ in memberInserts { await self?.enqueueRefresh() }
        }
        Task { [weak self] in
            for await _ in memberUpdates { await self?.enqueueRefresh() }
        }
        Task { [weak self] in
            for await _ in playerUpdates { await self?.enqueueRefresh() }
        }
        Task { [weak self] in
            for await _ in createReqUpdates { await self?.enqueueRefresh() }
        }

        await mainChannel.subscribe()
        channels.append(mainChannel)
        debugLog("PlaceUpdatesListener: subscribed to place_members/place_players/place_create_requests")
    }

    func stopListening() async {
        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = nil
        for channel in channels {
            await channel.unsubscribe()
        }
        channels.removeAll()
        debugLog("PlaceUpdatesListener: unsubscribed")
    }

    private func enqueueRefresh() async {
        debouncedRefreshTask?.cancel()
        let nanos = debounceNs
        debouncedRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard let self, !Task.isCancelled else { return }
            await PlaceSessionManager.shared.fetchMemberships()
            await PlaceSessionManager.shared.refreshLinkInActivePlace()
        }
    }
}

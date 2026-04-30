import Foundation
import Supabase
import Realtime

/// INSERT на `admin_player_merges` → полный resync локального кэша (phase 12).
/// **Примечание:** RLS на таблице — SELECT только для `super_admin`; обычные хост-клиенты событие не получат без отдельной политики/сигналов на бэкенде.
@MainActor
final class PlayerMergeListenerService {
    static let shared = PlayerMergeListenerService()

    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var debouncedResyncTask: Task<Void, Never>?
    /// Минимум между последовательными событиями INSERT (батч нескольких мержей подряд).
    private let debounceNs: UInt64 = 1_500_000_000

    private init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func startListening() async {
        guard channel == nil else { return }

        let channel = client.realtimeV2.channel("admin-player-merges")
        let insertions = channel.postgresChange(InsertAction.self, table: "admin_player_merges")

        Task { [weak self] in
            for await _ in insertions {
                await self?.enqueueDebouncedMergeResync()
            }
        }

        await channel.subscribe()
        self.channel = channel
        debugLog("PlayerMergeListener: subscribed to admin_player_merges (INSERT)")
    }

    func stopListening() async {
        debouncedResyncTask?.cancel()
        debouncedResyncTask = nil
        if let channel {
            await channel.unsubscribe()
            self.channel = nil
            debugLog("PlayerMergeListener: unsubscribed")
        }
    }

    private func enqueueDebouncedMergeResync() async {
        debouncedResyncTask?.cancel()
        let nanos = debounceNs
        debouncedResyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            do {
                try await SyncCoordinator.shared.fullResyncAfterMerge()
                debugLog("PlayerMergeListener: full resync after merge completed (debounced)")
            } catch {
                debugLog("PlayerMergeListener: fullResyncAfterMerge error: \(error)")
            }
        }
    }
}

import Foundation
import Supabase
import Realtime

/// Сервис Realtime-подписок через Supabase
/// Заменяет CKQuerySubscription из NotificationService
@MainActor
final class SupabaseRealtimeService: ObservableObject {
    static let shared = SupabaseRealtimeService()

    @Published var isConnected = false

    private let client: SupabaseClient
    private var gameChannel: RealtimeChannelV2?
    private var claimChannel: RealtimeChannelV2?
    private var profileChannel: RealtimeChannelV2?

    private nonisolated init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    // MARK: - Subscribe to All

    func subscribeAll() async {
        await subscribeToGames()
        await subscribeToClaims()
        await subscribeToProfiles()
        isConnected = true
        debugLog("Supabase Realtime: all subscriptions active")
    }

    // MARK: - Unsubscribe All

    func unsubscribeAll() async {
        if let channel = gameChannel {
            await channel.unsubscribe()
            gameChannel = nil
        }
        if let channel = claimChannel {
            await channel.unsubscribe()
            claimChannel = nil
        }
        if let channel = profileChannel {
            await channel.unsubscribe()
            profileChannel = nil
        }
        isConnected = false
        debugLog("Supabase Realtime: all subscriptions removed")
    }

    // MARK: - Games

    /// Подписка на новые/обновлённые игры (замена CKQuerySubscription "game-updates")
    private func subscribeToGames() async {
        let channel = client.realtimeV2.channel("game-changes")

        let insertions = channel.postgresChange(InsertAction.self, table: "games")
        let updates = channel.postgresChange(UpdateAction.self, table: "games")

        Task {
            for await insertion in insertions {
                await handleGameChange(record: insertion.record, isNew: true)
            }
        }

        Task {
            for await update in updates {
                await handleGameChange(record: update.record, isNew: false)
            }
        }

        await channel.subscribe()
        gameChannel = channel
        debugLog("Supabase Realtime: subscribed to games")
    }

    // MARK: - Claims

    private func subscribeToClaims() async {
        let channel = client.realtimeV2.channel("claim-changes")

        let insertions = channel.postgresChange(InsertAction.self, table: "player_claims")
        let updates = channel.postgresChange(UpdateAction.self, table: "player_claims")

        Task {
            for await insertion in insertions {
                await handleClaimChange(record: insertion.record, isNew: true)
            }
        }

        Task {
            for await update in updates {
                await handleClaimChange(record: update.record, isNew: false)
            }
        }

        await channel.subscribe()
        claimChannel = channel
        debugLog("Supabase Realtime: subscribed to claims")
    }

    // MARK: - Profiles

    /// Подписка на публичные профили (замена CKQuerySubscription "profile-public")
    private func subscribeToProfiles() async {
        let channel = client.realtimeV2.channel("profile-changes")

        let updates = channel.postgresChange(UpdateAction.self, table: "profiles")

        Task {
            for await update in updates {
                await handleProfileChange(record: update.record)
            }
        }

        await channel.subscribe()
        profileChannel = channel
        debugLog("Supabase Realtime: subscribed to profiles")
    }

    // MARK: - Handlers

    private func handleGameChange(record: [String: AnyJSON], isNew: Bool) async {
        guard let gameIdString = record["id"]?.stringValue,
              let gameId = UUID(uuidString: gameIdString) else { return }

        debugLog("Realtime: game \(isNew ? "created" : "updated") — \(gameId)")

        do {
            try await SupabaseSyncService.shared.performIncrementalSync()

            if isNew {
                let creatorId = record["creator_id"]?.stringValue ?? ""
                let gameType = record["game_type"]?.stringValue ?? "Poker"

                if let currentUserId = await SupabaseService.shared.currentUserId(),
                   creatorId != currentUserId.uuidString {
                    try await NotificationService.shared.notifyNewGame(
                        gameName: gameType,
                        hostName: "Игрок",
                        gameId: gameId
                    )
                }
            }
        } catch {
            debugLog("Realtime game handler error: \(error)")
        }
    }

    private func handleClaimChange(record: [String: AnyJSON], isNew: Bool) async {
        guard let claimIdString = record["id"]?.stringValue,
              let _ = UUID(uuidString: claimIdString) else { return }

        debugLog("Realtime: claim \(isNew ? "created" : "updated")")

        do {
            try await SupabaseSyncService.shared.performIncrementalSync()
        } catch {
            debugLog("Realtime claim handler error: \(error)")
        }
    }

    private func handleProfileChange(record: [String: AnyJSON]) async {
        let isPublic = record["is_public"]?.boolValue ?? false
        let displayName = record["display_name"]?.stringValue ?? "Игрок"

        if isPublic {
            debugLog("Realtime: profile became public — \(displayName)")
            await NotificationService.shared.notifyProfileBecamePublic(displayName: displayName)
        }

        do {
            try await SupabaseSyncService.shared.performIncrementalSync()
        } catch {
            debugLog("Realtime profile handler error: \(error)")
        }
    }
}

// MARK: - AnyJSON helpers

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        default: return nil
        }
    }
}

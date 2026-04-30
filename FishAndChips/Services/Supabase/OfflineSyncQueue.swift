import Foundation
import CoreData

/// Offline queue — сохраняет операции локально, когда нет сети
/// При восстановлении подключения проигрывает очередь по порядку
final class OfflineSyncQueue: ObservableObject {

    static let shared = OfflineSyncQueue()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isProcessing: Bool = false

    private let key = "offlineSyncQueue"
    private let lock = NSLock()
    private let maxRetries = 8

    struct QueuedOperation: Codable, Identifiable {
        let id: UUID
        let table: String
        let operation: OperationType
        let payload: Data
        let createdAt: Date
        var retryCount: Int

        enum OperationType: String, Codable {
            case upsert
            case delete
        }
    }

    private init() {
        pendingCount = loadQueue().count
    }

    // MARK: - Public API

    func enqueue<T: Encodable>(table: String, operation: QueuedOperation.OperationType, item: T) {
        lock.lock()
        defer { lock.unlock() }

        guard let payload = try? JSONEncoder().encode(item) else { return }

        let op = QueuedOperation(
            id: UUID(),
            table: table,
            operation: operation,
            payload: payload,
            createdAt: Date(),
            retryCount: 0
        )

        var queue = loadQueue()
        queue.append(op)
        saveQueue(queue)
        pendingCount = queue.count
    }

    func processQueue() async {
        let queue = lock.withLock { loadQueue() }
        guard !queue.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        var remaining: [QueuedOperation] = []
        let service = SupabaseService.shared

        for var op in queue {
            // Exponential backoff: wait 2^retryCount seconds before retrying
            if op.retryCount > 0 {
                let delay = min(pow(2.0, Double(op.retryCount)), 60.0)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                switch op.operation {
                case .upsert:
                    try await processUpsert(service: service, operation: op)
                case .delete:
                    try await processDelete(service: service, operation: op)
                }
                debugLog("OfflineSyncQueue: processed \(op.table) \(op.operation.rawValue)")
            } catch {
                op.retryCount += 1
                if op.retryCount < maxRetries {
                    remaining.append(op)
                } else {
                    debugLog("OfflineSyncQueue: dropped \(op.table) after \(maxRetries) retries")
                }
                debugLog("OfflineSyncQueue: retry \(op.retryCount)/\(maxRetries) for \(op.table): \(error)")
            }
        }

        lock.lock()
        saveQueue(remaining)
        pendingCount = remaining.count
        lock.unlock()
    }

    /// Mark that a full Supabase sync is needed when connectivity is restored
    func enqueueFullSync() {
        UserDefaults.standard.set(true, forKey: "offlineSyncNeedsFullSync")
        debugLog("OfflineSyncQueue: full sync enqueued for reconnect")
    }

    /// Check and clear the full-sync marker
    var needsFullSync: Bool {
        let needs = UserDefaults.standard.bool(forKey: "offlineSyncNeedsFullSync")
        if needs { UserDefaults.standard.set(false, forKey: "offlineSyncNeedsFullSync") }
        return needs
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        saveQueue([])
        pendingCount = 0
    }

    /// После admin merge на сервере pending upsert `game_players` конфликтуют с авторитетным состоянием — отбрасываем их.
    func discardPendingGamePlayerUpserts() {
        lock.lock()
        defer { lock.unlock() }
        var queue = loadQueue()
        let before = queue.count
        queue.removeAll { $0.table == "game_players" && $0.operation == .upsert }
        saveQueue(queue)
        pendingCount = queue.count
        if before != pendingCount {
            debugLog("OfflineSyncQueue: discarded \(before - pendingCount) pending game_players upserts (merge reconcile)")
        }
    }

    // MARK: - Processing

    private func processUpsert(service: SupabaseService, operation: QueuedOperation) async throws {
        switch operation.table {
        case "profiles":
            let dto = try JSONDecoder().decode(ProfileDTO.self, from: operation.payload)
            let _: [ProfileDTO] = try await service.upsert(table: "profiles", values: [dto])
        case "games":
            let dto = try JSONDecoder().decode(GameDTO.self, from: operation.payload)
            let _: [GameDTO] = try await service.upsert(table: "games", values: [dto])
        case "game_players":
            let dto = try JSONDecoder().decode(GamePlayerDTO.self, from: operation.payload)
            let _: [GamePlayerDTO] = try await service.upsert(table: "game_players", values: [dto])
        case "player_aliases":
            let dto = try JSONDecoder().decode(PlayerAliasDTO.self, from: operation.payload)
            let _: [PlayerAliasDTO] = try await service.upsert(table: "player_aliases", values: [dto])
        case "player_claims":
            let dto = try JSONDecoder().decode(PlayerClaimDTO.self, from: operation.payload)
            let _: [PlayerClaimDTO] = try await service.upsert(table: "player_claims", values: [dto])
        case "range_charts":
            let dto = try JSONDecoder().decode(RangeChartDTO.self, from: operation.payload)
            let _: RangeChartDTO = try await service.upsert(table: "range_charts", values: dto)
        default:
            debugLog("OfflineSyncQueue: unknown table \(operation.table)")
        }
    }

    private func processDelete(service: SupabaseService, operation: QueuedOperation) async throws {
        guard let idString = String(data: operation.payload, encoding: .utf8)?.replacingOccurrences(of: "\"", with: ""),
              let id = UUID(uuidString: idString) else { return }

        try await service.delete(table: operation.table, id: id)
    }

    // MARK: - Persistence

    private func loadQueue() -> [QueuedOperation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let queue = try? JSONDecoder().decode([QueuedOperation].self, from: data) else {
            return []
        }
        return queue
    }

    private func saveQueue(_ queue: [QueuedOperation]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

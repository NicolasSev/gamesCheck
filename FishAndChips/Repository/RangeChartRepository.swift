import Foundation

/// Точка доступа к диапазонам открытия.
/// Читает из Core Data (кэш), пишет в Core Data + Supabase (или очередь при офлайне).
@MainActor
final class RangeChartRepository {
    private let persistence: PersistenceController
    private let service: SupabaseService
    private let offlineQueue: OfflineSyncQueue

    init(
        persistence: PersistenceController = .shared,
        service: SupabaseService = .shared,
        offlineQueue: OfflineSyncQueue = .shared
    ) {
        self.persistence = persistence
        self.service = service
        self.offlineQueue = offlineQueue
    }

    // MARK: - Fetch (local + optional remote pull)

    /// Возвращает все 6 чартов для пользователя из Core Data.
    /// Если чарты отсутствуют — возвращает пустые модели (lazy init).
    func fetchAll(for userId: UUID) -> [RangeChartModel] {
        let stored = persistence.fetchAllRangeCharts(userId: userId)
        var byPosition: [String: RangeChartModel] = [:]
        for chart in stored {
            if let model = chart.toModel() {
                byPosition[model.position.rawValue] = model
            }
        }
        // Гарантируем наличие всех 6 позиций
        return RangePosition.allCases.map { pos in
            byPosition[pos.rawValue] ?? RangeChartModel(
                id: UUID(),
                userId: userId,
                position: pos,
                selectedHands: [],
                updatedAt: Date()
            )
        }
    }

    // MARK: - Pull from Supabase

    /// Скачивает все чарты пользователя с сервера и обновляет Core Data (last-write-wins).
    func syncFromRemote(userId: UUID) async throws {
        let dtos: [RangeChartDTO] = try await service.fetchByColumn(
            table: "range_charts",
            column: "user_id",
            value: userId.uuidString
        )
        for dto in dtos {
            let existing = persistence.fetchRangeChart(userId: dto.userId, position: dto.position)
            // last-write-wins по updatedAt
            if let existing = existing,
               let existingUpdated = Optional(existing.updatedAt),
               let remoteUpdated = dto.updatedAt,
               existingUpdated > remoteUpdated && existing.dirty {
                // Локальная версия новее и грязная — не перезаписываем
                continue
            }
            persistence.upsertRangeChart(from: dto)
        }
    }

    // MARK: - Save (optimistic local write + async remote)

    /// Сохраняет чарт локально и отправляет на сервер (или в офлайн-очередь).
    func save(_ model: RangeChartModel, isOnline: Bool) async {
        persistence.upsertRangeChart(model: model)

        let dto = RangeChartDTO(
            id: model.id,
            userId: model.userId,
            position: model.position.rawValue,
            selectedHands: Array(model.selectedHands),
            createdAt: nil,
            updatedAt: model.updatedAt
        )

        if isOnline {
            do {
                let _: RangeChartDTO = try await service.upsert(table: "range_charts", values: dto)
                // Сбрасываем dirty после успешного синка
                if let chart = persistence.fetchRangeChart(userId: model.userId, position: model.position.rawValue) {
                    chart.dirty = false
                    persistence.saveContext()
                }
            } catch {
                debugLog("RangeChartRepository: upsert failed — \(error)")
                // Остаётся dirty, подберём при следующем reconnect
            }
        } else {
            offlineQueue.enqueue(table: "range_charts", operation: .upsert, item: dto)
        }
    }

    // MARK: - Reset

    func reset(position: RangePosition, userId: UUID, isOnline: Bool) async {
        let emptyModel = RangeChartModel(
            id: persistence.fetchRangeChart(userId: userId, position: position.rawValue)?.id ?? UUID(),
            userId: userId,
            position: position,
            selectedHands: [],
            updatedAt: Date()
        )
        await save(emptyModel, isOnline: isOnline)
    }
}

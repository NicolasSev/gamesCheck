import Foundation
import Combine

@MainActor
final class RangesViewModel: ObservableObject {
    @Published private(set) var charts: [RangePosition: RangeChartModel] = [:]
    @Published private(set) var isLoading = false
    @Published var showResetConfirm = false

    private let repo: RangeChartRepository
    private let syncCoordinator: SyncCoordinator

    // Debounce: накапливаем изменения 400 мс, затем отправляем одним запросом
    private var saveWorkItems: [RangePosition: DispatchWorkItem] = [:]

    init(
        repo: RangeChartRepository? = nil,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repo = repo ?? RangeChartRepository()
        self.syncCoordinator = syncCoordinator ?? .shared
    }

    // MARK: - Load

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Сначала показываем локальный кэш
        let local = repo.fetchAll(for: userId)
        charts = Dictionary(uniqueKeysWithValues: local.map { ($0.position, $0) })

        // Затем тянем с сервера (если онлайн)
        do {
            try await syncCoordinator.syncRangeCharts(for: userId)
            // Обновляем из Core Data после синка
            let refreshed = repo.fetchAll(for: userId)
            charts = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.position, $0) })
        } catch {
            debugLog("RangesViewModel: sync error — \(error)")
        }
    }

    // MARK: - Toggle

    func toggle(hand: String, position: RangePosition, userId: UUID) {
        guard var chart = charts[position] else { return }
        chart.toggle(hand: hand)
        charts[position] = chart

        scheduleSave(chart: chart, userId: userId)
    }

    // MARK: - Reset

    func reset(position: RangePosition, userId: UUID) async {
        await repo.reset(position: position, userId: userId, isOnline: syncCoordinator.isOnline)
        let refreshed = repo.fetchAll(for: userId)
        charts = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.position, $0) })
    }

    // MARK: - Stats

    func percent(for position: RangePosition) -> Double {
        guard let chart = charts[position] else { return 0 }
        return HandGrid.weightedPercent(chart.selectedHands)
    }

    func handCount(for position: RangePosition) -> Int {
        charts[position]?.selectedHands.count ?? 0
    }

    // MARK: - Debounced Save

    private func scheduleSave(chart: RangeChartModel, userId: UUID) {
        saveWorkItems[chart.position]?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.repo.save(chart, isOnline: self.syncCoordinator.isOnline)
            }
        }
        saveWorkItems[chart.position] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }
}

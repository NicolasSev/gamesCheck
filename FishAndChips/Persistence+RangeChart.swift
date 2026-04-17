import CoreData

// MARK: - RangeChart Core Data Management

extension PersistenceController {

    // MARK: - Upsert (insert or update)

    @discardableResult
    func upsertRangeChart(from dto: RangeChartDTO) -> RangeChart {
        let context = container.viewContext
        let existing = fetchRangeChart(userId: dto.userId, position: dto.position)
        let chart = existing ?? RangeChart(context: context)

        chart.id = dto.id
        chart.userId = dto.userId
        chart.position = dto.position
        chart.selectedHandsJson = encodeHands(dto.selectedHands)
        chart.updatedAt = dto.updatedAt ?? Date()
        chart.dirty = false

        saveContext()
        return chart
    }

    @discardableResult
    func upsertRangeChart(model: RangeChartModel) -> RangeChart {
        let context = container.viewContext
        let existing = fetchRangeChart(userId: model.userId, position: model.position.rawValue)
        let chart = existing ?? RangeChart(context: context)

        chart.id = model.id
        chart.userId = model.userId
        chart.position = model.position.rawValue
        chart.selectedHandsJson = encodeHands(Array(model.selectedHands))
        chart.updatedAt = model.updatedAt
        chart.dirty = true

        saveContext()
        return chart
    }

    // MARK: - Fetch

    func fetchRangeChart(userId: UUID, position: String) -> RangeChart? {
        let context = container.viewContext
        let request: NSFetchRequest<RangeChart> = RangeChart.fetchRequest()
        request.predicate = NSPredicate(
            format: "userId == %@ AND position == %@",
            userId as CVarArg, position
        )
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    func fetchAllRangeCharts(userId: UUID) -> [RangeChart] {
        let context = container.viewContext
        let request: NSFetchRequest<RangeChart> = RangeChart.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchDirtyRangeCharts(userId: UUID) -> [RangeChart] {
        let context = container.viewContext
        let request: NSFetchRequest<RangeChart> = RangeChart.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND dirty == YES", userId as CVarArg)
        return (try? context.fetch(request)) ?? []
    }

    func deleteRangeChart(userId: UUID, position: String) {
        guard let chart = fetchRangeChart(userId: userId, position: position) else { return }
        container.viewContext.delete(chart)
        saveContext()
    }

    // MARK: - Helpers

    private func encodeHands(_ hands: [String]) -> String {
        (try? String(data: JSONEncoder().encode(hands), encoding: .utf8)) ?? "[]"
    }
}

// MARK: - RangeChart → Domain Model

extension RangeChart {
    func toModel() -> RangeChartModel? {
        guard let pos = RangePosition(rawValue: position) else { return nil }
        let hands = decodeHands(selectedHandsJson)
        return RangeChartModel(
            id: id,
            userId: userId,
            position: pos,
            selectedHands: Set(hands),
            updatedAt: updatedAt
        )
    }

    func toDTO() -> RangeChartDTO {
        RangeChartDTO(
            id: id,
            userId: userId,
            position: position,
            selectedHands: decodeHands(selectedHandsJson),
            createdAt: nil,
            updatedAt: updatedAt
        )
    }

    private func decodeHands(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let hands = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return hands
    }
}

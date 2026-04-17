import Testing
import Foundation
@testable import FishAndChips

// MARK: - HandGrid Tests

@MainActor
struct HandGridTests {

    // (0,0) → "AA", (0,1) → "AKs", (1,0) → "AKo", (12,12) → "22"
    @Test func handId_cornerCells() {
        #expect(HandGrid.handId(row: 0, col: 0) == "AA")
        #expect(HandGrid.handId(row: 0, col: 1) == "AKs")
        #expect(HandGrid.handId(row: 1, col: 0) == "AKo")
        #expect(HandGrid.handId(row: 12, col: 12) == "22")
    }

    @Test func handId_diagonalIsPair() {
        for i in 0..<13 {
            let hand = HandGrid.handId(row: i, col: i)
            #expect(hand.count == 2, "Expected pair of length 2, got \(hand)")
            #expect(hand.first == hand.last, "Pair should have same chars: \(hand)")
        }
    }

    @Test func handId_upperTriangleIsSuited() {
        // row < col → suited
        #expect(HandGrid.handId(row: 0, col: 2) == "AQs")
        #expect(HandGrid.handId(row: 1, col: 2) == "KQs")
    }

    @Test func handId_lowerTriangleIsOffsuit() {
        // row > col → offsuit
        #expect(HandGrid.handId(row: 2, col: 0) == "AQo")
        #expect(HandGrid.handId(row: 2, col: 1) == "KQo")
    }

    @Test func handId_all169Unique() {
        var ids = Set<String>()
        for row in 0..<13 {
            for col in 0..<13 {
                ids.insert(HandGrid.handId(row: row, col: col))
            }
        }
        #expect(ids.count == 169)
    }

    // MARK: - kind(of:)

    @Test func kind_pair() {
        #expect(HandGrid.kind(of: "AA") == .pair)
        #expect(HandGrid.kind(of: "22") == .pair)
        #expect(HandGrid.kind(of: "TT") == .pair)
    }

    @Test func kind_suited() {
        #expect(HandGrid.kind(of: "AKs") == .suited)
        #expect(HandGrid.kind(of: "T9s") == .suited)
        #expect(HandGrid.kind(of: "54s") == .suited)
    }

    @Test func kind_offsuit() {
        #expect(HandGrid.kind(of: "AKo") == .offsuit)
        #expect(HandGrid.kind(of: "Q7o") == .offsuit)
        #expect(HandGrid.kind(of: "32o") == .offsuit)
    }

    // MARK: - weightedPercent

    @Test func weightedPercent_empty() {
        #expect(HandGrid.weightedPercent([]) == 0)
    }

    @Test func weightedPercent_onePair() {
        // AA = 6 combos / 1326 * 100
        let pct = HandGrid.weightedPercent(["AA"])
        #expect(abs(pct - 6.0 / 1326.0 * 100.0) < 0.001)
    }

    @Test func weightedPercent_oneSuited() {
        // AKs = 4 combos / 1326 * 100
        let pct = HandGrid.weightedPercent(["AKs"])
        #expect(abs(pct - 4.0 / 1326.0 * 100.0) < 0.001)
    }

    @Test func weightedPercent_oneOffsuit() {
        // AKo = 12 combos / 1326 * 100
        let pct = HandGrid.weightedPercent(["AKo"])
        #expect(abs(pct - 12.0 / 1326.0 * 100.0) < 0.001)
    }

    @Test func weightedPercent_mixed() {
        // AA(6) + AKs(4) + AKo(12) = 22 combos
        let pct = HandGrid.weightedPercent(["AA", "AKs", "AKo"])
        #expect(abs(pct - 22.0 / 1326.0 * 100.0) < 0.001)
    }
}

// MARK: - RangeChartModel Tests

@MainActor
struct RangeChartModelTests {

    @Test func toggle_addsHand() {
        var model = makeModel()
        model.toggle(hand: "AA")
        #expect(model.selectedHands.contains("AA"))
    }

    @Test func toggle_removesHand() {
        var model = makeModel(hands: ["AA"])
        model.toggle(hand: "AA")
        #expect(!model.selectedHands.contains("AA"))
    }

    @Test func toggle_updatesTimestamp() {
        var model = makeModel()
        let before = model.updatedAt
        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)
        model.toggle(hand: "KK")
        #expect(model.updatedAt >= before)
    }

    // MARK: - Helpers

    private func makeModel(hands: Set<String> = []) -> RangeChartModel {
        RangeChartModel(
            id: UUID(),
            userId: UUID(),
            position: .BTN,
            selectedHands: hands,
            updatedAt: Date()
        )
    }
}

// MARK: - Persistence+RangeChart Tests

@MainActor
struct PersistenceRangeChartTests {

    @Test func upsertAndFetch() {
        let persistence = PersistenceController(inMemory: true)
        let userId = UUID()
        let dto = RangeChartDTO(
            id: UUID(),
            userId: userId,
            position: "BTN",
            selectedHands: ["AA", "KK", "AKs"],
            createdAt: nil,
            updatedAt: Date()
        )

        persistence.upsertRangeChart(from: dto)
        let fetched = persistence.fetchRangeChart(userId: userId, position: "BTN")

        #expect(fetched != nil)
        let model = fetched?.toModel()
        #expect(model?.selectedHands.contains("AA") == true)
        #expect(model?.selectedHands.contains("KK") == true)
        #expect(model?.selectedHands.count == 3)
    }

    @Test func upsertTwice_updatesExisting() {
        let persistence = PersistenceController(inMemory: true)
        let userId = UUID()
        let id = UUID()

        let dto1 = RangeChartDTO(id: id, userId: userId, position: "UTG",
                                 selectedHands: ["AA"], createdAt: nil, updatedAt: Date())
        persistence.upsertRangeChart(from: dto1)

        let dto2 = RangeChartDTO(id: id, userId: userId, position: "UTG",
                                 selectedHands: ["AA", "KK", "QQ"], createdAt: nil, updatedAt: Date())
        persistence.upsertRangeChart(from: dto2)

        let all = persistence.fetchAllRangeCharts(userId: userId)
        #expect(all.count == 1)
        #expect(all.first?.toModel()?.selectedHands.count == 3)
    }

    @Test func fetchAll_returns6Positions_afterUpsertingAll() {
        let persistence = PersistenceController(inMemory: true)
        let userId = UUID()

        for pos in RangePosition.allCases {
            let dto = RangeChartDTO(id: UUID(), userId: userId, position: pos.rawValue,
                                    selectedHands: [], createdAt: nil, updatedAt: Date())
            persistence.upsertRangeChart(from: dto)
        }

        let all = persistence.fetchAllRangeCharts(userId: userId)
        #expect(all.count == 6)
    }

    @Test func deleteRangeChart() {
        let persistence = PersistenceController(inMemory: true)
        let userId = UUID()
        let dto = RangeChartDTO(id: UUID(), userId: userId, position: "CO",
                                selectedHands: ["AA"], createdAt: nil, updatedAt: Date())
        persistence.upsertRangeChart(from: dto)
        #expect(persistence.fetchRangeChart(userId: userId, position: "CO") != nil)

        persistence.deleteRangeChart(userId: userId, position: "CO")
        #expect(persistence.fetchRangeChart(userId: userId, position: "CO") == nil)
    }
}

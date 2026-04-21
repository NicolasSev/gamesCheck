import XCTest
@testable import FishAndChips

final class EquityScenarioGeneratorTests: XCTestCase {
    func testFixedSpotsUniqueCards() throws {
        let adapter = EquityGuesserEngineAdapter()
        let cfg = EquitySessionConfig(difficulty: .medium, sessionLength: 6, showVillainImmediately: true)
        let scenarios = try awaitEquity { try await EquityScenarioGenerator.generateSession(config: cfg, adapter: adapter) }
        XCTAssertEqual(scenarios.count, 6)
        for s in scenarios {
            XCTAssertGreaterThanOrEqual(s.actualEquity, 0)
            XCTAssertLessThanOrEqual(s.actualEquity, 100)
        }
    }

    private func awaitEquity<T>(_ op: @escaping () async throws -> T) throws -> T {
        let exp = expectation(description: "async")
        var result: Result<T, Error>!
        Task {
            do {
                let v = try await op()
                result = .success(v)
            } catch {
                result = .failure(error)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 120)
        return try result.get()
    }
}

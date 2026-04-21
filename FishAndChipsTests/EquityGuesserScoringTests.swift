import XCTest
@testable import FishAndChips

final class EquityGuesserScoringTests: XCTestCase {
    func testDeltaBoundaries() {
        XCTAssertEqual(EquityGuesserScoring.scoreFromDelta(0).label, .perfect)
        XCTAssertEqual(EquityGuesserScoring.scoreFromDelta(2).label, .perfect)
        XCTAssertEqual(EquityGuesserScoring.scoreFromDelta(2.1).label, .close)
        XCTAssertEqual(EquityGuesserScoring.scoreFromDelta(20).label, .off)
        XCTAssertEqual(EquityGuesserScoring.scoreFromDelta(20.1).label, .miss)
    }

    func testStreakMultiplier() {
        XCTAssertEqual(EquityGuesserScoring.streakMultiplier(streak: 2), 1.0, accuracy: 0.001)
        XCTAssertEqual(EquityGuesserScoring.streakMultiplier(streak: 3), 1.2, accuracy: 0.001)
        XCTAssertEqual(EquityGuesserScoring.streakMultiplier(streak: 5), 1.4, accuracy: 0.001)
    }
}

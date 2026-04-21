import Foundation

enum EquityGuesserScoring {
    static func scoreFromDelta(_ delta: Double) -> (label: EquityAccuracyLabel, points: Int) {
        let d = abs(delta)
        if d <= 2 { return (.perfect, 100) }
        if d <= 5 { return (.close, 85) }
        if d <= 10 { return (.good, 60) }
        if d <= 20 { return (.off, 30) }
        return (.miss, 0)
    }

    static func streakMultiplier(streak: Int) -> Double {
        if streak >= 5 { return 1.4 }
        if streak >= 3 { return 1.2 }
        return 1.0
    }

    static func nextCloseOrBetterStreak(prev: Int, label: EquityAccuracyLabel) -> Int {
        switch label {
        case .perfect, .close: return prev + 1
        case .off, .miss: return 0
        case .good: return prev
        }
    }

    static func roundScore(basePoints: Int, label: EquityAccuracyLabel, streakAfter: Int) -> Int {
        guard label == .perfect || label == .close else { return basePoints }
        return Int(round(Double(basePoints) * streakMultiplier(streak: streakAfter)))
    }
}

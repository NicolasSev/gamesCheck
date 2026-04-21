import Foundation
import SwiftUI

@MainActor
final class EquityGuesserViewModel: ObservableObject {
    enum Phase {
        case loading, guessing, revealed, summary
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var scenarios: [EquityScenario] = []
    @Published private(set) var roundIndex: Int = 0
    @Published var currentGuess: Double = 50
    @Published private(set) var streak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    @Published private(set) var totalScore: Int = 0
    @Published private(set) var rounds: [EquityGuessRound] = []
    @Published private(set) var lastReveal: (delta: Double, label: EquityAccuracyLabel, points: Int)?

    private var config: EquitySessionConfig = .default
    private var roundStarted: Date = Date()
    private let engine = EquityGuesserEngineAdapter()

    var currentScenario: EquityScenario? {
        guard roundIndex < scenarios.count else { return nil }
        return scenarios[roundIndex]
    }

    func startSession(_ cfg: EquitySessionConfig) async {
        config = cfg
        phase = .loading
        roundIndex = 0
        streak = 0
        bestStreak = 0
        totalScore = 0
        rounds = []
        lastReveal = nil
        currentGuess = 50
        do {
            scenarios = try await EquityScenarioGenerator.generateSession(config: cfg, adapter: engine)
            roundStarted = Date()
            phase = .guessing
        } catch {
            debugLog("EquityGuesser generate failed: \(error)")
            phase = .summary
        }
    }

    func submitGuess() {
        guard phase == .guessing, let sc = currentScenario else { return }
        let actual = sc.actualEquity
        let raw = currentGuess - actual
        let delta = abs(raw)
        let (label, basePts) = EquityGuesserScoring.scoreFromDelta(raw)
        let nextS = EquityGuesserScoring.nextCloseOrBetterStreak(prev: streak, label: label)
        let pts = EquityGuesserScoring.roundScore(basePoints: basePts, label: label, streakAfter: nextS)
        streak = nextS
        bestStreak = max(bestStreak, nextS)
        totalScore += pts
        let round = EquityGuessRound(
            scenarioId: sc.id,
            userGuess: currentGuess,
            actualEquity: actual,
            delta: delta,
            score: pts,
            accuracy: label,
            timeSpentMs: Int(Date().timeIntervalSince(roundStarted) * 1000),
            scenario: sc
        )
        rounds.append(round)
        lastReveal = (delta: delta, label: label, points: pts)
        phase = .revealed
    }

    func nextRound() {
        guard phase == .revealed else { return }
        lastReveal = nil
        if roundIndex + 1 >= scenarios.count {
            phase = .summary
            return
        }
        roundIndex += 1
        currentGuess = 50
        roundStarted = Date()
        phase = .guessing
    }
}

import Foundation

enum EquityStreet: String, Codable, CaseIterable {
    case preflop, flop, turn, river
}

enum EquityHandCategory: String, Codable, CaseIterable {
    case coinflip, domination, set_vs_draw, wet_board, paired_board, monotone
}

enum EquityDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

enum EquityAccuracyLabel: String, Codable {
    case perfect, close, good, off, miss
}

struct EquitySessionConfig: Codable, Equatable {
    var difficulty: EquityDifficulty
    var sessionLength: Int
    /// Показывать руку Villain до ответа
    var showVillainImmediately: Bool

    static let `default` = EquitySessionConfig(
        difficulty: .medium,
        sessionLength: 10,
        showVillainImmediately: true
    )
}

struct EquityScenario: Codable, Equatable, Identifiable {
    let id: UUID
    let heroHand: [String]
    let villainHand: [String]
    let board: [String]
    let street: EquityStreet
    let category: EquityHandCategory
    let difficulty: EquityDifficulty
    let actualEquity: Double
    let iterationsUsed: Int
}

struct EquityGuessRound: Codable, Equatable {
    let scenarioId: UUID
    let userGuess: Double
    let actualEquity: Double
    let delta: Double
    let score: Int
    let accuracy: EquityAccuracyLabel
    let timeSpentMs: Int
    let scenario: EquityScenario
}

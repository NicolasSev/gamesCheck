import Foundation

/// Генерация сценариев (те же базовые споты, что и в вебе) + расчёт эквити.
enum EquityScenarioGenerator {

    private static let categories: [EquityHandCategory] = [
        .coinflip, .domination, .set_vs_draw, .wet_board, .paired_board, .monotone
    ]

    static func generateSession(
        config: EquitySessionConfig,
        adapter: EquityGuesserEngineAdapter
    ) async throws -> [EquityScenario] {
        try await Task.detached(priority: .userInitiated) {
            var out: [EquityScenario] = []
            for i in 0..<config.sessionLength {
                let cat = categories[i % categories.count]
                let s = try generateOne(category: cat, difficulty: config.difficulty, adapter: adapter)
                out.append(s)
            }
            return out
        }.value
    }

    private static func generateOne(
        category: EquityHandCategory,
        difficulty: EquityDifficulty,
        adapter: EquityGuesserEngineAdapter
    ) throws -> EquityScenario {
        let raw: (hero: [String], villain: [String], board: [String], street: EquityStreet) = try {
            switch category {
            case .coinflip:
                return (["Th", "Td"], ["Ah", "Kc"], [], .preflop)
            case .domination:
                return (["Ah", "Kd"], ["As", "Qc"], [], .preflop)
            case .set_vs_draw:
                return (["7h", "7d"], ["9s", "Ts"], ["7s", "8s", "2c"], .flop)
            case .wet_board:
                return (["Jh", "Td"], ["Ah", "Kd"], ["9h", "8h", "2c"], .flop)
            case .paired_board:
                return (["Ad", "Kc"], ["Qd", "Jc"], ["8s", "8h", "3d"], .flop)
            case .monotone:
                return (["Jd", "Jc"], ["9d", "Tc"], ["Ah", "Kh", "Qh"], .flop)
            }
        }()

        let hero = try raw.hero.map { try Card(notation: $0) }
        let villain = try raw.villain.map { try Card(notation: $0) }
        let board = try raw.board.map { try Card(notation: $0) }

        let equity = try adapter.computeHeroEquity(hero: hero, villain: villain, board: board)
        return EquityScenario(
            id: UUID(),
            heroHand: raw.hero,
            villainHand: raw.villain,
            board: raw.board,
            street: raw.street,
            category: category,
            difficulty: difficulty,
            actualEquity: equity,
            iterationsUsed: 20_000
        )
    }
}

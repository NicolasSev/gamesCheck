import Foundation

/// Обёртка над `PokerOddsCalculator` для тренажёра (20k итераций).
final class EquityGuesserEngineAdapter {
    private let calculator: PokerOddsCalculator

    init() {
        self.calculator = PokerOddsCalculator(gameVariant: .texasHoldem, iterations: 20_000)
    }

    /// Эквити Hero (0…100). Тяжёлый расчёт — вызывать вне main thread.
    func computeHeroEquity(hero: [Card], villain: [Card], board: [Card]) throws -> Double {
        let result = try calculator.calculate(playerHands: [hero, villain], board: board)
        return result.equities[0].equity
    }
}

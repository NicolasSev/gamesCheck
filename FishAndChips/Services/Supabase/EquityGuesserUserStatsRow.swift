import Foundation

/// Строка из представления `equity_guesser_user_stats` (PostgREST).
struct EquityGuesserUserStatsRow: Codable, Sendable {
    let total_sessions: Int64?
    let total_rounds: Int64?
    let overall_mae: Double?
    let best_streak: Int?
}

import Foundation

struct UserStatistics {
    let totalGamesCreated: Int
    let totalGamesParticipated: Int
    let totalBuyins: Decimal
    let totalCashouts: Decimal
    let currentBalance: Decimal
    let winRate: Double
    let profitByGameType: [String: Decimal]
    let recentGames: [GameSummary]
    let bestSession: Decimal
    let worstSession: Decimal
    let averageProfit: Decimal
    let totalSessions: Int

    var isPositive: Bool {
        currentBalance > 0
    }
}

struct GameSummary {
    let gameId: UUID
    let gameType: String
    let timestamp: Date
    let totalPlayers: Int
    let myBuyin: Decimal
    let myCashout: Decimal
    let profit: Decimal
    let isCreator: Bool

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedProfit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: profit)) ?? "$0"
    }
}

struct GameTypeStatistics {
    let gameType: String
    let gamesCount: Int
    let totalProfit: Decimal
    let winRate: Double
    let averageProfit: Decimal
    let bestSession: Decimal
}

enum GameFilter: Hashable {
    case all
    case created
    case participated
    case byType(String)
    case dateRange(from: Date, to: Date)
    case profitable
    case losing
}


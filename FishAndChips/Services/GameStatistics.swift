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
    let mvpCount: Int

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
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: profit)) ?? "₸0"
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
    case allGames // Все игры на устройстве независимо от пользователя
    case created
    case participated
    case byType(String)
    case dateRange(from: Date, to: Date)
    case profitable
    case losing
}

// Структура для топовых метрик
struct TopRecord {
    let value: Decimal
    let playerName: String
    let gameDate: Date
    let gameId: UUID?
    let buyinInTenge: Decimal? // Для вычисления эффективности
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: gameDate)
    }
    
    var efficiency: Decimal? {
        guard let buyin = buyinInTenge, buyin > 0 else { return nil }
        return value / buyin
    }
}

struct StreakRecord {
    let length: Int
    let startDate: Date
    let endDate: Date
    let playerName: String?
    
    var formattedPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }
}

struct TopAnalytics {
    let biggestWin: TopRecord?
    let biggestLoss: TopRecord?
    let maxBuyins: TopRecord?
    let mostExpensiveGame: TopRecord? // Самая дорогая игра (максимальная сумма байинов всех участников)
    let longestWinStreak: StreakRecord?
    let longestLoseStreak: StreakRecord?
    let averageWin: Decimal
    let averageLoss: Decimal
    let totalWinningGames: Int
    let totalLosingGames: Int
    let mostEfficientPlayer: TopRecord? // Самый эффективный (лучшее соотношение выигрыша к байинам)
    let leastEfficientPlayer: TopRecord? // Самый неэффективный (худшее соотношение)
}

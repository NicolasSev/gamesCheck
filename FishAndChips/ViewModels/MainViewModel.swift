import Foundation
import Combine

@MainActor
final class MainViewModel: ObservableObject {
    @Published var statistics: UserStatistics?
    @Published var gameTypeStats: [GameTypeStatistics] = []
    @Published var recentGames: [GameSummary] = []
    @Published var selectedFilter: GameFilter = .all
    @Published var filteredGames: [Game] = []
    @Published var isLoading = false
    @Published var topAnalytics: TopAnalytics?
    @Published var chartData: [(date: Date, buyin: Decimal, gameId: UUID)] = []

    private let gameService: GameService

    private(set) var userId: UUID?
    private(set) var selectedPlayerName: String?

    init(gameService: GameService = GameService()) {
        self.gameService = gameService
    }

    func loadData(forUser userId: UUID) {
        self.userId = userId
        self.selectedPlayerName = nil
        isLoading = true

        Task {
            let stats = gameService.getUserStatistics(userId)
            let typeStats = gameService.getGameTypeStatistics(userId)
            let games = gameService.getGames(filter: selectedFilter, forUser: userId)
            let topAnalytics = gameService.getTopAnalytics()

            self.statistics = stats
            self.gameTypeStats = typeStats
            self.recentGames = stats.recentGames
            self.filteredGames = games
            self.topAnalytics = topAnalytics
            self.chartData = gameService.getChartData(forUser: userId)
            self.isLoading = false
        }
    }
    
    func loadData(forPlayerName playerName: String) {
        self.userId = nil
        self.selectedPlayerName = playerName
        isLoading = true

        Task {
            let stats = gameService.getUserStatistics(byPlayerName: playerName)
            // Для игроков по имени тип статистики не поддерживается (нужен userId)
            let typeStats: [GameTypeStatistics] = []
            // Получаем все игры, где участвовал этот игрок
            let allGames = gameService.getAllGames()
            let games = allGames.filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
            }
            let topAnalytics = gameService.getTopAnalytics()

            self.statistics = stats
            self.gameTypeStats = typeStats
            self.recentGames = stats.recentGames
            self.filteredGames = games.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
            self.topAnalytics = topAnalytics
            self.chartData = gameService.getChartData(byPlayerName: playerName)
            self.isLoading = false
        }
    }

    func applyFilter(_ filter: GameFilter) {
        selectedFilter = filter
        // Если выбран игрок по имени, фильтруем игры по имени
        if let playerName = selectedPlayerName {
            let allGames = gameService.getAllGames()
            filteredGames = allGames.filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
            }.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
        } else if let userId = userId {
            filteredGames = gameService.getGames(filter: filter, forUser: userId)
        }
    }

    func refresh() {
        if let playerName = selectedPlayerName {
            loadData(forPlayerName: playerName)
        } else if let userId = userId {
            loadData(forUser: userId)
        }
    }
}


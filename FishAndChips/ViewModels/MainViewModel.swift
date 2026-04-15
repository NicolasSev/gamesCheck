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
    @Published var hasMoreGames = false

    private let gameService: GameService
    /// Локальная БД: грузим полный список, чтобы старые годы и календарь не «терялись» за prefix(pageSize).
    private let pageSize = 50
    private var currentPage = 0
    private var allGamesForPagination: [Game] = []

    private(set) var userId: UUID?
    private(set) var selectedPlayerName: String?

    init(gameService: GameService = GameService()) {
        self.gameService = gameService
    }

    func loadData(forUser userId: UUID) {
        self.userId = userId
        self.selectedPlayerName = nil
        isLoading = true
        currentPage = 0
        hasMoreGames = false

        Task {
            let stats = gameService.getUserStatistics(userId)
            let typeStats = gameService.getGameTypeStatistics(userId)
            let allGames = gameService.getGames(filter: selectedFilter, forUser: userId)
            allGamesForPagination = allGames
            let topAnalytics = gameService.getTopAnalytics()

            self.statistics = stats
            self.gameTypeStats = typeStats
            self.recentGames = stats.recentGames
            self.filteredGames = allGames
            self.hasMoreGames = false
            self.topAnalytics = topAnalytics
            self.chartData = gameService.getChartData(forUser: userId)
            self.isLoading = false
        }
    }
    
    func loadData(forPlayerName playerName: String) {
        self.userId = nil
        self.selectedPlayerName = playerName
        isLoading = true
        currentPage = 0
        hasMoreGames = false

        Task {
            let stats = gameService.getUserStatistics(byPlayerName: playerName)
            let typeStats: [GameTypeStatistics] = []
            let allGames = gameService.getAllGames()
            let games = allGames.filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
            }
            let sortedGames = games.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
            allGamesForPagination = sortedGames
            let topAnalytics = gameService.getTopAnalytics()

            self.statistics = stats
            self.gameTypeStats = typeStats
            self.recentGames = stats.recentGames
            self.filteredGames = sortedGames
            self.hasMoreGames = false
            self.topAnalytics = topAnalytics
            self.chartData = gameService.getChartData(byPlayerName: playerName)
            self.isLoading = false
        }
    }

    func applyFilter(_ filter: GameFilter) {
        selectedFilter = filter
        currentPage = 0
        if let playerName = selectedPlayerName {
            let allGames = gameService.getAllGames()
            let sorted = allGames.filter { game in
                let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
                return participations.contains { gwp in
                    guard let player = gwp.player, let name = player.name else { return false }
                    return name.lowercased() == playerName.lowercased()
                }
            }.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
            allGamesForPagination = sorted
            filteredGames = sorted
            hasMoreGames = false
        } else if let userId = userId {
            let all = gameService.getGames(filter: filter, forUser: userId)
            allGamesForPagination = all
            filteredGames = all
            hasMoreGames = false
        }
    }

    func refresh() {
        if let playerName = selectedPlayerName {
            loadData(forPlayerName: playerName)
        } else if let userId = userId {
            loadData(forUser: userId)
        }
    }

    /// Phase 2: Загрузить следующую страницу игр
    func loadMoreGames() {
        guard hasMoreGames, !isLoading else { return }
        let nextPage = currentPage + 1
        let start = nextPage * pageSize
        let end = min(start + pageSize, allGamesForPagination.count)
        guard start < allGamesForPagination.count else {
            hasMoreGames = false
            return
        }
        filteredGames.append(contentsOf: allGamesForPagination[start..<end])
        currentPage = nextPage
        hasMoreGames = end < allGamesForPagination.count
    }
}


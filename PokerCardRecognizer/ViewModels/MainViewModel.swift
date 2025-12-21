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

    private let gameService: GameService

    private(set) var userId: UUID?

    init(gameService: GameService = GameService()) {
        self.gameService = gameService
    }

    func loadData(forUser userId: UUID) {
        self.userId = userId
        isLoading = true

        Task {
            let stats = gameService.getUserStatistics(userId)
            let typeStats = gameService.getGameTypeStatistics(userId)
            let games = gameService.getGames(filter: selectedFilter, forUser: userId)

            self.statistics = stats
            self.gameTypeStats = typeStats
            self.recentGames = stats.recentGames
            self.filteredGames = games
            self.isLoading = false
        }
    }

    func applyFilter(_ filter: GameFilter) {
        guard let userId else { return }
        selectedFilter = filter
        filteredGames = gameService.getGames(filter: filter, forUser: userId)
    }

    func refresh() {
        guard let userId else { return }
        loadData(forUser: userId)
    }
}


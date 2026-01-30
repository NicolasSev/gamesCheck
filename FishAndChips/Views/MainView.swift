import SwiftUI
import UIKit

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkService: DeepLinkService
    @StateObject private var viewModel = MainViewModel()

    @State private var selectedTab: MainTab = .overview
    @State private var showingProfile = false
    @State private var showingAddGame = false
    @State private var showingImportGames = false
    @State private var deepLinkGame: Game?

    enum MainTab: Hashable {
        case overview
        case games
        case statistics
    }

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                OverviewTabView(
                    statistics: viewModel.statistics,
                    games: viewModel.filteredGames,
                    authViewModel: authViewModel,
                    onRefresh: {
                        viewModel.refresh()
                    },
                    onPlayerSelected: { selectedUserId, selectedPlayerName in
                        if let userId = selectedUserId {
                            viewModel.loadData(forUser: userId)
                        } else if let playerName = selectedPlayerName {
                            viewModel.loadData(forPlayerName: playerName)
                        } else if let currentUserId = authViewModel.currentUserId {
                            viewModel.loadData(forUser: currentUserId)
                        }
                    }
                )
                    .tabItem { Label("Обзор", systemImage: "chart.bar.fill") }
                    .tag(MainTab.overview)

                GamesListTabView(
                    games: viewModel.filteredGames,
                    userId: authViewModel.currentUserId,
                    selectedFilter: $viewModel.selectedFilter,
                    onFilterChange: viewModel.applyFilter
                )
                .tabItem { Label("Игры", systemImage: "list.bullet") }
                .tag(MainTab.games)

                StatisticsTabView(
                    statistics: viewModel.statistics,
                    gameTypeStats: viewModel.gameTypeStats,
                    topAnalytics: viewModel.topAnalytics,
                    chartData: viewModel.chartData
                )
                .tabItem { Label("Статистика", systemImage: "chart.pie.fill") }
                .tag(MainTab.statistics)
            }
            .navigationTitle(titleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddGame = true
                        } label: {
                            Label("Создать игру", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showingImportGames = true
                        } label: {
                            Label("Импортировать игры", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingAddGame) {
                AddGameSheet(isPresented: $showingAddGame)
                    .environmentObject(authViewModel)
                    .onDisappear { viewModel.refresh() }
            }
            .sheet(isPresented: $showingImportGames) {
                ImportDataSheet(isPresented: $showingImportGames)
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .environmentObject(authViewModel)
                    .onDisappear { viewModel.refresh() }
            }
            .sheet(item: $deepLinkGame) { game in
                NavigationView {
                    if let type = game.gameType, type == "Бильярд" {
                        BilliardGameDetailView(game: game)
                    } else {
                        GameDetailView(game: game)
                    }
                }
            }
            .onChange(of: deepLinkService.activeDeepLink) { newDeepLink in
                handleDeepLink(newDeepLink)
            }
            .onAppear {
                // Настройка цвета текста и иконки активного таба
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
                tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .white
                UITabBar.appearance().standardAppearance = tabBarAppearance
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                
                // Настройка NavigationBar - полностью отключаем масштабирование
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithTransparentBackground()
                navBarAppearance.backgroundColor = .clear
                navBarAppearance.shadowColor = .clear
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                
                UINavigationBar.appearance().standardAppearance = navBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
                UINavigationBar.appearance().compactAppearance = navBarAppearance
                UINavigationBar.appearance().compactScrollEdgeAppearance = navBarAppearance
                
                // Загружаем данные только если не выбран игрок по имени
                if let userId = authViewModel.currentUserId, viewModel.selectedPlayerName == nil {
                    viewModel.loadData(forUser: userId)
                }
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }

    private func titleForTab(_ tab: MainTab) -> String {
        switch tab {
        case .overview: return "Обзор"
        case .games: return "Игры"
        case .statistics: return "Статистика"
        }
    }
    
    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .game(let gameId):
            print("🔗 MainView: Opening game \(gameId)")
            
            // Fetch game from CoreData
            if let game = PersistenceController.shared.fetchGame(byId: gameId) {
                print("✅ MainView: Found game, showing detail view")
                deepLinkGame = game
                deepLinkService.clearDeepLink()
            } else {
                print("❌ MainView: Game not found with id \(gameId)")
                // TODO: Show alert that game was not found
            }
            
        case .none:
            break
        }
    }
}

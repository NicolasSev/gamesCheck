import SwiftUI
import UIKit

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkService: DeepLinkService
    @EnvironmentObject var syncService: CloudKitSyncService
    @StateObject private var viewModel = MainViewModel()

    @State private var selectedTab: MainTab = .overview
    @State private var showingProfile = false
    @State private var showingAddGame = false
    @State private var showingImportGames = false
    @State private var deepLinkGame: Game?
    @State private var pendingClaimsCount = 0
    
    private let claimService = PlayerClaimService()

    enum MainTab: Hashable {
        case overview
        case games
        case statistics
        case players
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
                    onFilterChange: viewModel.applyFilter,
                    onLoadMore: viewModel.loadMoreGames
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

                PlayersTabView()
                    .environmentObject(authViewModel)
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .tabItem { Label("Игроки", systemImage: "person.2.fill") }
                    .tag(MainTab.players)
            }
            .navigationTitle(titleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .zIndex(0)
                            
                            if pendingClaimsCount > 0 {
                                Text("\(pendingClaimsCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(
                                        Circle()
                                            .fill(Color.red)
                                    )
                                    .offset(x: 2, y: -2)
                                    .zIndex(1)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if syncService.isBackgroundSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
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
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
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
            .alert("Ошибка", isPresented: Binding(
                get: { deepLinkService.loadError != nil },
                set: { if !$0 { deepLinkService.clearDeepLink() } }
            )) {
                Button("Повторить") {
                    deepLinkService.retryLoadGame()
                }
                Button("Отмена", role: .cancel) {
                    deepLinkService.clearDeepLink()
                }
            } message: {
                Text(deepLinkService.loadError ?? "")
            }
            .overlay {
                if deepLinkService.isLoadingGame {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Загрузка игры...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Получение данных из CloudKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 10)
                    )
                }
            }
            .onChange(of: deepLinkService.activeDeepLink) { newDeepLink in
                handleDeepLink(newDeepLink)
            }
            .onChange(of: syncService.isBackgroundSyncing) { _, isSyncing in
                // При завершении фоновой синхронизации обновить данные
                if !isSyncing {
                    viewModel.refresh()
                }
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
                
                // Обновляем счетчик заявок
                updatePendingClaimsCount()
            }
            .onChange(of: showingProfile) { isShowing in
                // Обновляем счетчик заявок при закрытии профиля
                if !isShowing {
                    updatePendingClaimsCount()
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
        case .players: return "Игроки"
        }
    }
    
    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .game(let gameId):
            print("🔗 MainView: Opening game \(gameId)")
            
            // Fetch game from CoreData (уже должна быть загружена DeepLinkService)
            if let game = PersistenceController.shared.fetchGame(byId: gameId) {
                print("✅ MainView: Found game, showing detail view")
                deepLinkGame = game
                deepLinkService.clearDeepLink()
            } else {
                print("⚠️ MainView: Game not found locally, DeepLinkService should be loading it...")
                // DeepLinkService уже обрабатывает загрузку из CloudKit
            }
            
        case .none:
            break
        }
    }
    
    private func updatePendingClaimsCount() {
        guard let userId = authViewModel.currentUserId else {
            pendingClaimsCount = 0
            return
        }
        pendingClaimsCount = claimService.getPendingClaimsForHost(hostUserId: userId).count
    }
}

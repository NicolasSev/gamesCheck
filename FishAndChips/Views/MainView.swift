import SwiftUI
import UIKit

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkService: DeepLinkService
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    @StateObject private var viewModel = MainViewModel()

    @State private var selectedTab: MainTab = .overview
    @State private var showingAddGame = false
    @State private var showingImportGames = false
    @State private var deepLinkGame: Game?
    @State private var pendingClaimsCount = 0
    
    private let claimService = PlayerClaimService()
    @ObservedObject private var claimDiscovery = ClaimDiscoveryService.shared

    enum MainTab: Hashable {
        case overview
        case games
        case claimSelf
        case statistics
        case players
        case ranges
        case profile
    }

    private var freeClaimBadgeCount: Int {
        claimDiscovery.rows.filter { $0.status == "free" }.count
    }

    var body: some View {
        NavigationStack {
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
                    .accessibilityIdentifier("tab_overview")

                GamesViewV2(
                    games: viewModel.filteredGames,
                    userId: authViewModel.currentUserId,
                    selectedFilter: $viewModel.selectedFilter,
                    onFilterChange: viewModel.applyFilter,
                    onLoadMore: viewModel.loadMoreGames
                )
                    .tabItem { Label("Игры", systemImage: "list.bullet") }
                    .tag(MainTab.games)
                    .accessibilityIdentifier("tab_games")

                Group {
                    if let uid = authViewModel.currentUserId {
                        ClaimSelfView(userId: uid)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.rectangle.stack")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Войдите в аккаунт")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Чтобы искать себя среди записей игроков в чужих играх")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .v2ScreenBackground()
                    }
                }
                    .tabItem { Label("Найти себя", systemImage: "person.crop.rectangle.stack") }
                    .tag(MainTab.claimSelf)
                    .accessibilityIdentifier("tab_claim_self")
                    .modifier(BadgeOnlyIfPositive(count: freeClaimBadgeCount))

                StatisticsTabView(
                    statistics: viewModel.statistics,
                    gameTypeStats: viewModel.gameTypeStats,
                    placeStats: viewModel.placeStats,
                    topAnalytics: viewModel.topAnalytics,
                    chartData: viewModel.chartData
                )
                .environmentObject(authViewModel)
                .tabItem { Label("Статистика", systemImage: "chart.pie.fill") }
                .tag(MainTab.statistics)
                .accessibilityIdentifier("tab_statistics")

                PlayersTabView()
                    .environmentObject(authViewModel)
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .tabItem { Label("Игроки", systemImage: "person.2.fill") }
                    .tag(MainTab.players)
                    .accessibilityIdentifier("tab_players")

                RangesTabView()
                    .environmentObject(authViewModel)
                    .tabItem { Label("Диапазоны", systemImage: "square.grid.3x3.fill") }
                    .tag(MainTab.ranges)
                    .accessibilityIdentifier("tab_ranges")

                ProfileView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .environmentObject(authViewModel)
                    .environmentObject(NotificationService.shared)
                    .tabItem { Label("Профиль", systemImage: "person.fill") }
                    .tag(MainTab.profile)
                    .accessibilityIdentifier("tab_profile")
            }
            .accessibilityIdentifier("screen.main")
            .navigationTitle(titleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedTab = .profile
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
                    .accessibilityIdentifier("main_profile_button")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if syncCoordinator.isBackgroundSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        if selectedTab == .games {
                        Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingAddGame = true
                        } label: {
                            Label("Создать игру", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("main_add_game_button")
                        
                        Button {
                            showingImportGames = true
                        } label: {
                            Label("Импортировать игры", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("main_import_button")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityIdentifier("main_toolbar_menu_button")
                        }
                    }
                }
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
                NavigationStack {
                    GameDetailView(game: game)
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
                        Text("Получение данных с сервера")
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
            .onChange(of: syncCoordinator.isBackgroundSyncing) { _, isSyncing in
                // При завершении фоновой синхронизации обновить данные
                if !isSyncing {
                    viewModel.refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fullResyncCompleted)) { _ in
                viewModel.refresh()
                if let uid = authViewModel.currentUserId {
                    Task { await claimDiscovery.refresh(userId: uid) }
                }
            }
            .onAppear {
                // Активный таб — акцент как в web v13 (`--accent-green`).
                let tabBarAppearance = UITabBarAppearance()
                let accent = UIColor(Color.casinoAccentGreen)
                tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
                tabBarAppearance.stackedLayoutAppearance.selected.iconColor = accent
                tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.65)]
                tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.65)
                tabBarAppearance.backgroundColor = UIColor(red: 7/255, green: 7/255, blue: 18/255, alpha: 0.88)
                UITabBar.appearance().isTranslucent = true
                UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.5)
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

                Task {
                    if let id = authViewModel.currentUserId {
                        await claimDiscovery.refresh(userId: id)
                    }
                }

                Task {
                    await PlayerMergeListenerService.shared.startListening()
                }
            }
            .onDisappear {
                Task {
                    await PlayerMergeListenerService.shared.stopListening()
                }
            }
            .onChange(of: selectedTab) { _, new in
                if new == .profile {
                    updatePendingClaimsCount()
                }
                if new == .claimSelf, let uid = authViewModel.currentUserId {
                    Task { await claimDiscovery.refresh(userId: uid) }
                }
            }
            .refreshable {
                viewModel.refresh()
            }
        }
        .v2ScreenBackground(.rich)
    }

    private func titleForTab(_ tab: MainTab) -> String {
        switch tab {
        case .overview: return "Обзор"
        case .games: return "Игры"
        case .claimSelf: return "Найти себя"
        case .statistics: return "Статистика"
        case .players: return "Игроки"
        case .ranges: return "Диапазоны"
        case .profile: return "Профиль"
        }
    }
    
    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .game(let gameId):
            debugLog("🔗 MainView: Opening game \(gameId)")
            
            // Fetch game from CoreData (уже должна быть загружена DeepLinkService)
            if let game = PersistenceController.shared.fetchGame(byId: gameId) {
                debugLog("✅ MainView: Found game, showing detail view")
                deepLinkGame = game
                deepLinkService.clearDeepLink()
            } else {
                debugLog("⚠️ MainView: Game not found locally, DeepLinkService should be loading it...")
                // DeepLinkService подгружает игру через Supabase при необходимости
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

private struct BadgeOnlyIfPositive: ViewModifier {
    let count: Int

    func body(content: Content) -> some View {
        if count > 0 {
            content.badge(count)
        } else {
            content
        }
    }
}

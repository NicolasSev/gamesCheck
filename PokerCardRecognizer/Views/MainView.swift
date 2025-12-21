import SwiftUI

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MainViewModel()

    @State private var selectedTab: MainTab = .overview
    @State private var showingProfile = false
    @State private var showingAddGame = false

    enum MainTab: Hashable {
        case overview
        case games
        case statistics
    }

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                OverviewTabView(statistics: viewModel.statistics)
                    .tabItem { Label("Обзор", systemImage: "chart.bar.fill") }
                    .tag(MainTab.overview)

                GamesListTabView(
                    games: viewModel.filteredGames,
                    selectedFilter: $viewModel.selectedFilter,
                    onFilterChange: viewModel.applyFilter
                )
                .tabItem { Label("Игры", systemImage: "list.bullet") }
                .tag(MainTab.games)

                StatisticsTabView(
                    statistics: viewModel.statistics,
                    gameTypeStats: viewModel.gameTypeStats
                )
                .tabItem { Label("Статистика", systemImage: "chart.pie.fill") }
                .tag(MainTab.statistics)
            }
            .navigationTitle(titleForTab(selectedTab))
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
                    Button {
                        showingAddGame = true
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
            .onAppear {
                if let userId = authViewModel.currentUserId {
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
}

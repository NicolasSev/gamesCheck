# Task 1.7: Реализация фильтрации в MainView

**Приоритет:** 🟠 Высокий  
**Срок:** 2-3 дня  
**Статус:** 🟩 DONE  
**Исполнитель:** Cursor Agent  
**Начато:** 2025-12-21  
**Завершено:** 2025-12-21  
**Результат:** см. git log: `feat: обновлен MainView с фильтрами (Task 1.7)`  

---

## Описание

Обновить MainView для отображения персонализированной статистики пользователя с фильтрацией игр.

---

## Предусловия

- ✅ Task 1.6 завершена (GameService создан)
- ✅ Task 1.5 завершена (AuthViewModel обновлен)
- Существующий MainView

---

## Задачи

### 1. Создать ViewModel для MainView

Создайте `MainViewModel.swift`:

```swift
import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var statistics: UserStatistics?
    @Published var gameTypeStats: [GameTypeStatistics] = []
    @Published var recentGames: [GameSummary] = []
    @Published var selectedFilter: GameFilter = .all
    @Published var filteredGames: [Game] = []
    @Published var isLoading = false
    
    private let gameService: GameService
    private var cancellables = Set<AnyCancellable>()
    
    var userId: UUID?
    
    init(gameService: GameService = GameService()) {
        self.gameService = gameService
    }
    
    func loadData(forUser userId: UUID) {
        self.userId = userId
        isLoading = true
        
        Task {
            // Загрузить статистику
            let stats = gameService.getUserStatistics(userId)
            let typeStats = gameService.getGameTypeStatistics(userId)
            let games = gameService.getGames(filter: selectedFilter, forUser: userId)
            
            await MainActor.run {
                self.statistics = stats
                self.gameTypeStats = typeStats
                self.recentGames = stats.recentGames
                self.filteredGames = games
                self.isLoading = false
            }
        }
    }
    
    func applyFilter(_ filter: GameFilter) {
        guard let userId = userId else { return }
        
        selectedFilter = filter
        filteredGames = gameService.getGames(filter: filter, forUser: userId)
    }
    
    func refresh() {
        guard let userId = userId else { return }
        loadData(forUser: userId)
    }
}
```

### 2. Обновить MainView

Обновите существующий `MainView.swift`:

```swift
import SwiftUI
import Charts

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MainViewModel()
    
    @State private var selectedTab: MainTab = .overview
    @State private var showingProfile = false
    @State private var showingAddGame = false
    
    enum MainTab {
        case overview
        case games
        case statistics
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Overview Tab
                OverviewTabView(statistics: viewModel.statistics)
                    .tabItem {
                        Label("Обзор", systemImage: "chart.bar.fill")
                    }
                    .tag(MainTab.overview)
                
                // Games Tab
                GamesListTabView(
                    games: viewModel.filteredGames,
                    selectedFilter: $viewModel.selectedFilter,
                    onFilterChange: viewModel.applyFilter
                )
                .tabItem {
                    Label("Игры", systemImage: "list.bullet")
                }
                .tag(MainTab.games)
                
                // Statistics Tab
                StatisticsTabView(
                    statistics: viewModel.statistics,
                    gameTypeStats: viewModel.gameTypeStats
                )
                .tabItem {
                    Label("Статистика", systemImage: "chart.pie.fill")
                }
                .tag(MainTab.statistics)
            }
            .navigationTitle(selectedTab.title)
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
                AddGameSheet()
                    .environmentObject(authViewModel)
                    .onDisappear {
                        viewModel.refresh()
                    }
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
}

extension MainView.MainTab {
    var title: String {
        switch self {
        case .overview: return "Обзор"
        case .games: return "Игры"
        case .statistics: return "Статистика"
        }
    }
}
```

### 3. Создать OverviewTabView

```swift
import SwiftUI

struct OverviewTabView: View {
    let statistics: UserStatistics?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let stats = statistics {
                    // Balance Card
                    BalanceCardView(
                        balance: stats.currentBalance,
                        isPositive: stats.isPositive
                    )
                    .padding(.horizontal)
                    
                    // Quick Stats Grid
                    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 15) {
                        StatCardView(
                            title: "Всего игр",
                            value: "\(stats.totalSessions)",
                            icon: "gamecontroller.fill",
                            color: .blue
                        )
                        
                        StatCardView(
                            title: "Win Rate",
                            value: "\(Int(stats.winRate * 100))%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                        
                        StatCardView(
                            title: "Лучшая сессия",
                            value: formatCurrency(stats.bestSession),
                            icon: "star.fill",
                            color: .yellow
                        )
                        
                        StatCardView(
                            title: "Средний профит",
                            value: formatCurrency(stats.averageProfit),
                            icon: "dollarsign.circle.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Recent Games
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Последние игры")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(stats.recentGames.prefix(5), id: \.gameId) { game in
                            GameRowView(game: game)
                        }
                    }
                    .padding(.vertical)
                } else {
                    ProgressView("Загрузка...")
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0"
    }
}
```

### 4. Создать GamesListTabView

```swift
import SwiftUI

struct GamesListTabView: View {
    let games: [Game]
    @Binding var selectedFilter: GameFilter
    let onFilterChange: (GameFilter) -> Void
    
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("Фильтр", selection: $selectedFilter) {
                Text("Все").tag(GameFilter.all)
                Text("Мои игры").tag(GameFilter.created)
                Text("Участвовал").tag(GameFilter.participated)
                Text("Прибыльные").tag(GameFilter.profitable)
                Text("Убыточные").tag(GameFilter.losing)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedFilter) { newFilter in
                onFilterChange(newFilter)
            }
            
            // Games List
            if games.isEmpty {
                ContentUnavailableView(
                    "Нет игр",
                    systemImage: "tray",
                    description: Text("Добавьте вашу первую игру")
                )
            } else {
                List {
                    ForEach(games, id: \.gameId) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            GameListRowView(game: game)
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Поиск игр")
            }
        }
    }
}

struct GameListRowView: View {
    let game: Game
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.gameType ?? "Unknown")
                    .font(.headline)
                
                Text(game.displayTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(game.players?.count ?? 0) игроков")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if game.isBalanced {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

### 5. Создать компоненты UI

`BalanceCardView.swift`:

```swift
import SwiftUI

struct BalanceCardView: View {
    let balance: Decimal
    let isPositive: Bool
    
    @State private var displayedBalance: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Текущий баланс")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(Decimal(displayedBalance)))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    .linearGradient(
                        colors: isPositive ? [.green, .blue] : [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(isPositive ? "Прибыль" : "Убыток")
            }
            .font(.caption)
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .onAppear {
            animateBalance()
        }
    }
    
    private func animateBalance() {
        withAnimation(.easeOut(duration: 1.0)) {
            displayedBalance = Double(truncating: NSDecimalNumber(decimal: balance))
        }
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0"
    }
}
```

`StatCardView.swift`:

```swift
import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(15)
    }
}
```

`GameRowView.swift`:

```swift
import SwiftUI

struct GameRowView: View {
    let game: GameSummary
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.gameType)
                        .font(.headline)
                    
                    if game.isCreator {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(game.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(game.formattedProfit)
                    .font(.headline)
                    .foregroundColor(game.profit >= 0 ? .green : .red)
                
                Text("\(game.totalPlayers) игроков")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
```

---

## Тестирование

### Проверить в Simulator

1. Запустите приложение
2. Войдите под пользователем
3. Проверьте что отображается баланс
4. Проверьте фильтры игр
5. Проверьте что статистика обновляется
6. Добавьте новую игру и проверьте обновление

---

## Критерии приемки

- [ ] MainViewModel создан и работает
- [ ] MainView обновлен с табами
- [ ] OverviewTabView отображает статистику
- [ ] GamesListTabView с фильтрами работает
- [ ] UI компоненты созданы
- [ ] Анимация баланса работает
- [ ] Pull-to-refresh работает
- [ ] UI адаптивен

---

## Следующие шаги

- **Phase 2:** Функция присвоения анонимных игроков
- **Phase 5:** Улучшение UI/UX с графиками

---

## Заметки

- Используйте `.ultraThinMaterial` для современного вида
- Анимации делают UI живее
- Фильтры улучшают UX
- Pull-to-refresh - стандарт iOS

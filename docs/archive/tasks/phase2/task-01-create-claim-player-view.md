# Task 2.1: Создание ClaimPlayerView

**Приоритет:** 🟡 Средний  
**Срок:** 3-4 дня  
**Статус:** ⬜ TODO

---

## Описание

Создать UI для поиска и присвоения анонимных имен игроков к профилю текущего пользователя.

---

## Предусловия

- ✅ Phase 1 завершена
- ✅ PlayerAlias модель создана

---

## Задачи

### 1. Создать ClaimPlayerView.swift

```swift
import SwiftUI

struct ClaimPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ClaimPlayerViewModel()
    
    @State private var searchText = ""
    @State private var showingConfirmation = false
    @State private var selectedPlayer: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Загрузка...")
                } else {
                    List {
                        ForEach(filteredPlayers, id: \.self) { playerName in
                            PlayerClaimRow(
                                playerName: playerName,
                                gamesCount: viewModel.getGamesCount(for: playerName),
                                suggestedMatches: viewModel.getSimilarNames(for: playerName)
                            ) {
                                selectedPlayer = playerName
                                showingConfirmation = true
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Поиск по имени")
                }
            }
            .navigationTitle("Присвоить игроков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .confirmationDialog(
                "Присвоить \(selectedPlayer ?? "")?",
                isPresented: $showingConfirmation,
                presenting: selectedPlayer
            ) { player in
                Button("Это я") {
                    viewModel.claimPlayer(player)
                    dismiss()
                }
                Button("Отмена", role: .cancel) { }
            } message: { player in
                if let count = viewModel.getGamesCount(for: player) {
                    Text("Будет связано \(count) игр")
                }
            }
            .onAppear {
                viewModel.loadUnclaimedPlayers()
            }
        }
    }
    
    private var filteredPlayers: [String] {
        if searchText.isEmpty {
            return viewModel.unclaimedPlayers
        }
        return viewModel.unclaimedPlayers.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct PlayerClaimRow: View {
    let playerName: String
    let gamesCount: Int
    let suggestedMatches: [String]
    let onClaim: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(playerName)
                        .font(.headline)
                    Text("\(gamesCount) игр")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Это я") {
                    onClaim()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if !suggestedMatches.isEmpty {
                Text("Похожие: \(suggestedMatches.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### 2. Создать ViewModel

```swift
@MainActor
class ClaimPlayerViewModel: ObservableObject {
    @Published var unclaimedPlayers: [String] = []
    @Published var isLoading = false
    
    private let persistence = PersistenceController.shared
    private var playerGamesCount: [String: Int] = [:]
    
    func loadUnclaimedPlayers() {
        isLoading = true
        
        Task {
            let players = persistence.fetchUnclaimedPlayerNames()
            
            // Подсчитать игры для каждого
            for player in players {
                let count = await countGames(for: player)
                playerGamesCount[player] = count
            }
            
            await MainActor.run {
                self.unclaimedPlayers = players.sorted()
                self.isLoading = false
            }
        }
    }
    
    func getGamesCount(for player: String) -> Int {
        playerGamesCount[player] ?? 0
    }
    
    func getSimilarNames(for player: String) -> [String] {
        PlayerNameMatcher.suggestSimilarNames(
            for: player,
            from: unclaimedPlayers
        ).filter { $0 != player }.prefix(3).map { $0 }
    }
    
    func claimPlayer(_ playerName: String) {
        // Будет реализовано в Task 2.2
    }
    
    private func countGames(for player: String) async -> Int {
        // Подсчет игр из старой Player модели
        let context = persistence.container.viewContext
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", player)
        
        return (try? context.count(for: request)) ?? 0
    }
}
```

---

## Критерии приемки

- [ ] ClaimPlayerView UI создан
- [ ] Поиск работает
- [ ] Отображается количество игр
- [ ] Показываются похожие имена
- [ ] Confirmation dialog работает

---

## Следующие шаги

- **Task 2.2:** Создание PlayerClaimService

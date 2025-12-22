import SwiftUI

struct GamesListTabView: View {
    let games: [Game]
    @Binding var selectedFilter: GameFilter
    let onFilterChange: (GameFilter) -> Void

    @State private var searchText = ""

    private var filteredBySearch: [Game] {
        guard !searchText.isEmpty else { return games }
        let q = searchText.lowercased()
        return games.filter { game in
            (game.gameType ?? "").lowercased().contains(q) ||
            (game.notes ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Фильтр", selection: $selectedFilter) {
                Text("Все").tag(GameFilter.all)
                Text("Мои игры").tag(GameFilter.created)
                Text("Участвовал").tag(GameFilter.participated)
                Text("Прибыльные").tag(GameFilter.profitable)
                Text("Убыточные").tag(GameFilter.losing)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedFilter) { _, newFilter in
                onFilterChange(newFilter)
            }

            if filteredBySearch.isEmpty {
                ContentUnavailableView(
                    "Нет игр",
                    systemImage: "tray",
                    description: Text("Добавьте вашу первую игру")
                )
            } else {
                List {
                    ForEach(filteredBySearch, id: \.gameId) { game in
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
                Text("\(game.gameWithPlayers?.count ?? 0) игроков")
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


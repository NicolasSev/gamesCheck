import SwiftUI
import CoreData

struct AddPlayerToGameSheet: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: Player.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)]
    ) private var players: FetchedResults<Player>

    var game: Game
    @Binding var isPresented: Bool

    @State private var selectedPlayers: Set<Player> = []

    var body: some View {
        NavigationView {
            List {
                ForEach(players, id: \.self) { player in
                    Button(action: {
                        toggleSelection(for: player)
                    }) {
                        HStack {
                            Text(player.name ?? "Без имени")
                            Spacer()
                            if isPlayerAlreadyInGame(player) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.gray)
                            } else if selectedPlayers.contains(player) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .disabled(isPlayerAlreadyInGame(player))
                }
            }
            .navigationTitle("Добавить игроков")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addSelectedPlayersToGame()
                        isPresented = false
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(for player: Player) {
        if selectedPlayers.contains(player) {
            selectedPlayers.remove(player)
        } else {
            selectedPlayers.insert(player)
        }
    }

    private func isPlayerAlreadyInGame(_ player: Player) -> Bool {
        guard let existing = game.gameWithPlayers as? Set<GameWithPlayer> else { return false }
        return existing.contains { $0.player == player }
    }

    private func addSelectedPlayersToGame() {
        for player in selectedPlayers {
            guard !isPlayerAlreadyInGame(player) else { continue }

            let gameWithPlayer = GameWithPlayer(context: viewContext)
            gameWithPlayer.player = player
            gameWithPlayer.game = game
            gameWithPlayer.buyin = 0
        }

        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения игроков в игру: \(error.localizedDescription)")
        }

        selectedPlayers.removeAll()
    }
}

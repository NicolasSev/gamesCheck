import SwiftUI
import CoreData

enum GameType: String, CaseIterable, Identifiable {
    case poker = "Покер"

    var id: String { self.rawValue }
}

struct AddGameSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    @State private var selectedDate: Date = Date()
    @State private var selectedPlaceId: UUID? = nil
    @State private var showPlaceRequiredAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Тип игры")) {
                    Text("Покер")
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Место")) {
                    PlacePickerView(selectedPlaceId: $selectedPlaceId)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section(header: Text("Дата и время игры")) {
                    DatePicker("Дата и время игры", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .accessibilityIdentifier("add_game_date_picker")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Новая игра")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                    .foregroundColor(DS.Color.txt2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        guard selectedPlaceId != nil else {
                            showPlaceRequiredAlert = true
                            return
                        }
                        createGame()
                        isPresented = false
                    }
                    .accessibilityIdentifier("add_game_save_button")
                    .foregroundColor(DS.Color.green)
                }
            }
            .preferredColorScheme(.dark)
            .v2ScreenBackground()
            .alert("Выберите место", isPresented: $showPlaceRequiredAlert) {
                Button("Ок", role: .cancel) {}
            }
        }
    }

    private func createGame() {
        let newGame = Game(context: viewContext)
        newGame.gameId = UUID()
        newGame.timestamp = selectedDate
        newGame.gameType = GameType.poker.rawValue
        newGame.creatorUserId = authViewModel.currentUserId
        newGame.softDeleted = false
        if let placeId = selectedPlaceId,
           let place = PersistenceController.shared.fetchPlace(byId: placeId, context: viewContext) {
            newGame.placeId = placeId
            newGame.place = place
        }
        do {
            try viewContext.save()

            Task {
                await SyncCoordinator.shared.quickSyncGame(newGame)
                try? await MaterializedViewsService.shared.updateGameSummary(gameId: newGame.gameId)
                let gameName = newGame.gameType ?? "Покер"
                let hostName = authViewModel.currentUsername
                try? await NotificationService.shared.notifyNewGame(gameName: gameName, hostName: hostName, gameId: newGame.gameId)
            }
        } catch {
            debugLog("Ошибка сохранения игры: \(error.localizedDescription)")
        }
    }
}

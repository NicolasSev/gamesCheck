import SwiftUI
import CoreData

enum GameType: String, CaseIterable, Identifiable {
    case poker = "Покер"
    case billiards = "Бильярд"
    
    var id: String { self.rawValue }
}

struct AddGameSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedDate: Date = Date()
    @State private var gameType: GameType = .poker  // По умолчанию игра покер
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Тип игры")) {
                    Picker("Тип игры", selection: $gameType) {
                        ForEach(GameType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityIdentifier("add_game_type_picker")
                }
                
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
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createGame()
                        isPresented = false
                    }
                    .accessibilityIdentifier("add_game_save_button")
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
            .casinoBackground()
        }
    }
    
    private func createGame() {
        let newGame = Game(context: viewContext)
        newGame.gameId = UUID()
        newGame.timestamp = selectedDate
        newGame.gameType = gameType.rawValue // Устанавливаем тип игры: "Покер" или "Бильярд"
        newGame.creatorUserId = authViewModel.currentUserId
        newGame.softDeleted = false
        do {
            try viewContext.save()
            
            // Синхронизация через SyncCoordinator → Supabase
            Task {
                await SyncCoordinator.shared.quickSyncGame(newGame)
                try? await MaterializedViewsService.shared.updateGameSummary(gameId: newGame.gameId)
                // Push уведомление создавшему (потом уберём)
                let gameName = newGame.gameType ?? "Покер"
                let hostName = authViewModel.currentUsername
                try? await NotificationService.shared.notifyNewGame(gameName: gameName, hostName: hostName, gameId: newGame.gameId)
            }
        } catch {
            debugLog("Ошибка сохранения игры: \(error.localizedDescription)")
        }
    }
}

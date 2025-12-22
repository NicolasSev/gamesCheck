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
        NavigationView {
            Form {
                Section(header: Text("Тип игры")) {
                    Picker("Тип игры", selection: $gameType) {
                        ForEach(GameType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Дата и время игры")) {
                    DatePicker("Дата и время игры", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
            }
            .navigationTitle("Новая игра")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createGame()
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func createGame() {
        let newGame = Game(context: viewContext)
        newGame.gameId = UUID()
        newGame.timestamp = selectedDate
        newGame.gameType = gameType.rawValue // Устанавливаем тип игры: "Покер" или "Бильярд"
        newGame.creatorUserId = authViewModel.currentUserId
        newGame.isDeleted = false
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения игры: \(error.localizedDescription)")
        }
    }
}

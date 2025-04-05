import SwiftUI
import CoreData

struct AddPlayerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)]
    ) private var players: FetchedResults<Player>
    
    @Binding var isPresented: Bool
    @State private var newPlayerName = ""
    @State private var refreshId = UUID()  // Новый идентификатор для форсирования обновления

    var body: some View {
        NavigationView {
            VStack {
                Text("Добавить игрока")
                    .font(.headline)
                    .padding()
                
                HStack {
                    TextField("Имя", text: $newPlayerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: addPlayer) {
                        Label("Добавить", systemImage: "person.fill.badge.plus")
                    }
                    .disabled(newPlayerName.isEmpty)
                }
                .padding()
                
                Divider()
                
                List {
                    ForEach(players) { player in
                        Text(player.name ?? "Без имени")
                    }
                    .onDelete(perform: deletePlayers)
                }
                .id(refreshId)  // При изменении refreshId List перерисовывается
            }
            .navigationTitle("Игроки")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                viewContext.refreshAllObjects()
            }
        }
    }
    
    private func addPlayer() {
        let newPlayer = Player(context: viewContext)
        newPlayer.name = newPlayerName
        saveContext()
        newPlayerName = ""
    }
    
    private func deletePlayers(offsets: IndexSet) {
        offsets.map { players[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
            // Обновляем идентификатор, чтобы List перерисовался
            refreshId = UUID()
        } catch {
            print("Ошибка сохранения: \(error.localizedDescription)")
        }
    }
}

import SwiftUI
import CoreData

struct BilliardGameDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var game: Game  // Игра типа "billiards"
    // Получаем партии из отношения billiardBatches и сортируем их по timestamp (новые сверху)
    private var batches: [BilliardBatche] {
        let set = game.billiardBatches as? Set<BilliardBatche> ?? []
        return set.sorted { (batch1: BilliardBatche, batch2: BilliardBatche) -> Bool in
            let t1 = batch1.timestamp ?? Date()
            let t2 = batch2.timestamp ?? Date()
            return t1 > t2
        }
    }
    
    @State private var isEditPlayersSheetPresented: Bool = false
    @State private var showDeleteAlert = false
    @State private var selectedBatchToDelete: BilliardBatche?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Заголовок с информацией об игре
                VStack(spacing: 8) {
                    if let gameDate = game.timestamp {
                        Text("Дата игры: \(formattedDate(gameDate))")
                            .font(.headline)
                    }
                    HStack {
                        if let player1 = game.player1 {
                            Text("Игрок 1: \(player1.name ?? "Без имени")")
                        } else {
                            Text("Игрок 1: не выбран")
                        }
                        if let player2 = game.player2 {
                            Text("Игрок 2: \(player2.name ?? "Без имени")")
                        } else {
                            Text("Игрок 2: не выбран")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                
                Divider()
                
                // Список партий
                if batches.isEmpty {
                    Text("Нет партий для этой игры")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(Array(batches.enumerated()), id: \.element) { index, batch in
                            BilliardBatchRowView(
                                batch: batch,
                                player1Name: game.player1?.name ?? "Игрок 1",
                                player2Name: game.player2?.name ?? "Игрок 2",
                                saveContext: saveContext,
                                onDeleteConfirmed: {
                                    viewContext.delete(batch)
                                    saveContext()
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    selectedBatchToDelete = batch
                                    showDeleteAlert = true
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .alert("Удалить партию?", isPresented: $showDeleteAlert) {
                        Button("Удалить", role: .destructive) {
                            withAnimation {
                                if let batch = selectedBatchToDelete {
                                    viewContext.delete(batch)
                                    saveContext()
                                    selectedBatchToDelete = nil
                                }
                            }
                        }
                        Button("Отмена", role: .cancel) {
                            selectedBatchToDelete = nil
                        }
                    } message: {
                        Text("Это действие нельзя отменить.")
                    }
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isEditPlayersSheetPresented = true
                    } label: {
                        Label("Добавить игрока", systemImage: "person.fill.badge.plus")
                    }
                    Button {
                        addBatch()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isEditPlayersSheetPresented) {
                EditBilliardsPlayersSheet(isPresented: $isEditPlayersSheetPresented, game: game)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private func addBatch() {
        // Создаем новую партию с начальными значениями 0 для обоих игроков
        let newBatch = BilliardBatche(context: viewContext)
        newBatch.scorePlayer1 = 0
        newBatch.scorePlayer2 = 0
        newBatch.timestamp = Date()
        newBatch.game = game
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения новой партии: \(error.localizedDescription)")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения: \(error.localizedDescription)")
        }
    }
}

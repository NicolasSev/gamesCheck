//
//  BilliardBatchInput.swift
//  PokerCardRecognizer
//
//  Created by Николас on 31.03.2025.
//


import SwiftUI
import CoreData

// Структура для ввода данных о партии (батче)
struct BilliardBatchInput: Identifiable {
    let id = UUID()
    var scorePlayer1: Int16 = 0
    var scorePlayer2: Int16 = 0
}

struct AddBilliardsGameSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    
    // Предположим, что у вас есть глобальный список игроков, из которого можно выбрать 2 участников.
    // Например, можно использовать @FetchRequest или передать массив извне.
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)])
    private var players: FetchedResults<Player>
    
    @State private var selectedPlayer1: Player?
    @State private var selectedPlayer2: Player?
    
    @State private var batches: [BilliardBatchInput] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Выберите игроков (2 игрока)")) {
                    Picker("Игрок 1", selection: $selectedPlayer1) {
                        ForEach(players) { player in
                            Text(player.name ?? "Без имени").tag(Optional(player))
                        }
                    }
                    
                    Picker("Игрок 2", selection: $selectedPlayer2) {
                        ForEach(players) { player in
                            Text(player.name ?? "Без имени").tag(Optional(player))
                        }
                    }
                }
                
                Section(header: Text("Партии")) {
                    ForEach($batches) { $batch in
                        HStack {
                            Stepper("Игрок 1: \(batch.scorePlayer1)", value: $batch.scorePlayer1, in: 0...8)
                            Stepper("Игрок 2: \(batch.scorePlayer2)", value: $batch.scorePlayer2, in: 0...8)
                        }
                    }
                    Button("Добавить партию") {
                        batches.append(BilliardBatchInput())
                    }
                }
            }
            .navigationTitle("Новая игра (Бильярд)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createBilliardsGame()
                        isPresented = false
                    }
                    .disabled(selectedPlayer1 == nil || selectedPlayer2 == nil || selectedPlayer1 == selectedPlayer2)
                }
            }
        }
    }
    
    private func createBilliardsGame() {
        // Создаем новую игру и устанавливаем тип "billiards"
        let newGame = Game(context: viewContext)
        newGame.gameType = "billiards"
        newGame.player1 = selectedPlayer1
        newGame.player2 = selectedPlayer2
        
        // Для каждой введенной партии создаем запись BilliardBatch
        for batchInput in batches {
            let batch = BilliardBatche(context: viewContext)
            batch.scorePlayer1 = batchInput.scorePlayer1
            batch.scorePlayer2 = batchInput.scorePlayer2
            batch.game = newGame
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения игры по бильярду: \(error.localizedDescription)")
        }
    }
}

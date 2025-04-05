//
//  EditBilliardsPlayersSheet.swift
//  PokerCardRecognizer
//
//  Created by Николас on 31.03.2025.
//


import SwiftUI
import CoreData

struct EditBilliardsPlayersSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @ObservedObject var game: Game
    
    // Получаем список всех игроков для выбора
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)])
    private var players: FetchedResults<Player>
    
    // Локальные состояния для выбранных игроков
    @State private var selectedPlayer1: Player?
    @State private var selectedPlayer2: Player?
    
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
            }
            .navigationTitle("Об /\(game.player1?.name ?? "Игрок 1")")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        updatePlayers()
                        isPresented = false
                    }
                    .disabled(selectedPlayer1 == nil || selectedPlayer2 == nil || selectedPlayer1 == selectedPlayer2)
                }
            }
            .onAppear {
                // Инициализируем состояния выбранными игроками, если они уже установлены
                selectedPlayer1 = game.player1
                selectedPlayer2 = game.player2
            }
        }
    }
    
    private func updatePlayers() {
        game.player1 = selectedPlayer1
        game.player2 = selectedPlayer2
        do {
            try viewContext.save()
        } catch {
            print("Ошибка сохранения игроков: \(error.localizedDescription)")
        }
    }
}
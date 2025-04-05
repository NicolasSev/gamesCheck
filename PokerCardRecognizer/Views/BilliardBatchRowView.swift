// BilliardBatchRowView.swift
import SwiftUI

struct BilliardBatchRowView: View {
    @ObservedObject var batch: BilliardBatche
    var player1Name: String
    var player2Name: String
    var saveContext: () -> Void
    var onDeleteConfirmed: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var showAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Игрок 1: \(player1Name)")
                Spacer()
                Button(action: {
                    batch.scorePlayer1 = max(0, batch.scorePlayer1 - 1)
                    saveContext()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                Text("Шары: \(batch.scorePlayer1)")
                Button(action: {
                    if batch.scorePlayer1 < 8 {
                        batch.scorePlayer1 += 1
                        saveContext()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack {
                Text("Игрок 2: \(player2Name)")
                Spacer()
                Button(action: {
                    batch.scorePlayer2 = max(0, batch.scorePlayer2 - 1)
                    saveContext()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                Text("Шары: \(batch.scorePlayer2)")
                Button(action: {
                    if batch.scorePlayer2 < 8 {
                        batch.scorePlayer2 += 1
                        saveContext()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .alert("Удалить партию?", isPresented: $showAlert) {
            Button("Удалить", role: .destructive) {
                onDeleteConfirmed()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }
}

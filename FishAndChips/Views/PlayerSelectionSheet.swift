//
//  PlayerSelectionSheet.swift
//  PokerCardRecognizer
//
//  Created by AI Assistant on 06.02.2026.
//

import SwiftUI

struct PlayerSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let playerNames: [String]
    @Binding var selectedPlayerNames: Set<String>
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Инструкция
                VStack(alignment: .leading, spacing: 8) {
                    Text("Выберите себя из списка")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Можно выбрать несколько вариантов вашего имени (например: \"Я\", \"я\", \"Ник\", \"ник\")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Список игроков
                List {
                    ForEach(playerNames, id: \.self) { playerName in
                        Button(action: {
                            if selectedPlayerNames.contains(playerName) {
                                selectedPlayerNames.remove(playerName)
                            } else {
                                selectedPlayerNames.insert(playerName)
                            }
                        }) {
                            HStack {
                                // Checkbox
                                Image(systemName: selectedPlayerNames.contains(playerName) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlayerNames.contains(playerName) ? .blue : .gray)
                                    .font(.system(size: 20))
                                
                                // Имя игрока
                                Text(playerName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Дополнительный индикатор для выбранных
                                if selectedPlayerNames.contains(playerName) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Кто вы?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(selectedPlayerNames.isEmpty)
                    .font(.headline)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedPlayers: Set<String> = []
        
        var body: some View {
            PlayerSelectionSheet(
                playerNames: ["Ник", "ник", "Алекс", "Борис", "Я", "я", "Вова"],
                selectedPlayerNames: $selectedPlayers,
                onConfirm: {
                    print("Selected: \(selectedPlayers.joined(separator: ", "))")
                }
            )
        }
    }
    
    return PreviewWrapper()
}

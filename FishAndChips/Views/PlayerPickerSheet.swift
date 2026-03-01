//
//  PlayerPickerSheet.swift
//  FishAndChips
//

import SwiftUI

struct PlayerPickerSheet: View {
    let availablePlayers: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if availablePlayers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Нет доступных игроков")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Все игроки уже добавлены в раздачу")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(availablePlayers, id: \.self) { playerName in
                        Button(action: {
                            onSelect(playerName)
                            dismiss()
                        }) {
                            HStack {
                                Text(playerName)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Выберите игрока")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

//
//  ConflictResolutionView.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI

struct ConflictResolutionView: View {
    let conflict: ImportDataSheet.ConflictData
    let onReplace: () -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void
    
    // Создаем словарь существующих игроков для быстрого поиска
    private var existingPlayersDict: [String: ExistingPlayerData] {
        Dictionary(uniqueKeysWithValues: conflict.existingPlayers.map { ($0.name, $0) })
    }
    
    // Сортируем существующих игроков по имени (ascending)
    private var sortedExistingPlayers: [ExistingPlayerData] {
        conflict.existingPlayers.sorted { $0.name < $1.name }
    }
    
    // Сортируем новых игроков по имени (ascending)
    private var sortedNewPlayers: [ParsedPlayer] {
        conflict.newPlayers.sorted { $0.name < $1.name }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Заголовок
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Конфликт данных")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.orange)
                    }
                    
                    Text("Игра за \(dateFormatter.string(from: conflict.date)) уже существует")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // Существующие данные
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Существующие данные")
                            .font(.headline)
                            .bold()
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sortedExistingPlayers, id: \.name) { player in
                            PlayerRowView(
                                name: player.name,
                                buyin: player.buyin,
                                cashout: player.cashout,
                                buyinDiffers: false,
                                cashoutDiffers: false
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Новые данные
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("Импортируемые данные")
                            .font(.headline)
                            .bold()
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sortedNewPlayers, id: \.name) { player in
                            let existingPlayer = existingPlayersDict[player.name]
                            let buyinDiffers = existingPlayer != nil && existingPlayer!.buyin != player.buyin
                            let cashoutDiffers = existingPlayer != nil && existingPlayer!.cashout != player.cashout
                            
                            PlayerRowView(
                                name: player.name,
                                buyin: player.buyin,
                                cashout: player.cashout,
                                buyinDiffers: buyinDiffers,
                                cashoutDiffers: cashoutDiffers
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Кнопки действий
                VStack(spacing: 12) {
                    Button(action: onReplace) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Заменить существующие данные")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: onSkip) {
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                Text("Пропустить")
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onCancel) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Отмена")
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private struct PlayerRowView: View {
        let name: String
        let buyin: Int16
        let cashout: Int64
        let buyinDiffers: Bool
        let cashoutDiffers: Bool
        
        init(name: String, buyin: Int16, cashout: Int64, buyinDiffers: Bool = false, cashoutDiffers: Bool = false) {
            self.name = name
            self.buyin = buyin
            self.cashout = cashout
            self.buyinDiffers = buyinDiffers
            self.cashoutDiffers = cashoutDiffers
        }
        
        var body: some View {
            HStack {
                Text(name)
                    .font(.body)
                    .bold()
                    .frame(width: 100, alignment: .leading)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Байин:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(buyin)")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(buyinDiffers ? .red : .primary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Кэшаут:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCashout(cashout))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(cashoutDiffers ? .red : .primary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        
        private func formatCashout(_ value: Int64) -> String {
            if value == 0 {
                return "0"
            }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = " "
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }
    
}


//
//  ConflictsResolutionView.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI

struct ConflictsResolutionView: View {
    let conflicts: [ImportDataSheet.ConflictData]
    @Binding var skippedDates: Set<Date>
    let onSkip: (Date) -> Void
    let onImport: () -> Void
    let onCancel: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var calendar: Calendar {
        Calendar.current
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
                        Text(conflicts.count == 1 ? "Конфликт данных" : "Конфликты данных")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.orange)
                    }
                    
                    Text(conflicts.count == 1 
                         ? "Игра за \(dateFormatter.string(from: conflicts[0].date)) уже существует"
                         : "Найдено \(conflicts.count) конфликтов по датам")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // Список конфликтов
                ForEach(conflicts) { conflict in
                    ConflictItemView(
                        conflict: conflict,
                        isSkipped: isDateSkipped(conflict.date),
                        onSkip: {
                            onSkip(conflict.date)
                        }
                    )
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Кнопки действий
                VStack(spacing: 12) {
                    Button(action: onImport) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Импортировать")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
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
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func isDateSkipped(_ date: Date) -> Bool {
        let dateKey = calendar.startOfDay(for: date)
        return skippedDates.contains(dateKey)
    }
}

struct ConflictItemView: View {
    let conflict: ImportDataSheet.ConflictData
    let isSkipped: Bool
    let onSkip: () -> Void
    
    // Создаем словарь существующих игроков для быстрого поиска
    // Обрабатываем дубликаты имен, оставляя первого игрока с таким именем
    private var existingPlayersDict: [String: ExistingPlayerData] {
        var dict: [String: ExistingPlayerData] = [:]
        for player in conflict.existingPlayers {
            if dict[player.name] == nil {
                dict[player.name] = player
            }
        }
        return dict
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
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок конфликта
            HStack {
                Text(dateFormatter.string(from: conflict.date))
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                if isSkipped {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Будет пропущено")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Будет заменено")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Существующие данные
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Существующие данные")
                        .font(.subheadline)
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
                        .font(.subheadline)
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
            
            // Кнопка пропустить
            Button(action: onSkip) {
                HStack {
                    Image(systemName: isSkipped ? "arrow.uturn.backward.circle" : "xmark.circle")
                    Text(isSkipped ? "Вернуть в импорт" : "Пропустить")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSkipped ? Color.green : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSkipped ? Color.orange : Color.blue, lineWidth: 2)
        )
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


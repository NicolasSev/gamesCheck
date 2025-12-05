//
//  ImportDataSheet.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI
import CoreData

struct ImportDataSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    
    @State private var inputText: String = ""
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var conflictData: [ConflictData] = []
    @State private var skippedDates: Set<Date> = [] // Даты, которые нужно пропустить при импорте
    
    struct ConflictData: Identifiable {
        let id = UUID()
        let date: Date
        let existingPlayers: [ExistingPlayerData]
        let newPlayers: [ParsedPlayer]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Формат данных:")
                            .font(.headline)
                        
                        Text("""
                        DD.MM
                        Имя Количество(Кэшаут)
                        Имя Количество
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        Text("Пример:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("""
                        25.11
                        Антон С 3(8,000)
                        Коля 8(4,000)
                        Антон 10
                        Вова 5(40,000)
                        Я 10(22,000)
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    // Диалог конфликта/конфликтов
                    if !conflictData.isEmpty {
                        ConflictsResolutionView(
                            conflicts: conflictData,
                            skippedDates: $skippedDates,
                            onSkip: { date in
                                skipDate(date)
                            },
                            onImport: {
                                performImport()
                            },
                            onCancel: {
                                conflictData = []
                                skippedDates = []
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                Button(action: importData) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isImporting ? "Валидация..." : "Валидировать данные")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isImporting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isImporting || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 20)
                }
            }
            .navigationTitle("Импорт данных")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func importData() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isImporting = true
        errorMessage = nil
        successMessage = nil
        conflictData = []
        skippedDates = []
        
        let service = DataImportService(viewContext: viewContext)
        
        // Парсим данные
        let parsedGames = service.parseText(inputText)
        
        guard !parsedGames.isEmpty else {
            errorMessage = "Не удалось распарсить данные. Проверьте формат.\n\nУбедитесь, что:\n- Дата указана в формате DD.MM\n- Каждая строка с игроком содержит имя и количество байинов"
            isImporting = false
            return
        }
        
        // Проверяем существующие игры
        let existingGames = service.checkExistingGames(parsedGames)
        let calendar = Calendar.current
        
        // Собираем все конфликты
        var conflicts: [ConflictData] = []
        for parsedGame in parsedGames {
            let gameDate = calendar.startOfDay(for: parsedGame.date)
            if let existing = existingGames[gameDate] {
                conflicts.append(ConflictData(
                    date: parsedGame.date,
                    existingPlayers: existing.players,
                    newPlayers: parsedGame.players
                ))
            }
        }
        
        // Если есть конфликты, показываем диалог
        if !conflicts.isEmpty {
            conflictData = conflicts
            skippedDates = []
            isImporting = false
            return
        }
        
        // Если конфликтов нет, импортируем сразу
        performImport()
    }
    
    private func skipDate(_ date: Date) {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        if skippedDates.contains(dateKey) {
            skippedDates.remove(dateKey)
        } else {
            skippedDates.insert(dateKey)
        }
    }
    
    private func performImport() {
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        let service = DataImportService(viewContext: viewContext)
        let parsedGames = service.parseText(inputText)
        let calendar = Calendar.current
        
        // Импортируем игры с учетом пропущенных дат
        var importedCount = 0
        var skippedCount = 0
        var totalPlayers = 0
        var errors: [String] = []
        
        for parsedGame in parsedGames {
            let gameDate = calendar.startOfDay(for: parsedGame.date)
            
            // Если дата была пропущена - не импортируем
            if skippedDates.contains(gameDate) {
                skippedCount += 1
                continue
            }
            
            // Определяем, нужно ли заменять (если есть конфликт и не пропущено - заменяем)
            let hasConflict = conflictData.contains(where: { calendar.startOfDay(for: $0.date) == gameDate })
            let shouldReplace = hasConflict
            
            do {
                try service.importGames([parsedGame], replaceExisting: shouldReplace)
                importedCount += 1
                totalPlayers += parsedGame.players.count
            } catch {
                let errorMsg = "Ошибка импорта игры за \(dateFormatter.string(from: parsedGame.date)): \(error.localizedDescription)"
                errors.append(errorMsg)
                print(errorMsg)
            }
        }
        
        // Формируем сообщение
        if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
            isImporting = false
        } else {
            var message = "Успешно импортировано:\n• Игр: \(importedCount)"
            if skippedCount > 0 {
                message += "\n• Пропущено: \(skippedCount)"
            }
            message += "\n• Игроков: \(totalPlayers)"
            
            successMessage = message
            conflictData = []
            skippedDates = []
            
            // Очищаем поле ввода через небольшую задержку
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                inputText = ""
                isPresented = false
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}


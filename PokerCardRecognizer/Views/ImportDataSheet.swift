//
//  ImportDataSheet.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI
import CoreData
import UIKit

struct SimpleTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        // Критически важно для отключения AutoFill
        // Используем .none или nil - оба должны отключить AutoFill
        textView.textContentType = nil
        textView.isSecureTextEntry = false
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        // Отключаем все умные функции, которые могут вызвать AutoFill
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Каждый раз принудительно отключаем AutoFill
        uiView.textContentType = nil
        uiView.isSecureTextEntry = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SimpleTextEditor
        
        init(_ parent: SimpleTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct ImportDataSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
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
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Формат данных:")
                            .font(.headline)
                        
                        Text("""
                        DD.MM.YYYY
                        Имя Количество(Кэшаут)
                        Имя Количество
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("Пример:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("""
                        25.11.2024
                        Антон С 3(8,000)
                        Коля 8(4,000)
                        Антон 10
                        Вова 5(40,000)
                        Я 10(22,000)
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    SimpleTextEditor(text: $inputText)
                        .frame(minHeight: 200)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                if !conflictData.isEmpty {
                    Section {
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
                    }
                }
                
                Section {
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
                    }
                    .disabled(isImporting || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        
        let service = DataImportService(viewContext: viewContext, userId: authViewModel.currentUserId)
        
        // Парсим данные
        let parsedGames = service.parseText(inputText)
        
        guard !parsedGames.isEmpty else {
            errorMessage = "Не удалось распарсить данные. Проверьте формат.\n\nУбедитесь, что:\n- Дата указана в формате DD.MM.YYYY\n- Каждая строка с игроком содержит имя и количество байинов"
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
        
        let service = DataImportService(viewContext: viewContext, userId: authViewModel.currentUserId)
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

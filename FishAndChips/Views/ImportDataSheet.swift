//
//  ImportDataSheet.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI
import CoreData
import UIKit

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
    @State private var validatedGames: [ParsedGame] = []
    @State private var uniquePlayerNames: [String] = []
    @State private var selectedPlayerNames: Set<String> = []
    @State private var showPlayerSelection = false
    
    struct ConflictData: Identifiable {
        let id = UUID()
        let date: Date
        let existingPlayers: [ExistingPlayerData]
        let newPlayers: [ParsedPlayer]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Формат данных:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("""
                        DD.MM.YYYY
                        Имя Количество(Кэшаут)
                        Имя Количество
                        """)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        
                        Text("Пример:")
                            .font(.headline)
                            .foregroundColor(.white)
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
                        .foregroundColor(.white.opacity(0.65))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                
                Section {
                    SimpleTextEditor(text: $inputText)
                        .frame(minHeight: 200)
                }
                .listRowBackground(Color.white.opacity(0.06))
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red.opacity(0.95))
                            .font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                
                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(Color.casinoAccentGreen)
                            .font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
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
                    .buttonStyle(.borderedProminent)
                    .tint(Color.casinoAccentGreen)
                    .accessibilityIdentifier("import_validate_button")
                    .disabled(isImporting || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("import_data_root")
            .navigationTitle("Импорт данных")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .v2ScreenBackground()
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showPlayerSelection) {
                PlayerSelectionSheet(
                    playerNames: uniquePlayerNames,
                    selectedPlayerNames: $selectedPlayerNames,
                    onConfirm: {
                        performImportWithSelectedPlayers()
                    }
                )
            }
            .onAppear(perform: loadUITestImportFixtureIfNeeded)
        }
    }

    /// UITest: `--uitesting-import-file` + `UITEST_IMPORT_FILE_PATH` → подставить текст из файла (как ручной ввод).
    private func loadUITestImportFixtureIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("--uitesting-import-file") else { return }
        guard let path = ProcessInfo.processInfo.environment["UITEST_IMPORT_FILE_PATH"], !path.isEmpty else { return }
        guard let s = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else { return }
        inputText = s
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
        
        // Сохраняем валидированные игры и сразу извлекаем имена игроков
        // (чтобы список был готов и при показе sheet сразу, и после разрешения конфликтов)
        validatedGames = parsedGames
        uniquePlayerNames = service.extractUniquePlayerNames(from: parsedGames)
        
        // Если есть конфликты, показываем диалог (uniquePlayerNames уже заполнен для последующего выбора хоста)
        if !conflicts.isEmpty {
            conflictData = conflicts
            skippedDates = []
            isImporting = false
            return
        }
        
        // Если игроков нет, показываем ошибку
        guard !uniquePlayerNames.isEmpty else {
            errorMessage = "Не удалось найти игроков в данных"
            isImporting = false
            return
        }
        
        // Показываем селект выбора игрока (хост = кто вы в этих играх)
        isImporting = false
        showPlayerSelection = true
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
    
    private func performImportWithSelectedPlayers() {
        guard !selectedPlayerNames.isEmpty else {
            errorMessage = "Необходимо выбрать хотя бы одного игрока"
            return
        }
        
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        let service = DataImportService(viewContext: viewContext, userId: authViewModel.currentUserId)
        let calendar = Calendar.current
        
        // Проверяем есть ли конфликты и нужно ли показать диалог разрешения
        let existingGames = service.checkExistingGames(validatedGames)
        var conflicts: [ConflictData] = []
        for parsedGame in validatedGames {
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
        
        // Импортируем все игры одной транзакцией (один save в Core Data)
        let importedCount: Int
        let totalPlayers: Int
        do {
            try service.importGames(validatedGames, selectedPlayerNames: selectedPlayerNames, replaceExisting: false)
            importedCount = validatedGames.count
            totalPlayers = validatedGames.reduce(0) { $0 + $1.players.count }
        } catch {
            let detail = Self.coreDataErrorDescription(error)
            errorMessage = "Ошибка импорта: \(detail)"
            debugLog("Import failed: \(error)")
            isImporting = false
            return
        }
        
        let selectedNamesStr = selectedPlayerNames.sorted().joined(separator: ", ")
        let message = "Успешно импортировано:\n• Игр: \(importedCount)\n• Игроков: \(totalPlayers)\n• Вы выбраны как: \(selectedNamesStr)"
        
        Task {
            do {
                debugLog("☁️ [IMPORT] Sync после импорта (Supabase / офлайн-очередь)...")
                try await SyncCoordinator.shared.sync()
                debugLog("✅ [IMPORT] Синхронизация после импорта завершена")
                let hostName = authViewModel.currentUsername
                let gameName = importedCount == 1 ? "1 импортированная игра" : "\(importedCount) импортированных игр"
                try? await NotificationService.shared.notifyNewGame(gameName: gameName, hostName: hostName, gameId: nil)
            } catch {
                debugLog("⚠️ [IMPORT] Синхронизация после импорта: \(error)")
            }
        }
        
        successMessage = message
        validatedGames = []
        uniquePlayerNames = []
        selectedPlayerNames = []
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            inputText = ""
            isPresented = false
        }
        
        isImporting = false
    }
    
    private func performImport() {
        // Если игроки еще не выбраны, показываем селект (имена из валидированных данных)
        if selectedPlayerNames.isEmpty {
            let service = DataImportService(viewContext: viewContext, userId: authViewModel.currentUserId)
            let gamesToUse = validatedGames.isEmpty ? service.parseText(inputText) : validatedGames
            uniquePlayerNames = service.extractUniquePlayerNames(from: gamesToUse)
            
            guard !uniquePlayerNames.isEmpty else {
                errorMessage = "Не удалось найти игроков в данных. Проверьте формат: каждая строка с игроком — «Имя Число» или «Имя Число(Кэшаут)»."
                return
            }
            
            showPlayerSelection = true
            return
        }
        
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        let service = DataImportService(viewContext: viewContext, userId: authViewModel.currentUserId)
        let parsedGames = validatedGames.isEmpty ? service.parseText(inputText) : validatedGames
        let calendar = Calendar.current
        
        let gamesToImport = parsedGames.filter { !skippedDates.contains(calendar.startOfDay(for: $0.date)) }
        let skippedCount = parsedGames.count - gamesToImport.count
        
        do {
            try service.importGames(
                gamesToImport,
                selectedPlayerNames: selectedPlayerNames,
                replaceExisting: false,
                replaceExistingForDate: { date in
                    let d = calendar.startOfDay(for: date)
                    return conflictData.contains { calendar.startOfDay(for: $0.date) == d }
                }
            )
        } catch {
            errorMessage = "Ошибка импорта: \(Self.coreDataErrorDescription(error))"
            debugLog("Import failed: \(error)")
            isImporting = false
            return
        }
        
        let importedCount = gamesToImport.count
        let totalPlayers = gamesToImport.reduce(0) { $0 + $1.players.count }
        
        var message = "Успешно импортировано:\n• Игр: \(importedCount)"
        if skippedCount > 0 {
            message += "\n• Пропущено: \(skippedCount)"
        }
        message += "\n• Игроков: \(totalPlayers)"
        if !selectedPlayerNames.isEmpty {
            let selectedNamesStr = selectedPlayerNames.sorted().joined(separator: ", ")
            message += "\n• Вы выбраны как: \(selectedNamesStr)"
        }
        
        Task {
            do {
                debugLog("☁️ [IMPORT] Sync после импорта (Supabase / офлайн-очередь)...")
                try await SyncCoordinator.shared.sync()
                debugLog("✅ [IMPORT] Синхронизация после импорта завершена")
                let hostName = authViewModel.currentUsername
                let gameName = importedCount == 1 ? "1 импортированная игра" : "\(importedCount) импортированных игр"
                try? await NotificationService.shared.notifyNewGame(gameName: gameName, hostName: hostName, gameId: nil)
            } catch {
                debugLog("⚠️ [IMPORT] Синхронизация после импорта: \(error)")
            }
        }
        
        successMessage = message
        conflictData = []
        skippedDates = []
        validatedGames = []
        uniquePlayerNames = []
        selectedPlayerNames = []
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            inputText = ""
            isPresented = false
        }
        
        isImporting = false
    }
    
    /// Разворачивает вложенные NSError Core Data (Multiple validation errors) для UI.
    private static func coreDataErrorDescription(_ error: Error) -> String {
        let ns = error as NSError
        if let detailed = ns.userInfo[NSDetailedErrorsKey] as? [NSError], !detailed.isEmpty {
            return detailed.map { err in
                if let reason = err.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !reason.isEmpty {
                    return "\(err.localizedDescription): \(reason)"
                }
                return err.localizedDescription
            }.joined(separator: "\n")
        }
        return ns.localizedDescription
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

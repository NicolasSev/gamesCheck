import SwiftUI
import CoreData

struct GameDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: Game

    @State private var isAddPlayerSheetPresented = false
    @State private var showDeleteConfirmation = false
    @State private var isClaimPlayerSheetPresented = false
    @State private var isHandAddSheetPresented = false
    @State private var refreshHandsToggle = false // Для обновления списка раздач

    // Вместо флагов и массивов используем один @State shareData
    @State private var shareData: ShareData?
    
    private let claimService = PlayerClaimService()
    private let keychain = KeychainService.shared
    
    private var currentUserId: UUID? {
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            debugLog("❌ No currentUserId in Keychain")
            return nil
        }
        debugLog("✅ Current userId: \(userId)")
        return userId
    }
    
    private var isHost: Bool {
        guard let userId = currentUserId else {
            debugLog("❌ isHost: false - no currentUserId")
            return false
        }
        let result = game.creatorUserId == userId
        debugLog("🔍 isHost check: game.creatorUserId=\(game.creatorUserId?.uuidString ?? "nil"), currentUserId=\(userId.uuidString), isHost=\(result)")
        return result
    }
    
    private var canClaim: Bool {
        guard let userId = currentUserId else { return false }
        return !isHost && game.creatorUserId != nil
    }

    var gameWithPlayers: [GameWithPlayer] {
        let set = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }
    
    // Получаем раздачи для текущей игры
    private var handsForThisGame: [HandModel] {
        HandsStorageService.shared.getHands(forGameId: game.gameId)
            .sorted { $0.timestamp > $1.timestamp } // Новые вверху
    }
    
    // Вычисляем результаты игроков для гистограммы
    private var playerResults: [PlayerResult] {
        gameWithPlayers.map { gwp in
            let buyin = Decimal(Int(gwp.buyin))
            let cashout = Decimal(Int(gwp.cashout))
            let profit = cashout - (buyin * Decimal(ChipValue.tengePerChip))
            return PlayerResult(
                playerName: gwp.playerProfile?.displayName ?? gwp.player?.name ?? "Без имени",
                profit: profit,
                buyin: gwp.buyin,
                cashout: gwp.cashout
            )
        }.sorted { $0.profit > $1.profit }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
                List {
                    // Информация о дате и сумме байинов
                    VStack(alignment: .leading, spacing: 8) {
                        if let timestamp = game.timestamp {
                            HStack {
                                Text("Дата:")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text(formatDate(timestamp))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        HStack {
                            Text("Сумма байинов:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(Int(truncating: NSDecimalNumber(decimal: game.totalBuyins))) (\((game.totalBuyins * Decimal(ChipValue.tengePerChip)).formatCurrency()))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // Гистограмма результатов
                    GameResultsChart(playerResults: playerResults)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .padding(.vertical, 8)
                    
                    // Список раздач
                    Section {
                        ForEach(handsForThisGame) { hand in
                            HandRowView(hand: hand, game: game)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteHand(hand)
                                    } label: {
                                        VStack {
                                            Image(systemName: "trash")
                                            Text("Удалить")
                                                .font(.caption)
                                        }
                                    }
                                    .tint(.red)
                                }
                        }
                    } header: {
                        if !handsForThisGame.isEmpty {
                            Text("Раздачи (\(handsForThisGame.count))")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    // Список игроков
                    Section {
                        ForEach(gameWithPlayers, id: \.self) { gwp in
                            VStack(spacing: 8) {
                                PlayerRow(
                                    gameWithPlayer: gwp,
                                    updateBuyIn: updateBuyIn,
                                    setCashout: setCashout,
                                    isHost: isHost
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                
                                // Показать статус заявки если не хост
                                if canClaim, let userId = currentUserId {
                                    ClaimStatusView(gameWithPlayer: gwp, userId: userId)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if isHost {
                                    Button(role: .destructive) {
                                        removeGameWithPlayer(gwp: gwp)
                                    } label: {
                                        VStack {
                                            Image(systemName: "trash")
                                            Text("Удалить")
                                                .font(.caption)
                                        }
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    } header: {
                        Text("Игроки (\(gameWithPlayers.count))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                VStack(spacing: 12) {
                    // Кнопки для хоста
                    if isHost {
                        // Переключатель публичности
                        HStack {
                            Toggle("Публичная игра", isOn: Binding(
                                get: { game.isPublic },
                                set: { newValue in
                                    game.isPublic = newValue
                                    saveContext()
                                }
                            ))
                            .foregroundColor(.white)
                            .tint(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .liquidGlass(cornerRadius: 12)
                        
                        // Кнопка поделиться ссылкой
                        Button(action: shareGameLink) {
                            HStack {
                                Image(systemName: "link")
                                Text("Поделиться ссылкой на игру")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .liquidGlass(cornerRadius: 12)
                        }
                        .accessibilityIdentifier("game_detail_share_link_button")
                    }
                    
                    // Кнопка "Отправить статистику" (для всех)
                    Button(action: shareStatistics) {
                        Text("Отправить статистику по игре")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .liquidGlass(cornerRadius: 12)
                    }
                    .accessibilityIdentifier("game_detail_share_stats_button")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        .casinoBackground()
        .navigationTitle("Детали игры")
        .task(id: game.gameId) {
            // Phase 2: Lazy load GWP при открытии игры (если ещё не загружены)
            let count = game.gameWithPlayers?.count ?? 0
            guard count == 0 else { return }

            do {
                debugLog("📥 [GameDetail] Loading players for game \(game.gameId) (lazy load)")
                try await SyncCoordinator.shared.fetchGameWithPlayers(forGameId: game.gameId)
                debugLog("✅ [GameDetail] Players loaded")
            } catch {
                debugLog("❌ [GameDetail] Failed to load players: \(error)")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Кнопка "Подать заявку" (только для не-хостов)
                if canClaim {
                    Button {
                        isClaimPlayerSheetPresented = true
                    } label: {
                        Label("Подать заявку", systemImage: "person.badge.plus")
                    }
                    .accessibilityIdentifier("game_detail_claim_button")
                }
                
                // Кнопка "Добавить игрока" (только для хоста)
                if isHost {
                    Button {
                        isAddPlayerSheetPresented = true
                    } label: {
                        Label("Добавить игрока", systemImage: "person.fill.badge.plus")
                    }
                    .accessibilityIdentifier("game_detail_add_player_button")
                }
                
                // Кнопка "Добавить раздачу"
                Button {
                    isHandAddSheetPresented = true
                } label: {
                    Label("Добавить раздачу", systemImage: "rectangle.stack.fill.badge.plus")
                }
                .accessibilityIdentifier("game_detail_add_hand_button")
                
                // Кнопка "Удалить игру" (только для хоста)
                if isHost {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить игру", systemImage: "trash")
                    }
                    .accessibilityIdentifier("game_detail_delete_button")
                }
            }
        }
        // Лист добавления игроков
        .sheet(isPresented: $isAddPlayerSheetPresented) {
            AddPlayerToGameSheet(game: game, isPresented: $isAddPlayerSheetPresented)
                .environment(\.managedObjectContext, viewContext)
        }
        // Лист подачи заявки
        .sheet(isPresented: $isClaimPlayerSheetPresented) {
            ClaimPlayerView(game: game)
                .environment(\.managedObjectContext, viewContext)
        }
        // Лист добавления раздачи
        .sheet(isPresented: $isHandAddSheetPresented) {
            // При закрытии листа обновляем список
            refreshHandsToggle.toggle()
        } content: {
            HandAddView(game: game)
                .environment(\.managedObjectContext, viewContext)
        }
        // Лист шаринга - вызывается только если shareData != nil
        .sheet(item: $shareData) { data in
            ShareSheet(activityItems: data.items)
        }
        .alert("Удалить игру?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                deleteGame()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Вы уверены, что хотите удалить игру и все связанные данные?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .handDidUpdate)) { _ in
            refreshHandsToggle.toggle()
        }
    }

    private func updateBuyIn(for gwp: GameWithPlayer, change: Int16) {
        let newBuyIn = gwp.buyin + change
        if newBuyIn >= 0 {
            gwp.buyin = newBuyIn
            saveContext()
        }
    }

    private func setCashout(for gwp: GameWithPlayer, value: Int64) {
        gwp.cashout = value
        saveContext()
    }

    private func removeGameWithPlayer(gwp: GameWithPlayer) {
        viewContext.delete(gwp)
        saveContext()
    }
    
    private func deleteHand(_ hand: HandModel) {
        HandsStorageService.shared.deleteHand(id: hand.id)
        refreshHandsToggle.toggle()
    }

    private func saveContext() {
        do {
            try viewContext.save()
            game.objectWillChange.send()
        } catch {
            debugLog("Ошибка сохранения: \(error.localizedDescription)")
        }
    }

    /// Собирает статистику игры в виде строки
    private func buildStatistics() -> String {
        var message = "Статистика игры:\n"
        if let timestamp = game.timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message += "Дата игры: \(formatter.string(from: timestamp))\n"
        }
        for gwp in gameWithPlayers {
            let playerName = gwp.playerProfile?.displayName ?? gwp.player?.name ?? "Без имени"
            message += "\(playerName): Buy-in: \(gwp.buyin), Cashout: \(gwp.cashout)\n"
        }
        return message
    }

    /// Создаёт временный файл со статистикой и назначает shareData
    private func shareStatistics() {
        let message = buildStatistics()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("statistics_\(UUID().uuidString).txt")
        do {
            try message.write(to: fileURL, atomically: true, encoding: .utf8)
            // Считываем данные из файла для проверки
            let data = try Data(contentsOf: fileURL)
            debugLog("Файл записан, размер: \(data.count) байт")

            // Создаём объект ShareData
            shareData = ShareData(items: [fileURL])
            // При присвоении shareData, SwiftUI автоматически вызывает sheet(item:)
        } catch {
            debugLog("Ошибка записи файла статистики: \(error.localizedDescription)")
        }
    }
    
    /// Удаляет игру и связанные с ней данные, затем закрывает экран
    private func deleteGame() {
        // Если отношения настроены без каскадного удаления, можно удалить все связи вручную:
        if let set = game.gameWithPlayers as? Set<GameWithPlayer> {
            for gwp in set {
                viewContext.delete(gwp)
            }
        }
        viewContext.delete(game)
        saveContext()
        dismiss()
    }
    
    /// Генерирует ссылку на игру и открывает Share Sheet
    private func shareGameLink() {
        let gameId = game.gameId.uuidString
        let deepLink = "fishandchips://game/\(gameId)"
        let webURL = AppWebConfig.gameURL(gameId: game.gameId).absoluteString

        let message = """
        🎮 Приглашение в Fish & Chips!
        
        📋 Код игры: \(gameId)
        
        🌐 Веб (приложение): \(webURL)
        
        🔗 Схема приложения:
        \(deepLink)
        
        📱 Или вручную:
        1. Откройте приложение Fish & Chips
        2. Профиль → Мои заявки → Присоединиться
        3. Вставьте код игры
        
        💡 Подсказка: долгое нажатие на код → Скопировать
        """
        
        shareData = ShareData(items: [message])
    }
}

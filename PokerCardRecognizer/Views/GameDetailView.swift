import SwiftUI
import CoreData

// Структура для передачи элементов в лист шаринга.
// Делаем её Identifiable, чтобы использовать sheet(item:)
struct ShareData: Identifiable {
    let id = UUID()
    let items: [Any]
}

// Структура для данных гистограммы
struct PlayerResult: Identifiable, Hashable {
    let id = UUID()
    let playerName: String
    let profit: Decimal
    let buyin: Int16
    let cashout: Int64
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PlayerResult, rhs: PlayerResult) -> Bool {
        lhs.id == rhs.id
    }
}

// Компонент гистограммы результатов игроков
struct GameResultsChart: View {
    let playerResults: [PlayerResult]
    @State private var selectedResult: PlayerResult?
    
    private var maxAbsoluteProfit: Decimal {
        let profits = playerResults.map { abs($0.profit) }
        return profits.max() ?? 1
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₸0"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatBuyinInTenge(_ buyin: Int16) -> String {
        let buyinInTenge = Decimal(buyin) * 2000
        return formatCurrency(buyinInTenge)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты игры")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            if playerResults.isEmpty {
                Text("Нет данных")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 16) {
                    ForEach(playerResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(result.playerName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(width: 80, alignment: .leading)
                                
                                Spacer()
                                
                                Text(formatCurrency(result.profit))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(result.profit >= 0 ? .green : .red)
                                    .frame(width: 100, alignment: .trailing)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Фоновая линия
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 24)
                                        .cornerRadius(12)
                                    
                                    // Столбец гистограммы
                                    if result.profit != 0 {
                                        let profitValue = Double(truncating: NSDecimalNumber(decimal: abs(result.profit)))
                                        let maxValue = Double(truncating: NSDecimalNumber(decimal: maxAbsoluteProfit))
                                        let width = maxValue > 0 ? (profitValue / maxValue) * geometry.size.width : 0
                                        
                                        HStack {
                                            if result.profit < 0 {
                                                Spacer()
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.8))
                                                    .frame(width: width, height: 24)
                                                    .cornerRadius(12)
                                            } else {
                                                Rectangle()
                                                    .fill(Color.green.opacity(0.8))
                                                    .frame(width: width, height: 24)
                                                    .cornerRadius(12)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 24)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResult = result
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .liquidGlass(cornerRadius: 12)
        .popover(item: $selectedResult) { result in
            VStack(alignment: .leading, spacing: 12) {
                Text(result.playerName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Байины:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(result.buyin)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Байины (в тенге):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBuyinInTenge(result.buyin))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Кэшаут:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(Decimal(result.cashout)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Результат:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatCurrency(result.profit))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(result.profit >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .frame(width: 280)
        }
    }
}

// Обёртка над UIActivityViewController для Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct GameDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: Game

    @State private var isAddPlayerSheetPresented = false
    @State private var showDeleteConfirmation = false
    @State private var isClaimPlayerSheetPresented = false
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")

    // Вместо флагов и массивов используем один @State shareData
    @State private var shareData: ShareData?
    
    private let claimService = PlayerClaimService()
    
    private var currentUserId: UUID? {
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }
    
    private var isHost: Bool {
        guard let userId = currentUserId else { return false }
        return game.creatorUserId == userId
    }
    
    private var canClaim: Bool {
        guard let userId = currentUserId else { return false }
        return !isHost && game.creatorUserId != nil
    }

    var gameWithPlayers: [GameWithPlayer] {
        let set = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }
    
    // Вычисляем результаты игроков для гистограммы
    private var playerResults: [PlayerResult] {
        gameWithPlayers.map { gwp in
            let buyin = Decimal(Int(gwp.buyin))
            let cashout = Decimal(Int(gwp.cashout))
            let profit = cashout - (buyin * 2000)
            return PlayerResult(
                playerName: gwp.player?.name ?? "Без имени",
                profit: profit,
                buyin: gwp.buyin,
                cashout: gwp.cashout
            )
        }.sorted { $0.profit > $1.profit }
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₸0"
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
                            Text("\(Int(truncating: NSDecimalNumber(decimal: game.totalBuyins))) (\(formatCurrency(game.totalBuyins * 2000)))")
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
                    
                    // Список игроков
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        .background(
            Group {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        )
        .navigationTitle("Детали игры")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Кнопка "Подать заявку" (только для не-хостов)
                if canClaim {
                    Button {
                        isClaimPlayerSheetPresented = true
                    } label: {
                        Label("Подать заявку", systemImage: "person.badge.plus")
                    }
                }
                
                // Кнопка "Добавить игрока" (только для хоста)
                if isHost {
                    Button {
                        isAddPlayerSheetPresented = true
                    } label: {
                        Label("Добавить игрока", systemImage: "person.fill.badge.plus")
                    }
                }
                
                // Кнопка "Удалить игру" (только для хоста)
                if isHost {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить игру", systemImage: "trash")
                    }
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

    private func saveContext() {
        do {
            try viewContext.save()
            game.objectWillChange.send()
        } catch {
            print("Ошибка сохранения: \(error.localizedDescription)")
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
            let playerName = gwp.player?.name ?? "Без имени"
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
            print("Файл записан, размер: \(data.count) байт")

            // Создаём объект ShareData
            shareData = ShareData(items: [fileURL])
            // При присвоении shareData, SwiftUI автоматически вызывает sheet(item:)
        } catch {
            print("Ошибка записи файла статистики: \(error.localizedDescription)")
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
        let gameId = game.gameId
        let urlString = "pokertracker://game/\(gameId.uuidString)"
        guard let url = URL(string: urlString) else { return }
        
        shareData = ShareData(items: [url])
    }
}

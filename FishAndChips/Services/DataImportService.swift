//
//  DataImportService.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import Foundation
import CoreData

public struct ParsedPlayer {
    public let name: String
    public let buyin: Int16
    public let cashout: Int64
    
    public init(name: String, buyin: Int16, cashout: Int64) {
        self.name = name
        self.buyin = buyin
        self.cashout = cashout
    }
}

public struct ParsedGame {
    public let date: Date
    public let players: [ParsedPlayer]
    
    public init(date: Date, players: [ParsedPlayer]) {
        self.date = date
        self.players = players
    }
}

public struct ExistingGameData {
    public let game: Game
    public let players: [ExistingPlayerData]
    
    public init(game: Game, players: [ExistingPlayerData]) {
        self.game = game
        self.players = players
    }
}

public struct ExistingPlayerData {
    public let name: String
    public let buyin: Int16
    public let cashout: Int64
    
    public init(name: String, buyin: Int16, cashout: Int64) {
        self.name = name
        self.buyin = buyin
        self.cashout = cashout
    }
}

class DataImportService {
    private let viewContext: NSManagedObjectContext
    private let userId: UUID?
    private let persistence: PersistenceController
    
    init(viewContext: NSManagedObjectContext, userId: UUID? = nil) {
        self.viewContext = viewContext
        self.userId = userId
        self.persistence = PersistenceController.shared
    }
    
    /// Парсит текст и возвращает массив игр
    func parseText(_ text: String) -> [ParsedGame] {
        var games: [ParsedGame] = []
        let normalized = text
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
        let rawLines = normalized.components(separatedBy: .newlines)
        var inferredYear = Calendar.current.component(.year, from: Date())
        var currentDate: Date?
        var currentPlayers: [ParsedPlayer] = []
        
        func commitPendingGame() {
            if let date = currentDate, !currentPlayers.isEmpty {
                games.append(ParsedGame(date: date, players: currentPlayers))
            }
        }
        
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if isNoiseLine(line) {
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if t == "2025" { inferredYear = 2025 }
                if t == "2024" { inferredYear = 2024 }
                continue
            }
            
            if let date = parseFullDate(line) {
                inferredYear = Calendar.current.component(.year, from: date)
                commitPendingGame()
                currentDate = date
                currentPlayers = []
            } else if let date = parseDayMonthOnly(line, year: inferredYear) {
                inferredYear = Calendar.current.component(.year, from: date)
                commitPendingGame()
                currentDate = date
                currentPlayers = []
            } else if let player = parsePlayer(line) {
                currentPlayers.append(player)
            }
        }
        
        commitPendingGame()
        return games
    }
    
    /// Строки-разделители и заголовки секций (не игроки и не даты)
    private func isNoiseLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if t == "2025" || t == "2024" { return true }
        return t.unicodeScalars.allSatisfy { u in
            u == "-" || u == "—" || u == "–" || CharacterSet.whitespacesAndNewlines.contains(u)
        }
    }
    
    /// DD.MM.YYYY
    private func parseFullDate(_ line: String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let datePattern = #"^(\d{1,2})\.(\d{1,2})\.(\d{4})$"#
        guard let regex = try? NSRegularExpression(pattern: datePattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }
        guard let dayRange = Range(match.range(at: 1), in: trimmed),
              let monthRange = Range(match.range(at: 2), in: trimmed),
              let yearRange = Range(match.range(at: 3), in: trimmed),
              let day = Int(trimmed[dayRange]),
              let month = Int(trimmed[monthRange]),
              let year = Int(trimmed[yearRange]),
              day >= 1 && day <= 31,
              month >= 1 && month <= 12,
              year >= 2000 && year <= 2100 else {
            return nil
        }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        return Calendar.current.date(from: components)
    }
    
    /// DD.MM (год из контекста, напр. «24.06» после блока с 2025)
    private func parseDayMonthOnly(_ line: String, year: Int) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(\d{1,2})\.(\d{1,2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let dr = Range(match.range(at: 1), in: trimmed),
              let mr = Range(match.range(at: 2), in: trimmed),
              let day = Int(trimmed[dr]),
              let month = Int(trimmed[mr]),
              day >= 1 && day <= 31,
              month >= 1 && month <= 12 else {
            return nil
        }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        return Calendar.current.date(from: components)
    }
    
    private func normalizePlayerLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\u{00a0}", with: " ")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        while s.hasSuffix("/") {
            s.removeLast()
        }
        let open = s.filter { $0 == "(" }.count
        let close = s.filter { $0 == ")" }.count
        if open > close {
            s += String(repeating: ")", count: open - close)
        }
        return s
    }
    
    /// Сумма в скобках: запятые, ~, «12+18», отрицательные
    private func parseCashoutExpression(_ inner: String) -> Int64 {
        let cleaned = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return 0 }
        let parts = cleaned.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        var sum: Int64 = 0
        for p in parts {
            sum += parseSingleCashoutToken(p)
        }
        return sum
    }
    
    private func parseSingleCashoutToken(_ token: String) -> Int64 {
        var t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: ",", with: "")
        t = t.replacingOccurrences(of: "~", with: "")
        t = t.replacingOccurrences(of: " ", with: "")
        if t.hasPrefix("+") { t.removeFirst() }
        if t.isEmpty { return 0 }
        return Int64(t) ?? 0
    }
    
    /// «Имя (кэшаут)» без байина (редкие строки в ручных записях)
    private func parsePlayerCashoutOnly(_ trimmed: String) -> ParsedPlayer? {
        if trimmed.range(of: #"\s+\d+\s*\("#, options: .regularExpression) != nil {
            return nil
        }
        let pattern = #"^(.+?)\s*\(([\s\S]*)\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let nameRange = Range(match.range(at: 1), in: trimmed),
              let innerRange = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }
        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let inner = String(trimmed[innerRange])
        let cashout = parseCashoutExpression(inner)
        return ParsedPlayer(name: name, buyin: 0, cashout: cashout)
    }
    
    /// Имя, байин и опционально кэшаут в скобках; пробелы перед скобками допускаются
    private func parsePlayer(_ line: String) -> ParsedPlayer? {
        let trimmed = normalizePlayerLine(line)
        guard !trimmed.isEmpty else { return nil }
        
        let pattern = #"\s+(\d+)\s*(?:\(([\s\S]*)\))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let fullRange = Range(match.range(at: 0), in: trimmed),
              let buyinRange = Range(match.range(at: 1), in: trimmed),
              let buyin = Int16(trimmed[buyinRange]) else {
            return parsePlayerCashoutOnly(trimmed)
        }
        
        let name = String(trimmed[..<fullRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        
        var cashout: Int64 = 0
        if match.numberOfRanges > 2, let innerRange = Range(match.range(at: 2), in: trimmed) {
            let inner = String(trimmed[innerRange])
            cashout = parseCashoutExpression(inner)
        }
        return ParsedPlayer(name: name, buyin: buyin, cashout: cashout)
    }
    
    /// Проверяет существующие игры по датам
    func checkExistingGames(_ parsedGames: [ParsedGame]) -> [Date: ExistingGameData] {
        var existingGames: [Date: ExistingGameData] = [:]
        let calendar = Calendar.current
        
        for parsedGame in parsedGames {
            let gameDate = calendar.startOfDay(for: parsedGame.date)
            
            // Ищем игру за этот день
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            let startOfDay = calendar.startOfDay(for: parsedGame.date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
            fetchRequest.fetchLimit = 1
            
            if let existingGame = try? viewContext.fetch(fetchRequest).first {
                // Собираем данные об игроках существующей игры
                let gameWithPlayers = existingGame.gameWithPlayers as? Set<GameWithPlayer> ?? []
                let playersData = gameWithPlayers.compactMap { gwp -> ExistingPlayerData? in
                    guard let player = gwp.player, let name = player.name else { return nil }
                    return ExistingPlayerData(name: name, buyin: gwp.buyin, cashout: gwp.cashout)
                }
                
                existingGames[gameDate] = ExistingGameData(game: existingGame, players: playersData)
            }
        }
        
        return existingGames
    }
    
    /// Извлекает уникальные имена игроков из массива игр
    func extractUniquePlayerNames(from parsedGames: [ParsedGame]) -> [String] {
        var playerNames = Set<String>()
        
        for game in parsedGames {
            for player in game.players {
                let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    playerNames.insert(name)
                }
            }
        }
        
        return playerNames.sorted()
    }
    
    /// Обновляет creatorUserId для всех игр текущего пользователя, у которых он не установлен
    func updateCreatorUserIdForAllGames() throws {
        guard let userId = self.userId else {
            debugLog("⚠️ No userId provided, skipping creatorUserId migration")
            return
        }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "creatorUserId == nil")
        
        let games = try viewContext.fetch(fetchRequest)
        
        for game in games {
            game.creatorUserId = userId
        }
        
        if !games.isEmpty {
            try viewContext.save()
            debugLog("✅ Updated creatorUserId for \(games.count) games")
        } else {
            debugLog("✅ No games need creatorUserId migration")
        }
    }
    
    /// Импортирует игры в CoreData, заменяя существующие если нужно.
    /// - Parameter placeId: id места проведения (опционально); проставляется всем играм в пачке.
    /// - Parameter replaceExistingForDate: если задано, для каждой даты решает, заменять ли существующую игру (перекрывает `replaceExisting`).
    func importGames(
        _ parsedGames: [ParsedGame],
        selectedPlayerNames: Set<String>,
        placeId: UUID? = nil,
        replaceExisting: Bool = false,
        replaceExistingForDate: ((Date) -> Bool)? = nil
    ) throws {
        guard !parsedGames.isEmpty else {
            throw ImportError.noGamesFound
        }

        let calendar = Calendar.current
        let place: Place? = placeId.flatMap { persistence.fetchPlace(byId: $0, context: viewContext) }
        
        for parsedGame in parsedGames {
            guard !parsedGame.players.isEmpty else {
                continue // Пропускаем игры без игроков
            }
            
            let gameDate = calendar.startOfDay(for: parsedGame.date)
            
            // Проверяем, есть ли уже игра за этот день
            let startOfDay = calendar.startOfDay(for: parsedGame.date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
            fetchRequest.fetchLimit = 1
            
            let existingGames = try viewContext.fetch(fetchRequest)
            let game: Game
            
            let mustReplace = replaceExistingForDate?(parsedGame.date) ?? replaceExisting
            
            if let existingGame = existingGames.first {
                if mustReplace {
                    // Удаляем старые связи GameWithPlayer
                    if let gameWithPlayers = existingGame.gameWithPlayers as? Set<GameWithPlayer> {
                        for gwp in gameWithPlayers {
                            viewContext.delete(gwp)
                        }
                    }
                    game = existingGame
                    game.timestamp = parsedGame.date
                    game.gameType = "Покер"
                    // Убеждаемся, что обязательные поля установлены
                    let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
                    if let zeroUUID = zeroUUID, game.gameId == zeroUUID {
                        game.gameId = UUID()
                    }
                    game.softDeleted = false
                } else {
                    // Обновляем creatorUserId если он не установлен (без промежуточного save — один save в конце)
                    if existingGame.creatorUserId == nil {
                        existingGame.creatorUserId = userId
                        if let uid = userId, let creator = persistence.fetchUser(byId: uid) {
                            existingGame.creator = creator
                        }
                    }
                    // Пропускаем, если не заменяем
                    continue
                }
            } else {
                // Создаем новую игру
                game = Game(context: viewContext)
                game.gameId = UUID()
                game.timestamp = parsedGame.date
                game.gameType = "Покер"
                game.softDeleted = false
            }
            
            // Устанавливаем creatorUserId для всех импортированных игр
            game.creatorUserId = userId
            if let userId = userId, let creator = persistence.fetchUser(byId: userId) {
                game.creator = creator
            }

            // Привязка места (если указано — перекрываем при replace; иначе только если место не задано)
            if let place {
                if mustReplace || game.place == nil {
                    game.placeId = place.placeId
                    game.place = place
                }
            }
            
            // Создаем или находим игроков и связываем их с игрой
            for parsedPlayer in parsedGame.players {
                guard !parsedPlayer.name.isEmpty else {
                    continue // Пропускаем игроков без имени
                }
                
                // Ищем существующего игрока по имени (старая модель)
                let playerFetchRequest: NSFetchRequest<Player> = Player.fetchRequest()
                playerFetchRequest.predicate = NSPredicate(format: "name == %@", parsedPlayer.name)
                playerFetchRequest.fetchLimit = 1
                
                let existingPlayers = try viewContext.fetch(playerFetchRequest)
                let player: Player
                
                if let existingPlayer = existingPlayers.first {
                    player = existingPlayer
                } else {
                    // Создаем нового игрока
                    player = Player(context: viewContext)
                    player.name = parsedPlayer.name
                }
                
                // Ищем PlayerAlias для связи с PlayerProfile (новая модель)
                var playerProfile: PlayerProfile? = nil
                if let alias = persistence.fetchAlias(byName: parsedPlayer.name) {
                    playerProfile = alias.profile
                } else if let userId = userId {
                    // Если имя игрока совпадает с любым из выбранных имен пользователя, используем его профиль
                    if selectedPlayerNames.contains(parsedPlayer.name) {
                        playerProfile = persistence.fetchPlayerProfile(byUserId: userId)
                    }
                }
                
                // Создаем связь GameWithPlayer
                let gameWithPlayer = GameWithPlayer(context: viewContext)
                gameWithPlayer.game = game
                gameWithPlayer.player = player // Старая модель для обратной совместимости
                gameWithPlayer.playerProfile = playerProfile // Новая модель для фильтрации
                gameWithPlayer.buyin = parsedPlayer.buyin
                gameWithPlayer.cashout = parsedPlayer.cashout
            }
        }
        
        try viewContext.save()

        // Phase 2: Обновить materialized views в фоне
        if let userId = userId {
            Task {
                do {
                    try await MaterializedViewsService.shared.updateUserStatisticsSummary(userId: userId)
                    for parsedGame in parsedGames {
                        // Находим созданную игру по дате для обновления GameSummary
                        let gameDate = calendar.startOfDay(for: parsedGame.date)
                        let startOfDay = calendar.startOfDay(for: parsedGame.date)
                        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                        let fr: NSFetchRequest<Game> = Game.fetchRequest()
                        fr.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
                        fr.fetchLimit = 1
                        if let game = try? viewContext.fetch(fr).first {
                            try? await MaterializedViewsService.shared.updateGameSummary(gameId: game.gameId)
                        }
                    }
                } catch {
                    debugLog("⚠️ [MaterializedViews] Failed to update: \(error)")
                }
            }
        }
    }

    enum ImportError: LocalizedError {
        case noGamesFound
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .noGamesFound:
                return "Не найдено игр для импорта"
            case .invalidData:
                return "Неверный формат данных"
            }
        }
    }
}


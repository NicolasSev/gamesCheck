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
    private let currentUserName: String = "Ник" // Имя пользователя, заменяет "Я"
    
    init(viewContext: NSManagedObjectContext, userId: UUID? = nil) {
        self.viewContext = viewContext
        self.userId = userId
        self.persistence = PersistenceController.shared
    }
    
    /// Парсит текст и возвращает массив игр
    func parseText(_ text: String) -> [ParsedGame] {
        var games: [ParsedGame] = []
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var currentDate: Date?
        var currentPlayers: [ParsedPlayer] = []
        
        for line in lines {
            // Проверяем, является ли строка датой (формат DD.MM.YYYY)
            if let date = parseDate(line) {
                // Сохраняем предыдущую игру, если есть
                if let date = currentDate, !currentPlayers.isEmpty {
                    games.append(ParsedGame(date: date, players: currentPlayers))
                }
                // Начинаем новую игру
                currentDate = date
                currentPlayers = []
            } else {
                // Парсим игрока
                if let player = parsePlayer(line) {
                    currentPlayers.append(player)
                }
            }
        }
        
        // Добавляем последнюю игру
        if let date = currentDate, !currentPlayers.isEmpty {
            games.append(ParsedGame(date: date, players: currentPlayers))
        }
        
        return games
    }
    
    /// Парсит дату в формате DD.MM.YYYY
    private func parseDate(_ line: String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Проверяем формат DD.MM.YYYY
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
        
        // Создаем дату с указанным годом
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        
        guard let date = calendar.date(from: components) else { return nil }
        
        return date
    }
    
    /// Парсит строку игрока в формате "Имя Количество(Кэшаут)" или "Имя Количество"
    private func parsePlayer(_ line: String) -> ParsedPlayer? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Паттерн: Имя (опционально с пробелами) Число (опционально (Число))
        // Примеры: "Антон С 3(8,000)", "Коля 8(4,000)", "Антон 10", "Вова 5(40,000)"
        let pattern = #"^(.+?)\s+(\d+)(?:\(([\d,]+)\))?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }
        
        guard let nameRange = Range(match.range(at: 1), in: trimmed),
              let buyinRange = Range(match.range(at: 2), in: trimmed),
              let buyin = Int16(trimmed[buyinRange]) else {
            return nil
        }
        
        var name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Заменяем "Я" на имя пользователя
        if name == "Я" {
            name = currentUserName
        }
        
        var cashout: Int64 = 0
        if match.numberOfRanges > 3, let cashoutRange = Range(match.range(at: 3), in: trimmed) {
            let cashoutString = String(trimmed[cashoutRange]).replacingOccurrences(of: ",", with: "")
            cashout = Int64(cashoutString) ?? 0
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
    
    /// Обновляет creatorUserId для всех игр текущего пользователя, у которых он не установлен
    func updateCreatorUserIdForAllGames() throws {
        guard let userId = self.userId else {
            throw ImportError.invalidFormat
        }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "creatorUserId == nil")
        
        let games = try viewContext.fetch(fetchRequest)
        
        for game in games {
            game.creatorUserId = userId
        }
        
        try viewContext.save()
        
        print("✅ Updated creatorUserId for \(games.count) games")
    }
    
    /// Импортирует игры в CoreData, заменяя существующие если нужно
    func importGames(_ parsedGames: [ParsedGame], replaceExisting: Bool = false) throws {
        guard !parsedGames.isEmpty else {
            throw ImportError.noGamesFound
        }
        
        let calendar = Calendar.current
        
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
            
            if let existingGame = existingGames.first {
                if replaceExisting {
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
                    // Обновляем creatorUserId если он не установлен
                    if existingGame.creatorUserId == nil {
                        existingGame.creatorUserId = userId
                        try viewContext.save()
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
                    // Если это текущий пользователь ("Я" заменяется на currentUserName)
                    // или имя совпадает с именем пользователя, используем его профиль
                    if parsedPlayer.name == currentUserName || parsedPlayer.name == "Я" {
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


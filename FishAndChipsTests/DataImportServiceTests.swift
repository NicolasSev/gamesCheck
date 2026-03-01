//
//  DataImportServiceTests.swift
//  FishAndChipsTests
//
//  Unit tests for DataImportService parseText and extractUniquePlayerNames
//

import Foundation
import CoreData
import Testing
@testable import FishAndChips

struct DataImportServiceTests {

    private func makeService() -> DataImportService {
        let persistence = PersistenceController(inMemory: true)
        return DataImportService(viewContext: persistence.container.viewContext, userId: nil)
    }

    // MARK: - parseText

    @Test func parseText_validPokerGameInput_returnsParsedGames() async throws {
        let service = makeService()

        let input = """
        25.11.2024
        Антон С 3(8,000)
        Коля 8(4,000)
        Антон 10
        Вова 5(40,000)
        Я 10(22,000)
        """

        let games = service.parseText(input)

        #expect(games.count == 1)
        #expect(games[0].players.count == 5)

        let names = games[0].players.map(\.name)
        #expect(names == ["Антон С", "Коля", "Антон", "Вова", "Я"])

        #expect(games[0].players[0].buyin == 3)
        #expect(games[0].players[0].cashout == 8000)
        #expect(games[0].players[1].buyin == 8)
        #expect(games[0].players[1].cashout == 4000)
        #expect(games[0].players[2].buyin == 10)
        #expect(games[0].players[2].cashout == 0)
        #expect(games[0].players[3].buyin == 5)
        #expect(games[0].players[3].cashout == 40000)
        #expect(games[0].players[4].buyin == 10)
        #expect(games[0].players[4].cashout == 22000)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: games[0].date)
        #expect(components.day == 25)
        #expect(components.month == 11)
        #expect(components.year == 2024)
    }

    @Test func parseText_multipleGames_returnsAllGames() async throws {
        let service = makeService()

        let input = """
        01.12.2024
        Alice 5(10,000)
        Bob 10

        02.12.2024
        Alice 8(15,000)
        Charlie 3(5,000)
        """

        let games = service.parseText(input)

        #expect(games.count == 2)
        #expect(games[0].players.count == 2)
        #expect(games[1].players.count == 2)

        #expect(games[0].players[0].name == "Alice")
        #expect(games[0].players[1].name == "Bob")
        #expect(games[1].players[0].name == "Alice")
        #expect(games[1].players[1].name == "Charlie")
    }

    @Test func parseText_emptyString_returnsEmptyArray() async throws {
        let service = makeService()

        let games = service.parseText("")

        #expect(games.isEmpty)
    }

    @Test func parseText_whitespaceOnly_returnsEmptyArray() async throws {
        let service = makeService()

        let games = service.parseText("   \n\n  \t  ")

        #expect(games.isEmpty)
    }

    @Test func parseText_malformedInput_handlesGracefully() async throws {
        let service = makeService()

        // No valid date — should return empty (no game can be started)
        let noDate = """
        invalid line
        garbage
        """
        let gamesNoDate = service.parseText(noDate)
        #expect(gamesNoDate.isEmpty)

        // Date with only invalid player lines — game started but no players, so not appended
        let dateOnlyInvalidPlayers = """
        25.11.2024
        not a valid player
        missing number
        """
        let gamesInvalidPlayers = service.parseText(dateOnlyInvalidPlayers)
        #expect(gamesInvalidPlayers.isEmpty)

        // Date with mix of valid and invalid — valid players parsed, invalid skipped
        let mixedInput = """
        25.11.2024
        Valid 10(5,000)
        invalid line
        Another 5
        """
        let gamesMixed = service.parseText(mixedInput)
        #expect(gamesMixed.count == 1)
        #expect(gamesMixed[0].players.count == 2)
        #expect(gamesMixed[0].players[0].name == "Valid")
        #expect(gamesMixed[0].players[1].name == "Another")
    }

    // MARK: - extractUniquePlayerNames

    @Test func extractUniquePlayerNames_returnsSortedUniqueNames() async throws {
        let service = makeService()

        let games = [
            ParsedGame(
                date: Date(),
                players: [
                    ParsedPlayer(name: "Charlie", buyin: 5, cashout: 0),
                    ParsedPlayer(name: "Alice", buyin: 10, cashout: 0),
                    ParsedPlayer(name: "Bob", buyin: 3, cashout: 0)
                ]
            )
        ]

        let names = service.extractUniquePlayerNames(from: games)

        #expect(names == ["Alice", "Bob", "Charlie"])
    }

    @Test func extractUniquePlayerNames_duplicateNames_deduplicates() async throws {
        let service = makeService()

        let games = [
            ParsedGame(
                date: Date(),
                players: [
                    ParsedPlayer(name: "Alice", buyin: 5, cashout: 0),
                    ParsedPlayer(name: "Bob", buyin: 10, cashout: 0),
                    ParsedPlayer(name: "Alice", buyin: 8, cashout: 0),
                    ParsedPlayer(name: "Alice", buyin: 3, cashout: 0)
                ]
            )
        ]

        let names = service.extractUniquePlayerNames(from: games)

        #expect(names == ["Alice", "Bob"])
    }

    @Test func extractUniquePlayerNames_multipleGames_deduplicatesAcrossGames() async throws {
        let service = makeService()

        let baseDate = Date()
        let games = [
            ParsedGame(
                date: baseDate,
                players: [
                    ParsedPlayer(name: "Alice", buyin: 5, cashout: 0),
                    ParsedPlayer(name: "Bob", buyin: 10, cashout: 0)
                ]
            ),
            ParsedGame(
                date: baseDate.addingTimeInterval(86400),
                players: [
                    ParsedPlayer(name: "Bob", buyin: 8, cashout: 0),
                    ParsedPlayer(name: "Charlie", buyin: 3, cashout: 0)
                ]
            )
        ]

        let names = service.extractUniquePlayerNames(from: games)

        #expect(names == ["Alice", "Bob", "Charlie"])
    }

    @Test func extractUniquePlayerNames_emptyGames_returnsEmptyArray() async throws {
        let service = makeService()

        let names = service.extractUniquePlayerNames(from: [])

        #expect(names.isEmpty)
    }

    @Test func extractUniquePlayerNames_gamesWithEmptyPlayerNames_ignoresEmpty() async throws {
        let service = makeService()

        let games = [
            ParsedGame(
                date: Date(),
                players: [
                    ParsedPlayer(name: "Alice", buyin: 5, cashout: 0),
                    ParsedPlayer(name: "  ", buyin: 10, cashout: 0),
                    ParsedPlayer(name: "Bob", buyin: 3, cashout: 0)
                ]
            )
        ]

        let names = service.extractUniquePlayerNames(from: games)

        #expect(names == ["Alice", "Bob"])
    }
}

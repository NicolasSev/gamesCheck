//
//  DeepLinkParsingTests.swift
//  FishAndChipsTests
//
//  Unit tests for DeepLink.parse(from:) static method
//

import Foundation
import Testing
@testable import FishAndChips

struct DeepLinkParsingTests {

    // MARK: - Valid game URL

    @Test func parse_validGameURL_fishandchipsScheme_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "fishandchips://game/\(gameId.uuidString)")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    @Test func parse_validGameURL_pokertrackerScheme_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "pokertracker://game/\(gameId.uuidString)")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    @Test func parse_validGameURL_uppercaseUUID_returnsGame() {
        let uuidString = "550E8400-E29B-41D4-A716-446655440000"
        let url = URL(string: "fishandchips://game/\(uuidString)")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(UUID(uuidString: uuidString)!))
    }

    @Test func parse_validGameURL_lowercaseUUID_returnsGame() {
        let uuidString = "550e8400-e29b-41d4-a716-446655440000"
        let url = URL(string: "fishandchips://game/\(uuidString)")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(UUID(uuidString: uuidString)!))
    }

    @Test func parse_validGameURL_trailingSlash_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "fishandchips://game/\(gameId.uuidString)/")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    // MARK: - Invalid URL (no host)

    @Test func parse_noHost_returnsNone() {
        // fishandchips:// without host
        let url = URL(string: "fishandchips://")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_emptyHost_returnsNone() {
        let url = URL(string: "fishandchips:///")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    // MARK: - Invalid UUID in path

    @Test func parse_invalidUUID_returnsNone() {
        let url = URL(string: "fishandchips://game/not-a-valid-uuid")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_emptyUUID_returnsNone() {
        let url = URL(string: "fishandchips://game/")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_partialUUID_returnsNone() {
        let url = URL(string: "fishandchips://game/550e8400-e29b")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_garbageInPath_returnsNone() {
        let url = URL(string: "fishandchips://game/12345")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    // MARK: - Unknown host/path

    @Test func parse_unknownHost_returnsNone() {
        let url = URL(string: "fishandchips://unknown/550e8400-e29b-41d4-a716-446655440000")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_unknownPath_returnsNone() {
        let url = URL(string: "fishandchips://game/some/other/path")!
        // pathComponents.first = "some" which is not a valid UUID
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_httpsURL_withGamePath_returnsNone() {
        // Standard https URLs don't use host "game" - host would be domain
        let url = URL(string: "https://example.com/game/550e8400-e29b-41d4-a716-446655440000")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    // MARK: - Various URL formats

    @Test func parse_customScheme_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "myapp://game/\(gameId.uuidString)")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    @Test func parse_uuidWithExtraPathComponents_usesFirstComponent() {
        let gameId = UUID()
        let url = URL(string: "fishandchips://game/\(gameId.uuidString)/extra/path")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    @Test func parse_uuidWithQueryString_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "fishandchips://game/\(gameId.uuidString)?source=share")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    @Test func parse_uuidWithFragment_returnsGame() {
        let gameId = UUID()
        let url = URL(string: "fishandchips://game/\(gameId.uuidString)#section")!
        let result = DeepLink.parse(from: url)
        #expect(result == .game(gameId))
    }

    // MARK: - DeepLink enum cases coverage

    @Test func parse_noneCase_equatable() {
        let url = URL(string: "fishandchips://invalid")!
        let result = DeepLink.parse(from: url)
        #expect(result == .none)
    }

    @Test func parse_gameCase_extractsCorrectUUID() {
        let gameId = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let url = URL(string: "fishandchips://game/12345678-1234-1234-1234-123456789012")!
        let result = DeepLink.parse(from: url)
        if case .game(let id) = result {
            #expect(id == gameId)
        } else {
            Issue.record("Expected .game case, got \(result)")
        }
    }
}

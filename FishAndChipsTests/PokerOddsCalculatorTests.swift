//
//  PokerOddsCalculatorTests.swift
//  PokerCardRecognizerTests
//
//  Tests for Poker Odds Calculator
//

import XCTest
@testable import FishAndChips

final class PokerOddsCalculatorTests: XCTestCase {
    
    // MARK: - Card Parsing Tests
    
    func testCardParsing() throws {
        // Тестируем парсинг различных карт
        let aceHearts = try Card(notation: "Ah")
        XCTAssertEqual(aceHearts.rank, .ace)
        XCTAssertEqual(aceHearts.suit, .hearts)
        
        let tenSpades = try Card(notation: "Ts")
        XCTAssertEqual(tenSpades.rank, .ten)
        XCTAssertEqual(tenSpades.suit, .spades)
        
        let twoClubs = try Card(notation: "2c")
        XCTAssertEqual(twoClubs.rank, .two)
        XCTAssertEqual(twoClubs.suit, .clubs)
    }
    
    func testPlayerHandParsing() throws {
        let hand = try PlayerHand(notation: "AhKs")
        XCTAssertEqual(hand.cards.count, 2)
        XCTAssertEqual(hand.cards[0].rank, .ace)
        XCTAssertEqual(hand.cards[0].suit, .hearts)
        XCTAssertEqual(hand.cards[1].rank, .king)
        XCTAssertEqual(hand.cards[1].suit, .spades)
    }
    
    func testBoardParsing() throws {
        let board = try Board(notation: "7d9dTs")
        XCTAssertNotNil(board)
        XCTAssertEqual(board?.cards.count, 3)
    }
    
    // MARK: - Hand Evaluation Tests
    
    func testRoyalFlush() throws {
        let cards = try [
            Card(notation: "Ah"),
            Card(notation: "Kh"),
            Card(notation: "Qh"),
            Card(notation: "Jh"),
            Card(notation: "Th")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .royalFlush)
    }
    
    func testStraightFlush() throws {
        let cards = try [
            Card(notation: "9h"),
            Card(notation: "8h"),
            Card(notation: "7h"),
            Card(notation: "6h"),
            Card(notation: "5h")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .straightFlush)
    }
    
    func testFourOfAKind() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Ah"),
            Card(notation: "Ad"),
            Card(notation: "Ac"),
            Card(notation: "Kh")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .fourOfAKind)
    }
    
    func testFullHouse() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Ah"),
            Card(notation: "Ad"),
            Card(notation: "Kc"),
            Card(notation: "Kh")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .fullHouse)
    }
    
    func testFlush() throws {
        let cards = try [
            Card(notation: "Ah"),
            Card(notation: "Kh"),
            Card(notation: "9h"),
            Card(notation: "6h"),
            Card(notation: "2h")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .flush)
    }
    
    func testStraight() throws {
        let cards = try [
            Card(notation: "9h"),
            Card(notation: "8s"),
            Card(notation: "7d"),
            Card(notation: "6c"),
            Card(notation: "5h")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .straight)
    }
    
    func testWheel() throws {
        // A-2-3-4-5 (wheel)
        let cards = try [
            Card(notation: "Ah"),
            Card(notation: "2s"),
            Card(notation: "3d"),
            Card(notation: "4c"),
            Card(notation: "5h")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .straight)
    }
    
    func testThreeOfAKind() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Ah"),
            Card(notation: "Ad"),
            Card(notation: "Kc"),
            Card(notation: "Qh")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .threeOfAKind)
    }
    
    func testTwoPair() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Ah"),
            Card(notation: "Kd"),
            Card(notation: "Kc"),
            Card(notation: "Qh")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .twoPair)
    }
    
    func testOnePair() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Ah"),
            Card(notation: "Kd"),
            Card(notation: "Qc"),
            Card(notation: "Jh")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .onePair)
    }
    
    func testHighCard() throws {
        let cards = try [
            Card(notation: "As"),
            Card(notation: "Kh"),
            Card(notation: "Qd"),
            Card(notation: "Jc"),
            Card(notation: "9h")
        ]
        
        let evaluated = HandEvaluator.evaluate(cards: cards)
        XCTAssertEqual(evaluated.rankType, .highCard)
    }
    
    // MARK: - Deck Generator Tests
    
    func testFullDeckTexasHoldem() {
        let deck = DeckGenerator.createFullDeck(variant: .texasHoldem)
        XCTAssertEqual(deck.count, 52)
    }
    
    func testFullDeckShortDeck() {
        let deck = DeckGenerator.createFullDeck(variant: .shortDeck)
        XCTAssertEqual(deck.count, 36) // 9 ranks * 4 suits = 36
        
        // Проверяем, что нет карт 2-5
        for card in deck {
            XCTAssertTrue(card.rank.value >= 6 || card.rank == .ace)
        }
    }
    
    func testDeckWithExclusions() throws {
        let excluded = try [
            Card(notation: "Ah"),
            Card(notation: "Kh")
        ]
        
        let deck = DeckGenerator.createDeck(excluding: excluded, variant: .texasHoldem)
        XCTAssertEqual(deck.count, 50)
        
        // Проверяем, что исключенные карты отсутствуют
        for card in deck {
            XCTAssertFalse(excluded.contains(card))
        }
    }
    
    func testDuplicateDetection() throws {
        let cards = try [
            Card(notation: "Ah"),
            Card(notation: "Kh"),
            Card(notation: "Ah") // Дубликат
        ]
        
        let duplicates = DeckGenerator.findDuplicates(in: cards)
        XCTAssertEqual(duplicates.count, 1)
    }
    
    // MARK: - Odds Calculation Tests (Pre-Flop)
    
    func testAAvsKKPreFlop() throws {
        // AA vs KK - классический сценарий
        let result = try PokerOddsCalculator.calculate(
            players: ["AhAs", "KdKc"],
            board: nil,
            gameVariant: .texasHoldem,
            iterations: 5000
        )
        
        XCTAssertEqual(result.equities.count, 2)
        
        // AA должен выигрывать примерно в 82% случаев
        let aaEquity = result.equities[0].equity
        XCTAssertGreaterThan(aaEquity, 78.0)
        XCTAssertLessThan(aaEquity, 86.0)
        
        // KK должен выигрывать примерно в 18% случаев
        let kkEquity = result.equities[1].equity
        XCTAssertGreaterThan(kkEquity, 14.0)
        XCTAssertLessThan(kkEquity, 22.0)
    }
    
    func testAKvsQQPreFlop() throws {
        // AK vs QQ - популярный сценарий
        let result = try PokerOddsCalculator.calculate(
            players: ["AhKh", "QcQd"],
            board: nil,
            gameVariant: .texasHoldem,
            iterations: 5000
        )
        
        XCTAssertEqual(result.equities.count, 2)
        
        // QQ должно быть фаворитом
        let qqEquity = result.equities[1].equity
        XCTAssertGreaterThan(qqEquity, 50.0)
    }
    
    func testThreePlayersPreFlop() throws {
        let result = try PokerOddsCalculator.calculate(
            players: ["AhAs", "KdKc", "QsQh"],
            board: nil,
            gameVariant: .texasHoldem,
            iterations: 3000
        )
        
        XCTAssertEqual(result.equities.count, 3)
        
        // AA должно быть лучшей рукой
        let aaEquity = result.equities[0].equity
        XCTAssertGreaterThan(aaEquity, result.equities[1].equity)
        XCTAssertGreaterThan(aaEquity, result.equities[2].equity)
    }
    
    // MARK: - Odds Calculation Tests (Post-Flop)
    
    func testPostFlopWithFlush() throws {
        // У игрока 1 готовый флеш, у игрока 2 - сет
        let result = try PokerOddsCalculator.calculate(
            players: ["AhKh", "9s9c"],
            board: "2h5h9h", // Флеш на борде
            gameVariant: .texasHoldem,
            iterations: 3000
        )
        
        XCTAssertEqual(result.equities.count, 2)
        
        // AhKh (флеш) должен быть огромным фаворитом
        let flushEquity = result.equities[0].equity
        XCTAssertGreaterThan(flushEquity, 85.0)
    }
    
    func testPostFlopFlushDraw() throws {
        // У игрока 1 флеш дро, у игрока 2 - пара
        let result = try PokerOddsCalculator.calculate(
            players: ["AhKh", "QcQd"],
            board: "2h5h9c", // Флеш дро
            gameVariant: .texasHoldem,
            iterations: 3000
        )
        
        XCTAssertEqual(result.equities.count, 2)
        
        // QQ должно быть фаворитом, но не огромным
        let pairEquity = result.equities[1].equity
        XCTAssertGreaterThan(pairEquity, 55.0)
        XCTAssertLessThan(pairEquity, 75.0)
    }
    
    // MARK: - Validation Tests
    
    func testInsufficientPlayers() {
        XCTAssertThrowsError(try PokerOddsCalculator.calculate(
            players: ["AhAs"],
            board: nil
        )) { error in
            XCTAssertTrue(error is PokerOddsError)
        }
    }
    
    func testDuplicateCards() {
        XCTAssertThrowsError(try PokerOddsCalculator.calculate(
            players: ["AhAs", "AsKd"], // As дублируется
            board: nil
        )) { error in
            XCTAssertTrue(error is PokerOddsError)
        }
    }
    
    func testInvalidBoard() {
        XCTAssertThrowsError(try PokerOddsCalculator.calculate(
            players: ["AhAs", "KdKc"],
            board: "2h3h4h5h6h7h" // Слишком много карт
        )) { error in
            XCTAssertTrue(error is PokerOddsError)
        }
    }
    
    func testShortDeckInvalidCard() {
        XCTAssertThrowsError(try PokerOddsCalculator.calculate(
            players: ["AhAs", "2d2c"], // 2 не валидна в Short Deck
            board: nil,
            gameVariant: .shortDeck
        )) { error in
            XCTAssertTrue(error is PokerOddsError)
        }
    }
    
    // MARK: - Short Deck Tests
    
    func testShortDeckAAvsKK() throws {
        let result = try PokerOddsCalculator.calculate(
            players: ["AhAs", "KdKc"],
            board: nil,
            gameVariant: .shortDeck,
            iterations: 3000
        )
        
        XCTAssertEqual(result.equities.count, 2)
        
        // AA все равно должно быть фаворитом
        let aaEquity = result.equities[0].equity
        XCTAssertGreaterThan(aaEquity, 70.0)
    }
    
    // MARK: - Performance Tests
    
    func testCalculationPerformance() throws {
        measure {
            _ = try? PokerOddsCalculator.calculate(
                players: ["AhAs", "KdKc"],
                board: nil,
                iterations: 10000
            )
        }
    }
    
    func testThreePlayerPerformance() throws {
        measure {
            _ = try? PokerOddsCalculator.calculate(
                players: ["AhAs", "KdKc", "QsQh"],
                board: nil,
                iterations: 10000
            )
        }
    }
}

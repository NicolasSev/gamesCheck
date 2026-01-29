//
//  DeckGenerator.swift
//  PokerCardRecognizer
//
//  Generates poker decks and manages card dealing
//

import Foundation

class DeckGenerator {
    
    /// Создает полную колоду (52 карты или 36 для Short Deck)
    /// - Parameter gameVariant: Вариант игры
    /// - Returns: Массив всех карт в колоде
    static func createFullDeck(variant: GameVariant = .texasHoldem) -> [Card] {
        var deck: [Card] = []
        
        for suit in CardSuit.allCases {
            for rank in CardRank.allCases {
                let card = Card(rank: rank, suit: suit, confidence: 1.0, rect: .zero)
                
                // Для Short Deck исключаем 2-5
                if variant.usesShortDeck {
                    if card.isValidForShortDeck {
                        deck.append(card)
                    }
                } else {
                    deck.append(card)
                }
            }
        }
        
        return deck
    }
    
    /// Создает колоду с исключением определенных карт
    /// - Parameters:
    ///   - excludedCards: Карты, которые нужно исключить (руки игроков + борд)
    ///   - variant: Вариант игры
    /// - Returns: Колода без исключенных карт
    static func createDeck(excluding excludedCards: [Card], variant: GameVariant = .texasHoldem) -> [Card] {
        let fullDeck = createFullDeck(variant: variant)
        let excludedSet = Set(excludedCards)
        return fullDeck.filter { !excludedSet.contains($0) }
    }
    
    /// Перемешивает колоду
    /// - Parameter deck: Колода для перемешивания
    /// - Returns: Перемешанная колода
    static func shuffle(_ deck: [Card]) -> [Card] {
        return deck.shuffled()
    }
    
    /// Берет N карт из колоды
    /// - Parameters:
    ///   - count: Количество карт
    ///   - deck: Колода
    /// - Returns: Массив взятых карт
    static func deal(count: Int, from deck: [Card]) -> [Card] {
        return Array(deck.prefix(count))
    }
    
    /// Проверяет наличие дубликатов в массиве карт
    /// - Parameter cards: Карты для проверки
    /// - Returns: Массив дублирующихся карт (пустой если дубликатов нет)
    static func findDuplicates(in cards: [Card]) -> [Card] {
        var seen = Set<Card>()
        var duplicates = Set<Card>()
        
        for card in cards {
            if seen.contains(card) {
                duplicates.insert(card)
            } else {
                seen.insert(card)
            }
        }
        
        return Array(duplicates)
    }
    
    /// Валидирует набор карт для игры
    /// - Parameters:
    ///   - playerHands: Руки игроков
    ///   - board: Карты борда
    ///   - variant: Вариант игры
    /// - Throws: PokerOddsError если есть проблемы
    static func validate(playerHands: [[Card]], board: [Card], variant: GameVariant) throws {
        // Проверяем количество игроков
        guard playerHands.count >= 2 else {
            throw PokerOddsError.insufficientPlayers
        }
        
        // Проверяем размер рук
        for hand in playerHands {
            guard hand.count == 2 else {
                throw PokerOddsError.invalidHandSize(hand.count)
            }
        }
        
        // Проверяем размер борда
        guard board.count <= 5 else {
            throw PokerOddsError.invalidBoard
        }
        
        // Собираем все карты
        var allCards: [Card] = []
        for hand in playerHands {
            allCards.append(contentsOf: hand)
        }
        allCards.append(contentsOf: board)
        
        // Проверяем дубликаты
        let duplicates = findDuplicates(in: allCards)
        if !duplicates.isEmpty {
            throw PokerOddsError.duplicateCards(duplicates.map { $0.shortNotation })
        }
        
        // Для Short Deck проверяем валидность карт
        if variant.usesShortDeck {
            for card in allCards {
                if !card.isValidForShortDeck {
                    throw PokerOddsError.shortDeckInvalidCard(card.shortNotation)
                }
            }
        }
    }
}

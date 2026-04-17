//
//  GameResultInfo.swift
//  PokerCardRecognizer
//
//  Created by Николас on 07.04.2025.
//
import SwiftUI
import CoreData

struct GameResultInfo {
    let shortDate: String
    let summaryLine: String

    init(game: Game) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        self.shortDate = formatter.string(from: game.timestamp ?? Date())

        let buyin = game.totalBuyins
        self.summaryLine = "Байины: \(buyin), тип: \(game.gameType ?? "Покер")"
    }
}

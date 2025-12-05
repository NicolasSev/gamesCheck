//
//  GameResultInfo.swift
//  PokerCardRecognizer
//
//  Created by Николас on 07.04.2025.
//
import SwiftUI
import CoreData


struct GameResultInfo {
    let batches: [BilliardBatche]
    let resultText: String
    let shortDate: String

    init(game: Game) {
        self.batches = (game.billiardBatches as? Set<BilliardBatche>)?.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) } ?? []

        let player1Score = batches.reduce(0) {
            let baseScore = $0 + Int($1.scorePlayer1) * 100
            // Бонус 8-0 заменяет обычный бонус за 8, а не дополняет его
            let bonus: Int
            if Int($1.scorePlayer1) == 8 && Int($1.scorePlayer2) == 0 {
                bonus = 1000 // Бонус за 8-0
            } else if Int($1.scorePlayer1) == 8 {
                bonus = 1000 // Обычный бонус за 8
            } else {
                bonus = 0
            }
            return baseScore + bonus
        }

        let player2Score = batches.reduce(0) {
            let baseScore = $0 + Int($1.scorePlayer2) * 100
            // Бонус 8-0 заменяет обычный бонус за 8, а не дополняет его
            let bonus: Int
            if Int($1.scorePlayer2) == 8 && Int($1.scorePlayer1) == 0 {
                bonus = 1000 // Бонус за 8-0
            } else if Int($1.scorePlayer2) == 8 {
                bonus = 1000 // Обычный бонус за 8
            } else {
                bonus = 0
            }
            return baseScore + bonus
        }

        let diff = player1Score - player2Score
        if diff == 0 {
            self.resultText = "Ничья"
        } else if diff > 0 {
            self.resultText = "\(game.player1?.name ?? "Игрок 1") +\(diff)"
        } else {
            self.resultText = "\(game.player2?.name ?? "Игрок 2") +\(-diff)"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        self.shortDate = formatter.string(from: game.timestamp ?? Date())
    }
}

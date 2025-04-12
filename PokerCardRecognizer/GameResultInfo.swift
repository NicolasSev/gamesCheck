struct GameResultInfo {
    let batches: [BilliardBatche]
    let resultText: String
    let shortDate: String

    init(game: Game) {
        self.batches = (game.billiardBatches as? Set<BilliardBatche>)?.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) } ?? []

        let player1Score = batches.reduce(0) {
            $0 + Int($1.scorePlayer1) * 100 + (Int($1.scorePlayer1) == 8 ? 1000 : 0)
        }

        let player2Score = batches.reduce(0) {
            $0 + Int($1.scorePlayer2) * 100 + (Int($1.scorePlayer2) == 8 ? 1000 : 0)
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
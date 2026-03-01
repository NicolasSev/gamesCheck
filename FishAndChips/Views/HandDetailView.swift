//
//  HandDetailView.swift
//  FishAndChips
//

import SwiftUI

// Просмотр раздачи (открывается по клику)
struct HandDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    @State private var currentHand: HandModel
    
    init(hand: HandModel, game: Game) {
        self.game = game
        _currentHand = State(initialValue: hand)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Редактировать")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Борд
                    if !displayHand.boardCards.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Борд")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 10) {
                                ForEach(displayHand.boardCards, id: \.self) { cardNotation in
                                    HandDetailBoardCardView(notation: cardNotation)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Игроки")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(displayHand.players) { player in
                            PlayerHandRowView(player: player)
                        }
                    }
                    .padding(.horizontal)
                    
                    Text("Симуляций: \(displayHand.oddsResult.iterations), Время: \(String(format: "%.0f", displayHand.oddsResult.executionTime * 1000))ms")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Детали раздачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
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
        }
        .sheet(isPresented: $showingEditSheet) {
            HandEditView(hand: displayHand, game: game)
        }
        .onReceive(NotificationCenter.default.publisher(for: .handDidUpdate)) { _ in
            if let updated = HandsStorageService.shared.getAllHands().first(where: { $0.id == currentHand.id }) {
                currentHand = updated
            }
        }
    }
    
    private var displayHand: HandModel {
        let normalizedPlayers = currentHand.players.map { player in
            HandPlayerModel(
                id: player.id,
                name: player.name,
                card1: player.card1,
                card2: player.card2,
                equity: normalizeEquity(player.equity),
                wins: player.wins,
                ties: player.ties,
                losses: player.losses,
                preFlopEquity: player.preFlopEquity.map(normalizeEquity),
                flopEquity: player.flopEquity.map(normalizeEquity),
                turnEquity: player.turnEquity.map(normalizeEquity),
                riverEquity: player.riverEquity.map(normalizeEquity)
            )
        }
        
        return HandModel(
            id: currentHand.id,
            gameId: currentHand.gameId,
            creatorName: currentHand.creatorName,
            players: normalizedPlayers,
            boardCards: currentHand.boardCards,
            oddsResult: currentHand.oddsResult,
            timestamp: currentHand.timestamp
        )
    }
    
    private func normalizeEquity(_ value: Double) -> Double {
        return value > 100 ? value / 100 : value
    }
}

//
//  ClaimPlayerView.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import SwiftUI
import CoreData

struct ClaimPlayerView: View {
    let game: Game
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGameWithPlayer: GameWithPlayer?
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private let persistence = PersistenceController.shared
    private let claimService = PlayerClaimService()
    private let keychain = KeychainService.shared
    
    private var currentUserId: UUID? {
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }
    
    var gameWithPlayers: [GameWithPlayer] {
        let set = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        return set.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }
    
    private var isHost: Bool {
        guard let userId = currentUserId else { return false }
        return game.creatorUserId == userId
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isHost {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Вы создатель этой игры")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Нельзя подать заявку на свою игру")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Выберите игрока, которым вы были в этой игре")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                            
                            ForEach(gameWithPlayers, id: \.self) { gwp in
                                ClaimPlayerRow(
                                    gameWithPlayer: gwp,
                                    isClaimed: isAlreadyClaimed(gwp),
                                    onClaim: {
                                        selectedGameWithPlayer = gwp
                                        showingConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Подать заявку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Подать заявку?", isPresented: $showingConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Подать заявку") {
                    submitClaim()
                }
            } message: {
                if let gwp = selectedGameWithPlayer,
                   let playerName = gwp.player?.name {
                    Text("Вы хотите заявить, что вы были игроком \"\(playerName)\" в этой игре? Хост получит уведомление и сможет подтвердить заявку.")
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .background(
                Group {
                    if let image = UIImage(named: "casino-background") {
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
    }
    
    private func isAlreadyClaimed(_ gwp: GameWithPlayer) -> Bool {
        guard let userId = currentUserId else { return false }
        let myClaims = claimService.getMyClaims(userId: userId)
        let objectIdString = gwp.objectID.uriRepresentation().absoluteString
        return myClaims.contains { claim in
            claim.gameWithPlayerObjectId == objectIdString && claim.isPending
        }
    }
    
    private func submitClaim() {
        guard let gwp = selectedGameWithPlayer,
              let userId = currentUserId else {
            errorMessage = "Не удалось определить пользователя"
            showingError = true
            return
        }
        
        do {
            _ = try claimService.submitClaim(
                gameWithPlayer: gwp,
                claimantUserId: userId
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct ClaimPlayerRow: View {
    let gameWithPlayer: GameWithPlayer
    let isClaimed: Bool
    let onClaim: () -> Void
    
    private var playerName: String {
        gameWithPlayer.player?.name ?? "Без имени"
    }
    
    private var profit: Decimal {
        let buyin = Decimal(Int(gameWithPlayer.buyin))
        let cashout = Decimal(Int(gameWithPlayer.cashout))
        return cashout - (buyin * 2000)
    }
    
    private var formattedProfit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        return formatter.string(from: NSDecimalNumber(decimal: profit)) ?? "₸0"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(playerName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buy-in")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(gameWithPlayer.buyin)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cashout")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(gameWithPlayer.cashout)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Профит")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(formattedProfit)
                            .font(.subheadline)
                            .foregroundColor(profit >= 0 ? .green : .red)
                    }
                }
            }
            
            Spacer()
            
            if !isClaimed {
                Button(action: onClaim) {
                    Text("Подать заявку")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            } else {
                Text("Заявка подана")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}


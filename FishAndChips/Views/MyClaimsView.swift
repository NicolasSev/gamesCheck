//
//  MyClaimsView.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import SwiftUI
import CoreData

struct MyClaimsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var myClaims: [PlayerClaim] = []
    @State private var showingJoinGameSheet = false
    
    private let claimService = PlayerClaimService()
    private let keychain = KeychainService.shared
    
    private var currentUserId: UUID? {
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }
    
    var body: some View {
        NavigationView {
            Group {
                if myClaims.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Нет заявок")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Вы еще не подали ни одной заявки")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(myClaims, id: \.claimId) { claim in
                                MyClaimRow(claim: claim)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Мои заявки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingJoinGameSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link.badge.plus")
                            Text("Присоединиться")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingJoinGameSheet) {
                JoinGameByCodeSheet()
            }
            .onAppear {
                loadMyClaims()
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
    
    private func loadMyClaims() {
        guard let userId = currentUserId else { return }
        myClaims = claimService.getMyClaims(userId: userId)
    }
}

struct MyClaimRow: View {
    let claim: PlayerClaim
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: claim.createdAt)
    }
    
    private var statusColor: Color {
        switch claim.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch claim.status {
        case "pending": return "clock.fill"
        case "approved": return "checkmark.circle.fill"
        case "rejected": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(claim.playerName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        Text(claim.statusDisplayName)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                }
                
                if let game = claim.game {
                    Text("Игра: \(game.gameType ?? "Unknown")")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                if let notes = claim.notes, !notes.isEmpty {
                    Text("Комментарий: \(notes)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}


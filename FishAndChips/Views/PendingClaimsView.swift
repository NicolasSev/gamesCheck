//
//  PendingClaimsView.swift
//  PokerCardRecognizer
//
//  Created by Cursor Agent on 21.12.2025.
//

import SwiftUI
import CoreData

struct PendingClaimsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var pendingClaims: [PlayerClaim] = []
    @State private var selectedClaim: PlayerClaim?
    @State private var showingClaimDetail = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private let persistence = PersistenceController.shared
    private let claimService = PlayerClaimService()
    
    private var currentUserId: UUID? {
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }
    
    var body: some View {
        NavigationView {
            Group {
                if pendingClaims.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Нет ожидающих заявок")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Все заявки обработаны")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(pendingClaims, id: \.claimId) { claim in
                                PendingClaimRow(claim: claim) {
                                    selectedClaim = claim
                                    showingClaimDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Заявки на игроков")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadPendingClaims()
            }
            .sheet(item: $selectedClaim) { claim in
                ClaimDetailView(claim: claim) {
                    loadPendingClaims()
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
    
    private func loadPendingClaims() {
        guard let userId = currentUserId else { return }
        pendingClaims = claimService.getPendingClaimsForHost(hostUserId: userId)
    }
}

struct PendingClaimRow: View {
    let claim: PlayerClaim
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: claim.createdAt)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(claim.playerName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if let claimantUsername = claim.claimantUser?.username {
                        Text("Пользователь: \(claimantUsername)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let game = claim.game {
                        Text("Игра: \(game.gameType ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .liquidGlass(cornerRadius: 12)
        }
    }
}

struct ClaimDetailView: View {
    let claim: PlayerClaim
    let onResolved: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var notes: String = ""
    @State private var showingApproveConfirmation = false
    @State private var showingRejectConfirmation = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private let claimService = PlayerClaimService()
    
    private var currentUserId: UUID? {
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Информация о заявке
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Информация о заявке")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        InfoRow(label: "Игрок", value: claim.playerName)
                        
                        if let claimantUsername = claim.claimantUser?.username {
                            InfoRow(label: "Пользователь", value: claimantUsername)
                        }
                        
                        if let game = claim.game {
                            InfoRow(label: "Игра", value: game.gameType ?? "Unknown")
                            
                            if let timestamp = game.timestamp {
                                InfoRow(label: "Дата игры", value: formatDate(timestamp))
                            }
                        }
                        
                        InfoRow(label: "Дата заявки", value: formatDate(claim.createdAt))
                    }
                    .padding()
                    .liquidGlass(cornerRadius: 12)
                    
                    // Комментарий
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Комментарий (необязательно)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .liquidGlass(cornerRadius: 12)
                    
                    // Кнопки действий
                    HStack(spacing: 16) {
                        Button(action: {
                            showingRejectConfirmation = true
                        }) {
                            Text("Отклонить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingApproveConfirmation = true
                        }) {
                            Text("Одобрить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Детали заявки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Одобрить заявку?", isPresented: $showingApproveConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Одобрить") {
                    approveClaim()
                }
            } message: {
                Text("Пользователь получит доступ к статистике по этому игроку в этой игре.")
            }
            .alert("Отклонить заявку?", isPresented: $showingRejectConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Отклонить", role: .destructive) {
                    rejectClaim()
                }
            } message: {
                Text("Заявка будет отклонена. Пользователь получит уведомление.")
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
    
    private func approveClaim() {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось определить пользователя"
            showingError = true
            return
        }
        
        do {
            try claimService.approveClaim(
                claimId: claim.claimId,
                resolverUserId: userId,
                notes: notes.isEmpty ? nil : notes
            )
            onResolved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func rejectClaim() {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось определить пользователя"
            showingError = true
            return
        }
        
        do {
            try claimService.rejectClaim(
                claimId: claim.claimId,
                resolverUserId: userId,
                notes: notes.isEmpty ? nil : notes
            )
            onResolved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}


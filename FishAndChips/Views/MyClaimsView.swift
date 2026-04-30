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
        NavigationStack {
            Group {
                if myClaims.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Нет заявок")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Вы ещё не подали ни одной заявки")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(myClaims, id: \.claimId) { claim in
                                MyClaimRow(claim: claim, onReload: loadMyClaims)
                            }
                        }
                        .padding()
                    }
                }
            }
            .accessibilityIdentifier("my_claims_root")
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
            .v2ScreenBackground()
        }
    }
    
    private func loadMyClaims() {
        guard let userId = currentUserId else { return }
        myClaims = claimService.getMyClaims(userId: userId)
    }
}

struct MyClaimRow: View {
    let claim: PlayerClaim
    var onReload: () -> Void

    @State private var cancelError: String?
    @State private var cancelling = false

    private var placeLabel: String {
        guard let pid = claim.placeId,
              let name = PersistenceController.shared.fetchPlace(byId: pid)?.name else {
            return "Без места"
        }
        return name
    }

    private var bulkSubtitle: String? {
        guard claim.isBulk else { return nil }
        let n = claim.affectedGamePlayerIds.count
        if n <= 0 { return "@\(claim.hostUser?.username ?? "хост") · \(placeLabel)" }
        return "@\(claim.hostUser?.username ?? "хост") · \(placeLabel) · \(n) \(RussianPlural.pick(n, one: "игра", few: "игры", many: "игр"))"
    }

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
        case "blocked": return .red.opacity(0.9)
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch claim.status {
        case "pending": return "clock.fill"
        case "approved": return "checkmark.circle.fill"
        case "rejected": return "xmark.circle.fill"
        case "blocked": return "exclamationmark.octagon.fill"
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
                
                if let subtitle = bulkSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.82))
                } else if let game = claim.game {
                    Text("Игра: \(game.gameType ?? "Unknown")")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                if claim.status == "blocked", let br = claim.blockReason, !br.isEmpty {
                    Text("Причина: \(br)")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.85))
                }
                
                if let notes = claim.notes, !notes.isEmpty {
                    Text("Комментарий: \(notes)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }

                if claim.isBulk && claim.status == "pending" {
                    if cancelling {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 6)
                    } else {
                        Button("Отменить сводную заявку") {
                            Task { await cancelBulkTap() }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.top, 8)
                        .accessibilityIdentifier("my_claim_cancel_bulk")
                    }
                }
            }
        }
        .padding()
        .glassCardStyle(.plain)
        .alert(
            "Не удалось отменить",
            isPresented: Binding(
                get: { cancelError != nil },
                set: { if !$0 { cancelError = nil } }
            ),
            actions: { Button("OK") { cancelError = nil } },
            message: { Text(cancelError ?? "") }
        )
    }

    private func cancelBulkTap() async {
        await MainActor.run { cancelling = true }
        do {
            try await ClaimDiscoveryService.shared.cancelBulk(claimId: claim.claimId)
            try await SyncCoordinator.shared.fullResyncAfterClaim()
            await MainActor.run {
                cancelling = false
                onReload()
            }
        } catch {
            await MainActor.run {
                cancelling = false
                cancelError = error.localizedDescription
            }
        }
    }
}


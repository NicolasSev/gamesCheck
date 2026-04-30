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
    @Environment(\.dismiss) private var dismiss
    @State private var allClaims: [PlayerClaim] = []
    @State private var selectedClaim: PlayerClaim?
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
    
    private var pendingClaims: [PlayerClaim] {
        allClaims.filter { $0.status == "pending" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var blockedClaims: [PlayerClaim] {
        allClaims.filter { $0.status == "blocked" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var finalizedClaims: [PlayerClaim] {
        allClaims.filter { $0.status == "approved" || $0.status == "rejected" }
            .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if allClaims.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Нет заявок")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("У вас нет заявок на игроков")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Ожидающие заявки
                            if !pendingClaims.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ожидают (\(pendingClaims.count))")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal)
                                    
                                    ForEach(pendingClaims, id: \.claimId) { claim in
                                        PendingClaimRow(claim: claim) {
                                            selectedClaim = claim
                                        }
                                    }
                                }
                            }
                            
                            if !blockedClaims.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Заблокированы — требуют действия (\(blockedClaims.count))")
                                        .font(.headline)
                                        .foregroundColor(.red.opacity(0.95))
                                        .padding(.horizontal)
                                        .padding(.top, (pendingClaims.isEmpty ? 0 : 8))

                                    ForEach(blockedClaims, id: \.claimId) { claim in
                                        PendingClaimRow(claim: claim) {
                                            selectedClaim = claim
                                        }
                                    }
                                }
                            }

                            // Обработанные заявки
                            if !finalizedClaims.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Обработанные (\(finalizedClaims.count))")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal)
                                        .padding(.top, (pendingClaims.isEmpty && blockedClaims.isEmpty) ? 0 : 8)

                                    ForEach(finalizedClaims, id: \.claimId) { claim in
                                        ResolvedClaimRow(claim: claim)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .accessibilityIdentifier("pending_claims_root")
            .navigationTitle("Заявки на игроков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadAllClaims()
            }
            .sheet(item: $selectedClaim) { claim in
                ClaimDetailView(claim: claim) {
                    loadAllClaims()
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .v2ScreenBackground()
        }
    }
    
    private func loadAllClaims() {
        guard let userId = currentUserId else { return }
        allClaims = claimService.getAllClaimsForHost(hostUserId: userId)
    }
}

struct PendingClaimRow: View {
    let claim: PlayerClaim
    let onTap: () -> Void

    private var placeLabel: String {
        guard let pid = claim.placeId,
              let name = PersistenceController.shared.fetchPlace(byId: pid)?.name else {
            return "Без места"
        }
        return name
    }

    private var bulkGamesLine: String? {
        guard claim.isBulk else { return nil }
        let n = claim.affectedGamePlayerIds.count
        if n <= 0 { return "Сводная заявка по имени" }
        return "\(n) \(RussianPlural.pick(n, one: "игра", few: "игры", many: "игр")) в сводной заявке"
    }
    
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
                    
                    if claim.isBulk {
                        Text(bulkGamesLine ?? "Сводная заявка")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                        Text("Место: \(placeLabel)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
                    } else if let game = claim.game {
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
            .glassCardStyle(.plain)
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
    @State private var showMergeRequestSheet = false
    @State private var conflictHandles: [String] = []

    private let claimService = PlayerClaimService()
    private let keychain = KeychainService.shared
    
    private var currentUserId: UUID? {
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        return userId
    }

    private static let mergeReadyReason = "merge_resolved_pending_host_approval"

    private var blockedAwaitingMerge: Bool {
        claim.isBlocked && claim.blockReason != Self.mergeReadyReason
    }

    private var blockedReadyToApprove: Bool {
        claim.isBlocked && claim.blockReason == Self.mergeReadyReason
    }

    private var bulkPlaceDisplay: String {
        guard let pid = claim.placeId,
              let name = PersistenceController.shared.fetchPlace(byId: pid)?.name else {
            return "Без места"
        }
        return name
    }

    private var bulkGamesNote: String? {
        guard claim.isBulk else { return nil }
        let n = claim.affectedGamePlayerIds.count
        if n <= 0 { return nil }
        return "\(n) \(RussianPlural.pick(n, one: "игра", few: "игры", many: "игр"))"
    }

    private var blockedConflictExplanation: String {
        let base =
            "Имя «\(claim.playerName)» уже связано с другими учётными записями. Пока админ не выполнит merge имён, одобрение невозможно."
        if conflictHandles.isEmpty {
            return base
        }
        let handles = conflictHandles.map { "@\($0)" }.joined(separator: ", ")
        return base + " Связано с: \(handles)."
    }

    @ViewBuilder
    private var blockedOrNormalActionsCard: some View {
        if blockedReadyToApprove {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Админ объединил имена. Подтвердите заявку, чтобы связать статистику с профилем заявителя."
                )
                .font(.subheadline)
                .foregroundColor(Color.green.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button(action: { showingRejectConfirmation = true }) {
                        Text("Отклонить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.65))
                            .cornerRadius(12)
                    }
                    Button(action: { showingApproveConfirmation = true }) {
                        Text("Подтвердить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.82))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        } else if blockedAwaitingMerge {
            VStack(alignment: .leading, spacing: 12) {
                Text("Конфликт профилей")
                    .font(.headline)
                    .foregroundColor(Color.red.opacity(0.9))
                Text(blockedConflictExplanation)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: { showMergeRequestSheet = true }) {
                    Text("Запросить merge у админа")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.72))
                        .cornerRadius(12)
                }
                Button(action: { showingRejectConfirmation = true }) {
                    Text("Отклонить заявку")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.62))
                        .cornerRadius(12)
                }
            }
            .padding()
        } else {
            VStack(spacing: 12) {
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
            }
            .padding()
        }
    }

    var body: some View {
        NavigationStack {
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
                        if claim.isBulk {
                            InfoRow(label: "Тип", value: "Сводная по месту · bulk")
                            InfoRow(label: "Место", value: bulkPlaceDisplay)
                            if bulkGamesNote != nil {
                                InfoRow(label: "Охват", value: bulkGamesNote!)
                            }
                        }
                        if claim.status == "blocked", let br = claim.blockReason, !br.isEmpty {
                            InfoRow(label: "Причина блока", value: br)
                        }
                    }
                    .padding()
                    .glassCardStyle(.plain)
                    
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
                    .glassCardStyle(.plain)
                    
                    // Действия
                    blockedOrNormalActionsCard
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
                Text(
                    claim.isBulk
                        ? "Одобрить сводную заявку: все совпадающие игроки могут быть привязаны к профилю заявителя согласно правилам на сервере."
                        : "Пользователь получит доступ к статистике по этому игроку в этой игре."
                )
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
            .onAppear {
                guard claim.isBlocked else { return }
                Task {
                    guard !claim.conflictProfileIds.isEmpty else {
                        await MainActor.run { conflictHandles = [] }
                        return
                    }
                    do {
                        let names = try await claimService.conflictProfileDisplayNames(
                            for: claim.conflictProfileIds
                        )
                        await MainActor.run { conflictHandles = names }
                    } catch {
                        await MainActor.run { conflictHandles = [] }
                    }
                }
            }
            .sheet(isPresented: $showMergeRequestSheet) {
                RequestMergeRequestSheet(claim: claim, onSent: {
                    onResolved()
                })
            }
            .v2ScreenBackground()
        }
    }
    
    private func approveClaim() {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось определить пользователя"
            showingError = true
            return
        }
        
        Task {
            do {
                try await claimService.approveClaim(
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
    }
    private func rejectClaim() {
        guard let userId = currentUserId else {
            errorMessage = "Не удалось определить пользователя"
            showingError = true
            return
        }

        Task {
            do {
                try await claimService.rejectClaim(
                    claimId: claim.claimId,
                    resolverUserId: userId,
                    notes: notes.isEmpty ? nil : notes
                )
                await MainActor.run {
                    onResolved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Host: ask super-admin to merge names (admin_merge_requests)

struct RequestMergeRequestSheet: View {
    let claim: PlayerClaim
    var onSent: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var keysText: String
    @State private var canonicalText: String
    @State private var notesExtra: String = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let service = PlayerClaimService()

    init(claim: PlayerClaim, onSent: @escaping () -> Void) {
        self.claim = claim
        self.onSent = onSent
        let pk = claim.playerKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = claim.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = rawName.lowercased()
        _keysText = State(initialValue: (pk?.isEmpty == false) ? pk!.lowercased() : lowered)
        _canonicalText = State(initialValue: claim.playerName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Хост отправляет админам список имён для merge. Укажите все варианты написания (через запятую), которые нужно слить.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ключи имён")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("рус, руслан", text: $keysText, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                            .foregroundStyle(.primary)
                            .lineLimit(3 ... 9)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Каноническое имя")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Отображение после merge", text: $canonicalText)
                            .padding(10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Комментарий (необязательно)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Контекст для админа", text: $notesExtra, axis: .vertical)
                            .padding(10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                            .foregroundStyle(.primary)
                            .lineLimit(2 ... 6)
                    }

                    Button(action: { Task { await send() } }) {
                        Text(busy ? "Отправка…" : "Отправить админу")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.72))
                            .cornerRadius(12)
                    }
                    .disabled(busy)
                }
                .padding()
            }
            .navigationTitle("Запрос merge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = errorMessage {
                    Text(msg)
                }
            }
        }
    }

    private func send() async {
        let keys: [String] = keysText.split { separator in
            separator == "," || separator == ";" || separator.isNewline
        }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !keys.isEmpty else {
            await MainActor.run {
                errorMessage = "Добавьте хотя бы один ключ имени."
                showError = true
            }
            return
        }

        let unique = Array(Set(keys))
        busy = true
        defer { busy = false }

        do {
            try await service.submitAdminMergeRequest(
                blockedClaimId: claim.claimId,
                sourceKeys: unique,
                suggestedCanonical: canonicalText,
                notes: notesExtra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : notesExtra
            )
            await MainActor.run {
                dismiss()
                onSent()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
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

struct ResolvedClaimRow: View {
    let claim: PlayerClaim
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: claim.resolvedAt ?? claim.createdAt)
    }
    
    private var statusColor: Color {
        switch claim.status {
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch claim.status {
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
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                if let notes = claim.notes, !notes.isEmpty {
                    Text("Комментарий: \(notes)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .glassCardStyle(.plain)
        .opacity(0.8)
    }
}


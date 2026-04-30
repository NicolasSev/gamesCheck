//
//  ClaimSelfView.swift
//

import SwiftUI

/// Экран «Найти себя в играх» — RPC `get_claimable_players` + bulk submit/cancel.
struct ClaimSelfView: View {
    let userId: UUID

    @ObservedObject private var discovery = ClaimDiscoveryService.shared

    @State private var search = ""
    @State private var pending: ClaimableRow?
    @State private var alertError: String?
    @State private var blockedReasonShown: String?

    private var filtered: [ClaimableRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return discovery.rows }
        return discovery.rows.filter { $0.playerName.localizedCaseInsensitiveContains(q) }
    }

    private var grouped: [ClaimSelfHostPlaceGroup] {
        let buckets = Dictionary(grouping: filtered) { row in
            "\(row.hostId.uuidString)|\(row.placeId?.uuidString ?? "∅")"
        }
        return buckets.values.compactMap { items -> ClaimSelfHostPlaceGroup? in
            guard let first = items.first else { return nil }
            let sortedRows = items.sorted { lhs, rhs in
                let a = lhs.lastGameAt ?? .distantPast
                let b = rhs.lastGameAt ?? .distantPast
                if a != b { return a > b }
                return lhs.playerKey < rhs.playerKey
            }
            let sortKey = sortedRows.compactMap(\.lastGameAt).max() ?? .distantPast
            return ClaimSelfHostPlaceGroup(
                hostId: first.hostId,
                hostUsername: first.hostUsername,
                placeId: first.placeId,
                placeName: first.placeName,
                rows: sortedRows,
                sortKey: sortKey
            )
        }
        .sorted { $0.sortKey > $1.sortKey }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextField(
                    "",
                    text: $search,
                    prompt: Text("Поиск по имени игрока")
                        .foregroundColor(.white.opacity(0.45))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .foregroundColor(.white)

                if discovery.isLoading && discovery.rows.isEmpty {
                    ProgressView()
                        .padding(.vertical, 32)
                        .tint(.white)
                }

                ForEach(grouped) { group in
                    ClaimSelfHostPlaceCard(
                        group: group,
                        userId: userId,
                        onAskClaim: { pending = $0 },
                        onShowBlockedReason: { blockedReasonShown = $0 },
                        onMutationError: { alertError = $0 }
                    )
                }

                if !discovery.isLoading, discovery.rows.isEmpty {
                    Text("Нет строк для подачи заявки. Если вы уже играли в чужих играх, данные скоро появятся после синхронизации.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 24)
                } else if !discovery.isLoading, grouped.isEmpty, !discovery.rows.isEmpty {
                    Text("Ничего не найдено. Попробуйте другой запрос.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 24)
                }
            }
            .padding()
        }
        .navigationTitle("Найти себя")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await discovery.refresh(userId: userId)
        }
        .refreshable {
            await discovery.refresh(userId: userId)
        }
        .alert(
            "Подать заявку?",
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            )
        ) {
            Button("Отмена", role: .cancel) { pending = nil }
            Button("Подать заявку") {
                Task { await submitPending() }
            }
        } message: {
            if let r = pending {
                Text(
                    "Вы заявите себя как «\(r.playerName)» (\(r.totalGames) \(gamesWord(r.totalGames))) у @\(r.hostUsername). Место: \(r.placeName). Хост подтвердит заявку — это может охватить все совпадающие игры."
                )
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { alertError != nil },
            set: { if !$0 { alertError = nil } }
        )) {
            Button("OK") { alertError = nil }
        } message: {
            Text(alertError ?? "")
        }
        .alert(
            "Заблокировано",
            isPresented: Binding(
                get: { blockedReasonShown != nil },
                set: { if !$0 { blockedReasonShown = nil } }
            )
        ) {
            Button("OK") { blockedReasonShown = nil }
        } message: {
            Text(blockedReasonShown ?? "Конфликт профилей или иная причина на сервере.")
        }
        .v2ScreenBackground()
    }

    private func submitPending() async {
        guard let r = pending else { return }
        pending = nil
        do {
            _ = try await discovery.submitBulk(
                hostId: r.hostId,
                placeId: r.placeId,
                playerName: r.playerName
            )
            try await SyncCoordinator.shared.fullResyncAfterClaim()
            await discovery.refresh(userId: userId)
        } catch {
            alertError = error.localizedDescription
        }
    }

    private func gamesWord(_ n: Int) -> String {
        RussianPlural.pick(n, one: "игра", few: "игры", many: "игр")
    }
}

// MARK: - Grouping

private struct ClaimSelfHostPlaceGroup: Identifiable {
    var id: String { "\(hostId.uuidString)|\(placeId?.uuidString ?? "∅")" }
    let hostId: UUID
    let hostUsername: String
    let placeId: UUID?
    let placeName: String
    let rows: [ClaimableRow]
    let sortKey: Date
}

// MARK: - Cards

private struct ClaimSelfHostPlaceCard: View {
    let group: ClaimSelfHostPlaceGroup
    let userId: UUID
    let onAskClaim: (ClaimableRow) -> Void
    let onShowBlockedReason: (String) -> Void
    let onMutationError: (String) -> Void

    private var gamesInCard: Int {
        group.rows.reduce(0) { $0 + $1.totalGames }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("@\(group.hostUsername) · \(group.placeName)")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                Spacer()
                Text("\(gamesInCard) \(gamesWordRu(gamesInCard)) в карточке")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))
            }

            ForEach(group.rows) { row in
                ClaimSelfDiscoveryRowView(
                    row: row,
                    userId: userId,
                    onAskClaim: { onAskClaim(row) },
                    onShowBlockedReason: onShowBlockedReason,
                    onMutationError: onMutationError
                )
            }
        }
        .padding()
        .glassCardStyle(.plain)
    }

    private func gamesWordRu(_ n: Int) -> String {
        RussianPlural.pick(n, one: "игра", few: "игры", many: "игр")
    }
}

private struct ClaimSelfDiscoveryRowView: View {
    let row: ClaimableRow
    let userId: UUID
    let onAskClaim: () -> Void
    let onShowBlockedReason: (String) -> Void
    let onMutationError: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(row.playerName)
                        .font(.headline)
                        .foregroundColor(.white)
                    ClaimSelfRowStatusBadge(
                        row: row,
                        onBlockedTap: {
                            onShowBlockedReason(row.blockReason ?? "Конфликт профилей или данные уже заняты.")
                        }
                    )
                }

                subtitle
            }

            Spacer(minLength: 8)

            actionColumn
        }
        .padding(.vertical, 4)
    }

    private var subtitle: some View {
        let gamesTxt =
            "\(row.totalGames) \(RussianPlural.pick(row.totalGames, one: "игра", few: "игры", many: "игр"))"
        return HStack(spacing: 0) {
            Text("\(gamesTxt) · ")
                .foregroundColor(.white.opacity(0.55))
            Text(Decimal(row.totalBalance).formatTengeProto())
                .foregroundColor(balanceColor(row.totalBalance))
        }
        .font(.caption)
    }

    @ViewBuilder
    private var actionColumn: some View {
        switch row.status {
        case "free":
            Button("Это я", action: onAskClaim)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.casinoAccentGreen.opacity(0.85))
                .cornerRadius(10)

        case "my_pending":
            Button("Отменить") {
                Task {
                    guard let cid = row.claimId else { return }
                    do {
                        try await ClaimDiscoveryService.shared.cancelBulk(claimId: cid)
                        try await SyncCoordinator.shared.fullResyncAfterClaim()
                        await ClaimDiscoveryService.shared.refresh(userId: userId)
                    } catch {
                        await MainActor.run {
                            onMutationError(error.localizedDescription)
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .cornerRadius(8)

        default:
            EmptyView()
        }
    }

    private func balanceColor(_ v: Int64) -> Color {
        v >= 0 ? Color.green.opacity(0.95) : Color.red.opacity(0.95)
    }
}

// MARK: - Status badge

private struct ClaimSelfRowStatusBadge: View {
    let row: ClaimableRow
    let onBlockedTap: () -> Void

    var body: some View {
        switch row.status {
        case "free":
            EmptyView()
        case "my_pending":
            badge("На проверке у хоста", foreground: Color.yellow.opacity(0.95), bg: Color.yellow.opacity(0.12))
        case "mine_approved":
            badge("Уже ваше", foreground: Color.casinoAccentGreen, bg: Color.green.opacity(0.12))
        case "taken_by_other":
            badge(
                "Занято" + usernameSuffix(row.takenByUsername),
                foreground: Color.white.opacity(0.72),
                bg: Color.white.opacity(0.08)
            )
        case "pending_other":
            badge(
                "Запросил" + usernameSuffix(row.takenByUsername),
                foreground: Color.white.opacity(0.72),
                bg: Color.white.opacity(0.08)
            )
        case "blocked":
            Button(action: onBlockedTap) {
                badge("Заблокировано", foreground: Color.red.opacity(0.95), bg: Color.red.opacity(0.12))
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    private func usernameSuffix(_ u: String?) -> String {
        guard let u, !u.isEmpty else { return "" }
        return " @\(u)"
    }

    private func badge(_ text: String, foreground: Color, bg: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(foreground.opacity(0.35), lineWidth: 1)
            )
    }
}

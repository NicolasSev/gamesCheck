import SwiftUI

/// Промежуточный экран для пользователя, который уже стал member места,
/// но ещё не привязан к карточке `place_players` (нет записи с `profile_id = me`).
///
/// Показывает список имён игроков места (через `place_players_names_only` view —
/// без финансов). Каждая свободная карточка имеет кнопку «Это я» → открывает
/// `RequestPlayerLinkView` с pre-selected playerId.
///
/// Под кнопкой «Меня нет в списке» (skip) — сохраняется в UserDefaults
/// (ключ `link_skipped:<placeId>`), чтобы пользователь не блокировался.
struct PostAccessPlayerLinkView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager
    @Environment(\.dismiss) private var dismiss

    let placeId: UUID
    let placeName: String

    @State private var players: [PlacePlayerNameOnlyDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var requestForPlayer: PlacePlayerNameOnlyDTO?
    @State private var showRequestSheet = false

    var body: some View {
        ZStack {
            DS.Color.bgBase.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if isLoading {
                        ProgressView()
                            .tint(DS.Color.green)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage {
                        errorView(message: errorMessage)
                    } else if players.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(players) { player in
                            playerRow(player)
                        }
                    }

                    skipButton
                }
                .padding(20)
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
        .sheet(isPresented: $showRequestSheet) {
            if let p = requestForPlayer {
                RequestPlayerLinkView(prefilledPlayerId: p.id, prefilledPlayerName: p.displayName)
                    .environmentObject(placeSession)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Найдите себя в списке")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("«\(placeName)» — выберите карточку, которая принадлежит вам, чтобы привязать к ней свой профиль.")
                .font(.body)
                .foregroundColor(DS.Color.txt2)
        }
    }

    @ViewBuilder
    private func playerRow(_ player: PlacePlayerNameOnlyDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                if player.isMe {
                    Label("Это вы", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(DS.Color.green)
                } else if player.isClaimed {
                    Text("Уже занято")
                        .font(.caption)
                        .foregroundColor(DS.Color.txt2)
                }
            }
            Spacer()
            if player.isMe {
                Button("Готово") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.green)
            } else if !player.isClaimed {
                Button("Это я") {
                    requestForPlayer = player
                    showRequestSheet = true
                }
                .buttonStyle(.bordered)
                .tint(DS.Color.green)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(player.isClaimed ? 0.03 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .opacity(player.isClaimed && !player.isMe ? 0.55 : 1.0)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundColor(DS.Color.txt2)
            Text("В этом месте пока нет игроков")
                .font(.headline)
                .foregroundColor(.white)
            Text("Вернитесь сюда, когда в месте появятся игры.")
                .font(.subheadline)
                .foregroundColor(DS.Color.txt2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Не удалось загрузить список")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(DS.Color.txt2)
                .multilineTextAlignment(.center)
            Button("Повторить") { Task { await reload() } }
                .buttonStyle(.bordered)
                .tint(DS.Color.green)
        }
        .padding(.top, 40)
    }

    private var skipButton: some View {
        Button(action: skip) {
            HStack {
                Image(systemName: "arrow.right.circle")
                Text("Меня нет в списке — пропустить")
                Spacer()
            }
            .padding(14)
            .foregroundColor(DS.Color.txt2)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    @MainActor
    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            let rows = try await placeSession.fetchPlacePlayersNamesOnly(placeId: placeId)
            // Сортировка: «вы» наверху, потом свободные, потом занятые.
            players = rows.sorted { lhs, rhs in
                if lhs.isMe != rhs.isMe { return lhs.isMe }
                if lhs.isClaimed != rhs.isClaimed { return !lhs.isClaimed }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func skip() {
        UserDefaults.standard.set(true, forKey: "link_skipped:\(placeId.uuidString)")
        dismiss()
    }
}

import SwiftUI

/// User flow: pick a place_player at the active place and request to link their profile to it.
struct RequestPlayerLinkView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager
    @Environment(\.dismiss) private var dismiss

    /// Если заданы — picker не показываем, отправляем заявку на конкретного игрока.
    let prefilledPlayerId: UUID?
    let prefilledPlayerName: String?

    init(prefilledPlayerId: UUID? = nil, prefilledPlayerName: String? = nil) {
        self.prefilledPlayerId = prefilledPlayerId
        self.prefilledPlayerName = prefilledPlayerName
    }

    @State private var players: [PlacePlayerDTO] = []
    @State private var selectedPlayerId: UUID?
    @State private var message: String = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.bgBase.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DS.Color.green)
                } else {
                    Form {
                        Section(header: Text("Игрок в месте")) {
                            if let prefilledPlayerId, let prefilledPlayerName {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(DS.Color.green)
                                    Text(prefilledPlayerName)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .onAppear { selectedPlayerId = prefilledPlayerId }
                            } else if players.isEmpty {
                                Text("Нет свободных игроков для привязки")
                                    .foregroundColor(DS.Color.txt2)
                            } else {
                                Picker("Игрок", selection: $selectedPlayerId) {
                                    Text("Выберите игрока").tag(UUID?.none)
                                    ForEach(players) { player in
                                        Text(player.displayName).tag(Optional(player.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        Section(header: Text("Сообщение (необязательно)")) {
                            TextEditor(text: $message)
                                .frame(minHeight: 80)
                        }

                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }

                        if didSend {
                            Section {
                                Label("Заявка отправлена!", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(DS.Color.green)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Привязать к игроку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(DS.Color.txt2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Отправка…" : "Отправить") {
                        sendRequest()
                    }
                    .disabled(isSending || selectedPlayerId == nil || didSend)
                    .foregroundColor(DS.Color.green)
                }
            }
            .preferredColorScheme(.dark)
            .task { await loadPlayers() }
        }
    }

    private func loadPlayers() async {
        // Если pre-selected — список не нужен.
        if prefilledPlayerId != nil { return }

        guard let placeId = placeSession.activePlaceId else {
            errorMessage = "Сначала выберите место"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            players = try await placeSession.fetchPlacePlayers(placeId: placeId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendRequest() {
        guard let playerId = selectedPlayerId else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
                try await placeSession.requestPlayerLink(placePlayerId: playerId, message: msg.isEmpty ? nil : msg)
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

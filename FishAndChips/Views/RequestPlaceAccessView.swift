import SwiftUI

/// User flow: find a place and request membership.
/// Можно открыть с pre-selected `placeId` (из onboarding-gate).
struct RequestPlaceAccessView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager
    @Environment(\.dismiss) private var dismiss

    let prefilledPlaceId: UUID?
    let prefilledPlaceName: String?

    init(prefilledPlaceId: UUID? = nil, prefilledPlaceName: String? = nil) {
        self.prefilledPlaceId = prefilledPlaceId
        self.prefilledPlaceName = prefilledPlaceName
    }

    @State private var places: [PlaceDTO] = []
    @State private var selectedPlaceId: UUID?
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
                        Section(header: Text("Место")) {
                            if let prefilledPlaceId, let prefilledPlaceName {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(DS.Color.green)
                                    Text(prefilledPlaceName)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .onAppear { selectedPlaceId = prefilledPlaceId }
                            } else if places.isEmpty {
                                Text("Нет доступных мест")
                                    .foregroundColor(DS.Color.txt2)
                            } else {
                                Picker("Место", selection: $selectedPlaceId) {
                                    Text("Выберите место").tag(UUID?.none)
                                    ForEach(places) { place in
                                        Text(place.name).tag(Optional(place.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        Section(header: Text("Сообщение (необязательно)")) {
                            TextEditor(text: $message)
                                .frame(minHeight: 80)
                                .font(.body)
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
            .navigationTitle("Запрос доступа к месту")
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
                    .disabled(isSending || selectedPlaceId == nil || didSend)
                    .foregroundColor(DS.Color.green)
                }
            }
            .preferredColorScheme(.dark)
            .task { await loadPlaces() }
        }
    }

    private func loadPlaces() async {
        // Если место уже выбрано (открыто из onboarding-gate) — fetch не нужен.
        if prefilledPlaceId != nil { return }

        isLoading = true
        defer { isLoading = false }
        do {
            var all = try await placeSession.fetchAllActivePlaces()
            // Exclude places user is already a member of
            let myIds = Set(placeSession.memberships.map(\.placeId))
            all = all.filter { !myIds.contains($0.id) }
            places = all
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendRequest() {
        guard let placeId = selectedPlaceId else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
                try await placeSession.requestAccess(placeId: placeId, message: msg.isEmpty ? nil : msg)
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

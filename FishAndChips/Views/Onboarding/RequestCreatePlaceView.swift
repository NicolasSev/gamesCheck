import SwiftUI

/// Форма заявки на создание нового места проведения игр.
/// После отправки заявка летит супер-админу; на approve происходит:
///   - INSERT в `places`
///   - INSERT в `place_members` (role='admin', applicant)
///   - опционально INSERT в `place_players` для applicant'а
/// (см. RPC `decide_create_place` в migration 052).
struct RequestCreatePlaceView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var proposedName: String = ""
    @State private var message: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.bgBase.ignoresSafeArea()
                Form {
                    Section(header: Text("Название места")) {
                        TextField("Например: «Подвальный аквариум»", text: $proposedName)
                            .textInputAutocapitalization(.sentences)
                            .disabled(didSend)
                    }

                    Section(header: Text("Сообщение супер-админу (необязательно)")) {
                        TextEditor(text: $message)
                            .frame(minHeight: 80)
                            .disabled(didSend)
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
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Заявка отправлена", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(DS.Color.green)
                                Text("Дождитесь одобрения супер-админом. После approve вы автоматически станете администратором этого места.")
                                    .font(.caption)
                                    .foregroundColor(DS.Color.txt2)
                            }
                        }
                    } else {
                        Section {
                            Button(action: submit) {
                                HStack {
                                    if isSending {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(isSending ? "Отправка..." : "Отправить заявку")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.Color.green)
                            .disabled(proposedName.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Создать новое место")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        Task {
            await MainActor.run {
                isSending = true
                errorMessage = nil
            }
            do {
                try await placeSession.requestCreatePlace(
                    proposedName: proposedName.trimmingCharacters(in: .whitespaces),
                    message: message.isEmpty ? nil : message
                )
                await MainActor.run {
                    didSend = true
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
}

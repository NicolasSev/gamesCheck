import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Пользователь") {
                    Text(authViewModel.currentUsername)
                    if let id = authViewModel.currentUserId {
                        Text(id.uuidString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Безопасность") {
                    Toggle("Биометрия", isOn: Binding(
                        get: { authViewModel.isBiometricEnabled },
                        set: { authViewModel.isBiometricEnabled = $0 }
                    ))
                    .disabled(!authViewModel.canUseBiometric)
                }

                Section {
                    Button("Выйти", role: .destructive) {
                        authViewModel.logout()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}


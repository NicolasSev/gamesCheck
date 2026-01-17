import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Учетные данные") {
                    TextField("Имя пользователя", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Email (опционально)", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }

                Section("Пароль") {
                    SecureField("Пароль", text: $password)
                    SecureField("Подтвердите пароль", text: $confirmPassword)

                    if !password.isEmpty {
                        if !authViewModel.validatePassword(password).isValid {
                            Text(authViewModel.validatePassword(password).message ?? "")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button("Зарегистрироваться") {
                        register()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        !username.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        authViewModel.validatePassword(password).isValid
    }

    private func register() {
        Task {
            do {
                try await authViewModel.register(
                    username: username,
                    password: password,
                    email: email.isEmpty ? nil : email
                )
                dismiss()
            } catch let error as AuthenticationError {
                errorMessage = error.errorDescription ?? "Ошибка регистрации"
                showingError = true
            } catch {
                errorMessage = "Неизвестная ошибка"
                showingError = true
            }
        }
    }
}


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
    @State private var showingSuccess = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    var body: some View {
        NavigationView {
            Form {
                Section("Учетные данные") {
                    TextField("Имя пользователя", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                        
                        if !email.isEmpty {
                            Image(systemName: authViewModel.validateEmail(email) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(authViewModel.validateEmail(email) ? .green : .red)
                        }
                    }
                    
                    if !email.isEmpty && !authViewModel.validateEmail(email) {
                        Text("Неверный формат email")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    HStack {
                        if showPassword {
                            TextField("Пароль", text: $password)
                        } else {
                            SecureField("Пароль", text: $password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        if showConfirmPassword {
                            TextField("Подтвердите пароль", text: $confirmPassword)
                        } else {
                            SecureField("Подтвердите пароль", text: $confirmPassword)
                        }
                        Button(action: { showConfirmPassword.toggle() }) {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }

                    if !password.isEmpty {
                        let validation = authViewModel.validatePassword(password)
                        if !validation.isValid {
                            Text(validation.message ?? "")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("✓ Пароль соответствует требованиям")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Пароли не совпадают")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Пароль")
                } footer: {
                    Text("Минимум 6 символов, должен содержать буквы и цифры")
                        .font(.caption)
                }

                Section {
                    Button(action: register) {
                        if authViewModel.isLoading {
                            HStack {
                                ProgressView()
                                Text("Регистрация...")
                            }
                        } else {
                            Text("Зарегистрироваться")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || authViewModel.isLoading)
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
            .alert("Успех", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Вы успешно зарегистрировались!")
            }
        }
    }

    private var isValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        authViewModel.validateEmail(email) &&
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
                    email: email
                )
                // Успешная регистрация - показываем уведомление
                await MainActor.run {
                    showingSuccess = true
                }
            } catch let error as AuthenticationError {
                await MainActor.run {
                    errorMessage = error.errorDescription ?? "Ошибка регистрации"
                    showingError = true
                }
            } catch {
                // Логируем полную информацию об ошибке
                print("❌ [REGISTRATION_VIEW] Unexpected error: \(error)")
                print("❌ [REGISTRATION_VIEW] Error type: \(type(of: error))")
                print("❌ [REGISTRATION_VIEW] Localized: \(error.localizedDescription)")
                
                // Показываем более информативное сообщение
                await MainActor.run {
                    errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}


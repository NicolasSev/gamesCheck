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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.5),
                                Color(red: 0.95, green: 0.78, blue: 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.35), radius: 16, y: 6)
                        .padding(.top, 12)

                    // Учётные данные
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Учётные данные")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20)
                            TextField("Имя пользователя", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .accessibilityIdentifier("register_username")
                        }
                        .padding()
                        .glassCardStyle(.plain)

                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .foregroundColor(.white)
                                .accessibilityIdentifier("register_email")
                            
                            if !email.isEmpty {
                                Image(systemName: authViewModel.validateEmail(email) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(authViewModel.validateEmail(email) ? .green : .red)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                        .glassCardStyle(.plain)
                        
                        if !email.isEmpty && !authViewModel.validateEmail(email) {
                            Text("Неверный формат email")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.leading, 4)
                        }
                    }
                    .padding()
                    .glassCardStyle(.plain)

                    // Пароль
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Пароль")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20)
                            if showPassword {
                                TextField("Пароль", text: $password)
                                    .keyboardType(.asciiCapable)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.white)
                            } else {
                                SecureField("Пароль", text: $password)
                                    .keyboardType(.asciiCapable)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.white)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .glassCardStyle(.plain)
                        .accessibilityIdentifier("register_password")

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20)
                            if showConfirmPassword {
                                TextField("Подтвердите пароль", text: $confirmPassword)
                                    .keyboardType(.asciiCapable)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.white)
                            } else {
                                SecureField("Подтвердите пароль", text: $confirmPassword)
                                    .keyboardType(.asciiCapable)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.white)
                            }
                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .glassCardStyle(.plain)
                        .accessibilityIdentifier("register_confirm_password")

                        if !password.isEmpty {
                            let validation = authViewModel.validatePassword(password)
                            if !validation.isValid {
                                Label(validation.message ?? "", systemImage: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.leading, 4)
                            } else {
                                Label("Пароль соответствует требованиям", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green.opacity(0.9))
                                    .padding(.leading, 4)
                            }
                        }
                        
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Label("Пароли не совпадают", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.leading, 4)
                        }
                        
                        Text("Минимум 6 символов, буквы и цифры")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    .padding()
                    .glassCardStyle(.plain)

                    // Кнопка регистрации
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        register()
                    }) {
                        if authViewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Регистрация...")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        } else {
                            Text("Зарегистрироваться")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.2, green: 0.72, blue: 0.48))
                    .disabled(!isValid || authViewModel.isLoading)
                    .accessibilityIdentifier("register_button")
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .v2ScreenBackground()
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Успех", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
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
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showingSuccess = true
                }
            } catch let error as AuthenticationError {
                await MainActor.run {
                    errorMessage = error.errorDescription ?? "Ошибка регистрации"
                    showingError = true
                }
            } catch {
                debugLog("❌ [REGISTRATION_VIEW] Unexpected error: \(error)")
                await MainActor.run {
                    errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

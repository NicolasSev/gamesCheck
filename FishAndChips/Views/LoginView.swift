import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var showingError = false
    @State private var isAppearing = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "suit.spade.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.linearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.5),
                                    Color(red: 0.95, green: 0.78, blue: 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.45), radius: 20, y: 8)
                            .scaleEffect(isAppearing ? 1.0 : 0.6)
                            .opacity(isAppearing ? 1.0 : 0)

                        Text("Fish & Chips")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                            .opacity(isAppearing ? 1.0 : 0)
                    }
                    .padding(.bottom, 20)

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .foregroundColor(.white)
                                .accessibilityIdentifier("login_email")
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 12)

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            SecureField("Пароль", text: $password)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .accessibilityIdentifier("login_password")
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 12)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            login()
                        }) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            } else {
                                Text("Войти")
                                    .frame(maxWidth: .infinity)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 4)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.2, green: 0.72, blue: 0.48))
                        .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                        .accessibilityIdentifier("login_button")
                    }
                    .padding(.horizontal, 32)
                    .offset(y: isAppearing ? 0 : 30)
                    .opacity(isAppearing ? 1.0 : 0)

                    if authViewModel.canUseBiometric && authViewModel.isBiometricEnabled {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            authenticateWithBiometric()
                        }) {
                            Label(
                                "Войти с \(authViewModel.biometricName)",
                                systemImage: authViewModel.biometricType == .faceID ? "faceid" : "touchid"
                            )
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.3))
                        .transition(.opacity.combined(with: .scale))
                    }

                    Spacer()

                    Button("Нет аккаунта? Зарегистрироваться") {
                        showingRegistration = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 16)
                }
                .padding()
            }
            .casinoBackground()
            .accessibilityIdentifier("screen.login")
            .navigationBarHidden(true)
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "Неизвестная ошибка")
            }
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                // UITest: без задержки анимации поля остаются с opacity 0 / не hittable для XCUITest.
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    isAppearing = true
                    // Креды из launchEnvironment (UITest передаёт их в процесс приложения — схема даёт env только раннеру).
                    let e = ProcessInfo.processInfo.environment["FC_TEST_EMAIL"] ?? ""
                    let p = ProcessInfo.processInfo.environment["FC_TEST_PASSWORD"] ?? ""
                    // Схема Xcode без export даёт буквально "$(FC_TEST_EMAIL)" — не подставлять.
                    if !e.isEmpty, !p.isEmpty,
                       !Self.isUnresolvedSchemePlaceholder(e), !Self.isUnresolvedSchemePlaceholder(p) {
                        email = e
                        password = p
                    }
                    if ProcessInfo.processInfo.arguments.contains("--uitesting-auto-submit-login"),
                       !email.isEmpty, !password.isEmpty {
                        Task {
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            await MainActor.run {
                                login()
                            }
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isAppearing = true
                    }
                }
            }
        }
    }

    private static func isUnresolvedSchemePlaceholder(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("$(") && t.hasSuffix(")")
    }

    private func login() {
        guard !authViewModel.isLoading else { return }
        Task {
            do {
                try await authViewModel.login(email: email, password: password)
            } catch let error as AuthenticationError {
                authViewModel.errorMessage = error.errorDescription
                showingError = true
            } catch {
                authViewModel.errorMessage = "Неизвестная ошибка"
                showingError = true
            }
        }
    }

    private func authenticateWithBiometric() {
        Task {
            do {
                try await authViewModel.authenticateWithBiometric()
            } catch let error as AuthenticationError {
                authViewModel.errorMessage = error.errorDescription
                showingError = true
            } catch {
                authViewModel.errorMessage = "Неизвестная ошибка"
                showingError = true
            }
        }
    }
}

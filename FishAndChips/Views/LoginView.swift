import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var username = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var showingError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.linearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .padding(.bottom, 30)

                Text("PokerTracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 15) {
                    TextField("Имя пользователя", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button(action: login) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Войти")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || authViewModel.isLoading)
                }
                .padding(.horizontal, 30)

                if authViewModel.canUseBiometric && authViewModel.isBiometricEnabled {
                    Button(action: authenticateWithBiometric) {
                        Label(
                            "Войти с \(authViewModel.biometricName)",
                            systemImage: authViewModel.biometricType == .faceID ? "faceid" : "touchid"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Нет аккаунта? Зарегистрироваться") {
                    showingRegistration = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding()
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
        }
    }

    private func login() {
        Task {
            do {
                try await authViewModel.login(username: username, password: password)
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

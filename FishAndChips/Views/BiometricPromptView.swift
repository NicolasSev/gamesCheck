import SwiftUI

struct BiometricPromptView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var attemptCount = 0

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 100))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text("Добро пожаловать!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let username = authViewModel.currentUser?.username, username != "Guest" {
                    Text(username)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text("Используйте \(authViewModel.biometricName) для входа")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()

            VStack(spacing: 16) {
                Button(action: authenticate) {
                    Label("Войти с \(authViewModel.biometricName)", systemImage: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Войти с паролем") {
                    authViewModel.authState = .unauthenticated
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Выйти") {
                    authViewModel.logout()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.footnote)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            // Auto-trigger biometric on first appearance
            if attemptCount == 0 {
                authenticate()
            }
        }
        .alert("Ошибка аутентификации", isPresented: $showingError) {
            Button("Повторить", action: authenticate)
            Button("Войти с паролем") {
                authViewModel.authState = .unauthenticated
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func authenticate() {
        attemptCount += 1
        Task {
            do {
                try await authViewModel.authenticateWithBiometric()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}


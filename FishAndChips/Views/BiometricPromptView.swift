import SwiftUI

struct BiometricPromptView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var attemptCount = 0
    @State private var isAppearing = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.8, blue: 0.5),
                        Color(red: 0.95, green: 0.78, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.45), radius: 20, y: 8)
                .symbolEffect(.pulse)
                .scaleEffect(isAppearing ? 1.0 : 0.5)
                .opacity(isAppearing ? 1.0 : 0)

            VStack(spacing: 12) {
                Text("Добро пожаловать!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let username = authViewModel.currentUser?.username, username != "Guest" {
                    Text(username)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("Используйте \(authViewModel.biometricName) для входа")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .opacity(isAppearing ? 1.0 : 0)
            .offset(y: isAppearing ? 0 : 20)
            
            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    authenticate()
                }) {
                    Label("Войти с \(authViewModel.biometricName)", systemImage: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.2, green: 0.72, blue: 0.48))
                .controlSize(.large)

                Button("Войти с паролем") {
                    authViewModel.authState = .unauthenticated
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                
                Button("Выйти") {
                    authViewModel.logout()
                }
                .font(.footnote)
                .foregroundColor(.red.opacity(0.8))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
            .opacity(isAppearing ? 1.0 : 0)
            .offset(y: isAppearing ? 0 : 30)
        }
        .padding()
        .accessibilityIdentifier("biometric_prompt_root")
        .v2ScreenBackground()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isAppearing = true
            }
            if attemptCount == 0, !ProcessInfo.processInfo.arguments.contains("--uitesting-skip-faceid") {
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

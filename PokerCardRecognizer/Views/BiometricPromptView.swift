import SwiftUI

struct BiometricPromptView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Используйте \(authViewModel.biometricName)")
                .font(.title2)

            Button("Войти с \(authViewModel.biometricName)") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Войти с паролем") {
                authViewModel.authState = .unauthenticated
            }
            .buttonStyle(.plain)
        }
        .padding()
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        Task {
            try? await authViewModel.authenticateWithBiometric()
        }
    }
}


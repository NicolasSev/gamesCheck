import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unauthenticated:
                LoginView()
                    .environmentObject(authViewModel)

            case .biometricAvailable:
                BiometricPromptView()
                    .environmentObject(authViewModel)

            case .authenticated:
                MainView()
                    .environmentObject(authViewModel)

            case .authenticating:
                ProgressView("Вход...")

            case .error(let message):
                VStack(spacing: 16) {
                    Text("Ошибка")
                        .font(.headline)
                    Text(message)
                        .foregroundColor(.secondary)
                    Button("Попробовать снова") {
                        authViewModel.checkAuthenticationStatus()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
}

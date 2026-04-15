import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unauthenticated:
                LoginView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .biometricAvailable:
                BiometricPromptView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .authenticated:
                MainView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .authenticating:
                ZStack {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Вход...")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .casinoBackground()
                .transition(.opacity)

            case .error(let message):
                ZStack {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.4), radius: 12, y: 4)

                        Text("Ошибка")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button("Попробовать снова") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            authViewModel.checkAuthenticationStatus()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .casinoBackground()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authViewModel.authState)
    }
}

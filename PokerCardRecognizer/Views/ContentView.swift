import SwiftUI

struct ContentView: View {
    @StateObject var authViewModel = AuthViewModel()
    
    // Проверка, запущено ли на симуляторе
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                MainView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            // На симуляторе автоматически пропускаем авторизацию
            if isSimulator {
                authViewModel.isLoggedIn = true
            }
        }
    }
}

import SwiftUI
import Combine
import LocalAuthentication

class AuthViewModel: ObservableObject {
    @Published var login: String = ""
    @Published var password: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String?

    // Пример проверки логина и пароля
    func signIn() {
        // Здесь может быть запрос к серверу, но пока сделаем упрощённо
        if login == "admin" && password == "123" {
            isLoggedIn = true
            errorMessage = nil
        } else {
            isLoggedIn = false
            errorMessage = "Неверный логин или пароль"
        }
    }
    
    // Функция аутентификации через Face ID
    func authenticateBiometrically() {
        let context = LAContext()
        var authError: NSError?
        let reason = "Используйте Face ID для входа в приложение"
        
        // Проверяем, доступна ли биометрическая аутентификация
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        self.isLoggedIn = true
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = evaluationError?.localizedDescription ?? "Ошибка Face ID"
                        self.isLoggedIn = false
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.errorMessage = authError?.localizedDescription ?? "Биометрическая аутентификация не поддерживается"
                self.isLoggedIn = false
            }
        }
    }
    
    func signOut() {
        isLoggedIn = false
        login = ""
        password = ""
    }
}

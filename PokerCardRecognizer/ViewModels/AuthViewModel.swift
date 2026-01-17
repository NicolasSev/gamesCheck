import Foundation
import SwiftUI
import LocalAuthentication
import CryptoKit
import Combine

enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
    case biometricAvailable
    case error(String)
}

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userAlreadyExists
    case userNotFound
    case weakPassword
    case biometricFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверное имя пользователя или пароль"
        case .userAlreadyExists:
            return "Пользователь с таким именем уже существует"
        case .userNotFound:
            return "Пользователь не найден"
        case .weakPassword:
            return "Пароль должен содержать минимум 6 символов"
        case .biometricFailed:
            return "Биометрическая аутентификация не удалась"
        case .unknown:
            return "Произошла неизвестная ошибка"
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let persistence: PersistenceController
    private let userDefaults: UserDefaults
    private let context: LAContext

    // MARK: - UserDefaults Keys
    private let currentUserIdKey = "currentUserId"
    private let biometricEnabledKey = "biometricEnabled"

    init(
        persistence: PersistenceController = .shared,
        userDefaults: UserDefaults = .standard,
        context: LAContext = LAContext()
    ) {
        self.persistence = persistence
        self.userDefaults = userDefaults
        self.context = context
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        guard let userIdString = userDefaults.string(forKey: currentUserIdKey),
              let userId = UUID(uuidString: userIdString),
              let user = persistence.fetchUser(byId: userId) else {
            authState = .unauthenticated
            currentUser = nil
            return
        }

        currentUser = user

        if isBiometricEnabled && canUseBiometric {
            authState = .biometricAvailable
        } else {
            authState = .authenticated
        }
    }

    // MARK: - Registration
    func register(username: String, password: String, email: String?) async throws {
        guard !username.isEmpty else { throw AuthenticationError.invalidCredentials }

        let passwordValidation = validatePassword(password)
        guard passwordValidation.isValid else { throw AuthenticationError.weakPassword }

        if persistence.fetchUser(byUsername: username) != nil {
            throw AuthenticationError.userAlreadyExists
        }

        let passwordHash = hashPassword(password)

        guard let user = persistence.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        ) else {
            throw AuthenticationError.unknown
        }

        // Создать PlayerProfile для пользователя (Task 1.3)
        _ = persistence.createPlayerProfile(displayName: username, userId: user.userId)

        try await login(username: username, password: password)
    }

    // MARK: - Login
    func login(username: String, password: String) async throws {
        isLoading = true
        authState = .authenticating

        // Небольшая задержка для UI
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let user = persistence.fetchUser(byUsername: username) else {
            isLoading = false
            authState = .error("Пользователь не найден")
            throw AuthenticationError.userNotFound
        }

        let passwordHash = hashPassword(password)
        guard user.passwordHash == passwordHash else {
            isLoading = false
            authState = .error("Неверный пароль")
            throw AuthenticationError.invalidCredentials
        }

        persistence.updateUserLastLogin(user)
        
        // Устанавливаем супер админа для пользователя "Ник"
        if username == "Ник" {
            persistence.setSuperAdmin(username: "Ник", isSuperAdmin: true)
            user.isSuperAdmin = true
        }
        
        userDefaults.set(user.userId.uuidString, forKey: currentUserIdKey)

        currentUser = user
        isLoading = false
        authState = .authenticated
        errorMessage = nil
    }

    // MARK: - Logout
    func logout() {
        currentUser = nil
        authState = .unauthenticated
        userDefaults.removeObject(forKey: currentUserIdKey)
    }

    // Backward-compatible alias (старый код)
    func signOut() {
        logout()
    }

    // MARK: - Biometric Authentication
    var canUseBiometric: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: LABiometryType {
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Биометрия"
        }
    }

    var isBiometricEnabled: Bool {
        get { userDefaults.bool(forKey: biometricEnabledKey) }
        set { userDefaults.set(newValue, forKey: biometricEnabledKey) }
    }

    func authenticateWithBiometric() async throws {
        guard canUseBiometric else { throw AuthenticationError.biometricFailed }

        let reason = "Войдите используя \(biometricName)"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                authState = .authenticated
            } else {
                throw AuthenticationError.biometricFailed
            }
        } catch {
            throw AuthenticationError.biometricFailed
        }
    }

    // MARK: - Password Hashing
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Password Validation
    func validatePassword(_ password: String) -> (isValid: Bool, message: String?) {
        guard password.count >= 6 else {
            return (false, "Минимум 6 символов")
        }

        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil

        if !hasLetter || !hasNumber {
            return (false, "Пароль должен содержать буквы и цифры")
        }

        return (true, nil)
    }
}

// MARK: - Convenience
extension AuthViewModel {
    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var currentUserId: UUID? {
        currentUser?.userId
    }

    var currentUsername: String {
        currentUser?.username ?? "Guest"
    }
}

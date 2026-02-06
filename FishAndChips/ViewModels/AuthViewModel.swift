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
    case emailAlreadyExists
    case userNotFound
    case weakPassword
    case invalidEmail
    case biometricFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверное имя пользователя или пароль"
        case .userAlreadyExists:
            return "Пользователь с таким именем уже существует"
        case .emailAlreadyExists:
            return "Пользователь с такой почтой уже существует"
        case .userNotFound:
            return "Пользователь не найден"
        case .weakPassword:
            return "Пароль должен содержать минимум 6 символов"
        case .invalidEmail:
            return "Неверный формат email адреса"
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
    
    // Флаг: требуется ли повторная аутентификация после logout
    private var requiresReauth = false

    private let persistence: PersistenceController
    private let keychain: KeychainService

    // MARK: - UserDefaults Keys (Legacy - migrating to Keychain)
    private let currentUserIdKey = "currentUserId"
    private let biometricEnabledKey = "biometricEnabled"

    init(
        persistence: PersistenceController = .shared,
        keychain: KeychainService = .shared
    ) {
        self.persistence = persistence
        self.keychain = keychain
        
        // Migrate from UserDefaults to Keychain if needed
        migrateToKeychain()
        
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        print("\n🔍 [AUTH STATUS] Checking authentication status...")
        print("   - Requires reauth: \(requiresReauth)")
        
        guard let userIdString = keychain.getUserId() else {
            print("⚠️ [AUTH STATUS] No userId in Keychain")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        print("📱 [AUTH STATUS] Found userId in Keychain: \(userIdString)")
        
        guard let userId = UUID(uuidString: userIdString) else {
            print("❌ [AUTH STATUS] Invalid UUID format: \(userIdString)")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        
        guard let user = persistence.fetchUser(byId: userId) else {
            print("❌ [AUTH STATUS] User not found in database: \(userId)")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        
        print("✅ [AUTH STATUS] User found in database:")
        print("   - Username: \(user.username)")
        print("   - Email: \(user.email ?? "nil")")
        print("   - UserId: \(user.userId)")

        // Если требуется повторная аутентификация (после logout)
        if requiresReauth {
            print("⚠️ [AUTH STATUS] Reauth required after logout")
            currentUser = nil
            if isBiometricEnabled && canUseBiometric {
                print("🔐 [AUTH STATUS] Biometric available -> .biometricAvailable")
                authState = .biometricAvailable
            } else {
                print("🔑 [AUTH STATUS] Biometric not available -> .unauthenticated")
                authState = .unauthenticated
            }
            requiresReauth = false
            return
        }

        // Обычная проверка (при первом запуске)
        currentUser = user

        if isBiometricEnabled && canUseBiometric {
            print("🔐 [AUTH STATUS] Biometric available and enabled -> .biometricAvailable")
            authState = .biometricAvailable
        } else {
            print("✅ [AUTH STATUS] User authenticated -> .authenticated")
            authState = .authenticated
        }
    }
    
    // MARK: - Migration from UserDefaults to Keychain
    private func migrateToKeychain() {
        // Migrate userId if exists in UserDefaults
        if let userIdString = UserDefaults.standard.string(forKey: currentUserIdKey),
           keychain.getUserId() == nil {
            _ = keychain.saveUserId(userIdString)
            UserDefaults.standard.removeObject(forKey: currentUserIdKey)
        }
        
        // Migrate biometric setting if exists in UserDefaults
        if UserDefaults.standard.object(forKey: biometricEnabledKey) != nil {
            let enabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
            _ = keychain.setBiometricEnabled(enabled)
            UserDefaults.standard.removeObject(forKey: biometricEnabledKey)
        }
    }

    // MARK: - Registration
    func register(username: String, password: String, email: String) async throws {
        print("\n📝 [REGISTER] Starting registration process...")
        print("👤 [REGISTER] Username: \(username)")
        print("📧 [REGISTER] Email: \(email)")
        print("🔒 [REGISTER] Password: ****** (length: \(password.count))")
        
        guard !username.isEmpty else {
            print("❌ [REGISTER] FAILED: Username is empty")
            throw AuthenticationError.invalidCredentials
        }
        guard !email.isEmpty else {
            print("❌ [REGISTER] FAILED: Email is empty")
            throw AuthenticationError.invalidEmail
        }

        print("🔍 [REGISTER] Validating password...")
        let passwordValidation = validatePassword(password)
        guard passwordValidation.isValid else {
            print("❌ [REGISTER] FAILED: Weak password - \(passwordValidation.message ?? "unknown")")
            throw AuthenticationError.weakPassword
        }
        print("✅ [REGISTER] Password validation passed")
        
        // Validate email format
        print("🔍 [REGISTER] Validating email format...")
        guard validateEmail(email) else {
            print("❌ [REGISTER] FAILED: Invalid email format")
            throw AuthenticationError.invalidEmail
        }
        print("✅ [REGISTER] Email format valid")
        
        // Check if email already exists
        print("🔍 [REGISTER] Checking if email already exists...")
        if let existingUser = persistence.fetchUser(byEmail: email) {
            print("❌ [REGISTER] FAILED: Email already exists (user: \(existingUser.username))")
            throw AuthenticationError.emailAlreadyExists
        }
        print("✅ [REGISTER] Email is available")

        print("🔍 [REGISTER] Checking if username already exists...")
        if let existingUser = persistence.fetchUser(byUsername: username) {
            print("❌ [REGISTER] FAILED: Username already exists (email: \(existingUser.email ?? "nil"))")
            throw AuthenticationError.userAlreadyExists
        }
        print("✅ [REGISTER] Username is available")

        print("🔐 [REGISTER] Hashing password...")
        let passwordHash = hashPassword(password)
        print("   - Hash: \(passwordHash.prefix(20))...")

        print("💾 [REGISTER] Creating user in database...")
        guard let user = persistence.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        ) else {
            print("❌ [REGISTER] FAILED: Could not create user in database")
            throw AuthenticationError.unknown
        }
        print("✅ [REGISTER] User created:")
        print("   - UserId: \(user.userId)")
        print("   - Username: \(user.username)")
        print("   - Email: \(user.email ?? "nil")")

        print("👤 [REGISTER] Creating PlayerProfile...")
        let profile = persistence.createPlayerProfile(displayName: username, userId: user.userId)
        print("✅ [REGISTER] PlayerProfile created")

        // Автоматическая синхронизация в CloudKit
        print("☁️ [REGISTER] Syncing new user to CloudKit...")
        await CloudKitSyncService.shared.quickSyncUser(user)
        await CloudKitSyncService.shared.quickSyncPlayerProfile(profile)

        print("🔑 [REGISTER] Auto-login after registration...")
        try await login(email: email, password: password)
    }

    // MARK: - Login
    func login(email: String, password: String) async throws {
        print("\n🔑 [LOGIN] Starting login process...")
        print("📧 [LOGIN] Email provided: \(email)")
        print("🔒 [LOGIN] Password provided: \(password.isEmpty ? "empty" : "****** (length: \(password.count))")")
        
        isLoading = true
        authState = .authenticating

        // Небольшая задержка для UI
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Попытка 1: Поиск пользователя локально по email
        print("🔍 [LOGIN] Attempt 1: Searching user locally by email...")
        var user = persistence.fetchUser(byEmail: email)
        
        if let localUser = user {
            print("✅ [LOGIN] User found locally:")
            print("   - Username: \(localUser.username)")
            print("   - Email: \(localUser.email ?? "nil")")
            print("   - UserId: \(localUser.userId)")
        } else {
            print("⚠️ [LOGIN] User NOT found locally")
        }
        
        // Попытка 2: Если не найден локально - попробовать загрузить из CloudKit
        if user == nil {
            print("🔍 [LOGIN] Attempt 2: Trying to fetch from CloudKit...")
            do {
                user = try await CloudKitSyncService.shared.fetchUser(byEmail: email)
                if let cloudUser = user {
                    print("✅ [LOGIN] User restored from CloudKit:")
                    print("   - Username: \(cloudUser.username)")
                    print("   - Email: \(cloudUser.email ?? "nil")")
                    print("   - UserId: \(cloudUser.userId)")
                }
            } catch {
                print("❌ [LOGIN] Failed to fetch user from CloudKit: \(error)")
            }
        }
        
        // Если пользователь все еще не найден - ошибка
        guard let foundUser = user else {
            print("❌ [LOGIN] FAILED: User not found (neither locally nor in CloudKit)")
            isLoading = false
            authState = .error("Пользователь не найден")
            throw AuthenticationError.userNotFound
        }

        print("🔐 [LOGIN] Validating password...")
        let passwordHash = hashPassword(password)
        print("   - Password hash: \(passwordHash.prefix(20))...")
        print("   - Stored hash: \(foundUser.passwordHash.prefix(20))...")
        
        guard foundUser.passwordHash == passwordHash else {
            print("❌ [LOGIN] FAILED: Password does not match")
            isLoading = false
            authState = .error("Неверный пароль")
            throw AuthenticationError.invalidCredentials
        }
        
        print("✅ [LOGIN] Password validated successfully")

        persistence.updateUserLastLogin(foundUser)
        print("✅ [LOGIN] Updated last login timestamp")
        
        // Устанавливаем супер админа для пользователя "Ник"
        if foundUser.username == "Ник" {
            persistence.setSuperAdmin(username: "Ник", isSuperAdmin: true)
            foundUser.isSuperAdmin = true
            print("👑 [LOGIN] Super admin flag set for user 'Ник'")
        }
        
        print("💾 [LOGIN] Saving to Keychain...")
        _ = keychain.saveUserId(foundUser.userId.uuidString)
        _ = keychain.saveUsername(foundUser.username)
        print("   - UserId saved: \(foundUser.userId)")
        print("   - Username saved: \(foundUser.username)")

        currentUser = foundUser
        isLoading = false
        authState = .authenticated
        errorMessage = nil
        requiresReauth = false  // Сбрасываем флаг после успешного входа
        
        print("✅ [LOGIN] Login successful! User: \(foundUser.username)\n")
    }

    // MARK: - Logout
    func logout() {
        print("\n🚪 [LOGOUT] Starting logout...")
        print("   - Current user: \(currentUser?.username ?? "nil")")
        print("   - Biometric enabled: \(isBiometricEnabled)")
        
        currentUser = nil
        authState = .unauthenticated
        requiresReauth = true  // Требуем повторную аутентификацию
        
        // НЕ очищаем Keychain - оставляем userId и username для Face ID
        // Только очищаем текущую сессию и устанавливаем флаг требования повторной аутентификации
        print("✅ [LOGOUT] Logout complete (Keychain preserved, reauth required)")
    }

    // Backward-compatible alias (старый код)
    func signOut() {
        logout()
    }

    // MARK: - Biometric Authentication
    var canUseBiometric: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
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
        get { keychain.isBiometricEnabled() }
        set { _ = keychain.setBiometricEnabled(newValue) }
    }

    func authenticateWithBiometric() async throws {
        print("🔐 [BIOMETRIC] Starting biometric authentication...")
        
        guard canUseBiometric else {
            print("❌ [BIOMETRIC] Biometric authentication not available")
            throw AuthenticationError.biometricFailed
        }

        // Создаем новый LAContext для каждой попытки
        let context = LAContext()
        let reason = "Войдите используя \(biometricName)"
        
        do {
            print("🔐 [BIOMETRIC] Requesting \(biometricName) authentication...")
            print("🔐 [BIOMETRIC] Creating new LAContext for fresh authentication attempt")
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                print("✅ [BIOMETRIC] Biometric authentication successful")
                
                // Загружаем пользователя из Keychain
                guard let userIdString = keychain.getUserId(),
                      let userId = UUID(uuidString: userIdString) else {
                    print("❌ [BIOMETRIC] No userId found in Keychain")
                    throw AuthenticationError.userNotFound
                }
                
                print("🔍 [BIOMETRIC] Loading user from database: \(userId)")
                guard let user = persistence.fetchUser(byId: userId) else {
                    print("❌ [BIOMETRIC] User not found in database: \(userId)")
                    throw AuthenticationError.userNotFound
                }
                
                print("✅ [BIOMETRIC] User loaded: \(user.username) (email: \(user.email ?? "nil"))")
                
                // Устанавливаем пользователя
                currentUser = user
                authState = .authenticated
                requiresReauth = false  // Сбрасываем флаг после успешной биометрии
                
                print("✅ [BIOMETRIC] Authentication complete")
            } else {
                print("❌ [BIOMETRIC] Biometric authentication failed")
                throw AuthenticationError.biometricFailed
            }
        } catch {
            print("❌ [BIOMETRIC] Error: \(error.localizedDescription)")
            throw AuthenticationError.biometricFailed
        }
    }
    
    // MARK: - Update User
    func updateUsername(_ newUsername: String) async throws {
        guard !newUsername.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard let user = currentUser else {
            throw AuthenticationError.unknown
        }
        
        // Проверить, не занято ли имя
        let success = persistence.updateUsername(user, newUsername: newUsername)
        if !success {
            throw AuthenticationError.userAlreadyExists
        }
        
        // Обновить keychain
        _ = keychain.saveUsername(newUsername)
        
        // Обновить текущее состояние
        currentUser = user
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
    
    // MARK: - Email Validation
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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

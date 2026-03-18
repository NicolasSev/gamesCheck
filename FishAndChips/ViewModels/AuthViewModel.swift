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
    private let keychain: KeychainServiceProtocol
    private let cloudKitSync: AuthCloudKitSyncProtocol
    private let syncCoordinator: SyncCoordinator
    private let supabaseAuth: SupabaseAuthService
    private let networkMonitor: NetworkMonitor

    // MARK: - UserDefaults Keys (Legacy - migrating to Keychain)
    private let currentUserIdKey = "currentUserId"
    private let biometricEnabledKey = "biometricEnabled"

    init(
        persistence: PersistenceController = .shared,
        keychain: KeychainServiceProtocol = KeychainService.shared,
        cloudKitSync: AuthCloudKitSyncProtocol? = nil,
        syncCoordinator: SyncCoordinator? = nil,
        supabaseAuth: SupabaseAuthService? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.persistence = persistence
        self.keychain = keychain
        self.cloudKitSync = cloudKitSync ?? CloudKitSyncService.shared
        self.syncCoordinator = syncCoordinator ?? SyncCoordinator.shared
        self.supabaseAuth = supabaseAuth ?? SupabaseAuthService.shared
        self.networkMonitor = networkMonitor ?? NetworkMonitor.shared
        
        // Migrate from UserDefaults to Keychain if needed
        migrateToKeychain()
        
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        debugLog("\n🔍 [AUTH STATUS] Checking authentication status...")
        debugLog("   - Requires reauth: \(requiresReauth)")
        
        guard let userIdString = keychain.getUserId() else {
            debugLog("⚠️ [AUTH STATUS] No userId in Keychain")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        debugLog("📱 [AUTH STATUS] Found userId in Keychain: \(userIdString)")
        
        guard let userId = UUID(uuidString: userIdString) else {
            debugLog("❌ [AUTH STATUS] Invalid UUID format: \(userIdString)")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        
        guard let user = persistence.fetchUser(byId: userId) else {
            debugLog("❌ [AUTH STATUS] User not found in database: \(userId)")
            authState = .unauthenticated
            currentUser = nil
            requiresReauth = false
            return
        }
        
        debugLog("✅ [AUTH STATUS] User found in database:")
        debugLog("   - Username: \(user.username)")
        debugLog("   - Email: \(user.email ?? "nil")")
        debugLog("   - UserId: \(user.userId)")

        // Если требуется повторная аутентификация (после logout)
        if requiresReauth {
            debugLog("⚠️ [AUTH STATUS] Reauth required after logout")
            currentUser = nil
            if isBiometricEnabled && canUseBiometric {
                debugLog("🔐 [AUTH STATUS] Biometric available -> .biometricAvailable")
                authState = .biometricAvailable
            } else {
                debugLog("🔑 [AUTH STATUS] Biometric not available -> .unauthenticated")
                authState = .unauthenticated
            }
            requiresReauth = false
            return
        }

        // Обычная проверка (при первом запуске)
        currentUser = user

        if isBiometricEnabled && canUseBiometric {
            debugLog("🔐 [AUTH STATUS] Biometric available and enabled -> .biometricAvailable")
            authState = .biometricAvailable
        } else {
            debugLog("✅ [AUTH STATUS] User authenticated -> .authenticated")
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
        debugLog("\n📝 [REGISTER] Starting registration process...")
        debugLog("👤 [REGISTER] Username: \(username)")
        debugLog("📧 [REGISTER] Email: \(email)")
        debugLog("🔒 [REGISTER] Password: ****** (length: \(password.count))")
        
        guard !username.isEmpty else {
            debugLog("❌ [REGISTER] FAILED: Username is empty")
            throw AuthenticationError.invalidCredentials
        }
        guard !email.isEmpty else {
            debugLog("❌ [REGISTER] FAILED: Email is empty")
            throw AuthenticationError.invalidEmail
        }

        debugLog("🔍 [REGISTER] Validating password...")
        let passwordValidation = validatePassword(password)
        guard passwordValidation.isValid else {
            debugLog("❌ [REGISTER] FAILED: Weak password - \(passwordValidation.message ?? "unknown")")
            throw AuthenticationError.weakPassword
        }
        debugLog("✅ [REGISTER] Password validation passed")
        
        // Validate email format
        debugLog("🔍 [REGISTER] Validating email format...")
        guard validateEmail(email) else {
            debugLog("❌ [REGISTER] FAILED: Invalid email format")
            throw AuthenticationError.invalidEmail
        }
        debugLog("✅ [REGISTER] Email format valid")
        
        // Check if email already exists
        debugLog("🔍 [REGISTER] Checking if email already exists...")
        if let existingUser = persistence.fetchUser(byEmail: email) {
            debugLog("❌ [REGISTER] FAILED: Email already exists (user: \(existingUser.username))")
            throw AuthenticationError.emailAlreadyExists
        }
        debugLog("✅ [REGISTER] Email is available")

        // Check email uniqueness — Supabase (online) or CloudKit (offline)
        if networkMonitor.isOnline {
            debugLog("☁️ [REGISTER] Checking email via Supabase Auth...")
            // Supabase Auth will reject duplicate emails during signUp — no pre-check needed
        } else {
            debugLog("☁️ [REGISTER] Offline — checking email in CloudKit Public DB...")
            do {
                if let cloudUser = try await cloudKitSync.fetchUser(byEmail: email) {
                    debugLog("❌ [REGISTER] FAILED: Email exists in CloudKit (userId: \(cloudUser.userId))")
                    isLoading = false
                    authState = .error("Пользователь с такой почтой уже существует")
                    throw AuthenticationError.emailAlreadyExists
                }
                debugLog("✅ [REGISTER] Email not found in CloudKit - OK to register")
            } catch {
                if let authError = error as? AuthenticationError { throw authError }
                debugLog("❌ [REGISTER] CloudKit check failed: \(error)")
                isLoading = false
                authState = .error("Ошибка проверки: \(error.localizedDescription)")
                throw AuthenticationError.unknown
            }
        }
        
        // NOTE: Локальная проверка username убрана
        // Email - единственный источник правды, хранится в CloudKit Public DB
        // Локальная БД может содержать устаревшие данные (после удаления приложения, при восстановлении и т.д.)
        // При создании нового User с уже существующим username - старый локальный User будет перезаписан

        debugLog("🔐 [REGISTER] Hashing password...")
        let passwordHash = hashPassword(password)
        debugLog("   - Hash: \(passwordHash.prefix(20))...")

        debugLog("💾 [REGISTER] Creating user in database...")
        if persistence.fetchUser(byUsername: username) != nil {
            debugLog("❌ [REGISTER] FAILED: Username already exists")
            throw AuthenticationError.userAlreadyExists
        }
        guard let user = persistence.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        ) else {
            debugLog("❌ [REGISTER] FAILED: Could not create user in database")
            throw AuthenticationError.unknown
        }
        debugLog("✅ [REGISTER] User created:")
        debugLog("   - UserId: \(user.userId)")
        debugLog("   - Username: \(user.username)")
        debugLog("   - Email: \(user.email ?? "nil")")

        debugLog("👤 [REGISTER] Creating PlayerProfile...")
        let profile = persistence.createPlayerProfile(displayName: username, userId: user.userId)
        debugLog("✅ [REGISTER] PlayerProfile created")

        // Sync user and profile via SyncCoordinator (Supabase primary / CloudKit fallback)
        debugLog("☁️ [REGISTER] Syncing via SyncCoordinator...")

        if networkMonitor.isOnline {
            do {
                let _ = try await supabaseAuth.signUp(
                    email: email,
                    password: password,
                    username: username,
                    displayName: username
                )
                debugLog("☁️ [REGISTER] Supabase Auth signUp succeeded")
            } catch {
                debugLog("⚠️ [REGISTER] Supabase signUp error: \(error) — continuing with local user")
            }
        }

        await syncCoordinator.quickSyncPlayerProfile(profile)
        debugLog("☁️ [REGISTER] Profile sync completed")

        debugLog("🔑 [REGISTER] Auto-login after registration...")
        try await login(email: email, password: password)
        
        // Показываем уведомление об успешной регистрации
        await MainActor.run {
            authState = .authenticated
        }
        debugLog("✅ [REGISTER] Registration completed successfully!")
    }

    // MARK: - Login
    func login(email: String, password: String) async throws {
        debugLog("\n🔑 [LOGIN] Starting login process...")
        debugLog("📧 [LOGIN] Email provided: \(email)")
        debugLog("🔒 [LOGIN] Password provided: \(password.isEmpty ? "empty" : "****** (length: \(password.count))")")
        
        isLoading = true
        authState = .authenticating

        // Небольшая задержка для UI
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Попытка 1: Поиск пользователя локально по email
        debugLog("🔍 [LOGIN] Attempt 1: Searching user locally by email...")
        var user = persistence.fetchUser(byEmail: email)
        
        if let localUser = user {
            debugLog("✅ [LOGIN] User found locally:")
            debugLog("   - Username: \(localUser.username)")
            debugLog("   - Email: \(localUser.email ?? "nil")")
            debugLog("   - UserId: \(localUser.userId)")
        } else {
            debugLog("⚠️ [LOGIN] User NOT found locally")
        }
        
        // Попытка 2: Если не найден локально — Supabase (online) или CloudKit (offline)
        if user == nil {
            if networkMonitor.isOnline {
                debugLog("🔍 [LOGIN] Attempt 2: Trying Supabase Auth signIn...")
                do {
                    let _ = try await supabaseAuth.signIn(email: email, password: password)
                    debugLog("✅ [LOGIN] Supabase Auth signIn succeeded — pulling profile...")
                    try? await syncCoordinator.smartSync()
                    user = persistence.fetchUser(byEmail: email)
                } catch {
                    debugLog("⚠️ [LOGIN] Supabase signIn failed: \(error)")
                }
            }

            if user == nil {
                debugLog("🔍 [LOGIN] Attempt 3: Trying to fetch from CloudKit...")
                do {
                    user = try await cloudKitSync.fetchUser(byEmail: email)
                    if let cloudUser = user {
                        debugLog("✅ [LOGIN] User restored from CloudKit: \(cloudUser.username)")
                    }
                } catch {
                    debugLog("❌ [LOGIN] Failed to fetch user from CloudKit: \(error)")
                }
            }
        }
        
        // Если пользователь все еще не найден - ошибка
        guard let foundUser = user else {
            debugLog("❌ [LOGIN] FAILED: User not found (neither locally nor in CloudKit)")
            isLoading = false
            authState = .error("Пользователь не найден")
            throw AuthenticationError.userNotFound
        }

        debugLog("🔐 [LOGIN] Validating password...")
        let passwordHash = hashPassword(password)
        debugLog("   - Password hash: \(passwordHash.prefix(20))...")
        debugLog("   - Stored hash: \(foundUser.passwordHash.prefix(20))...")
        
        guard foundUser.passwordHash == passwordHash else {
            debugLog("❌ [LOGIN] FAILED: Password does not match")
            isLoading = false
            authState = .error("Неверный пароль")
            throw AuthenticationError.invalidCredentials
        }
        
        debugLog("✅ [LOGIN] Password validated successfully")

        persistence.updateUserLastLogin(foundUser)
        debugLog("✅ [LOGIN] Updated last login timestamp")
        
        debugLog("💾 [LOGIN] Saving to Keychain...")
        _ = keychain.saveUserId(foundUser.userId.uuidString)
        _ = keychain.saveUsername(foundUser.username)
        debugLog("   - UserId saved: \(foundUser.userId)")
        debugLog("   - Username saved: \(foundUser.username)")

        currentUser = foundUser
        isLoading = false
        authState = .authenticated
        errorMessage = nil
        requiresReauth = false  // Сбрасываем флаг после успешного входа
        
        debugLog("✅ [LOGIN] Login successful! User: \(foundUser.username)\n")
    }

    // MARK: - Logout
    func logout() {
        debugLog("\n🚪 [LOGOUT] Starting logout...")
        debugLog("   - Current user: \(currentUser?.username ?? "nil")")
        debugLog("   - Biometric enabled: \(isBiometricEnabled)")
        
        currentUser = nil
        authState = .unauthenticated
        requiresReauth = true  // Требуем повторную аутентификацию
        
        // НЕ очищаем Keychain - оставляем userId и username для Face ID
        // Только очищаем текущую сессию и устанавливаем флаг требования повторной аутентификации
        debugLog("✅ [LOGOUT] Logout complete (Keychain preserved, reauth required)")
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
        debugLog("🔐 [BIOMETRIC] Starting biometric authentication...")
        
        guard canUseBiometric else {
            debugLog("❌ [BIOMETRIC] Biometric authentication not available")
            throw AuthenticationError.biometricFailed
        }

        // Создаем новый LAContext для каждой попытки
        let context = LAContext()
        let reason = "Войдите используя \(biometricName)"
        
        do {
            debugLog("🔐 [BIOMETRIC] Requesting \(biometricName) authentication...")
            debugLog("🔐 [BIOMETRIC] Creating new LAContext for fresh authentication attempt")
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                debugLog("✅ [BIOMETRIC] Biometric authentication successful")
                
                // Загружаем пользователя из Keychain
                guard let userIdString = keychain.getUserId(),
                      let userId = UUID(uuidString: userIdString) else {
                    debugLog("❌ [BIOMETRIC] No userId found in Keychain")
                    throw AuthenticationError.userNotFound
                }
                
                debugLog("🔍 [BIOMETRIC] Loading user from database: \(userId)")
                guard let user = persistence.fetchUser(byId: userId) else {
                    debugLog("❌ [BIOMETRIC] User not found in database: \(userId)")
                    throw AuthenticationError.userNotFound
                }
                
                debugLog("✅ [BIOMETRIC] User loaded: \(user.username) (email: \(user.email ?? "nil"))")
                
                // Устанавливаем пользователя
                currentUser = user
                authState = .authenticated
                requiresReauth = false  // Сбрасываем флаг после успешной биометрии
                
                debugLog("✅ [BIOMETRIC] Authentication complete")
            } else {
                debugLog("❌ [BIOMETRIC] Biometric authentication failed")
                throw AuthenticationError.biometricFailed
            }
        } catch {
            debugLog("❌ [BIOMETRIC] Error: \(error.localizedDescription)")
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

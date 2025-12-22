# Task 1.5: Обновление AuthViewModel

**Приоритет:** 🔴 Критический  
**Срок:** 2-3 дня  
**Статус:** 🟩 DONE  
**Исполнитель:** Cursor Agent  
**Начато:** 2025-12-21  
**Завершено:** 2025-12-21  
**Результат:** см. git log: `feat: обновлен AuthViewModel (Task 1.5)`  

---

## Описание

Обновить AuthViewModel для работы с новой моделью User, добавить регистрацию, улучшить безопасность с использованием CryptoKit.

---

## Предусловия

- ✅ Task 1.1 завершена (модель User создана)
- Существующий файл AuthViewModel.swift

---

## Задачи

### 1. Изучить текущий AuthViewModel

Откройте существующий файл и поймите текущую логику аутентификации.

### 2. Добавить зависимости

Импортируйте необходимые фреймворки:

```swift
import Foundation
import SwiftUI
import LocalAuthentication
import CryptoKit
import Combine
```

### 3. Создать enum для состояний авторизации

```swift
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
```

### 4. Обновить AuthViewModel

```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let persistence = PersistenceController.shared
    private let context = LAContext()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    private let currentUserIdKey = "currentUserId"
    private let biometricEnabledKey = "biometricEnabled"
    
    init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    
    func checkAuthenticationStatus() {
        // Проверить сохраненный userId
        guard let userIdString = UserDefaults.standard.string(forKey: currentUserIdKey),
              let userId = UUID(uuidString: userIdString),
              let user = persistence.fetchUser(byId: userId) else {
            authState = .unauthenticated
            return
        }
        
        currentUser = user
        
        // Проверить доступность биометрии
        if isBiometricEnabled && canUseBiometric {
            authState = .biometricAvailable
        } else {
            authState = .authenticated
        }
    }
    
    // MARK: - Registration
    
    func register(username: String, password: String, email: String?) async throws {
        // Валидация
        guard !username.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard password.count >= 6 else {
            throw AuthenticationError.weakPassword
        }
        
        // Проверить существование пользователя
        if persistence.fetchUser(byUsername: username) != nil {
            throw AuthenticationError.userAlreadyExists
        }
        
        // Хешировать пароль
        let passwordHash = hashPassword(password)
        
        // Создать пользователя
        guard let user = persistence.createUser(
            username: username,
            passwordHash: passwordHash,
            email: email
        ) else {
            throw AuthenticationError.unknown
        }
        
        // Создать PlayerProfile для пользователя
        let _ = persistence.createPlayerProfile(
            displayName: username,
            userId: user.userId
        )
        
        // Автоматический вход
        try await login(username: username, password: password)
    }
    
    // MARK: - Login
    
    func login(username: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            authState = .authenticating
        }
        
        // Небольшая задержка для UI
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Получить пользователя
        guard let user = persistence.fetchUser(byUsername: username) else {
            await MainActor.run {
                isLoading = false
                authState = .error("Пользователь не найден")
            }
            throw AuthenticationError.userNotFound
        }
        
        // Проверить пароль
        let passwordHash = hashPassword(password)
        guard user.passwordHash == passwordHash else {
            await MainActor.run {
                isLoading = false
                authState = .error("Неверный пароль")
            }
            throw AuthenticationError.invalidCredentials
        }
        
        // Обновить последний вход
        persistence.updateUserLastLogin(user)
        
        // Сохранить в UserDefaults
        UserDefaults.standard.set(user.userId.uuidString, forKey: currentUserIdKey)
        
        await MainActor.run {
            currentUser = user
            isLoading = false
            authState = .authenticated
            errorMessage = nil
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        currentUser = nil
        authState = .unauthenticated
        UserDefaults.standard.removeObject(forKey: currentUserIdKey)
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
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Биометрия"
        }
    }
    
    var isBiometricEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: biometricEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: biometricEnabledKey)
        }
    }
    
    func authenticateWithBiometric() async throws {
        guard canUseBiometric else {
            throw AuthenticationError.biometricFailed
        }
        
        let reason = "Войдите используя \(biometricName)"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                await MainActor.run {
                    authState = .authenticated
                }
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
        
        // Можно добавить дополнительные проверки
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
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    var currentUserId: UUID? {
        currentUser?.userId
    }
    
    var currentUsername: String {
        currentUser?.username ?? "Guest"
    }
}
```

### 5. Создать Views для аутентификации

Создайте `LoginView.swift`:

```swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var username = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.linearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .padding(.bottom, 30)
                
                Text("PokerTracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Login Form
                VStack(spacing: 15) {
                    TextField("Имя пользователя", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: login) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Войти")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || authViewModel.isLoading)
                }
                .padding(.horizontal, 30)
                
                // Biometric
                if authViewModel.canUseBiometric && authViewModel.isBiometricEnabled {
                    Button(action: authenticateWithBiometric) {
                        Label("Войти с \(authViewModel.biometricName)", 
                              systemImage: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                // Registration
                Button("Нет аккаунта? Зарегистрироваться") {
                    showingRegistration = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "Неизвестная ошибка")
            }
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
            }
        }
    }
    
    private func login() {
        Task {
            do {
                try await authViewModel.login(username: username, password: password)
            } catch {
                showingError = true
            }
        }
    }
    
    private func authenticateWithBiometric() {
        Task {
            do {
                try await authViewModel.authenticateWithBiometric()
            } catch {
                showingError = true
            }
        }
    }
}
```

Создайте `RegistrationView.swift`:

```swift
import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Учетные данные") {
                    TextField("Имя пользователя", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Email (опционально)", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
                
                Section("Пароль") {
                    SecureField("Пароль", text: $password)
                    SecureField("Подтвердите пароль", text: $confirmPassword)
                    
                    if !password.isEmpty {
                        let validation = authViewModel.validatePassword(password)
                        if !validation.isValid {
                            Text(validation.message ?? "")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button("Зарегистрироваться") {
                        register()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !username.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        authViewModel.validatePassword(password).isValid
    }
    
    private func register() {
        Task {
            do {
                try await authViewModel.register(
                    username: username,
                    password: password,
                    email: email.isEmpty ? nil : email
                )
                dismiss()
            } catch let error as AuthenticationError {
                errorMessage = error.errorDescription ?? "Ошибка регистрации"
                showingError = true
            } catch {
                errorMessage = "Неизвестная ошибка"
                showingError = true
            }
        }
    }
}
```

### 6. Обновить ContentView

```swift
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
                VStack {
                    Text("Ошибка")
                        .font(.headline)
                    Text(message)
                        .foregroundColor(.secondary)
                    Button("Попробовать снова") {
                        authViewModel.checkAuthenticationStatus()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
    }
}
```

Создайте `BiometricPromptView.swift`:

```swift
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
            // Автоматически показать биометрию
            authenticate()
        }
    }
    
    private func authenticate() {
        Task {
            try? await authViewModel.authenticateWithBiometric()
        }
    }
}
```

---

## Тестирование

### Unit тесты

`AuthViewModelTests.swift`:

```swift
import XCTest
@testable import PokerCardRecognizer

final class AuthViewModelTests: XCTestCase {
    var authViewModel: AuthViewModel!
    var persistence: PersistenceController!
    
    @MainActor
    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        authViewModel = AuthViewModel()
    }
    
    override func tearDown() {
        authViewModel = nil
        persistence = nil
        super.tearDown()
    }
    
    @MainActor
    func testRegistration() async throws {
        try await authViewModel.register(
            username: "testuser",
            password: "password123",
            email: "test@example.com"
        )
        
        XCTAssertNotNil(authViewModel.currentUser)
        XCTAssertEqual(authViewModel.currentUser?.username, "testuser")
        XCTAssertTrue(authViewModel.isAuthenticated)
    }
    
    @MainActor
    func testLogin() async throws {
        // Сначала зарегистрировать
        try await authViewModel.register(
            username: "logintest",
            password: "password123",
            email: nil
        )
        
        // Выйти
        authViewModel.logout()
        XCTAssertFalse(authViewModel.isAuthenticated)
        
        // Войти снова
        try await authViewModel.login(
            username: "logintest",
            password: "password123"
        )
        
        XCTAssertTrue(authViewModel.isAuthenticated)
    }
    
    @MainActor
    func testInvalidLogin() async {
        do {
            try await authViewModel.login(
                username: "nonexistent",
                password: "wrong"
            )
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is AuthenticationError)
        }
    }
    
    func testPasswordValidation() {
        let weak = authViewModel.validatePassword("123")
        XCTAssertFalse(weak.isValid)
        
        let noNumber = authViewModel.validatePassword("password")
        XCTAssertFalse(noNumber.isValid)
        
        let valid = authViewModel.validatePassword("password123")
        XCTAssertTrue(valid.isValid)
    }
}
```

---

## Критерии приемки

- [ ] AuthViewModel обновлен с регистрацией
- [ ] Используется CryptoKit для хеширования
- [ ] LoginView и RegistrationView созданы
- [ ] Биометрическая аутентификация работает
- [ ] Валидация пароля реализована
- [ ] Unit тесты проходят
- [ ] UI корректно отображается

---

## Следующие шаги

- **Task 1.6:** Создание GameService
- **Task 1.7:** Реализация фильтрации в MainView

---

## Заметки

- Пароли хешируются с SHA256
- В production нужно добавить salt
- Биометрия опциональна
- Можно добавить восстановление пароля позже

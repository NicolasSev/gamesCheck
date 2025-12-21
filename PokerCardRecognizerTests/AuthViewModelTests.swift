//
//  AuthViewModelTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.5: AuthViewModel tests
//

import Foundation
import Testing
@testable import PokerCardRecognizer

struct AuthViewModelTests {
    @Test @MainActor func registration_createsUserAndAuthenticates() async throws {
        let persistence = PersistenceController(inMemory: true)
        let defaults = UserDefaults(suiteName: "AuthViewModelTests.registration")!
        defaults.removePersistentDomain(forName: "AuthViewModelTests.registration")

        let vm = AuthViewModel(persistence: persistence, userDefaults: defaults)

        try await vm.register(
            username: "testuser",
            password: "password123",
            email: "test@example.com"
        )

        #expect(vm.currentUser != nil)
        #expect(vm.currentUser?.username == "testuser")
        #expect(vm.isAuthenticated == true)
        #expect(persistence.fetchUser(byUsername: "testuser") != nil)
    }

    @Test @MainActor func login_logout_flow() async throws {
        let persistence = PersistenceController(inMemory: true)
        let defaults = UserDefaults(suiteName: "AuthViewModelTests.login")!
        defaults.removePersistentDomain(forName: "AuthViewModelTests.login")

        // Подготовить пользователя напрямую
        _ = persistence.createUser(username: "logintest", passwordHash: "irrelevant")
        // Перезапишем корректным хешом через register (проверяет и создание профиля)
        let vm = AuthViewModel(persistence: persistence, userDefaults: defaults)
        try await vm.register(username: "logintest2", password: "password123", email: nil)

        vm.logout()
        #expect(vm.isAuthenticated == false)

        try await vm.login(username: "logintest2", password: "password123")
        #expect(vm.isAuthenticated == true)
    }

    @Test func passwordValidation_rules() async throws {
        let persistence = PersistenceController(inMemory: true)
        let defaults = UserDefaults(suiteName: "AuthViewModelTests.password")!
        defaults.removePersistentDomain(forName: "AuthViewModelTests.password")

        let vm = await MainActor.run { AuthViewModel(persistence: persistence, userDefaults: defaults) }

        let weak = await MainActor.run { vm.validatePassword("123") }
        #expect(weak.isValid == false)

        let noNumber = await MainActor.run { vm.validatePassword("password") }
        #expect(noNumber.isValid == false)

        let valid = await MainActor.run { vm.validatePassword("password123") }
        #expect(valid.isValid == true)
    }
}


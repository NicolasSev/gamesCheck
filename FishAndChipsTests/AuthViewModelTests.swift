//
//  AuthViewModelTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.5: AuthViewModel tests
//

import Foundation
import Testing
@testable import FishAndChips

@MainActor
struct AuthViewModelTests {
    @Test @MainActor func registration_createsUserAndAuthenticates() async throws {
        let persistence = PersistenceController(inMemory: true)
        let keychain = MockKeychainService()
        let cloudKitSync = MockAuthCloudKitSync()

        let vm = AuthViewModel(persistence: persistence, keychain: keychain, cloudKitSync: cloudKitSync)

        // Уникальный username для изоляции при параллельном запуске
        let username = "reg_\(UUID().uuidString.prefix(8))"
        let email = "\(username)@example.com"

        try await vm.register(
            username: username,
            password: "password123",
            email: email
        )

        #expect(vm.currentUser != nil)
        #expect(vm.currentUser?.username == username)
        #expect(vm.isAuthenticated == true)
        #expect(persistence.fetchUser(byUsername: username) != nil)
    }

    @Test @MainActor func login_logout_flow() async throws {
        let persistence = PersistenceController(inMemory: true)
        let keychain = MockKeychainService()
        let cloudKitSync = MockAuthCloudKitSync()

        let vm = AuthViewModel(persistence: persistence, keychain: keychain, cloudKitSync: cloudKitSync)
        try await vm.register(username: "logintest2", password: "password123", email: "logintest2@example.com")

        vm.logout()
        #expect(vm.isAuthenticated == false)

        try await vm.login(email: "logintest2@example.com", password: "password123")
        #expect(vm.isAuthenticated == true)
    }

    @Test func passwordValidation_rules() async throws {
        let persistence = PersistenceController(inMemory: true)
        let keychain = MockKeychainService()
        let cloudKitSync = MockAuthCloudKitSync()

        let vm = await MainActor.run {
            AuthViewModel(persistence: persistence, keychain: keychain, cloudKitSync: cloudKitSync)
        }

        let weak = await MainActor.run { vm.validatePassword("123") }
        #expect(weak.isValid == false)

        let noNumber = await MainActor.run { vm.validatePassword("password") }
        #expect(noNumber.isValid == false)

        let valid = await MainActor.run { vm.validatePassword("password123") }
        #expect(valid.isValid == true)
    }
}

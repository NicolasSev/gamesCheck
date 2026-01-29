//
//  AuthenticationTests.swift
//  PokerCardRecognizerTests
//
//  Created for Phase 2: Authentication & Security Enhancement
//

import XCTest
@testable import FishAndChips

@MainActor
final class AuthenticationTests: XCTestCase {
    var sut: AuthViewModel!
    var persistence: PersistenceController!
    var keychain: KeychainService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use in-memory persistence for testing
        persistence = PersistenceController(inMemory: true)
        keychain = KeychainService.shared
        sut = AuthViewModel(persistence: persistence, keychain: keychain)
    }
    
    override func tearDown() async throws {
        _ = keychain.clearAll()
        sut = nil
        persistence = nil
        try await super.tearDown()
    }
    
    // MARK: - Email Validation Tests
    
    func testValidEmailFormats() {
        XCTAssertTrue(sut.validateEmail("test@example.com"))
        XCTAssertTrue(sut.validateEmail("user.name@example.co.uk"))
        XCTAssertTrue(sut.validateEmail("user+tag@example.com"))
        XCTAssertTrue(sut.validateEmail("user123@test-domain.com"))
    }
    
    func testInvalidEmailFormats() {
        XCTAssertFalse(sut.validateEmail("invalid"))
        XCTAssertFalse(sut.validateEmail("@example.com"))
        XCTAssertFalse(sut.validateEmail("user@"))
        XCTAssertFalse(sut.validateEmail("user @example.com"))
        XCTAssertFalse(sut.validateEmail(""))
    }
    
    // MARK: - Password Validation Tests
    
    func testValidPasswords() {
        let result1 = sut.validatePassword("Pass123")
        XCTAssertTrue(result1.isValid)
        XCTAssertNil(result1.message)
        
        let result2 = sut.validatePassword("abc123")
        XCTAssertTrue(result2.isValid)
        XCTAssertNil(result2.message)
    }
    
    func testPasswordTooShort() {
        let result = sut.validatePassword("abc12")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "Минимум 6 символов")
    }
    
    func testPasswordNoNumbers() {
        let result = sut.validatePassword("abcdefgh")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "Пароль должен содержать буквы и цифры")
    }
    
    func testPasswordNoLetters() {
        let result = sut.validatePassword("123456")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "Пароль должен содержать буквы и цифры")
    }
    
    // MARK: - Registration Tests
    
    func testSuccessfulRegistration() async throws {
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.username, "testuser")
        XCTAssertEqual(sut.currentUser?.email, "test@example.com")
        XCTAssertTrue(sut.isAuthenticated)
    }
    
    func testRegistrationWithDuplicateUsername() async {
        do {
            try await sut.register(username: "testuser", password: "Pass123", email: "test1@example.com")
            try await sut.register(username: "testuser", password: "Pass456", email: "test2@example.com")
            XCTFail("Should throw userAlreadyExists error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.userAlreadyExists)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testRegistrationWithDuplicateEmail() async {
        do {
            try await sut.register(username: "user1", password: "Pass123", email: "test@example.com")
            sut.logout() // Logout first user
            try await sut.register(username: "user2", password: "Pass456", email: "test@example.com")
            XCTFail("Should throw emailAlreadyExists error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.emailAlreadyExists)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testRegistrationWithInvalidEmail() async {
        do {
            try await sut.register(username: "testuser", password: "Pass123", email: "invalid-email")
            XCTFail("Should throw invalidEmail error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.invalidEmail)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testRegistrationWithWeakPassword() async {
        do {
            try await sut.register(username: "testuser", password: "abc", email: "test@example.com")
            XCTFail("Should throw weakPassword error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.weakPassword)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Login Tests
    
    func testSuccessfulLogin() async throws {
        // First register
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        sut.logout()
        
        // Then login
        try await sut.login(username: "testuser", password: "Pass123")
        
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.username, "testuser")
        XCTAssertTrue(sut.isAuthenticated)
    }
    
    func testLoginWithWrongPassword() async {
        do {
            try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
            sut.logout()
            try await sut.login(username: "testuser", password: "WrongPass123")
            XCTFail("Should throw invalidCredentials error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.invalidCredentials)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testLoginWithNonexistentUser() async {
        do {
            try await sut.login(username: "nonexistent", password: "Pass123")
            XCTFail("Should throw userNotFound error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, AuthenticationError.userNotFound)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Logout Tests
    
    func testLogout() async throws {
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        XCTAssertTrue(sut.isAuthenticated)
        
        sut.logout()
        
        XCTAssertNil(sut.currentUser)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(keychain.getUserId())
    }
    
    // MARK: - Keychain Integration Tests
    
    func testKeychainStorageAfterLogin() async throws {
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        
        let storedUserId = keychain.getUserId()
        XCTAssertNotNil(storedUserId)
        XCTAssertEqual(storedUserId, sut.currentUser?.userId.uuidString)
        
        let storedUsername = keychain.getUsername()
        XCTAssertEqual(storedUsername, "testuser")
    }
    
    func testKeychainClearOnLogout() async throws {
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        XCTAssertNotNil(keychain.getUserId())
        
        sut.logout()
        
        XCTAssertNil(keychain.getUserId())
        XCTAssertNil(keychain.getUsername())
    }
    
    // MARK: - Session Management Tests
    
    func testCheckAuthenticationStatusWithValidSession() async throws {
        try await sut.register(username: "testuser", password: "Pass123", email: "test@example.com")
        
        // Create new ViewModel instance (simulating app restart)
        let newSut = AuthViewModel(persistence: persistence, keychain: keychain)
        
        XCTAssertNotNil(newSut.currentUser)
        XCTAssertEqual(newSut.currentUser?.username, "testuser")
    }
    
    func testCheckAuthenticationStatusWithoutSession() {
        let newSut = AuthViewModel(persistence: persistence, keychain: keychain)
        
        XCTAssertNil(newSut.currentUser)
        XCTAssertFalse(newSut.isAuthenticated)
    }
}

//
//  MockKeychainService.swift
//  FishAndChipsTests
//

import Foundation
@testable import FishAndChips

/// In-memory Keychain mock for isolated tests
final class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    
    func saveUserId(_ userId: String) -> Bool {
        storage["userId"] = userId
        return true
    }
    
    func getUserId() -> String? {
        storage["userId"]
    }
    
    func deleteUserId() -> Bool {
        storage.removeValue(forKey: "userId")
        return true
    }
    
    func saveUsername(_ username: String) -> Bool {
        storage["username"] = username
        return true
    }
    
    func getUsername() -> String? {
        storage["username"]
    }
    
    func deleteUsername() -> Bool {
        storage.removeValue(forKey: "username")
        return true
    }
    
    func setBiometricEnabled(_ enabled: Bool) -> Bool {
        storage["biometricEnabled"] = enabled ? "true" : "false"
        return true
    }
    
    func isBiometricEnabled() -> Bool {
        storage["biometricEnabled"] == "true"
    }
    
    func clearAll() -> Bool {
        storage.removeAll()
        return true
    }
}

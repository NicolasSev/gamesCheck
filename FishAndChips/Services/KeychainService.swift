//
//  KeychainService.swift
//  PokerCardRecognizer
//
//  Created for Phase 2: Authentication & Security Enhancement
//

import Foundation
import Security

/// Service for secure storage of sensitive data in iOS Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let userIdKey = "com.nicolascooper.FishAndChips.userId"
        static let usernameKey = "com.nicolascooper.FishAndChips.username"
        static let biometricEnabledKey = "com.nicolascooper.FishAndChips.biometricEnabled"
    }
    
    // MARK: - User ID Storage
    func saveUserId(_ userId: String) -> Bool {
        return save(key: Keys.userIdKey, value: userId)
    }
    
    func getUserId() -> String? {
        return load(key: Keys.userIdKey)
    }
    
    func deleteUserId() -> Bool {
        return delete(key: Keys.userIdKey)
    }
    
    // MARK: - Username Storage
    func saveUsername(_ username: String) -> Bool {
        return save(key: Keys.usernameKey, value: username)
    }
    
    func getUsername() -> String? {
        return load(key: Keys.usernameKey)
    }
    
    func deleteUsername() -> Bool {
        return delete(key: Keys.usernameKey)
    }
    
    // MARK: - Biometric Enabled Flag
    func setBiometricEnabled(_ enabled: Bool) -> Bool {
        return save(key: Keys.biometricEnabledKey, value: enabled ? "true" : "false")
    }
    
    func isBiometricEnabled() -> Bool {
        return load(key: Keys.biometricEnabledKey) == "true"
    }
    
    // MARK: - Clear All
    func clearAll() -> Bool {
        let userId = deleteUserId()
        let username = deleteUsername()
        return userId && username
    }
    
    // MARK: - Private Helpers
    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

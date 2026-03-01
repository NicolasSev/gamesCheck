//
//  MockAuthCloudKitSync.swift
//  FishAndChipsTests
//

import Foundation
@testable import FishAndChips

/// Mock CloudKit sync for auth tests — bypasses real CloudKit
final class MockAuthCloudKitSync: AuthCloudKitSyncProtocol {
    func fetchUser(byEmail email: String) async throws -> User? {
        nil
    }
    
    func quickSyncUser(_ user: User) async {
        // No-op
    }
    
    func quickSyncPlayerProfile(_ profile: PlayerProfile) async {
        // No-op
    }
}

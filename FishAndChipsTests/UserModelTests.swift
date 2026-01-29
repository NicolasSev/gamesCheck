//
//  UserModelTests.swift
//  PokerCardRecognizerTests
//
//  Task 1.1: User model tests
//

import Foundation
import Testing
@testable import FishAndChips

struct UserModelTests {
    @Test func createUser_setsDefaultValues() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(
            username: "testuser",
            passwordHash: "hashedpassword123",
            email: "test@example.com"
        )

        #expect(user != nil)
        #expect(user?.username == "testuser")
        #expect(user?.subscriptionStatus == "free")
        #expect(user?.isPremium == false)
        #expect(user?.email == "test@example.com")
        #expect(user?.userId != nil)
    }

    @Test func fetchUserByUsername_returnsCreatedUser() async throws {
        let persistence = PersistenceController(inMemory: true)

        let created = persistence.createUser(username: "fetchtest", passwordHash: "hash")
        #expect(created != nil)

        let fetched = persistence.fetchUser(byUsername: "fetchtest")
        #expect(fetched != nil)
        #expect(fetched?.userId == created?.userId)
    }

    @Test func premiumStatus_dependsOnExpirationDate() async throws {
        let persistence = PersistenceController(inMemory: true)

        let user = persistence.createUser(username: "premiumuser", passwordHash: "hash")
        #expect(user?.isPremium == false)

        let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        persistence.updateUserSubscription(user!, status: "premium", expiresAt: future)
        #expect(user?.isPremium == true)

        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        persistence.updateUserSubscription(user!, status: "premium", expiresAt: past)
        #expect(user?.isSubscriptionExpired == true)
        #expect(user?.isPremium == false)
    }

    @Test func createUser_rejectsDuplicateUsername() async throws {
        let persistence = PersistenceController(inMemory: true)

        let first = persistence.createUser(username: "dup", passwordHash: "hash")
        #expect(first != nil)

        let second = persistence.createUser(username: "dup", passwordHash: "hash2")
        #expect(second == nil)
    }
}


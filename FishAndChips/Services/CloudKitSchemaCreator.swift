//
//  CloudKitSchemaCreator.swift
//  FishAndChips
//
//  Utility to help create CloudKit schema in Development environment
//  ⚠️ This only works when CloudKit Dashboard is set to "Development" mode
//

import CloudKit
import Foundation

/// Helper class to create CloudKit schema programmatically
/// This only works in Development environment
class CloudKitSchemaCreator {
    
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.nicolascooper.FishAndChips")
        self.database = container.privateCloudDatabase
    }
    
    /// Creates sample records to automatically generate schema in Development mode
    /// CloudKit will infer the schema from these records
    func createDevelopmentSchema() async throws {
        print("🔧 Creating CloudKit schema in Development mode...")
        
        // Create sample User record
        try await createSampleUserRecord()
        
        // Create sample Game record
        try await createSampleGameRecord()
        
        // Create sample PlayerProfile record
        try await createSamplePlayerProfileRecord()
        
        // Create sample PlayerAlias record
        try await createSamplePlayerAliasRecord()
        
        // Create sample PlayerClaim record
        try await createSamplePlayerClaimRecord()
        
        print("✅ Development schema created successfully!")
        print("⚠️ Now go to CloudKit Dashboard and:")
        print("   1. Select 'Development' environment")
        print("   2. Go to Schema → Record Types")
        print("   3. Add indexes as needed")
        print("   4. Deploy to Production")
    }
    
    // MARK: - Sample Record Creation
    
    private func createSampleUserRecord() async throws {
        let record = CKRecord(recordType: "User")
        record["username"] = "sample_user" as CKRecordValue
        record["email"] = "sample@example.com" as CKRecordValue
        record["passwordHash"] = "hash" as CKRecordValue
        record["subscriptionStatus"] = "none" as CKRecordValue
        record["isSuperAdmin"] = 0 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["lastLoginAt"] = Date() as CKRecordValue
        record["subscriptionExpiresAt"] = Date() as CKRecordValue
        
        try await database.save(record)
        print("✓ User record type created")
    }
    
    private func createSampleGameRecord() async throws {
        let record = CKRecord(recordType: "Game")
        record["gameType"] = "poker" as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["isPublic"] = 0 as CKRecordValue
        record["softDeleted"] = 0 as CKRecordValue
        record["notes"] = "" as CKRecordValue
        // Reference will be nil for sample
        
        try await database.save(record)
        print("✓ Game record type created")
    }
    
    private func createSamplePlayerProfileRecord() async throws {
        let record = CKRecord(recordType: "PlayerProfile")
        record["displayName"] = "Sample Player" as CKRecordValue
        record["isAnonymous"] = 0 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["totalGamesPlayed"] = 0 as CKRecordValue
        record["totalBuyins"] = 0.0 as CKRecordValue
        record["totalCashouts"] = 0.0 as CKRecordValue
        
        try await database.save(record)
        print("✓ PlayerProfile record type created")
    }
    
    private func createSamplePlayerAliasRecord() async throws {
        let record = CKRecord(recordType: "PlayerAlias")
        record["aliasName"] = "Sample Alias" as CKRecordValue
        record["claimedAt"] = Date() as CKRecordValue
        record["gamesCount"] = 0 as CKRecordValue
        
        try await database.save(record)
        print("✓ PlayerAlias record type created")
    }
    
    private func createSamplePlayerClaimRecord() async throws {
        let record = CKRecord(recordType: "PlayerClaim")
        record["playerName"] = "Sample Player" as CKRecordValue
        record["gameWithPlayerObjectId"] = "sample-id" as CKRecordValue
        record["status"] = "pending" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["resolvedAt"] = Date() as CKRecordValue
        record["notes"] = "" as CKRecordValue
        
        try await database.save(record)
        print("✓ PlayerClaim record type created")
    }
}

// MARK: - Usage Instructions

/*
 How to use this schema creator:
 
 1. In CloudKit Dashboard, make sure you're in DEVELOPMENT environment
 2. Add this code to your app's initialization (e.g., in FishAndChipsApp.swift):
 
    .onAppear {
        #if DEBUG
        Task {
            do {
                try await CloudKitSchemaCreator().createDevelopmentSchema()
            } catch {
                print("❌ Schema creation failed: \(error)")
            }
        }
        #endif
    }
 
 3. Run the app once
 4. Go to CloudKit Dashboard → Development → Schema → Record Types
 5. You should see all record types created
 6. Add indexes where needed (username, email, displayName, etc.)
 7. Deploy schema to Production using "Deploy Schema Changes"
 
 ⚠️ IMPORTANT: This only works in Development environment!
 ⚠️ After schema is deployed to Production, remove or comment out this code
 */

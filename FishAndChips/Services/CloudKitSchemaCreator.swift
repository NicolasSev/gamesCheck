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
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.nicolascooper.FishAndChips")
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
    }
    
    /// Creates sample records to automatically generate schema in Development mode
    /// CloudKit will infer the schema from these records
    func createDevelopmentSchema() async throws {
        print("🔧 Creating CloudKit schema in Development mode...")
        print("")
        print("📋 PRIVATE DATABASE (личные данные пользователя):")
        
        // Private Database records
        try await createSampleUserRecord()
        try await createSamplePlayerProfileRecord()
        try await createSamplePlayerClaimRecord()
        
        print("")
        print("🌍 PUBLIC DATABASE (публичные игры и псевдонимы):")
        
        // Public Database records
        try await createSampleGameRecord()
        try await createSampleGameWithPlayerRecord()
        try await createSamplePlayerAliasRecord()
        
        print("")
        print("✅ Development schema created successfully!")
        print("")
        print("⚠️ Now go to CloudKit Dashboard and:")
        print("   1. Select 'Development' environment")
        print("   2. Check Private Database → Record Types:")
        print("      - User, PlayerProfile, PlayerClaim")
        print("   3. Check Public Database → Record Types:")
        print("      - Game, GameWithPlayer, PlayerAlias")
        print("   4. Add indexes if needed")
        print("   5. Deploy to Production")
    }
    
    // MARK: - Sample Record Creation - PRIVATE DATABASE
    
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
        
        try await privateDB.save(record)
        print("  ✓ User (Private)")
    }
    
    private func createSamplePlayerProfileRecord() async throws {
        let record = CKRecord(recordType: "PlayerProfile")
        record["displayName"] = "Sample Player" as CKRecordValue
        record["isAnonymous"] = 0 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["totalGamesPlayed"] = 0 as CKRecordValue
        record["totalBuyins"] = 0.0 as CKRecordValue
        record["totalCashouts"] = 0.0 as CKRecordValue
        
        try await privateDB.save(record)
        print("  ✓ PlayerProfile (Private)")
    }
    
    private func createSamplePlayerClaimRecord() async throws {
        let record = CKRecord(recordType: "PlayerClaim")
        record["playerName"] = "Sample Player" as CKRecordValue
        record["gameWithPlayerObjectId"] = "sample-id" as CKRecordValue
        record["status"] = "pending" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["resolvedAt"] = Date() as CKRecordValue
        record["notes"] = "" as CKRecordValue
        
        try await privateDB.save(record)
        print("  ✓ PlayerClaim (Private)")
    }
    
    // MARK: - Sample Record Creation - PUBLIC DATABASE
    
    private func createSampleGameRecord() async throws {
        let record = CKRecord(recordType: "Game")
        record["gameType"] = "poker" as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["isPublic"] = 0 as CKRecordValue
        record["softDeleted"] = 0 as CKRecordValue
        record["notes"] = "" as CKRecordValue
        record["gameCode"] = "ABC123" as CKRecordValue
        // Reference will be nil for sample
        
        try await publicDB.save(record)
        print("  ✓ Game (Public)")
    }
    
    private func createSampleGameWithPlayerRecord() async throws {
        let record = CKRecord(recordType: "GameWithPlayer")
        record["playerPosition"] = 1 as CKRecordValue
        record["buyIn"] = 100.0 as CKRecordValue
        record["cashOut"] = 150.0 as CKRecordValue
        record["profitLoss"] = 50.0 as CKRecordValue
        
        try await publicDB.save(record)
        print("  ✓ GameWithPlayer (Public)")
    }
    
    private func createSamplePlayerAliasRecord() async throws {
        let record = CKRecord(recordType: "PlayerAlias")
        record["aliasName"] = "Sample Alias" as CKRecordValue
        record["claimedAt"] = Date() as CKRecordValue
        record["gamesCount"] = 0 as CKRecordValue
        
        try await publicDB.save(record)
        print("  ✓ PlayerAlias (Public)")
    }
}

// MARK: - Usage Instructions

/*
 How to use this schema creator:
 
 🎯 ЦЕЛЬ: Создать правильную схему CloudKit с разделением на Public/Private Database
 
 📋 ШАГ 1: Временно добавить код
 
 В FishAndChipsApp.swift в ContentView.onAppear добавь:
 
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
 
 📱 ШАГ 2: Запустить приложение один раз
 
 - В консоли увидишь:
   📋 PRIVATE DATABASE (личные данные пользователя):
     ✓ User (Private)
     ✓ PlayerProfile (Private)
     ✓ PlayerClaim (Private)
   
   🌍 PUBLIC DATABASE (публичные игры и псевдонимы):
     ✓ Game (Public)
     ✓ GameWithPlayer (Public)
     ✓ PlayerAlias (Public)
 
 🌐 ШАГ 3: Проверить в CloudKit Dashboard
 
 1. Открой: https://icloud.developer.apple.com/dashboard
 2. Выбери контейнер: iCloud.com.nicolascooper.FishAndChips
 3. Выбери окружение: Development
 4. Проверь Private Database → Schema → Record Types:
    - User ✓
    - PlayerProfile ✓
    - PlayerClaim ✓
 5. Проверь Public Database → Schema → Record Types:
    - Game ✓
    - GameWithPlayer ✓
    - PlayerAlias ✓
 
 📊 ШАГ 4: Добавить индексы (опционально, для оптимизации)
 
 Game (Public):
 - createdAt: Queryable, Sortable
 - gameCode: Queryable
 - softDeleted: Queryable
 
 GameWithPlayer (Public):
 - gameId (reference): Queryable
 
 PlayerClaim (Private):
 - status: Queryable
 - createdAt: Sortable
 
 🚀 ШАГ 5: Deploy в Production (когда будешь готов)
 
 В CloudKit Dashboard:
 - Schema → Deploy Schema Changes
 - Выбери изменения для деплоя
 - Confirm deployment
 
 🧹 ШАГ 6: Удалить этот код после создания схемы
 
 После успешного создания схемы:
 - Удали .onAppear код из FishAndChipsApp.swift
 - Или оставь под #if DEBUG для будущих изменений
 
 ⚠️ ВАЖНО:
 - Это работает только в Development!
 - После деплоя в Production нельзя изменить тип базы данных (Public/Private)
 - Sample записи можно удалить из CloudKit Dashboard после создания схемы
 */

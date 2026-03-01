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
        debugLog("🔧 Creating CloudKit schema in Development mode...")
        debugLog("")
        debugLog("📋 PRIVATE DATABASE (личные данные пользователя):")
        
        // Private Database records
        try await createSampleUserRecord()
        try await createSamplePlayerProfileRecord()
        try await createSamplePlayerClaimRecord()
        
        debugLog("")
        debugLog("🌍 PUBLIC DATABASE (публичные игры и псевдонимы):")
        
        // Public Database records
        try await createSampleGameRecord()
        try await createSampleGameWithPlayerRecord()
        try await createSamplePlayerAliasRecord()
        
        // Phase 2: Materialized views (Public DB)
        try await createSampleUserStatisticsSummaryRecord()
        try await createSampleGameSummaryRecord()
        try await createSampleUserGameIndexRecord()
        
        debugLog("")
        debugLog("✅ Development schema created successfully!")
        debugLog("")
        debugLog("⚠️ Now go to CloudKit Dashboard and:")
        debugLog("   1. Select 'Development' environment")
        debugLog("   2. Check Private Database → Record Types:")
        debugLog("      - User, PlayerProfile, PlayerClaim")
        debugLog("   3. Check Public Database → Record Types:")
        debugLog("      - Game, GameWithPlayer, PlayerAlias")
        debugLog("   4. Add indexes if needed")
        debugLog("   5. Deploy to Production")
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
        debugLog("  ✓ User (Private)")
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
        debugLog("  ✓ PlayerProfile (Private)")
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
        debugLog("  ✓ PlayerClaim (Private)")
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
        debugLog("  ✓ Game (Public)")
    }
    
    private func createSampleGameWithPlayerRecord() async throws {
        let record = CKRecord(recordType: "GameWithPlayer")
        record["playerPosition"] = 1 as CKRecordValue
        record["buyIn"] = 100.0 as CKRecordValue
        record["cashOut"] = 150.0 as CKRecordValue
        record["profitLoss"] = 50.0 as CKRecordValue
        
        try await publicDB.save(record)
        debugLog("  ✓ GameWithPlayer (Public)")
    }
    
    private func createSamplePlayerAliasRecord() async throws {
        let record = CKRecord(recordType: "PlayerAlias")
        record["aliasName"] = "Sample Alias" as CKRecordValue
        record["claimedAt"] = Date() as CKRecordValue
        record["gamesCount"] = 0 as CKRecordValue
        
        try await publicDB.save(record)
        debugLog("  ✓ PlayerAlias (Public)")
    }

    // MARK: - Phase 2: Materialized Views (Public DB)

    private func createSampleUserStatisticsSummaryRecord() async throws {
        let record = CKRecord(recordType: "UserStatisticsSummary")
        record["userId"] = UUID().uuidString as CKRecordValue
        record["totalGamesPlayed"] = 0 as CKRecordValue
        record["totalBuyins"] = 0.0 as CKRecordValue
        record["totalCashouts"] = 0.0 as CKRecordValue
        record["balance"] = 0.0 as CKRecordValue
        record["winRate"] = 0.0 as CKRecordValue
        record["avgProfit"] = 0.0 as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue

        try await publicDB.save(record)
        debugLog("  ✓ UserStatisticsSummary (Public)")
    }

    private func createSampleGameSummaryRecord() async throws {
        let record = CKRecord(recordType: "GameSummary")
        record["gameId"] = UUID().uuidString as CKRecordValue
        record["gameType"] = "poker" as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["totalPlayers"] = 0 as CKRecordValue
        record["totalBuyins"] = 0.0 as CKRecordValue
        record["isPublic"] = 0 as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue

        try await publicDB.save(record)
        debugLog("  ✓ GameSummary (Public)")
    }

    private func createSampleUserGameIndexRecord() async throws {
        let record = CKRecord(recordType: "UserGameIndex")
        record["indexId"] = UUID().uuidString as CKRecordValue
        record["userId"] = UUID().uuidString as CKRecordValue
        record["gameId"] = UUID().uuidString as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["buyin"] = 0.0 as CKRecordValue
        record["cashout"] = 0.0 as CKRecordValue
        record["isHost"] = 0 as CKRecordValue

        try await publicDB.save(record)
        debugLog("  ✓ UserGameIndex (Public)")
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
                debugLog("❌ Schema creation failed: \(error)")
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

import SwiftUI
import CoreData

/// Экран для отладки и тестирования миграций
struct DebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    private let keychain = KeychainService.shared
    
    @State private var migrationStatus = ""
    @State private var userInfo = ""
    @State private var gamesInfo = ""
    @State private var cloudKitStatus = ""
    @State private var isCreatingSchema = false
    @State private var isSyncing = false
    
    var body: some View {
        NavigationView {
            List {
                Section("User Info") {
                    Text(userInfo)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button("Refresh User Info") {
                        loadUserInfo()
                    }
                }
                
                Section("Games Info") {
                    Text(gamesInfo)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button("Refresh Games Info") {
                        loadGamesInfo()
                    }
                }
                
                Section("CloudKit") {
                    Text(cloudKitStatus)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button(action: {
                        Task {
                            await createCloudKitSchema()
                        }
                    }) {
                        if isCreatingSchema {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Creating Schema...")
                            }
                        } else {
                            Text("Create CloudKit Schema")
                        }
                    }
                    .disabled(isCreatingSchema)
                    .foregroundColor(.orange)
                    
                    Button(action: {
                        Task {
                            await manualSync()
                        }
                    }) {
                        if isSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                            }
                        } else {
                            Text("Manual CloudKit Sync")
                        }
                    }
                    .disabled(isSyncing)
                    .foregroundColor(.blue)
                }
                
                Section("Migration") {
                    Text(migrationStatus)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button("Reset Migration Flag") {
                        resetMigrationFlag()
                    }
                    
                    Button("Run Migration Now") {
                        runMigration()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Actions") {
                    Button("Clear All UserDefaults") {
                        clearUserDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Debug")
            .onAppear {
                loadUserInfo()
                loadGamesInfo()
            }
        }
    }
    
    private func loadUserInfo() {
        if let userIdString = keychain.getUserId(),
           let userId = UUID(uuidString: userIdString) {
            userInfo = """
            currentUserId: \(userId.uuidString)
            hasMigratedCreatorUserId: \(UserDefaults.standard.bool(forKey: "hasMigratedCreatorUserId"))
            Source: Keychain ✅
            """
        } else {
            userInfo = """
            No currentUserId found in Keychain ❌
            Checking UserDefaults (legacy): \(UserDefaults.standard.string(forKey: "currentUserId") ?? "none")
            """
        }
    }
    
    private func loadGamesInfo() {
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let games = try viewContext.fetch(fetchRequest)
            gamesInfo = """
            Total games: \(games.count)
            Games with creatorUserId: \(games.filter { $0.creatorUserId != nil }.count)
            Games without creatorUserId: \(games.filter { $0.creatorUserId == nil }.count)
            
            Recent games:
            \(games.prefix(5).map { game in
                "- \(game.timestamp?.formatted() ?? "No date"): creatorUserId=\(game.creatorUserId?.uuidString ?? "nil")"
            }.joined(separator: "\n"))
            """
        } catch {
            gamesInfo = "Error: \(error.localizedDescription)"
        }
    }
    
    private func resetMigrationFlag() {
        UserDefaults.standard.set(false, forKey: "hasMigratedCreatorUserId")
        migrationStatus = "✅ Migration flag reset. Restart app to run migration."
        loadUserInfo()
    }
    
    private func runMigration() {
        guard let userIdString = keychain.getUserId(),
              let userId = UUID(uuidString: userIdString) else {
            migrationStatus = "❌ No currentUserId found in Keychain"
            return
        }
        
        let importService = DataImportService(viewContext: viewContext, userId: userId)
        
        do {
            try importService.updateCreatorUserIdForAllGames()
            migrationStatus = "✅ Migration completed successfully"
            loadGamesInfo()
        } catch {
            migrationStatus = "❌ Migration failed: \(error.localizedDescription)"
        }
    }
    
    private func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        migrationStatus = "⚠️ All UserDefaults cleared. Restart app."
        loadUserInfo()
    }
    
    private func createCloudKitSchema() async {
        isCreatingSchema = true
        cloudKitStatus = "🔄 Creating CloudKit schema..."
        
        do {
            try await CloudKitSchemaCreator().createDevelopmentSchema()
            cloudKitStatus = """
            ✅ CloudKit schema created successfully!
            
            Next steps:
            1. Open CloudKit Dashboard
            2. Check Development → Public Database:
               - Game ✓
               - GameWithPlayer ✓
               - PlayerAlias ✓
            3. Check Development → Private Database:
               - User ✓
               - PlayerProfile ✓
               - PlayerClaim ✓
            4. Deploy schema to Production
            5. Run Manual CloudKit Sync
            """
        } catch {
            cloudKitStatus = "❌ Failed to create schema: \(error.localizedDescription)"
        }
        
        isCreatingSchema = false
    }
    
    private func manualSync() async {
        isSyncing = true
        cloudKitStatus = "🔄 Syncing with CloudKit..."
        
        do {
            try await CloudKitSyncService.shared.performFullSync()
            cloudKitStatus = """
            ✅ CloudKit sync completed!
            
            Check CloudKit Dashboard to verify:
            - Games synced to Public DB
            - GameWithPlayer records synced
            - Users synced to Private DB
            """
            loadGamesInfo()
        } catch {
            cloudKitStatus = "❌ Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
}

#Preview {
    DebugView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

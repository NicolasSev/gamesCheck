import SwiftUI
import CoreData

/// Экран для отладки и тестирования миграций
struct DebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var migrationStatus = ""
    @State private var userInfo = ""
    @State private var gamesInfo = ""
    
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
        if let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: userIdString) {
            userInfo = """
            currentUserId: \(userId.uuidString)
            hasMigratedCreatorUserId: \(UserDefaults.standard.bool(forKey: "hasMigratedCreatorUserId"))
            """
        } else {
            userInfo = "No currentUserId found"
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
        guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdString) else {
            migrationStatus = "❌ No currentUserId found"
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
}

#Preview {
    DebugView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

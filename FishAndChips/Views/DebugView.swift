import SwiftUI
import CoreData

/// Экран для отладки и тестирования миграций
struct DebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    private let keychain = KeychainService.shared
    
    @State private var migrationStatus = ""
    @State private var userInfo = ""
    @State private var gamesInfo = ""
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineSyncQueue.shared
    @State private var isForcingSupabase = false
    @State private var isRefreshingUser = false
    @State private var isRefreshingGames = false
    @State private var userRefreshSuccess = false
    @State private var gamesRefreshSuccess = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(userInfo)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button(action: {
                        Task {
                            await refreshUserInfo()
                        }
                    }) {
                        HStack {
                            if isRefreshingUser {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Refreshing...")
                            } else if userRefreshSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Refreshed!")
                            } else {
                                Text("Refresh User Info")
                            }
                        }
                    }
                    .disabled(isRefreshingUser)
                    .buttonStyle(.borderedProminent)
                    .tint(userRefreshSuccess ? .green : Color.casinoAccentGreen)
                } header: {
                    Text("User Info")
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Section {
                    Text(gamesInfo)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button(action: {
                        Task {
                            await refreshGamesInfo()
                        }
                    }) {
                        HStack {
                            if isRefreshingGames {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Refreshing...")
                            } else if gamesRefreshSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Refreshed!")
                            } else {
                                Text("Refresh Games Info")
                            }
                        }
                    }
                    .disabled(isRefreshingGames)
                    .buttonStyle(.borderedProminent)
                    .tint(gamesRefreshSuccess ? .green : Color.casinoAccentGreen)
                } header: {
                    Text("Games Info")
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Section {
                    HStack {
                        Circle()
                            .fill(networkMonitor.isOnline ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text("Network: \(networkMonitor.isOnline ? "Online" : "Offline") (\(networkMonitor.connectionType.rawValue))")
                    }

                    HStack {
                        Circle()
                            .fill(syncCoordinator.isSyncing ? Color.orange : Color.green)
                            .frame(width: 10, height: 10)
                        Text("Sync: \(syncCoordinator.syncStatusText)")
                    }

                    HStack {
                        Circle()
                            .fill(offlineQueue.pendingCount > 0 ? Color.yellow : Color.green)
                            .frame(width: 10, height: 10)
                        Text("Offline Queue: \(offlineQueue.pendingCount) pending\(offlineQueue.isProcessing ? " (processing...)" : "")")
                    }

                    Text("Backend: \(BackendSwitch.isSupabase ? "Supabase" : "CloudKit")")
                        .font(.system(.caption, design: .monospaced))

                    Button("Force Supabase Sync") {
                        Task {
                            isForcingSupabase = true
                            defer { isForcingSupabase = false }
                            do { try await SupabaseSyncService.shared.performFullSync() }
                            catch { debugLog("Force Supabase sync error: \(error)") }
                        }
                    }
                    .disabled(isForcingSupabase)
                    .foregroundColor(.purple)

                    Button("Process Offline Queue") {
                        Task { await offlineQueue.processQueue() }
                    }
                    .disabled(offlineQueue.pendingCount == 0 || offlineQueue.isProcessing)
                    .foregroundColor(.orange)
                } header: {
                    Text("Backend Status")
                        .foregroundColor(.white.opacity(0.85))
                }

                Section {
                    Text(migrationStatus)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button("Reset Migration Flag") {
                        resetMigrationFlag()
                    }
                    
                    Button("Run Migration Now") {
                        runMigration()
                    }
                    .foregroundColor(Color.casinoAccentGreen)
                } header: {
                    Text("Migration")
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Section {
                    Button("Clear All UserDefaults") {
                        clearUserDefaults()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Actions")
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .listRowBackground(Color.white.opacity(0.08))
            .accessibilityIdentifier("debug_view_root")
            .navigationTitle("Debug")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .v2ScreenBackground()
            .preferredColorScheme(.dark)
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
    
    private func refreshUserInfo() async {
        isRefreshingUser = true
        userRefreshSuccess = false
        
        // Имитация загрузки (для визуального эффекта)
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 сек
        
        loadUserInfo()
        
        isRefreshingUser = false
        userRefreshSuccess = true
        
        // Сброс success состояния через 2 секунды
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 сек
        userRefreshSuccess = false
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
    
    private func refreshGamesInfo() async {
        isRefreshingGames = true
        gamesRefreshSuccess = false
        
        // Имитация загрузки (для визуального эффекта)
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 сек
        
        loadGamesInfo()
        
        isRefreshingGames = false
        gamesRefreshSuccess = true
        
        // Сброс success состояния через 2 секунды
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 сек
        gamesRefreshSuccess = false
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
    
}

#Preview {
    DebugView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

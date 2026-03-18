//
//  FishAndChipsApp.swift
//  FishAndChips
//
//  Created by Николас on 24.03.2025.
//

import SwiftUI
import UserNotifications

@main
struct FishAndChipsApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var deepLinkService = DeepLinkService()
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var isInitialSyncComplete = false

    init() {
        // Миграция игр (Task 1.2) — один раз после обновления модели
        let hasMigratedGames = UserDefaults.standard.bool(forKey: "hasMigratedGamesToV2")
        if !hasMigratedGames {
            persistenceController.migrateExistingGames()
            UserDefaults.standard.set(true, forKey: "hasMigratedGamesToV2")
        }
        
        // Миграция creatorUserId — один раз для исправления импортированных игр
        let hasMigratedCreatorUserId = UserDefaults.standard.bool(forKey: "hasMigratedCreatorUserId")
        debugLog("🔧 hasMigratedCreatorUserId: \(hasMigratedCreatorUserId)")
        if !hasMigratedCreatorUserId {
            let keychain = KeychainService.shared
            if let userIdString = keychain.getUserId(),
               let userId = UUID(uuidString: userIdString) {
                debugLog("🔧 Starting creatorUserId migration for user: \(userId)")
                let importService = DataImportService(
                    viewContext: persistenceController.container.viewContext,
                    userId: userId
                )
                try? importService.updateCreatorUserIdForAllGames()
                UserDefaults.standard.set(true, forKey: "hasMigratedCreatorUserId")
                debugLog("🔧 Migration completed and flag set")
            } else {
                debugLog("⚠️ Cannot migrate: no currentUserId found in Keychain")
            }
        } else {
            debugLog("✅ Migration already completed")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppBodyView(
                isInitialSyncComplete: $isInitialSyncComplete,
                persistenceController: persistenceController,
                notificationService: notificationService,
                deepLinkService: deepLinkService,
                syncCoordinator: syncCoordinator
            )
        }
    }
}

struct AppBodyView: View {
    @Binding var isInitialSyncComplete: Bool
    let persistenceController: PersistenceController
    @ObservedObject var notificationService: NotificationService
    @ObservedObject var deepLinkService: DeepLinkService
    @ObservedObject var syncCoordinator: SyncCoordinator
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if isInitialSyncComplete {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(notificationService)
                    .environmentObject(deepLinkService)
                    .environmentObject(syncCoordinator)
                    .onOpenURL { url in
                        debugLog("🔗 App received URL: \(url)")
                        deepLinkService.handleURL(url)
                    }
                    .onAppear {
                        // Request notification permissions
                        Task {
                            try? await notificationService.requestAuthorization()
                            await MainActor.run {
                                notificationService.registerForRemoteNotifications()
                            }
                        }

                        // Test CloudKit connection
                        Task {
                            do {
                                let status = try await CloudKitService.shared.checkAccountStatus()
                                switch status {
                                case .available:
                                    debugLog("✅ CloudKit Status: AVAILABLE - Ready to use!")
                                case .noAccount:
                                    debugLog("❌ CloudKit Status: NO ACCOUNT - Please sign in to iCloud")
                                case .restricted:
                                    debugLog("⚠️ CloudKit Status: RESTRICTED - iCloud access is restricted")
                                case .couldNotDetermine:
                                    debugLog("⚠️ CloudKit Status: COULD NOT DETERMINE")
                                case .temporarilyUnavailable:
                                    debugLog("⚠️ CloudKit Status: TEMPORARILY UNAVAILABLE")
                                @unknown default:
                                    debugLog("⚠️ CloudKit Status: UNKNOWN")
                                }
                            } catch {
                                debugLog("❌ CloudKit Status Check Failed: \(error.localizedDescription)")
                            }
                        }
                    }
            } else {
                // Splash Screen с фоновым изображением
                SplashScreenView()
            }
        }
        .task {
            // Phase 3: Smart Sync — витринная двухфазная загрузка
            do {
                // Phase 1: Минимальная загрузка для быстрого показа UI
                // Phase 2 (в фоне): Проверка витрин, при расхождении — полная синхронизация
                debugLog("🚀 Starting smart sync...")
                try await syncCoordinator.smartSync()
                isInitialSyncComplete = true
                debugLog("✅ Smart sync Phase 1 completed - UI ready")

                // Phase 2: Миграция materialized views - один раз (после синхронизации)
                let hasMigrated = UserDefaults.standard.bool(forKey: "hasMigratedMaterializedViewsV1")
                if !hasMigrated {
                    try? await DataMigrationService().generateMaterializedViews()
                    UserDefaults.standard.set(true, forKey: "hasMigratedMaterializedViewsV1")
                }
            } catch {
                debugLog("❌ Sync error: \(error)")
                // Не блокируем запуск приложения при ошибке синхронизации
                isInitialSyncComplete = true
            }
        }
        // Синхронизация при возврате из фона
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                debugLog("🔄 App became active, starting background sync...")
                Task {
                    do {
                        // Используем incremental sync если возможно
                        try await syncCoordinator.performIncrementalSync()
                        debugLog("✅ Background sync completed")
                    } catch {
                        debugLog("❌ Background sync error: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            UNUserNotificationCenter.current().delegate = NotificationService.shared
        }
        // CloudKit subscriptions — ранняя регистрация при запуске (до ContentView)
        Task {
            guard await CloudKitService.shared.isCloudKitAvailable() else { return }
            await NotificationService.shared.setupGameSubscription()
            await NotificationService.shared.setupPlayerProfileSubscription()
        }
        // Phase 2: Включить Background Fetch (каждые 15 мин)
        application.setMinimumBackgroundFetchInterval(15 * 60)
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.setDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        debugLog("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        debugLog("📬 Received remote notification: \(userInfo)")
        
        // Handle silent push notifications - CloudKit subscription (Game, PlayerProfile, Claims и т.д.)
        if userInfo["ck"] != nil {
            do {
                let subscriptionID = (userInfo["ck"] as? [String: Any])
                    .flatMap { $0["qry"] as? [String: Any] }
                    .flatMap { $0["sid"] as? String }

                if subscriptionID == "profile-public" {
                    try await SyncCoordinator.shared.fetchPlayerProfiles(notifyOnNewPublic: true)
                } else {
                    try await SyncCoordinator.shared.performIncrementalSync()
                    await MainActor.run {
                        Task {
                            try? await NotificationService.shared.notifyGameUpdated(gameName: "Новая игра")
                        }
                    }
                }
                return .newData
            } catch {
                debugLog("❌ Sync failed: \(error)")
                return .failed
            }
        }
        
        return .noData
    }

    /// Phase 2: Background Fetch - периодическая синхронизация в фоне
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        debugLog("🔄 Background fetch triggered")
        Task {
            do {
                try await SyncCoordinator.shared.performIncrementalSync()
                completionHandler(.newData)
            } catch {
                debugLog("❌ Background fetch error: \(error)")
                completionHandler(.failed)
            }
        }
    }
}

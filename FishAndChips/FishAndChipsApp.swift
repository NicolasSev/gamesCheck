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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Миграция игр (Task 1.2) — один раз после обновления модели
        let hasMigratedGames = UserDefaults.standard.bool(forKey: "hasMigratedGamesToV2")
        if !hasMigratedGames {
            persistenceController.migrateExistingGames()
            UserDefaults.standard.set(true, forKey: "hasMigratedGamesToV2")
        }
        
        // Миграция creatorUserId — один раз для исправления импортированных игр
        let hasMigratedCreatorUserId = UserDefaults.standard.bool(forKey: "hasMigratedCreatorUserId")
        print("🔧 hasMigratedCreatorUserId: \(hasMigratedCreatorUserId)")
        if !hasMigratedCreatorUserId {
            let keychain = KeychainService.shared
            if let userIdString = keychain.getUserId(),
               let userId = UUID(uuidString: userIdString) {
                print("🔧 Starting creatorUserId migration for user: \(userId)")
                let importService = DataImportService(
                    viewContext: persistenceController.container.viewContext,
                    userId: userId
                )
                try? importService.updateCreatorUserIdForAllGames()
                UserDefaults.standard.set(true, forKey: "hasMigratedCreatorUserId")
                print("🔧 Migration completed and flag set")
            } else {
                print("⚠️ Cannot migrate: no currentUserId found in Keychain")
            }
        } else {
            print("✅ Migration already completed")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(notificationService)
                .environmentObject(deepLinkService)
                .onOpenURL { url in
                    print("🔗 App received URL: \(url)")
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
                                print("✅ CloudKit Status: AVAILABLE - Ready to use!")
                            case .noAccount:
                                print("❌ CloudKit Status: NO ACCOUNT - Please sign in to iCloud")
                            case .restricted:
                                print("⚠️ CloudKit Status: RESTRICTED - iCloud access is restricted")
                            case .couldNotDetermine:
                                print("⚠️ CloudKit Status: COULD NOT DETERMINE")
                            case .temporarilyUnavailable:
                                print("⚠️ CloudKit Status: TEMPORARILY UNAVAILABLE")
                            @unknown default:
                                print("⚠️ CloudKit Status: UNKNOWN")
                            }
                        } catch {
                            print("❌ CloudKit Status Check Failed: \(error.localizedDescription)")
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
        // Set notification delegate
        Task { @MainActor in
            UNUserNotificationCenter.current().delegate = NotificationService.shared
        }
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
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        print("📬 Received remote notification: \(userInfo)")
        
        // Handle silent push notifications here
        // This is where CloudKit subscription notifications arrive
        
        // Trigger sync if needed
        if userInfo["ck"] != nil {
            // CloudKit notification
            do {
                try await CloudKitSyncService.shared.sync()
                return .newData
            } catch {
                print("❌ Sync failed: \(error)")
                return .failed
            }
        }
        
        return .noData
    }
}

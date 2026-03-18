//
//  PokerCardRecognizerApp.swift
//  PokerCardRecognizer
//
//  Created by Николас on 24.03.2025.
//

import SwiftUI
import UserNotifications

@main
struct PokerCardRecognizerApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var notificationService = NotificationService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Миграция игр (Task 1.2) — один раз после обновления модели
        let hasMigratedGames = UserDefaults.standard.bool(forKey: "hasMigratedGamesToV2")
        if !hasMigratedGames {
            persistenceController.migrateExistingGames()
            UserDefaults.standard.set(true, forKey: "hasMigratedGamesToV2")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(notificationService)
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
                    
                    // TEMPORARY: Create CloudKit schema in Development mode
                    // ⚠️ Remove this code after schema is deployed to Production!
                    #if DEBUG
                    Task {
                        do {
                            print("🔧 Starting CloudKit schema creation...")
                            try await CloudKitSchemaCreator().createDevelopmentSchema()
                            print("✅ Schema creation completed! Check CloudKit Dashboard.")
                        } catch {
                            print("❌ Schema creation failed: \(error)")
                            print("   Details: \(error.localizedDescription)")
                        }
                    }
                    #endif
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
                try await SyncCoordinator.shared.sync()
                return .newData
            } catch {
                print("❌ Sync failed: \(error)")
                return .failed
            }
        }
        
        return .noData
    }
}

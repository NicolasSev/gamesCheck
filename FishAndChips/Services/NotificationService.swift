//
//  NotificationService.swift
//  PokerCardRecognizer
//
//  Created for Phase 4: Push Notifications
//

import Foundation
import UserNotifications
import UIKit
import CloudKit

/// Service for managing push notifications
@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    @Published var badgeCount: Int = 0
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Notification Categories
    
    enum NotificationCategory: String {
        case playerClaim = "PLAYER_CLAIM"
        case claimResponse = "CLAIM_RESPONSE"
        case gameInvite = "GAME_INVITE"
    }
    
    // MARK: - Notification Actions
    
    enum NotificationAction: String {
        case approveClaim = "APPROVE_CLAIM"
        case rejectClaim = "REJECT_CLAIM"
        case viewClaim = "VIEW_CLAIM"
        case viewGame = "VIEW_GAME"
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotificationCategories()
        checkAuthorizationStatus()
    }
    
    // MARK: - Request Authorization
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await notificationCenter.requestAuthorization(options: options)
        
        if granted {
            await updateAuthorizationStatus()
            print("✅ Push notifications authorized")
        } else {
            print("❌ Push notifications denied")
        }
    }
    
    func checkAuthorizationStatus() {
        Task {
            await updateAuthorizationStatus()
        }
    }
    
    private func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    // MARK: - Device Token Registration
    
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func setDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
        print("📱 Device Token: \(tokenString)")
        
        // Save token to UserDefaults for later use
        UserDefaults.standard.set(tokenString, forKey: "deviceToken")
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        // Player Claim Category
        let approveAction = UNNotificationAction(
            identifier: NotificationAction.approveClaim.rawValue,
            title: "Одобрить",
            options: [.authenticationRequired, .foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: NotificationAction.rejectClaim.rawValue,
            title: "Отклонить",
            options: [.authenticationRequired, .destructive]
        )
        let viewClaimAction = UNNotificationAction(
            identifier: NotificationAction.viewClaim.rawValue,
            title: "Посмотреть",
            options: [.foreground]
        )
        
        let claimCategory = UNNotificationCategory(
            identifier: NotificationCategory.playerClaim.rawValue,
            actions: [approveAction, rejectAction, viewClaimAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Claim Response Category
        let viewResponseAction = UNNotificationAction(
            identifier: NotificationAction.viewClaim.rawValue,
            title: "Посмотреть",
            options: [.foreground]
        )
        
        let responseCategory = UNNotificationCategory(
            identifier: NotificationCategory.claimResponse.rawValue,
            actions: [viewResponseAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Game Invite Category
        let viewGameAction = UNNotificationAction(
            identifier: NotificationAction.viewGame.rawValue,
            title: "Открыть игру",
            options: [.foreground]
        )
        
        let gameCategory = UNNotificationCategory(
            identifier: NotificationCategory.gameInvite.rawValue,
            actions: [viewGameAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        notificationCenter.setNotificationCategories([claimCategory, responseCategory, gameCategory])
    }
    
    // MARK: - Send Local Notification (for testing)
    
    func sendLocalNotification(title: String, body: String, category: NotificationCategory, userInfo: [String: Any] = [:]) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        content.userInfo = userInfo
        
        // Badge increment
        badgeCount += 1
        content.badge = NSNumber(value: badgeCount)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    // MARK: - Player Claim Notifications
    
    func notifyNewClaim(claimId: String, playerName: String, gameName: String, hostUserId: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Новая заявка на игрока"
        content.body = "\(playerName) хочет присвоить себя в игре \(gameName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.playerClaim.rawValue
        content.userInfo = [
            "claimId": claimId,
            "playerName": playerName,
            "gameName": gameName,
            "type": "new_claim"
        ]
        
        badgeCount += 1
        content.badge = NSNumber(value: badgeCount)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "claim_\(claimId)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        print("📬 Sent claim notification for: \(playerName)")
    }
    
    func notifyClaimApproved(claimId: String, playerName: String, gameName: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Заявка одобрена ✅"
        content.body = "Ваша заявка на \(playerName) в игре \(gameName) была одобрена"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.claimResponse.rawValue
        content.userInfo = [
            "claimId": claimId,
            "playerName": playerName,
            "gameName": gameName,
            "type": "claim_approved"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "claim_response_\(claimId)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        print("✅ Sent approval notification for: \(playerName)")
    }
    
    func notifyClaimRejected(claimId: String, playerName: String, gameName: String, reason: String?) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Заявка отклонена ❌"
        var body = "Ваша заявка на \(playerName) в игре \(gameName) была отклонена"
        if let reason = reason, !reason.isEmpty {
            body += ": \(reason)"
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.claimResponse.rawValue
        content.userInfo = [
            "claimId": claimId,
            "playerName": playerName,
            "gameName": gameName,
            "type": "claim_rejected"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "claim_response_\(claimId)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        print("❌ Sent rejection notification for: \(playerName)")
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        badgeCount = count
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    func incrementBadge() {
        updateBadgeCount(badgeCount + 1)
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        clearBadge()
    }
    
    func clearNotification(withIdentifier identifier: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
    
    // Handle notification tap/action
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        print("📬 Notification action: \(actionIdentifier)")
        print("📬 User info: \(userInfo)")
        
        // Handle different actions
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped the notification
            await handleNotificationTap(userInfo: userInfo)
        } else if let action = NotificationAction(rawValue: actionIdentifier) {
            await handleNotificationAction(action, userInfo: userInfo)
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "new_claim", "claim_approved", "claim_rejected":
            if let claimId = userInfo["claimId"] as? String {
                await deepLink(to: .claim(claimId))
            }
        case "game_invite":
            if let gameId = userInfo["gameId"] as? String {
                await deepLink(to: .game(gameId))
            }
        default:
            break
        }
    }
    
    private func handleNotificationAction(_ action: NotificationAction, userInfo: [AnyHashable: Any]) async {
        switch action {
        case .approveClaim:
            if let claimId = userInfo["claimId"] as? String {
                await deepLink(to: .approveClaim(claimId))
            }
        case .rejectClaim:
            if let claimId = userInfo["claimId"] as? String {
                await deepLink(to: .rejectClaim(claimId))
            }
        case .viewClaim:
            if let claimId = userInfo["claimId"] as? String {
                await deepLink(to: .claim(claimId))
            }
        case .viewGame:
            if let gameId = userInfo["gameId"] as? String {
                await deepLink(to: .game(gameId))
            }
        }
    }
    
    // MARK: - Deep Linking
    
    enum DeepLink {
        case claim(String)
        case game(String)
        case approveClaim(String)
        case rejectClaim(String)
    }
    
    private func deepLink(to destination: DeepLink) async {
        // Post notification for app to handle deep linking
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("DeepLinkNotification"),
                object: destination
            )
        }
    }
}

//
//  PushNotificationService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  PushNotificationService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import UserNotifications
import FirebaseMessaging
import Observation
import UIKit

@MainActor
@Observable
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    var isAuthorized = false
    var fcmToken: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    func configure() {
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Request notification permission
        requestAuthorization()
        
        // Register for remote notifications
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        ErrorLoggingService.shared.logInfo(
            "Push notification service configured",
            context: "Notifications"
        )
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                
                if let error = error {
                    ErrorLoggingService.shared.logError(
                        error,
                        context: "Request notification authorization"
                    )
                } else if granted {
                    ErrorLoggingService.shared.logInfo(
                        "Notification authorization granted",
                        context: "Notifications"
                    )
                } else {
                    ErrorLoggingService.shared.logInfo(
                        "Notification authorization denied",
                        context: "Notifications"
                    )
                }
            }
        }
    }
    
    // MARK: - Token Management
    
    func saveFCMToken(for userID: String) async {
        guard let token = fcmToken else {
            ErrorLoggingService.shared.logInfo(
                "No FCM token available to save",
                context: "Notifications"
            )
            return
        }
        
        // Save token to Firestore so backend can send notifications
        do {
            try await FirestoreService.shared.saveFCMToken(token, for: userID)
            
            ErrorLoggingService.shared.logInfo(
                "Saved FCM token for user: \(userID)",
                context: "Notifications"
            )
        } catch {
            ErrorLoggingService.shared.logFirebaseError(
                error,
                operation: "Save FCM token"
            )
        }
    }
    
    func clearFCMToken(for userID: String) async {
        do {
            try await FirestoreService.shared.clearFCMToken(for: userID)
            fcmToken = nil
            
            ErrorLoggingService.shared.logInfo(
                "Cleared FCM token for user: \(userID)",
                context: "Notifications"
            )
        } catch {
            ErrorLoggingService.shared.logFirebaseError(
                error,
                operation: "Clear FCM token"
            )
        }
    }
    
    // MARK: - Send Notifications
    
    func sendNotification(
        to userID: String,
        type: NotificationType,
        actorName: String,
        collectionTitle: String? = nil
    ) async {
        let notification = PushNotificationPayload(
            userID: userID,
            type: type,
            actorName: actorName,
            collectionTitle: collectionTitle
        )
        
        do {
            try await FirestoreService.shared.queueNotification(notification)
            
            ErrorLoggingService.shared.logInfo(
                "Queued notification: \(type.rawValue) for user: \(userID)",
                context: "Notifications"
            )
        } catch {
            ErrorLoggingService.shared.logFirebaseError(
                error,
                operation: "Queue notification"
            )
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            
            ErrorLoggingService.shared.logInfo(
                "Received FCM token",
                context: "Notifications"
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        ErrorLoggingService.shared.logInfo(
            "Received notification in foreground",
            context: "Notifications"
        )
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Parse notification data
        if let typeString = userInfo["type"] as? String,
           let type = NotificationType(rawValue: typeString) {
            
            // Handle navigation based on notification type
            handleNotificationTap(type: type, userInfo: userInfo)
        }
        
        completionHandler()
        
        ErrorLoggingService.shared.logInfo(
            "User tapped notification",
            context: "Notifications"
        )
    }
    
    private func handleNotificationTap(type: NotificationType, userInfo: [AnyHashable: Any]) {
        // We'll implement navigation in the next step
        // For now, just log it
        ErrorLoggingService.shared.logInfo(
            "Handling notification tap: \(type.rawValue)",
            context: "Notifications"
        )
        
        // Post notification to handle navigation in app
        NotificationCenter.default.post(
            name: .handlePushNotificationTap,
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
}

// MARK: - Models

enum NotificationType: String, Codable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case mention = "mention"
    
    var title: String {
        switch self {
        case .like: return "New Like"
        case .comment: return "New Comment"
        case .follow: return "New Follower"
        case .mention: return "You were mentioned"
        }
    }
    
    func body(actorName: String, collectionTitle: String?) -> String {
        switch self {
        case .like:
            if let title = collectionTitle {
                return "\(actorName) liked your collection \"\(title)\""
            }
            return "\(actorName) liked your collection"
            
        case .comment:
            if let title = collectionTitle {
                return "\(actorName) commented on \"\(title)\""
            }
            return "\(actorName) commented on your collection"
            
        case .follow:
            return "\(actorName) started following you"
            
        case .mention:
            return "\(actorName) mentioned you in a comment"
        }
    }
}

struct PushNotificationPayload: Codable {
    let userID: String
    let type: NotificationType
    let actorName: String
    let collectionTitle: String?
    let timestamp: Date
    
    init(userID: String, type: NotificationType, actorName: String, collectionTitle: String? = nil) {
        self.userID = userID
        self.type = type
        self.actorName = actorName
        self.collectionTitle = collectionTitle
        self.timestamp = Date()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let handlePushNotificationTap = Notification.Name("handlePushNotificationTap")
}

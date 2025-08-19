import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

@objc(AppNotificationService)
class AppNotificationService: NSObject {
    
    static let shared = AppNotificationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup Methods
    
    func setupNotifications() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "setupNotifications() Setting up notification service")
        
        // Note: UNUserNotificationCenter delegate is now set by NotificationPermissionService
        // This avoids conflicts and ensures proper delegation
        
        // Note: MessagingDelegate is set by AppDelegate - we don't set it here to avoid conflicts
        // AppDelegate will call our token update methods when needed
        
        // Don't request permission here - it's now handled by NotificationPermissionService
        // at the appropriate time when user reaches main view
        registerForRemoteNotifications()
    }
    
    // REMOVED: requestNotificationPermission() - use NotificationPermissionService instead
    
    private func registerForRemoteNotifications() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "registerForRemoteNotifications() Registering for remote notifications")
        
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Token Management
    
    func updateDeviceToken(_ token: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateDeviceToken() Updating device token: \(token)")
        
        guard let userId = SessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateDeviceToken() Error: No user ID found")
            return
        }
        
        let tokenData: [String: Any] = [
            "User_device_token": token,  // Use same field name as Android for consistency
            "token_updated_at": Date(),
            "platform": "ios"
        ]
        
        Firestore.firestore().collection("Users").document(userId).setData(tokenData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateDeviceToken() Error updating token: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateDeviceToken() Token updated successfully")
            }
        }
    }
    
    // MARK: - Notification Handling
    
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() Handling notification: \(userInfo)")
        
        // Handle FCM notifications (sent from Firebase Cloud Functions)
        if let source = userInfo["source"] as? String, source == "fcm" {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() Processing FCM notification")
            
            let senderId = userInfo["sender_id"] as? String ?? ""
            let title = userInfo["title"] as? String ?? ""
            let body = userInfo["body"] as? String ?? ""
            
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() FCM data - senderId: \(senderId), title: \(title), body: \(body)")
            
            // For FCM notifications, the chat navigation is based on sender_id
            if !senderId.isEmpty {
                handleMessageNotification(chatId: "", senderId: senderId)
            }
            return
        }
        
        // Handle other notification formats (legacy/APNS)
        guard let data = userInfo["data"] as? [String: Any] else {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() No data found in notification, checking for direct fields")
            
            // Check for direct notification fields (for FCM/APNS notifications)
            let senderId = userInfo["sender_id"] as? String ?? ""
            let _ = userInfo["title"] as? String ?? ""
            let _ = userInfo["body"] as? String ?? ""
            
            if !senderId.isEmpty {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() Found direct notification fields - senderId: \(senderId)")
                handleMessageNotification(chatId: "", senderId: senderId)
            }
            return
        }
        
        let type = data["type"] as? String ?? ""
        let chatId = data["chat_id"] as? String ?? ""
        let senderId = data["sender_id"] as? String ?? ""
        
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() Legacy format - type: \(type), chatId: \(chatId), senderId: \(senderId)")
        
        switch type {
        case "message":
            handleMessageNotification(chatId: chatId, senderId: senderId)
        case "call":
            handleCallNotification(chatId: chatId, senderId: senderId)
        case "live":
            handleLiveNotification(chatId: chatId, senderId: senderId)
        default:
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() Unknown notification type: \(type)")
        }
    }
    
    private func handleMessageNotification(chatId: String, senderId: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleMessageNotification() Handling message notification for chat: \(chatId)")
        
        // Navigate to message screen if app is active
        DispatchQueue.main.async {
            // Since we're using SwiftUI, use NavigationManager for chat navigation
            // TODO: Implement SwiftUI-based chat navigation through NavigationManager
            self.navigateToChat(chatId: chatId, senderId: senderId)
        }
    }
    
    private func handleCallNotification(chatId: String, senderId: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleCallNotification() Handling call notification for chat: \(chatId)")
        
        // Show incoming call screen
        DispatchQueue.main.async {
            // Implementation for showing incoming call screen
        }
    }
    
    private func handleLiveNotification(chatId: String, senderId: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleLiveNotification() Handling live notification for chat: \(chatId)")
        
        // Handle live call
        DispatchQueue.main.async {
            // Implementation for live call
        }
    }
    
    private func navigateToChat(chatId: String, senderId: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "navigateToChat() Navigating to chat: \(chatId)")
        
        // Get sender details and navigate to chat
        Task {
            do {
                let document = try await Firestore.firestore().collection("Users").document(senderId).getDocument()
                if document.exists {
                    let data = document.data()
                    let name = data?["name"] as? String ?? "Unknown"
                    let profileImage = data?["profile_image"] as? String ?? ""
                    let gender = data?["gender"] as? String ?? ""
                    
                    let _ = Chat(
                        ChatId: chatId,
                        UserId: senderId,
                        ProfileImage: profileImage,
                        Name: name,
                        Lastsentby: senderId,
                        Gender: gender,
                        DeviceId: "",
                        LastTimeStamp: Date(),
                        newmessage: false,
                        inbox: 0,
                        type: "message",
                        lastMessageSentByUserId: senderId
                    )
                    
                    DispatchQueue.main.async {
                        // TODO: Use SwiftUI navigation to MessagesView instead of UIKit MessageController
                        // NavigationManager.shared.navigateToMessages(with: chat)
                        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "navigateToChat() TODO: Implement SwiftUI navigation to chat")
                    }
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "navigateToChat() Firestore error: \(error)")
            }
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateBadgeCount() Updating badge count")
        
        guard let userId = SessionManager.shared.userId else { return }
        
        // Count unread messages
        Firestore.firestore().collection("Users").document(userId).collection("Chats")
            .whereField("new_message", isEqualTo: true)
            .getDocuments { (snapshot, error) in
                if let snapshot = snapshot {
                    let badgeCount = snapshot.documents.count
                    
                    DispatchQueue.main.async {
                        if #available(iOS 16.0, *) {
                            UNUserNotificationCenter.current().setBadgeCount(badgeCount)
                        } else {
                            UIApplication.shared.applicationIconBadgeNumber = badgeCount
                        }
                        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateBadgeCount() Badge count updated to: \(badgeCount)")
                    }
                }
            }
    }
    
    func clearBadge() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "clearBadge() Clearing badge")
        
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    // MARK: - FCM Message Handling (called by AppDelegate MessagingDelegate)
    
    /// Handle FCM messages received from Firebase Cloud Functions
    /// This is the centralized handler for all FCM message processing (iOS equivalent to Android onMessageReceived)
    func handleFCMMessage(_ data: [AnyHashable: Any]) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Processing FCM message")
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Full message data: \(data)")
        
        // Try to extract data from different FCM message structures
        var senderId: String?
        var title: String?
        var body: String?
        var source: String?
        
        // First, check if there's a 'data' field (new FCM format)
        if let fcmData = data["data"] as? [String: Any] {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Found 'data' field in FCM message")
            senderId = fcmData["sender_id"] as? String
            title = fcmData["title"] as? String
            body = fcmData["body"] as? String
            source = fcmData["source"] as? String
        } else {
            // Fallback to direct fields (legacy format)
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() No 'data' field found, checking direct fields")
            senderId = data["sender_id"] as? String
            title = data["title"] as? String
            body = data["body"] as? String
            source = data["source"] as? String
        }
        
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Extracted - sender_id: \(senderId ?? "nil"), title: \(title ?? "nil"), body: \(body ?? "nil"), source: \(source ?? "nil")")
        
        // Validate that this is an FCM message from our cloud function
        if source == "fcm" {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Confirmed FCM message from cloud function")
        } else {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() Warning: source field is not 'fcm', might be legacy message")
        }
        
        if let senderId = senderId,
           let title = title,
           let body = body {
            
            // Check notification permission before showing notification
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .authorized {
                    AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() notification permission granted, showing notification")
                    
                    // Create and show local notification (iOS equivalent to Android NotificationManager)
                    self.showNotificationFromFCM(
                        senderId: senderId,
                        title: title,
                        body: body
                    )
                } else {
                    AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() notification permission not granted, status: \(settings.authorizationStatus.rawValue)")
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleFCMMessage() missing required notification data - sender_id: \(senderId ?? "nil"), title: \(title ?? "nil"), body: \(body ?? "nil")")
        }
    }
    
    /// Display notification from FCM data (iOS equivalent to Android NotificationManager)
    private func showNotificationFromFCM(senderId: String, title: String, body: String) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "showNotificationFromFCM() Creating notification for sender: \(senderId)")
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add custom data for notification tap handling (same structure as Android)
        content.userInfo = [
            "sender_id": senderId,
            "title": title,
            "body": body,
            "source": "fcm"
        ]
        
        // Create notification ID using sender_id hash (same as Android)
        let notificationIdentifier = String(senderId.hashValue)
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil // Show immediately
        )
        
        // Add notification to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "showNotificationFromFCM() notification display error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "showNotificationFromFCM() notification displayed successfully for sender: \(senderId)")
            }
        }
    }
    
    // MARK: - Token Management (called by AppDelegate MessagingDelegate)
    // Note: AppDelegate is the primary MessagingDelegate and calls this method when tokens are received
    func handleReceivedRegistrationToken(_ fcmToken: String?) {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleReceivedRegistrationToken() FCM token received: \(fcmToken ?? "nil")")
        
        if let token = fcmToken {
            updateDeviceToken(token)
        }
    }
}

// REMOVED: UNUserNotificationCenterDelegate extension - now handled by NotificationPermissionService
// This prevents conflicts and ensures proper delegation hierarchy

// MARK: - UIApplication Extension
extension UIApplication {
    func topViewController() -> UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.visibleViewController
        }
        
        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }
        
        return topViewController
    }
} 

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
    
    // DEPRECATED: Permission request moved to NotificationPermissionService
    private func requestNotificationPermission() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "requestNotificationPermission() DEPRECATED - Use NotificationPermissionService instead")
        
        // This method is kept for backward compatibility but does nothing
        // Permission is now requested by NotificationPermissionService at appropriate time
    }
    
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
            "device_token": token,
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
        
        guard let data = userInfo["data"] as? [String: Any] else {
            AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "handleNotification() No data found in notification")
            return
        }
        
        let type = data["type"] as? String ?? ""
        let chatId = data["chat_id"] as? String ?? ""
        let senderId = data["sender_id"] as? String ?? ""
        
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
                    
                    let chat = Chat(
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
                        UIApplication.shared.applicationIconBadgeNumber = badgeCount
                        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "updateBadgeCount() Badge count updated to: \(badgeCount)")
                    }
                }
            }
    }
    
    func clearBadge() {
        AppLogger.log(tag: "LOG-APP: AppNotificationService", message: "clearBadge() Clearing badge")
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
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

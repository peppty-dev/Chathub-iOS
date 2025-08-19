import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications

/// iOS equivalent of Android FirebaseMessagingService.UpdateTokenToServer()
/// Handles contextual FCM token updates when user grants notification permission
class FCMTokenUpdateService {
    static let shared = FCMTokenUpdateService()
    
    private init() {}
    
    /// Request notification permission and update FCM token - called when user sends first message
    /// This is the iOS equivalent of Android's contextual notification permission flow
    func requestPermissionAndUpdateToken(context: String, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "requestPermissionAndUpdateToken() context: \(context)")
        
        // Check if notification permission should be requested
        // Don't skip based on token - check actual permission status
        AppNotificationPermissionService.shared.checkPermissionStatus { status in
            // If permission is already granted, just update the token
            if status == .authorized {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "requestPermissionAndUpdateToken() permission already authorized")
                self.updateFCMToken { success in
                    completion(success)
                }
                return
            }
            
            // If permission should not be requested (already asked before), just update token
            if !AppNotificationPermissionService.shared.shouldRequestPermission() {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "requestPermissionAndUpdateToken() permission already requested before, updating token only")
                self.updateFCMToken { success in
                    completion(success)
                }
                return
            }
            
            // Request notification permission first
            AppNotificationPermissionService.shared.requestNotificationPermissionWithContext(
                context: context
            ) { [weak self] granted in
                guard let self = self else { 
                    completion(false)
                    return 
                }
                
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "requestPermissionAndUpdateToken() permission granted: \(granted)")
                
                // Get FCM token regardless of permission result
                // This ensures we have the best possible token for the user
                self.updateFCMToken { success in
                    completion(success)
                }
            }
        }
    }
    
    /// Update FCM token - called when APNS token is available
    /// This is the iOS equivalent of Android FirebaseMessagingService.UpdateTokenToServer()
    func updateFCMToken(completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "updateFCMToken() getting FCM token")
        
        // Small delay to ensure APNS token is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            Messaging.messaging().token { [weak self] (token, error) in
                guard let self = self else { 
                    completion(false)
                    return 
                }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "updateFCMToken() error: \(error.localizedDescription)")
                    
                    // Even if FCM fails, we should still allow the user to continue
                    // Use a fallback token that indicates FCM is unavailable but permission was requested
                    let fallbackToken = "ios_fcm_unavailable_after_permission_\(Date().timeIntervalSince1970)"
                    self.saveTokenToFirebaseAndSession(token: fallbackToken) { success in
                        completion(success)
                    }
                    return
                }
                
                if let deviceToken = token {
                    AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "updateFCMToken() FCM token received successfully")
                    self.saveTokenToFirebaseAndSession(token: deviceToken) { success in
                        completion(success)
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "updateFCMToken() FCM token was nil")
                    let fallbackToken = "ios_fcm_nil_after_permission_\(Date().timeIntervalSince1970)"
                    self.saveTokenToFirebaseAndSession(token: fallbackToken) { success in
                        completion(success)
                    }
                }
            }
        }
    }
    
    /// Save token to both Firebase and SessionManager
    /// This mirrors Android SessionManager.setUserToken() and Firebase update
    private func saveTokenToFirebaseAndSession(token: String, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "saveTokenToFirebaseAndSession() updating token: \(token.prefix(20))...")
        
        guard let userId = SessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "saveTokenToFirebaseAndSession() no user ID available")
            completion(false)
            return
        }
        
        // Update SessionManager first (like Android)
        SessionManager.shared.deviceToken = token
        
        // Update Firebase (like Android FirebaseMessagingService.UpdateTokenToServer)
        let tokenData: [String: Any] = [
            "User_device_token": token,  // Using same field name as Android
            "token_updated_at": FieldValue.serverTimestamp(),
            "platform": "iOS"
        ]
        
        Firestore.firestore().collection("Users").document(userId).setData(tokenData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "saveTokenToFirebaseAndSession() Firebase update error: \(error.localizedDescription)")
                completion(false)
            } else {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "saveTokenToFirebaseAndSession() Firebase and session updated successfully")
                completion(true)
            }
        }
    }
    
    /// Check if current token is a placeholder token
    func hasPlaceholderToken() -> Bool {
        guard let token = SessionManager.shared.deviceToken else { return true }
        return token.contains("ios_pending_notification_permission") || 
               token.contains("ios_fcm_unavailable") || 
               token.contains("ios_fcm_nil")
    }
    
    /// Force refresh FCM token - called from AppDelegate when token changes
    /// This is the iOS equivalent of Android FirebaseMessagingService.onNewToken()
    func handleTokenRefresh(newToken: String) {
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "handleTokenRefresh() new token received")
        
        // Only update if we have a user session
        guard SessionManager.shared.userId != nil else {
            AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "handleTokenRefresh() no user session, skipping update")
            return
        }
        
        saveTokenToFirebaseAndSession(token: newToken) { success in
            AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "handleTokenRefresh() update completed: \(success)")
        }
    }
    
    /// Attempt to upgrade placeholder token to real FCM token
    /// Called when app becomes active to retry getting real token for users with placeholders
    func attemptTokenUpgrade() {
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() checking if token upgrade is needed")
        
        // Only attempt upgrade if we have a placeholder token
        guard hasPlaceholderToken() else {
            AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() already have real token, no upgrade needed")
            return
        }
        
        // Only attempt if we have a user session
        guard SessionManager.shared.userId != nil else {
            AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() no user session, skipping upgrade")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() attempting to upgrade placeholder token")
        
        // Try to get FCM token without requesting permission again
        // This works if user has already granted permission in system settings
        updateFCMToken { success in
            if success {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() successfully upgraded to real FCM token")
            } else {
                AppLogger.log(tag: "LOG-APP: FCMTokenUpdateService", message: "attemptTokenUpgrade() upgrade failed, keeping placeholder token")
            }
        }
    }
} 

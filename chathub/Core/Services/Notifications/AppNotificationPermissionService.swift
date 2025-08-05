import Foundation
import UserNotifications
import UIKit

/// Service to handle delayed notification permission requests
/// This moves the permission request from app launch to when user reaches main view
@objc(AppNotificationPermissionService)
class AppNotificationPermissionService: NSObject {
    static let shared = AppNotificationPermissionService()
    
    private var hasRequestedPermission = false
    private let permissionRequestedKey = "notification_permission_requested"
    
    // MARK: - Retry Mechanism Constants (Android Parity)
    private let retryAfterMessageCount = 15 // Show again after 15 messages (sent + received)
    private let maxRetryAttempts = 3 // Maximum retry attempts
    private let retryAttemptKey = "notification_retry_attempt_count"
    private let maybeLaterMessageCountKey = "notification_maybe_later_message_count"
    private let lastRetryContextKey = "notification_last_retry_context"
    
    private override init() {
        super.init()
    }
    
    /// Check if we should request notification permission
    /// Only request once per app installation
    func shouldRequestPermission() -> Bool {
        // Don't request if already requested in this session
        if hasRequestedPermission {
            return false
        }
        
        // Don't request if already requested before (stored in UserDefaults)
        if UserDefaults.standard.bool(forKey: permissionRequestedKey) {
            return false
        }
        
        return true
    }
    
    /// Request notification permission with user-friendly timing
    /// This should be called when user reaches main view, not at app launch
    func requestNotificationPermission() {
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermission() Requesting notification permission")
        
        guard shouldRequestPermission() else {
            AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermission() Permission already requested, skipping")
            return
        }
        
        // Mark as requested to prevent multiple requests
        hasRequestedPermission = true
        UserDefaults.standard.set(true, forKey: permissionRequestedKey)
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermission() Error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermission() Permission granted: \(granted)")
            }
            
            // Register for remote notifications regardless of local permission
            // This allows the app to receive silent notifications for data sync
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            // Show settings alert only if permission was denied
            if !granted {
                DispatchQueue.main.async {
                    self.showNotificationSettingsAlert()
                }
            }
        }
    }
    
    /// Request notification permission with context and completion callback
    /// This method is used for contextual permission requests (e.g., after first message)
    func requestNotificationPermissionWithContext(
        context: String,
        onComplete: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermissionWithContext() context: \(context)")
        
        guard shouldRequestPermission() else {
            AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermissionWithContext() Permission already requested, skipping")
            onComplete(false)
            return
        }
        
        // Mark as requested to prevent multiple requests
        hasRequestedPermission = true
        UserDefaults.standard.set(true, forKey: permissionRequestedKey)
        
        // Log context for analytics
        UserDefaults.standard.set(context, forKey: "notification_permission_context")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "notification_permission_request_time")
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermissionWithContext() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestNotificationPermissionWithContext() Permission granted: \(granted), context: \(context)")
                }
                
                // Register for remote notifications regardless of local permission
                UIApplication.shared.registerForRemoteNotifications()
                
                // Log result for analytics
                UserDefaults.standard.set(granted, forKey: "notification_permission_granted")
                
                onComplete(granted)
                
                // Show settings alert only if permission was denied
                if !granted {
                    self.showNotificationSettingsAlert()
                }
            }
        }
    }
    
    /// Setup notification center delegate without requesting permission
    /// This should be called at app launch to prepare for notifications
    func setupNotificationDelegate() {
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "setupNotificationDelegate() Setting up notification delegate")
        
        UNUserNotificationCenter.current().delegate = self
        
        // Set up UI appearance (moved from AppDelegate)
        let BarButtonItemAppearance = UIBarButtonItem.appearance()
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 0.1, weight: .bold), NSAttributedString.Key.foregroundColor: UIColor.clear]
        BarButtonItemAppearance.setTitleTextAttributes(attributes, for: .normal)
        BarButtonItemAppearance.setTitleTextAttributes(attributes, for: .highlighted)
    }
    
    /// Check current notification permission status
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    /// Show alert to guide user to notification settings
    private func showNotificationSettingsAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Enable Notifications",
            message: "Get notified when you receive new messages and friend requests. You can enable notifications in Settings > Notifications > ChatHub.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Maybe Later", style: .cancel, handler: nil))
        
        rootVC.present(alert, animated: true, completion: nil)
    }
    
    /// Reset permission request flag (for testing purposes)
    func resetPermissionRequestFlag() {
        hasRequestedPermission = false
        UserDefaults.standard.removeObject(forKey: permissionRequestedKey)
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "resetPermissionRequestFlag() Permission request flag reset")
    }
    
    // MARK: - Retry Mechanism Methods (Smart "Maybe Later" Handling)
    
    /// Handle "maybe later" response by setting up retry mechanism
    func handleMaybeLaterResponse(context: String) {
        let currentTotalMessages = SessionManager.shared.totalNoOfMessageSent + SessionManager.shared.totalNoOfMessageReceived
        let retryAttempt = UserDefaults.standard.integer(forKey: retryAttemptKey)
        
        // Store when user said "maybe later" for retry calculation
        UserDefaults.standard.set(currentTotalMessages, forKey: maybeLaterMessageCountKey)
        UserDefaults.standard.set(context, forKey: lastRetryContextKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "notification_maybe_later_time")
        
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "handleMaybeLaterResponse() User chose maybe later at total message count: \(currentTotalMessages) (sent: \(SessionManager.shared.totalNoOfMessageSent), received: \(SessionManager.shared.totalNoOfMessageReceived)), retry attempt: \(retryAttempt), context: \(context)")
    }
    
    /// Check if we should show retry popup based on message count
    func shouldShowRetryPopup() -> Bool {
        // Check if permission is already granted or denied permanently
        guard shouldRequestPermission() else {
            AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "shouldShowRetryPopup() Permission already handled")
            return false
        }
        
        let retryAttempt = UserDefaults.standard.integer(forKey: retryAttemptKey)
        
        // Don't retry if we've exceeded max attempts
        guard retryAttempt < maxRetryAttempts else {
            AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "shouldShowRetryPopup() Max retry attempts reached: \(retryAttempt)")
            return false
        }
        
        // Check if user previously said "maybe later"
        let maybeLaterTotalMessages = UserDefaults.standard.integer(forKey: maybeLaterMessageCountKey)
        guard maybeLaterTotalMessages > 0 else {
            AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "shouldShowRetryPopup() No previous maybe later response")
            return false
        }
        
        let currentTotalMessages = SessionManager.shared.totalNoOfMessageSent + SessionManager.shared.totalNoOfMessageReceived
        let messagesSinceMaybeLater = currentTotalMessages - maybeLaterTotalMessages
        
        // Show retry popup if user has sent/received enough messages since "maybe later"
        let shouldRetry = messagesSinceMaybeLater >= retryAfterMessageCount
        
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "shouldShowRetryPopup() Total messages since maybe later: \(messagesSinceMaybeLater)/\(retryAfterMessageCount) (current total: \(currentTotalMessages), maybe later at: \(maybeLaterTotalMessages)), should retry: \(shouldRetry)")
        
        return shouldRetry
    }
    
    /// Request notification permission for retry scenario
    func requestRetryPermission(context: String, onComplete: @escaping (Bool) -> Void = { _ in }) {
        let retryAttempt = UserDefaults.standard.integer(forKey: retryAttemptKey)
        let newRetryAttempt = retryAttempt + 1
        
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "requestRetryPermission() Retry attempt: \(newRetryAttempt), context: \(context)")
        
        // Update retry attempt count
        UserDefaults.standard.set(newRetryAttempt, forKey: retryAttemptKey)
        
        // Use the existing contextual permission request method
        requestNotificationPermissionWithContext(context: "retry_\(newRetryAttempt)_\(context)", onComplete: onComplete)
    }
    
    /// Reset retry mechanism (when permission is granted or user goes to settings)
    func resetRetryMechanism() {
        UserDefaults.standard.removeObject(forKey: retryAttemptKey)
        UserDefaults.standard.removeObject(forKey: maybeLaterMessageCountKey)
        UserDefaults.standard.removeObject(forKey: lastRetryContextKey)
        UserDefaults.standard.removeObject(forKey: "notification_maybe_later_time")
        
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "resetRetryMechanism() Retry mechanism reset")
    }
    
    /// Get retry statistics for debugging/analytics
    func getRetryStatistics() -> [String: Any] {
        let currentTotalMessages = SessionManager.shared.totalNoOfMessageSent + SessionManager.shared.totalNoOfMessageReceived
        let maybeLaterTotalMessages = UserDefaults.standard.integer(forKey: maybeLaterMessageCountKey)
        
        return [
            "retry_attempts": UserDefaults.standard.integer(forKey: retryAttemptKey),
            "maybe_later_total_message_count": maybeLaterTotalMessages,
            "current_total_message_count": currentTotalMessages,
            "current_sent_messages": SessionManager.shared.totalNoOfMessageSent,
            "current_received_messages": SessionManager.shared.totalNoOfMessageReceived,
            "messages_since_maybe_later": currentTotalMessages - maybeLaterTotalMessages,
            "retry_threshold": retryAfterMessageCount,
            "max_retry_attempts": maxRetryAttempts,
            "last_retry_context": UserDefaults.standard.string(forKey: lastRetryContextKey) ?? "none",
            "maybe_later_time": UserDefaults.standard.double(forKey: "notification_maybe_later_time")
        ]
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppNotificationPermissionService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "willPresent() Notification will present")
        
        let userInfo = notification.request.content.userInfo
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "willPresent() Notification payload: \(userInfo)")
        
        // Forward notification handling to NotificationService
        AppNotificationService.shared.handleNotification(userInfo)
        
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "didReceive() Notification tapped")
        
        let userInfo = response.notification.request.content.userInfo
        AppLogger.log(tag: "LOG-APP: NotificationPermissionService", message: "didReceive() Notification payload: \(userInfo)")
        
        // Forward notification handling to NotificationService
        AppNotificationService.shared.handleNotification(userInfo)
        
        completionHandler()
    }
} 

import Foundation
import UIKit
import SwiftUI
import UserNotifications
import FirebaseFirestore

/// CallEndNotificationHandler - iOS equivalent of Android CallEndBroadcastReceiver.java functionality exactly
/// Handles call end actions from notifications with 100% Android parity
@objc(CallEndNotificationHandler)
class CallEndNotificationHandler: NSObject {
    
    // MARK: - Singleton
    static let shared = CallEndNotificationHandler()
    private override init() { super.init() }
    
    // MARK: - Properties (Android Parity)
    private let database = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    private let messagingSettingsManager = MessagingSettingsSessionManager.shared
    
    // MARK: - Notification Categories Setup (Android Parity)
    
    /// Setup notification categories - Android equivalent of broadcast receiver registration
    func setupNotificationCategories() {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "setupNotificationCategories() setting up call notification actions")
        
        // Audio call end action
        let endAudioCallAction = UNNotificationAction(
            identifier: "END_AUDIO_CALL",
            title: "End Call",
            options: [.destructive, .foreground]
        )
        
        // Video call end action
        let endVideoCallAction = UNNotificationAction(
            identifier: "END_VIDEO_CALL",
            title: "End Call",
            options: [.destructive, .foreground]
        )
        
        // Audio call category
        let audioCallCategory = UNNotificationCategory(
            identifier: "AUDIO_CALL",
            actions: [endAudioCallAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Video call category
        let videoCallCategory = UNNotificationCategory(
            identifier: "VIDEO_CALL",
            actions: [endVideoCallAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Incoming audio call category
        let incomingAudioCallCategory = UNNotificationCategory(
            identifier: "INCOMING_AUDIO_CALL",
            actions: [endAudioCallAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Incoming video call category
        let incomingVideoCallCategory = UNNotificationCategory(
            identifier: "INCOMING_VIDEO_CALL",
            actions: [endVideoCallAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register all categories
        UNUserNotificationCenter.current().setNotificationCategories([
            audioCallCategory,
            videoCallCategory,
            incomingAudioCallCategory,
            incomingVideoCallCategory
        ])
        
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "setupNotificationCategories() notification categories registered successfully")
    }
    
    // MARK: - Notification Action Handling (Android onReceive() Parity)
    
    /// Handle notification response - Android onReceive() equivalent
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleNotificationResponse() received action: \(response.actionIdentifier)")
        
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        switch actionIdentifier {
        case "END_AUDIO_CALL":
            handleEndAudioCall(userInfo: userInfo)
            
        case "END_VIDEO_CALL":
            handleEndVideoCall(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleNotificationTap(userInfo: userInfo)
            
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleNotificationResponse() notification dismissed")
            
        default:
            AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleNotificationResponse() unknown action: \(actionIdentifier)")
        }
    }
    
    // MARK: - Call End Handlers (Android Parity)
    
    /// Handle end audio call action - Android endCall() equivalent
    private func handleEndAudioCall(userInfo: [AnyHashable: Any]) {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleEndAudioCall() ending audio call from notification")
        
        // Extract call data from notification
        let callerUid = userInfo["caller_uid"] as? String ?? ""
        let currentUserId = sessionManager.userId ?? ""
        
        // End call in Firebase - Android parity
        endCallInFirebase(callerUid: callerUid, currentUserId: currentUserId, isAudio: true)
        
        // Stop audio call service
        MakeAudioCallService.shared.stopService()
        IncomingAudioCallService.shared.stopService()
        
        // Clear notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["audio_call", "incoming_audio_call"])
        
        // Return to main app
        returnToMainApp()
    }
    
    /// Handle end video call action - Android endCall() equivalent
    private func handleEndVideoCall(userInfo: [AnyHashable: Any]) {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleEndVideoCall() ending video call from notification")
        
        // Extract call data from notification
        let callerUid = userInfo["caller_uid"] as? String ?? ""
        let currentUserId = sessionManager.userId ?? ""
        
        // End call in Firebase - Android parity
        endCallInFirebase(callerUid: callerUid, currentUserId: currentUserId, isAudio: false)
        
        // Stop video call service
        MakeVideoCallService.shared.stopService()
        IncomingVideoCallService.shared.stopService()
        
        // Clear notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["video_call", "incoming_video_call"])
        
        // Return to main app
        returnToMainApp()
    }
    
    /// Handle notification tap - Android default action equivalent
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "handleNotificationTap() user tapped notification")
        
        let callType = userInfo["call_type"] as? String ?? "audio"
        let isIncoming = userInfo["is_incoming"] as? Bool ?? false
        
        // Navigate to appropriate call screen
        if isIncoming {
            if callType == "video" {
                NavigationManager.shared.navigateToIncomingVideoCall()
            } else {
                NavigationManager.shared.navigateToIncomingAudioCall()
            }
        } else {
            // Navigate to active call screen
            if callType == "video" {
                // Navigate to MakeVideoCallView
                navigateToActiveVideoCall(userInfo: userInfo)
            } else {
                // Navigate to MakeAudioCallView
                navigateToActiveAudioCall(userInfo: userInfo)
            }
        }
    }
    
    // MARK: - Firebase Call Management (Android Parity)
    
    /// End call in Firebase - Android endCallInFirebase() equivalent
    private func endCallInFirebase(callerUid: String, currentUserId: String, isAudio: Bool) {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "endCallInFirebase() ending call in Firebase")
        
        let batch = database.batch()
        
        // End call for current user
        let currentUserData: [String: Any] = [
            "call_ended": true,
            "incoming_call": false
        ]
        
        let currentUserRef = database.collection("Users").document(currentUserId).collection("Calls").document("Calls")
        batch.setData(currentUserData, forDocument: currentUserRef, merge: true)
        
        // End call for other user
        let otherUserData: [String: Any] = [
            "call_ended": true,
            "incoming_call": false
        ]
        
        let otherUserRef = database.collection("Users").document(callerUid).collection("Calls").document("Calls")
        batch.setData(otherUserData, forDocument: otherUserRef, merge: true)
        
        // Update online status
        setOnCallStatus(uid: currentUserId, onCall: false)
        setOnCallStatus(uid: callerUid, onCall: false)
        
        batch.commit { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "endCallInFirebase() error: \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "endCallInFirebase() call ended successfully in Firebase")
            }
        }
        
        // Clear session data
        messagingSettingsManager.clearIncomingCall()
    }
    
    /// Set user online call status - Android setOnCall() equivalent
    private func setOnCallStatus(uid: String, onCall: Bool) {
        let data: [String: Any] = ["on_call": onCall]
        database.collection("Users").document(uid).setData(data, merge: true)
    }
    
    // MARK: - Navigation Helpers (iOS Specific)
    
    /// Navigate to active audio call
    private func navigateToActiveAudioCall(userInfo: [AnyHashable: Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let otherUserId = userInfo["caller_uid"] as? String ?? ""
        let otherUserName = userInfo["caller_name"] as? String ?? ""
        let chatId = userInfo["channel_name"] as? String ?? ""
        
        let audioCallView = MakeAudioCallView(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserProfileImage: "",
            chatId: chatId
        )
        
        let hostingController = UIHostingController(rootView: audioCallView)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
    }
    
    /// Navigate to active video call
    private func navigateToActiveVideoCall(userInfo: [AnyHashable: Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let otherUserId = userInfo["caller_uid"] as? String ?? ""
        let otherUserName = userInfo["caller_name"] as? String ?? ""
        let chatId = userInfo["channel_name"] as? String ?? ""
        
        let videoCallView = MakeVideoCallView(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserProfileImage: "",
            chatId: chatId
        )
        
        let hostingController = UIHostingController(rootView: videoCallView)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
    }
    
    /// Return to main app - Android MainActivity equivalent
    private func returnToMainApp() {
        AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "returnToMainApp() returning to main app")
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            // Navigate back to MainView
            let mainView = MainView()
            let hostingController = UIHostingController(rootView: mainView)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        }
    }
    
    // MARK: - Notification Creation Helpers (Android Parity)
    
    /// Create call notification with end action - Android createCallNotification() equivalent
    func createCallNotification(
        title: String,
        body: String,
        identifier: String,
        categoryIdentifier: String,
        userInfo: [String: Any]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // Handle sound separately
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "createCallNotification() error: \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: CallEndNotificationHandler", message: "createCallNotification() notification created: \(identifier)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate Extension
extension CallEndNotificationHandler: UNUserNotificationCenterDelegate {
    
    /// Handle notification response when app is in background/foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotificationResponse(response)
        completionHandler()
    }
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground (Android parity)
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - NavigationManager Extension for Call Navigation
extension NavigationManager {
    
    /// Navigate to main view - Android MainActivity equivalent
    func navigateToMainView() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToMainView() navigating to main view")
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            let mainView = MainView()
            let hostingController = UIHostingController(rootView: mainView)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        }
    }
}
//
//  MessageAnalytics.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import FirebaseAnalytics

class MessageAnalytics {
    static let shared = MessageAnalytics()
    private init() {}
    
    // MARK: - Message Limit Events
    
    func trackMessageLimitPopupShown(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, triggerReason: String = "limit_reached") {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "current_usage": currentUsage,
            "limit": limit,
            "remaining_cooldown_seconds": Int(remainingCooldown),
            "trigger_reason": triggerReason,
            "user_type": getCurrentUserType(),
            "is_limit_reached": currentUsage >= limit
        ]
        
        Analytics.logEvent("message_limit_popup_shown", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackMessageLimitPopupShown() - Usage: \(currentUsage)/\(limit), Cooldown: \(remainingCooldown)s")
    }
    
    func trackMessageSendAttempted(currentUsage: Int, limit: Int) {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "current_usage": currentUsage,
            "limit": limit,
            "user_type": getCurrentUserType(),
            "is_limit_reached": currentUsage >= limit
        ]
        
        Analytics.logEvent("message_send_attempted", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackMessageSendAttempted() - Usage: \(currentUsage)/\(limit)")
    }
    
    func trackMessageSendSuccessful(currentUsage: Int, limit: Int) {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "current_usage": currentUsage,
            "limit": limit,
            "user_type": getCurrentUserType(),
            "remaining_messages": max(0, limit - currentUsage)
        ]
        
        Analytics.logEvent("message_send_successful", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackMessageSendSuccessful() - Usage: \(currentUsage)/\(limit)")
    }
    
    func trackMessageSendBlocked(currentUsage: Int, limit: Int, reason: String) {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "current_usage": currentUsage,
            "limit": limit,
            "block_reason": reason,
            "user_type": getCurrentUserType()
        ]
        
        Analytics.logEvent("message_send_blocked", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackMessageSendBlocked() - Reason: \(reason), Usage: \(currentUsage)/\(limit)")
    }
    
    func trackSubscriptionButtonTapped(priceDisplayed: String?, currentUsage: Int, limit: Int) {
        var parameters: [String: Any] = [
            "feature_type": "message",
            "current_usage": currentUsage,
            "limit": limit,
            "user_type": getCurrentUserType(),
            "source": "message_limit_popup"
        ]
        
        if let price = priceDisplayed {
            parameters["price_displayed"] = price
        }
        
        Analytics.logEvent("message_subscription_button_tapped", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackSubscriptionButtonTapped() - Price: \(priceDisplayed ?? "nil"), Usage: \(currentUsage)/\(limit)")
    }
    
    func trackPopupDismissed(method: String, currentUsage: Int, limit: Int) {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "dismiss_method": method, // "background_tap", "button_action", etc.
            "current_usage": currentUsage,
            "limit": limit,
            "user_type": getCurrentUserType()
        ]
        
        Analytics.logEvent("message_popup_dismissed", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackPopupDismissed() - Method: \(method), Usage: \(currentUsage)/\(limit)")
    }
    
    func trackLimitReset(previousUsage: Int, limit: Int, resetReason: String = "cooldown_expired") {
        let parameters: [String: Any] = [
            "feature_type": "message",
            "previous_usage": previousUsage,
            "limit": limit,
            "reset_reason": resetReason,
            "user_type": getCurrentUserType()
        ]
        
        Analytics.logEvent("message_limit_reset", parameters: parameters)
        AppLogger.log(tag: "LOG-APP: MessageAnalytics", message: "trackLimitReset() - Reset from \(previousUsage) to 0, Limit: \(limit)")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserType() -> String {
        let subscriptionManager = SubscriptionSessionManager.shared
        
        if subscriptionManager.isUserSubscribedToPro() {
            return "pro_subscriber"
        } else if subscriptionManager.isUserSubscribedToPlus() {
            return "plus_subscriber"
        } else if subscriptionManager.isUserSubscribedToLite() {
            return "lite_subscriber"
        } else if isNewUser() {
            return "new_user"
        } else {
            return "free_user"
        }
    }
    
    /// Check if user is within new user grace period
    private func isNewUser() -> Bool {
        let userSessionManager = UserSessionManager.shared
        let sessionManager = SessionManager.shared
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = sessionManager.newUserFreePeriodSeconds
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < TimeInterval(newUserPeriod)
    }
}
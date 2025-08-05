//
//  MessageLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Message Limit Manager
class MessageLimitManager: BaseFeatureLimitManager {
    static let shared = MessageLimitManager()
    
    private init() {
        super.init(featureType: .message)
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        // Use existing message tracking from MessagingSettingsSessionManager
        return messagingSessionManager.totalNoOfMessageSent
    }
    
    override func getLimit() -> Int {
        return messagingSessionManager.freeMessagesLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return messagingSessionManager.freeMessagesCooldownSeconds
    }
    
    override func setUsageCount(_ count: Int) {
        messagingSessionManager.totalNoOfMessageSent = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        // Use existing freeMessageTime as cooldown start time
        return Int64(messagingSessionManager.freeMessageTime)
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        messagingSessionManager.freeMessageTime = TimeInterval(time)
    }
    
    // MARK: - Message-Specific Methods
    
    /// Check if message can be sent and return detailed result
    func checkMessageLimit() -> FeatureLimitResult {
        let canProceed = canPerformAction()
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        let remainingCooldown = getRemainingCooldown()
        
        // Show popup if user is not premium and either at limit or in cooldown
        let showPopup = !subscriptionSessionManager.isSubscriptionActive() && 
                       (currentUsage >= limit || isInCooldown())
        
        return FeatureLimitResult(
            canProceed: canProceed,
            showPopup: showPopup,
            remainingCooldown: remainingCooldown,
            currentUsage: currentUsage,
            limit: limit
        )
    }
    
    /// Perform message send if allowed
    func performMessageSend(completion: @escaping (Bool) -> Void) {
        let result = checkMessageLimit()
        
        if result.canProceed {
            incrementUsage()
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "performMessageSend() Message sent. Usage: \(getCurrentUsageCount())/\(getLimit())")
            completion(true)
        } else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "performMessageSend() Message blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")
            completion(false)
        }
    }
    
    /// Reset message usage (for testing or admin purposes)
    func resetMessageUsage() {
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "resetMessageUsage() Resetting message usage and cooldown")
        resetCooldown()
    }
    
    /// Check if user has free messages available (legacy compatibility)
    func hasFreeMessagesAvailable() -> Bool {
        return canPerformAction()
    }
    
    /// Get remaining free messages count
    func getRemainingFreeMessages() -> Int {
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        return max(0, limit - currentUsage)
    }
}
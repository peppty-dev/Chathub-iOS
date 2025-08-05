//
//  ConversationLimitManagerNew.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Conversation Limit Manager (New Implementation)
class ConversationLimitManagerNew: BaseFeatureLimitManager {
    static let shared = ConversationLimitManagerNew()
    
    private init() {
        super.init(featureType: .conversation)
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        return messagingSessionManager.conversationsStartedCount
    }
    
    override func getLimit() -> Int {
        return messagingSessionManager.freeConversationsLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return messagingSessionManager.freeConversationsCooldownSeconds
    }
    
    override func setUsageCount(_ count: Int) {
        messagingSessionManager.conversationsStartedCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return messagingSessionManager.conversationLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        messagingSessionManager.conversationLimitCooldownStartTime = time
    }
    
    // MARK: - Conversation-Specific Methods
    
    /// Check if conversation can be started and return detailed result
    func checkConversationLimit() -> FeatureLimitResult {
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
    
    /// Perform conversation start if allowed
    func performConversationStart(completion: @escaping (Bool) -> Void) {
        let result = checkConversationLimit()
        
        if result.canProceed {
            incrementUsage()
            AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "performConversationStart() Conversation started. Usage: \(getCurrentUsageCount())/\(getLimit())")
            completion(true)
        } else {
            AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "performConversationStart() Conversation blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")
            completion(false)
        }
    }
    
    /// Increment conversation count (for external use)
    func incrementConversationsStarted() {
        incrementUsage()
        AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "incrementConversationsStarted() Count incremented to: \(getCurrentUsageCount())")
    }
    
    /// Reset conversation usage (for testing or admin purposes)
    func resetConversationUsage() {
        AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "resetConversationUsage() Resetting conversation usage and cooldown")
        resetCooldown()
    }
    
    /// Legacy compatibility method for checking if new user
    func isNewUser() -> Bool {
        // Check if user is within new user grace period
        let userSessionManager = UserSessionManager.shared
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = messagingSessionManager.newUserFreePeriodSeconds
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < newUserPeriod
    }
}
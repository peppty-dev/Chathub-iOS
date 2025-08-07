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
    
    // MARK: - Override Base Methods (Using SessionManager)
    
    override func getCurrentUsageCount() -> Int {
        return SessionManager.shared.conversationsStartedCount
    }
    
    override func getLimit() -> Int {
        return SessionManager.shared.freeConversationsLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return TimeInterval(SessionManager.shared.freeConversationsCooldownSeconds)
    }
    
    override func setUsageCount(_ count: Int) {
        SessionManager.shared.conversationsStartedCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return SessionManager.shared.conversationLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        SessionManager.shared.conversationLimitCooldownStartTime = time
    }
    
    // MARK: - Conversation-Specific Methods
    
    /// Check if conversation can be started and return detailed result (Always-Show Popup Strategy)
    func checkConversationLimit() -> FeatureLimitResult {
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        var remainingCooldown = getRemainingCooldown()

        // Shadow Ban check (apply on conversation start)
        let moderationManager = ModerationSettingsSessionManager.shared
        if moderationManager.textModerationIssueSB {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let sbStart = moderationManager.textModerationIssueCoolDownTime
            let sbDurationSeconds = Int64(SessionManager.shared.defaults.integer(forKey: "TEXT_MODERATION_SB_LOCK_DURATION_SECONDS"))
            let effectiveDuration = sbDurationSeconds > 0 ? sbDurationSeconds : 3600
            let elapsed = currentTime - sbStart
            let sbRemaining = max(0, TimeInterval(effectiveDuration - elapsed))
            if sbRemaining > 1.0 { // SB active
                remainingCooldown = sbRemaining
                // Always show popup, but block proceed
                return FeatureLimitResult(
                    canProceed: false,
                    showPopup: true,
                    remainingCooldown: remainingCooldown,
                    currentUsage: currentUsage,
                    limit: limit
                )
            } else {
                // SB expired, clear flags
                moderationManager.textModerationIssueSB = false
                moderationManager.textModerationIssueCoolDownTime = 0
            }
        }
        
        // Check if user can proceed without popup (ONLY Plus+ subscribers and new users)
        let hasPlusOrHigher = subscriptionSessionManager.hasPlusTierOrHigher()
        let isNewUserInFreePeriod = isNewUser()
        
        // ONLY Plus+ subscribers and new users bypass popup entirely
        if hasPlusOrHigher || isNewUserInFreePeriod {
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users (FREE and LITE users), always show popup (to display conversation count or timer)
        let canProceed = canPerformAction()
        
        // Always show popup for non-Plus/non-new users to display progress
        let shouldShowPopup = true
        
        return FeatureLimitResult(
            canProceed: canProceed,
            showPopup: shouldShowPopup,
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
            
            // Track analytics for blocked conversation
            if result.remainingCooldown > 0 {
                ConversationAnalytics.shared.trackConversationBlockedCooldown(
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    remainingCooldown: result.remainingCooldown
                )
            } else {
                ConversationAnalytics.shared.trackConversationBlockedLimitReached(
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    cooldownDuration: getCooldownDuration()
                )
            }
            
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
        let previousUsage = getCurrentUsageCount()
        let limit = getLimit()
        
        AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "resetConversationUsage() Resetting conversation usage and cooldown from \(previousUsage) to 0")
        resetCooldown()
        
        // Track analytics for limit reset
        ConversationAnalytics.shared.trackConversationLimitReset(
            previousUsage: previousUsage,
            limit: limit
        )
    }
    
    /// Start cooldown when popup opens (matching refresh/filter/search behavior)
    override func startCooldownOnPopupOpen() {
        if getCurrentUsageCount() >= getLimit() && !isInCooldown() {
            let currentTime = Int64(Date().timeIntervalSince1970)
            setCooldownStartTime(currentTime)
            AppLogger.log(tag: "LOG-APP: ConversationLimitManagerNew", message: "startCooldownOnPopupOpen() Started cooldown at popup open")
        }
    }
    
    /// Legacy compatibility method for checking if new user
    func isNewUser() -> Bool {
        // Check if user is within new user grace period
        let userSessionManager = UserSessionManager.shared
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = TimeInterval(SessionManager.shared.newUserFreePeriodSeconds)
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < newUserPeriod
    }
}
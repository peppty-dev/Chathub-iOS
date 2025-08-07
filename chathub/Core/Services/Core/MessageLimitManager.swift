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
    
    // Current user ID for per-user message tracking
    private var currentUserId: String?
    
    private init() {
        super.init(featureType: .message)
    }
    
    /// Set the current user ID for per-user message tracking
    func setCurrentUserId(_ userId: String) {
        currentUserId = userId
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "setCurrentUserId() Set current user ID: \(userId)")
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        // Use per-user message tracking from MessagingSettingsSessionManager
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "getCurrentUsageCount() No current user ID set, returning 0")
            return 0
        }
        
        let count = MessagingSettingsSessionManager.shared.getMessageCount(otherUserId: userId)
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "getCurrentUsageCount() User \(userId) has sent \(count) messages")
        return count
    }
    
    override func getLimit() -> Int {
        // Use SessionManager for consistency with all other limit features
        return sessionManager.freeMessagesLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        // Use SessionManager for consistency with all other limit features  
        return TimeInterval(sessionManager.freeMessagesCooldownSeconds)
    }
    
    override func setUsageCount(_ count: Int) {
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "setUsageCount() No current user ID set, cannot set count")
            return
        }
        
        MessagingSettingsSessionManager.shared.setMessageCount(otherUserId: userId, count: count)
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "setUsageCount() Set message count for user \(userId): \(count)")
    }
    
    override func getCooldownStartTime() -> Int64 {
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "getCooldownStartTime() No current user ID set, returning 0")
            return 0
        }
        
        let time = MessagingSettingsSessionManager.shared.getMessageLimitCooldownStartTime(otherUserId: userId)
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "getCooldownStartTime() User \(userId) cooldown start time: \(time)")
        return time
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "setCooldownStartTime() No current user ID set, cannot set cooldown time")
            return
        }
        
        MessagingSettingsSessionManager.shared.setMessageLimitCooldownStartTime(otherUserId: userId, time: time)
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "setCooldownStartTime() Set cooldown start time for user \(userId): \(time)")
    }
    
    // MARK: - Override Base Methods for Pro Subscription
    
    override func canPerformAction() -> Bool {
        // Pro subscription users bypass all limits
        if subscriptionSessionManager.hasProTier() {
            return true
        }
        
        // New users bypass all limits during their free period
        if isNewUser() {
            return true
        }
        
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        
        // If under limit, can proceed
        if currentUsage < limit {
            return true
        }
        
        // If over limit, check if cooldown has expired (only if cooldown was actually started)
        if isInCooldown() {
            // In active cooldown, check if it has expired
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if getRemainingCooldown() <= 1.0 {
                // Cooldown has expired, reset usage count for fresh start
                AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "canPerformAction() - Cooldown expired, resetting usage count from \(currentUsage) to 0 (remaining: \(getRemainingCooldown())s)")
                resetCooldown()
                return true
            } else {
                // Still in cooldown, cannot proceed
                return false
            }
        } else {
            // Limit reached but cooldown not started yet (will be started when popup opens)
            return false
        }
    }
    
    // MARK: - Message-Specific Methods
    
    /// Check if message can be sent and return detailed result
    func checkMessageLimit() -> FeatureLimitResult {
        // CRITICAL: Check if cooldown has expired and auto-reset if needed (per-user)
        var wasAutoReset = false
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() No current user ID set")
            return FeatureLimitResult(canProceed: false, showPopup: false, remainingCooldown: 0, currentUsage: 0, limit: getLimit())
        }
        
        let cooldownStart = getCooldownStartTime()
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() COOLDOWN CHECK - User: \(userId), Start: \(cooldownStart), Current: \(currentTime), Elapsed: \(elapsed)s, Duration: \(cooldownDuration)s, Remaining: \(remaining)s")
            
            // Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() - Cooldown expired for user \(userId), auto-resetting count (remaining: \(remaining)s)")
                resetPerUserCooldownOnly(userId: userId)
                wasAutoReset = true
            }
        }
        
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        let remainingCooldown = getRemainingCooldown()
        
        // Check if user can proceed without popup (Pro subscribers and new users)
        let hasProAccess = subscriptionSessionManager.hasProTier()
        let isNewUserInFreePeriod = isNewUser()
        
        // Debug logging to understand user categorization
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() - User: \(userId), hasProAccess: \(hasProAccess), isNewUser: \(isNewUserInFreePeriod), currentUsage: \(currentUsage), limit: \(limit), wasAutoReset: \(wasAutoReset)")
        
        // Pro subscribers and new users bypass popup entirely
        if hasProAccess || isNewUserInFreePeriod {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() - User \(userId) bypassing popup (Pro: \(hasProAccess), New: \(isNewUserInFreePeriod))")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // If cooldown was just auto-reset, don't show popup - user has fresh messages
        if wasAutoReset {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() - Cooldown auto-reset for user \(userId), bypassing popup to allow immediate messaging")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users, check if they can proceed and if popup should be shown
        let canProceed = canPerformAction()
        
        // Show popup only when limit is reached for non-Pro, non-new users
        let showPopup = currentUsage >= limit
        
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "checkMessageLimit() - User \(userId): Showing popup: \(showPopup), canProceed: \(canProceed), isLimitReached: \(currentUsage >= limit)")
        
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
    
    // MARK: - Per-User Reset Methods
    
    /// Reset only the cooldown for a specific user when cooldown expires (SECURITY: Prevents conversation clearing exploit)
    private func resetPerUserCooldownOnly(userId: String) {
        // CRITICAL: Only reset count and cooldown when cooldown time has genuinely expired
        // This prevents users from bypassing limits by clearing conversations
        // 
        // SECURITY NOTE: Message limit data is stored in UserDefaults with keys:
        // - "message_count_\(otherUserId)" 
        // - "message_limit_cooldown_start_time_\(otherUserId)"
        // These are NOT affected by ClearConversationService which only clears Firebase chat data
        MessagingSettingsSessionManager.shared.resetMessageLimits(otherUserId: userId)
        
        AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "resetPerUserCooldownOnly() Reset count and cooldown for user \(userId) due to cooldown expiration")
    }
    
    /// Override resetCooldown to work with per-user tracking (SECURITY FIX)
    override func resetCooldown() {
        guard let userId = currentUserId else {
            AppLogger.log(tag: "LOG-APP: MessageLimitManager", message: "resetCooldown() No current user ID set, cannot reset")
            return
        }
        
        // Only reset if this is a legitimate cooldown expiration, not a manual reset
        resetPerUserCooldownOnly(userId: userId)
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if user is within new user grace period
    private func isNewUser() -> Bool {
        let userSessionManager = UserSessionManager.shared
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        // Use SessionManager for consistency with all other limit features
        let newUserPeriod = sessionManager.newUserFreePeriodSeconds
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < TimeInterval(newUserPeriod)
    }
}
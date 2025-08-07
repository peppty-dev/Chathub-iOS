//
//  SearchLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Search Limit Manager
class SearchLimitManager: BaseFeatureLimitManager {
    static let shared = SearchLimitManager()
    
    private init() {
        super.init(featureType: .search)
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        return sessionManager.searchUsageCount
    }
    
    override func getLimit() -> Int {
        return sessionManager.freeSearchLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return TimeInterval(sessionManager.freeSearchCooldownSeconds)
    }
    
    override func setUsageCount(_ count: Int) {
        sessionManager.searchUsageCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return sessionManager.searchLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        sessionManager.searchLimitCooldownStartTime = time
    }
    
    // MARK: - Search-Specific Methods
    
    /// Check if search action can be performed and return detailed result
    func checkSearchLimit() -> FeatureLimitResult {
        // Check if cooldown has expired and auto-reset if needed
        var wasAutoReset = false
        // CRITICAL FIX: Use more robust cooldown expiration check to handle precision issues
        let cooldownStart = getCooldownStartTime()
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() PRECISION DEBUG - Start: \(cooldownStart), Current: \(currentTime), Elapsed: \(elapsed)s, Duration: \(cooldownDuration)s, Remaining: \(remaining)s")
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() - Cooldown expired, auto-resetting usage count (remaining: \(remaining)s)")
                resetCooldown()
                wasAutoReset = true
            }
        }
        
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        let remainingCooldown = getRemainingCooldown()
        
        // Check if user can proceed without popup (Lite+ subscribers and new users)
        let hasLiteAccess = subscriptionSessionManager.hasLiteTierOrHigher()
        let isNewUserInFreePeriod = isNewUser()
        
        // Debug logging to understand user categorization
        AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() - hasLiteAccess: \(hasLiteAccess), isNewUser: \(isNewUserInFreePeriod), currentUsage: \(currentUsage), limit: \(limit), wasAutoReset: \(wasAutoReset)")
        
        // Lite+ subscribers and new users bypass popup entirely
        if hasLiteAccess || isNewUserInFreePeriod {
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() - User bypassing popup (LiteOrHigher: \(hasLiteAccess), New: \(isNewUserInFreePeriod))")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // If cooldown was just auto-reset, don't show popup - user has fresh applications
        if wasAutoReset {
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() - Cooldown auto-reset, bypassing popup to allow immediate search")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users, always show popup (to display search count or timer)
        let canProceed = canPerformAction()
        
        // Always show popup for non-Lite/non-new users to display progress
        let shouldShowPopup = true
        
        AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "checkSearchLimit() - Showing popup with currentUsage: \(currentUsage), limit: \(limit), isLimitReached: \(currentUsage >= limit), canProceed: \(canProceed)")
        
        return FeatureLimitResult(
            canProceed: canProceed,
            showPopup: shouldShowPopup,
            remainingCooldown: remainingCooldown,
            currentUsage: currentUsage,
            limit: limit
        )
    }
    
    /// Perform search action if allowed
    func performSearch(completion: @escaping (Bool) -> Void) {
        let result = checkSearchLimit()
        
        if result.canProceed {
            incrementUsage()
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "performSearch() Search performed. Usage: \(getCurrentUsageCount())/\(getLimit())")
            completion(true)
        } else {
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "performSearch() Search blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")
            completion(false)
        }
    }
    
    /// Reset search usage (for testing or admin purposes)
    func resetSearchUsage() {
        AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "resetSearchUsage() Resetting search usage and cooldown")
        resetCooldown()
    }
    
    /// Start cooldown when popup opens (if at limit and not already in cooldown)
    override func startCooldownOnPopupOpen() {
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        
        // Only start cooldown if we're at the limit and not already in cooldown
        if currentUsage >= limit && !isInCooldown() {
            AppLogger.log(tag: "LOG-APP: SearchLimitManager", message: "startCooldownOnPopupOpen() - Starting cooldown as user has reached limit")
            startCooldown()
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if user is within new user grace period
    private func isNewUser() -> Bool {
        let userSessionManager = UserSessionManager.shared
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
//
//  RefreshLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Refresh Limit Manager
class RefreshLimitManager: BaseFeatureLimitManager {
    static let shared = RefreshLimitManager()
    
    private init() {
        super.init(featureType: .refresh)
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        return SessionManager.shared.refreshUsageCount
    }
    
    override func getLimit() -> Int {
        return SessionManager.shared.freeRefreshLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return SessionManager.shared.freeRefreshCooldownSeconds
    }
    
    override func setUsageCount(_ count: Int) {
        SessionManager.shared.refreshUsageCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return SessionManager.shared.refreshLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        SessionManager.shared.refreshLimitCooldownStartTime = time
    }
    
    // MARK: - Refresh-Specific Methods
    
    /// Check if refresh action can be performed and return detailed result
    func checkRefreshLimit() -> FeatureLimitResult {
        // DEBUG: Add comprehensive logging for app launch cooldown debugging
        let currentTime = Int64(Date().timeIntervalSince1970)
        let cooldownStartTime = getCooldownStartTime()
        let cooldownDuration = getCooldownDuration()
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        
        AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() DEBUG - Current time: \(currentTime), Cooldown start: \(cooldownStartTime), Duration: \(cooldownDuration)s, Usage: \(currentUsage)/\(limit)")
        
        if cooldownStartTime > 0 {
            let elapsed = currentTime - cooldownStartTime
            let remaining = cooldownDuration - TimeInterval(elapsed)
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() DEBUG - Elapsed: \(elapsed)s, Remaining: \(remaining)s, isInCooldown: \(isInCooldown())")
        }
        
        // Check if cooldown has expired and auto-reset if needed
        var wasAutoReset = false
        // CRITICAL FIX: Use more robust cooldown expiration check to handle precision issues
        let cooldownStart = getCooldownStartTime()
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() PRECISION DEBUG - Start: \(cooldownStart), Current: \(currentTime), Elapsed: \(elapsed)s, Duration: \(cooldownDuration)s, Remaining: \(remaining)s")
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() - Cooldown expired, auto-resetting usage count (remaining: \(remaining)s)")
                resetCooldown()
                wasAutoReset = true
            }
        }
        
        // Reuse variables from earlier debug section
        let remainingCooldown = getRemainingCooldown()
        
        // Check if user can proceed without popup (Light subscribers and new users)
        let isLightSubscriber = subscriptionSessionManager.isUserSubscribedToLite()
        let isNewUserInFreePeriod = isNewUser()
        
        // Debug logging to understand user categorization
        AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() - isLiteSubscriber: \(isLightSubscriber), isNewUser: \(isNewUserInFreePeriod), currentUsage: \(currentUsage), limit: \(limit), wasAutoReset: \(wasAutoReset)")
        
        // Light subscribers and new users bypass popup entirely
        if isLightSubscriber || isNewUserInFreePeriod {
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() - User bypassing popup (Lite: \(isLightSubscriber), New: \(isNewUserInFreePeriod))")
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
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() - Cooldown auto-reset, bypassing popup to allow immediate refresh")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users, always show popup (to display refresh count or timer)
        let canProceed = canPerformAction()
        
        // Always show popup for non-Lite/non-new users to display progress
        let shouldShowPopup = true
        
        AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "checkRefreshLimit() - Showing popup with currentUsage: \(currentUsage), limit: \(limit), isLimitReached: \(currentUsage >= limit), canProceed: \(canProceed)")
        
        return FeatureLimitResult(
            canProceed: canProceed,
            showPopup: shouldShowPopup,
            remainingCooldown: remainingCooldown,
            currentUsage: currentUsage,
            limit: limit
        )
    }
    
    /// Check if user is within new user grace period
    private func isNewUser() -> Bool {
        let userSessionManager = UserSessionManager.shared
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = SessionManager.shared.newUserFreePeriodSeconds
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < TimeInterval(newUserPeriod)
    }
    
    /// Perform refresh action if allowed
    func performRefresh(completion: @escaping (Bool) -> Void) {
        let result = checkRefreshLimit()
        let userType = RefreshAnalytics.shared.getUserType()
        
        if result.canProceed {
            let wasFirstRefresh = getCurrentUsageCount() == 0
            incrementUsage()
            
            // Track successful refresh
            RefreshAnalytics.shared.trackRefreshPerformed(
                userType: userType,
                currentUsage: getCurrentUsageCount(),
                limit: getLimit(),
                isFirstRefreshOfSession: wasFirstRefresh
            )
            
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "performRefresh() Refresh performed. Usage: \(getCurrentUsageCount())/\(getLimit())")
            completion(true)
        } else {
            // Track blocked refresh (cooldown already started in checkRefreshLimit)
            if isInCooldown() {
                RefreshAnalytics.shared.trackRefreshBlockedCooldown(
                    remainingCooldown: result.remainingCooldown,
                    currentUsage: getCurrentUsageCount(),
                    limit: getLimit()
                )
            } else {
                RefreshAnalytics.shared.trackRefreshBlockedLimitReached(
                    currentUsage: getCurrentUsageCount(),
                    limit: getLimit(),
                    cooldownDuration: getCooldownDuration()
                )
            }
            
            AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "performRefresh() Refresh blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")
            completion(false)
        }
    }
    
    /// Reset refresh usage (for testing or admin purposes)
    func resetRefreshUsage() {
        AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "resetRefreshUsage() Resetting refresh usage and cooldown")
        setUsageCount(0)
        resetCooldown()
    }
    

}
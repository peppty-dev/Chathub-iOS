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
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        let remainingCooldown = getRemainingCooldown()
        
        // Check if user can proceed without popup (Light subscribers and new users)
        let isLightSubscriber = subscriptionSessionManager.isUserSubscribedToLite()
        let isNewUserInFreePeriod = isNewUser()
        
        // Light subscribers and new users bypass popup entirely
        if isLightSubscriber || isNewUserInFreePeriod {
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users, show popup only when they exceed their limit
        let canProceed = canPerformAction()
        
        // Only show popup when user has reached or exceeded their limit
        let shouldShowPopup = currentUsage >= limit
        
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
            // Track blocked refresh
            if isInCooldown() {
                RefreshAnalytics.shared.trackRefreshBlockedCooldown(
                    remainingCooldown: result.remainingCooldown,
                    currentUsage: getCurrentUsageCount(),
                    limit: getLimit()
                )
            } else {
                // Start cooldown when user first exceeds limit
                if getCurrentUsageCount() >= getLimit() && !isInCooldown() {
                    startCooldown()
                }
                
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
        resetCooldown()
    }
}
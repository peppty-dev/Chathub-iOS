//
//  FilterLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Filter Limit Manager
class FilterLimitManager: BaseFeatureLimitManager {
    static let shared = FilterLimitManager()
    
    private init() {
        super.init(featureType: .filter)
    }
    
    // MARK: - Override Base Methods
    
    override func getCurrentUsageCount() -> Int {
        return SessionManager.shared.filterUsageCount
    }
    
    override func getLimit() -> Int {
        return SessionManager.shared.freeFilterLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return TimeInterval(SessionManager.shared.freeFilterCooldownSeconds)
    }
    
    override func setUsageCount(_ count: Int) {
        SessionManager.shared.filterUsageCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return SessionManager.shared.filterLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        SessionManager.shared.filterLimitCooldownStartTime = time
    }
    
    // MARK: - Filter-Specific Methods
    
    /// Check if filter action can be performed and return detailed result
    func checkFilterLimit() -> FeatureLimitResult {
        // Enhanced debugging for app resume cooldown issue
        let cooldownStartTime = getCooldownStartTime()
        let currentTime = Int64(Date().timeIntervalSince1970)
        let elapsed = currentTime - cooldownStartTime
        let remaining = getRemainingCooldown()
        
        AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - DEBUGGING: cooldownStart=\(cooldownStartTime), currentTime=\(currentTime), elapsed=\(elapsed)s, remaining=\(remaining)s, isInCooldown=\(isInCooldown())")
        
        // Check if cooldown has expired and auto-reset if needed
        var wasAutoReset = false
        // CRITICAL FIX: Use more robust cooldown expiration check to handle precision issues
        let cooldownStart = getCooldownStartTime()
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() PRECISION DEBUG - Start: \(cooldownStart), Current: \(currentTime), Elapsed: \(elapsed)s, Duration: \(cooldownDuration)s, Remaining: \(remaining)s")
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - Cooldown expired, auto-resetting usage count (remaining: \(remaining)s)")
                resetCooldown()
                wasAutoReset = true
            }
        }
        
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        let remainingCooldown = getRemainingCooldown()
        
        // Check if user can proceed without popup (Lite subscribers and new users)
        let isLiteSubscriber = subscriptionSessionManager.isUserSubscribedToLite()
        let isNewUserInFreePeriod = isNewUser()
        
        // Debug logging to understand user categorization
        AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - isLiteSubscriber: \(isLiteSubscriber), isNewUser: \(isNewUserInFreePeriod), currentUsage: \(currentUsage), limit: \(limit), wasAutoReset: \(wasAutoReset)")
        
        // Lite subscribers and new users bypass popup entirely
        if isLiteSubscriber || isNewUserInFreePeriod {
            AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - User bypassing popup (Lite: \(isLiteSubscriber), New: \(isNewUserInFreePeriod))")
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
            AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - Cooldown auto-reset, bypassing popup to allow immediate filter")
            return FeatureLimitResult(
                canProceed: true,
                showPopup: false,
                remainingCooldown: 0,
                currentUsage: currentUsage,
                limit: limit
            )
        }
        
        // For all other users, always show popup (to display filter count or timer)
        let canProceed = canPerformAction()
        
        // Always show popup for non-Lite/non-new users to display progress
        let shouldShowPopup = true
        
        AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "checkFilterLimit() - Showing popup with currentUsage: \(currentUsage), limit: \(limit), isLimitReached: \(currentUsage >= limit), canProceed: \(canProceed)")

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
    
    /// Perform filter action if allowed
    func performFilter(completion: @escaping (Bool) -> Void) {
        let result = checkFilterLimit()
        
        if result.canProceed {
            incrementUsage()
            AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "performFilter() Filter applied. Usage: \(getCurrentUsageCount())/\(getLimit())")
            completion(true)
        } else {
            AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "performFilter() Filter blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")
            completion(false)
        }
    }
    
    /// Reset filter usage (for testing or admin purposes)
    func resetFilterUsage() {
        AppLogger.log(tag: "LOG-APP: FilterLimitManager", message: "resetFilterUsage() Resetting filter usage and cooldown")
        resetCooldown()
    }
}
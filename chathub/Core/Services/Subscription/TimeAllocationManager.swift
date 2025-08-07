//
//  TimeAllocationManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/21/25.
//

import Foundation

/**
 * Manages time allocations for Live calls and Voice/Video calls based on subscription tiers
 * Handles time tracking, subscription period resets, and enforcement of time limits
 */
class TimeAllocationManager {
    static let shared = TimeAllocationManager()
    
    private let defaults = UserDefaults.standard
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let liveTimeUsed = "liveTimeUsed"
        static let callTimeUsed = "callTimeUsed"
        static let lastSubscriptionRenewalTime = "lastSubscriptionRenewalTime"
        static let currentSubscriptionPeriodStart = "currentSubscriptionPeriodStart"
    }
    
    // MARK: - Live Time Management
    
    /// Get remaining live time for current subscription tier
    func getRemainingLiveTime() -> Int {
        let tier = subscriptionSessionManager.getSubscriptionTier()
        let totalAllowance = SubscriptionConstants.getLiveTimeLimit(tier: tier)
        
        if totalAllowance == SubscriptionConstants.NO_TIME {
            return 0 // No live access for this tier
        }
        
        let usedTime = getLiveTimeUsed()
        return max(0, totalAllowance - usedTime)
    }
    
    /// Get total live time used in current subscription period
    func getLiveTimeUsed() -> Int {
        checkAndResetIfNewPeriod()
        return defaults.integer(forKey: Keys.liveTimeUsed)
    }
    
    /// Consume live time (called during live sessions)
    func consumeLiveTime(seconds: Int) {
        let currentUsed = getLiveTimeUsed()
        let newUsed = currentUsed + seconds
        defaults.set(newUsed, forKey: Keys.liveTimeUsed)
        
        AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "consumeLiveTime() Used \(seconds)s, total: \(newUsed)s")
    }
    
    /// Check if user can start live session
    func canStartLiveSession() -> Bool {
        // Check if tier has live access (Plus or higher)
        if !subscriptionSessionManager.hasPlusTierOrHigher() {
            return false
        }
        
        // Check if there's remaining time
        return getRemainingLiveTime() > 0
    }
    
    // MARK: - Call Time Management
    
    /// Get remaining call time for current subscription tier
    func getRemainingCallTime() -> Int {
        let tier = subscriptionSessionManager.getSubscriptionTier()
        let totalAllowance = SubscriptionConstants.getCallTimeLimit(tier: tier)
        
        if totalAllowance == SubscriptionConstants.NO_TIME {
            return 0 // No call access for this tier
        }
        
        let usedTime = getCallTimeUsed()
        return max(0, totalAllowance - usedTime)
    }
    
    /// Get total call time used in current subscription period
    func getCallTimeUsed() -> Int {
        checkAndResetIfNewPeriod()
        return defaults.integer(forKey: Keys.callTimeUsed)
    }
    
    /// Consume call time (called during voice/video calls)
    func consumeCallTime(seconds: Int) {
        let currentUsed = getCallTimeUsed()
        let newUsed = currentUsed + seconds
        defaults.set(newUsed, forKey: Keys.callTimeUsed)
        
        AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "consumeCallTime() Used \(seconds)s, total: \(newUsed)s")
    }
    
    /// Check if user can start voice/video call
    func canStartCall() -> Bool {
        // Check if tier has call access (Pro only)
        if !subscriptionSessionManager.hasProTier() {
            return false
        }
        
        // Check if there's remaining time
        return getRemainingCallTime() > 0
    }
    
    // MARK: - Subscription Period Management
    
    /// Mark subscription renewal (resets time allocations)
    func markSubscriptionRenewal() {
        let currentTime = Date().timeIntervalSince1970
        defaults.set(currentTime, forKey: Keys.lastSubscriptionRenewalTime)
        defaults.set(currentTime, forKey: Keys.currentSubscriptionPeriodStart)
        
        // Reset time usage
        defaults.set(0, forKey: Keys.liveTimeUsed)
        defaults.set(0, forKey: Keys.callTimeUsed)
        
        AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "markSubscriptionRenewal() Time allocations reset for new subscription period")
    }
    
    /// Check if we're in a new subscription period and reset if needed
    private func checkAndResetIfNewPeriod() {
        let subscriptionState = subscriptionSessionManager.getCurrentSubscriptionState()
        
        // If subscription is not active, don't reset anything
        if !subscriptionState.isActive {
            return
        }
        
        let currentPeriodStart = defaults.double(forKey: Keys.currentSubscriptionPeriodStart)
        let subscriptionStartTime = Double(subscriptionState.startTimeMillis) / 1000.0 // Convert from milliseconds
        
        // If the subscription start time is newer than our recorded period start, it's a new period
        if subscriptionStartTime > currentPeriodStart {
            AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "checkAndResetIfNewPeriod() New subscription period detected, resetting time allocations")
            markSubscriptionRenewal()
        }
    }
    
    // MARK: - Replenishment Logic (Legacy Compatibility)
    
    /// Replenish live seconds for MessagingSettingsSessionManager compatibility
    func replenishLiveSecondsIfNeeded() {
        let hasPlusAccess = subscriptionSessionManager.hasPlusTierOrHigher()
        
        if hasPlusAccess {
            let remainingTime = getRemainingLiveTime()
            
            if remainingTime > 0 {
                // Set the live seconds to the remaining time allocation
                MessagingSettingsSessionManager.shared.liveSeconds = remainingTime
                AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "replenishLiveSecondsIfNeeded() Set liveSeconds to \(remainingTime)")
            } else {
                // No time remaining in current period
                MessagingSettingsSessionManager.shared.liveSeconds = 0
                AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "replenishLiveSecondsIfNeeded() No live time remaining in current period")
            }
        } else {
            MessagingSettingsSessionManager.shared.liveSeconds = 0
        }
    }
    
    /// Replenish call seconds for call functionality
    func replenishCallSecondsIfNeeded() {
        let hasProAccess = subscriptionSessionManager.hasProTier()
        
        if hasProAccess {
            let remainingTime = getRemainingCallTime()
            
            if remainingTime > 0 {
                // Set the call seconds to the remaining time allocation
                MessagingSettingsSessionManager.shared.callSeconds = remainingTime
                AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "replenishCallSecondsIfNeeded() Set callSeconds to \(remainingTime)")
            } else {
                // No time remaining in current period
                MessagingSettingsSessionManager.shared.callSeconds = 0
                AppLogger.log(tag: "LOG-APP: TimeAllocationManager", message: "replenishCallSecondsIfNeeded() No call time remaining in current period")
            }
        } else {
            MessagingSettingsSessionManager.shared.callSeconds = 0
        }
    }
    
    // MARK: - Debug and Monitoring
    
    /// Get current time allocation status for debugging
    func getTimeAllocationStatus() -> [String: Any] {
        let tier = subscriptionSessionManager.getSubscriptionTier()
        
        return [
            "tier": tier,
            "liveTimeLimit": SubscriptionConstants.getLiveTimeLimit(tier: tier),
            "liveTimeUsed": getLiveTimeUsed(),
            "liveTimeRemaining": getRemainingLiveTime(),
            "callTimeLimit": SubscriptionConstants.getCallTimeLimit(tier: tier),
            "callTimeUsed": getCallTimeUsed(),
            "callTimeRemaining": getRemainingCallTime(),
            "currentPeriodStart": defaults.double(forKey: Keys.currentSubscriptionPeriodStart),
            "canStartLive": canStartLiveSession(),
            "canStartCall": canStartCall()
        ]
    }
}

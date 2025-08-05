//
//  FeatureLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import Combine

// MARK: - Feature Limit Manager Protocol
protocol FeatureLimitManager {
    var featureType: FeatureLimitType { get }
    
    func canPerformAction() -> Bool
    func incrementUsage()
    func getRemainingCooldown() -> TimeInterval
    func isInCooldown() -> Bool
    func resetCooldown()
    func getCurrentUsageCount() -> Int
    func getLimit() -> Int
    func getCooldownDuration() -> TimeInterval
}

// MARK: - Feature Limit Types
enum FeatureLimitType: String, CaseIterable {
    case conversation = "conversation"
    case refresh = "refresh"
    case filter = "filter"
    case search = "search"
    case message = "message"
    
    var displayName: String {
        switch self {
        case .conversation: return "Start Conversation"
        case .refresh: return "Refresh"
        case .filter: return "Apply Filter"
        case .search: return "Search"
        case .message: return "Send Message"
        }
    }
}

// MARK: - Feature Limit Result
struct FeatureLimitResult {
    let canProceed: Bool
    let showPopup: Bool
    let remainingCooldown: TimeInterval
    let currentUsage: Int
    let limit: Int
    
    var isLimitReached: Bool {
        return currentUsage >= limit
    }
}

// MARK: - Base Feature Limit Manager
class BaseFeatureLimitManager: FeatureLimitManager {
    let featureType: FeatureLimitType
    internal let messagingSessionManager = MessagingSettingsSessionManager.shared
    internal let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    init(featureType: FeatureLimitType) {
        self.featureType = featureType
        
        // Start background monitoring when any feature limit manager is created
        DispatchQueue.main.async {
            BackgroundTimerManager.shared.startMonitoring()
        }
    }
    
    func canPerformAction() -> Bool {
        // Light subscription users bypass all limits
        if subscriptionSessionManager.isUserSubscribedToLite() {
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
                AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "canPerformAction() - Cooldown expired, resetting usage count from \(currentUsage) to 0 (remaining: \(getRemainingCooldown())s)")
                resetCooldown()
                return true
            } else {
                // Still in cooldown, cannot proceed
                return false
            }
        } else {
            // Limit reached but cooldown not started yet (will be started when popup opens)
            AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "canPerformAction() - Limit reached (\(currentUsage)/\(limit)), cooldown will start when popup opens")
            return false
        }
    }
    
    /// Check if user is within new user grace period
    private func isNewUser() -> Bool {
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
    
    func incrementUsage() {
        let currentUsage = getCurrentUsageCount()
        setUsageCount(currentUsage + 1)
        
        // NOTE: Cooldown timestamp is now set when popup opens, not when limit is reached
        // This ensures users see the full cooldown timer when they click after reaching limit
    }
    
    func getRemainingCooldown() -> TimeInterval {
        guard isInCooldown() else { return 0 }
        
        let cooldownStartTime = getCooldownStartTime()
        let cooldownDuration = getCooldownDuration()
        let currentTime = Int64(Date().timeIntervalSince1970)
        let elapsed = currentTime - cooldownStartTime
        
        return max(0, cooldownDuration - TimeInterval(elapsed))
    }
    
    func isInCooldown() -> Bool {
        let cooldownStartTime = getCooldownStartTime()
        guard cooldownStartTime > 0 else { return false }
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        let elapsed = currentTime - cooldownStartTime
        
        return elapsed < Int64(getCooldownDuration())
    }
    
    func resetCooldown() {
        setCooldownStartTime(0)
        setUsageCount(0)
        
        // Note: Precise timers are managed by BackgroundTimerManager independently
        // to prevent cross-feature interference
    }
    
    func startCooldown() {
        let currentTime = Int64(Date().timeIntervalSince1970)
        setCooldownStartTime(currentTime)
        
        // Note: Precise timers are managed by BackgroundTimerManager independently
        // to prevent cross-feature interference
    }
    
    /// Start cooldown when popup opens (for limit-reached users)
    func startCooldownOnPopupOpen() {
        let currentUsage = getCurrentUsageCount()
        let limit = getLimit()
        
        // CRITICAL FIX: Check if cooldown expired while popup was closed using robust precision logic
        let cooldownStart = getCooldownStartTime()
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            // Fix: Use tolerance of 1 second to handle timing precision issues (same as BackgroundTimerManager)
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "startCooldownOnPopupOpen() - Cooldown expired while popup closed, auto-resetting (remaining: \(remaining)s)")
                resetCooldown()
                return // User gets fresh usage count, no need to start cooldown
            } else {
                AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "startCooldownOnPopupOpen() - Cooldown already active, remaining: \(remaining)s")
                return // Already in active cooldown
            }
        }
        
        // Only start cooldown if limit is reached and not already in cooldown
        if currentUsage >= limit {
            AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "startCooldownOnPopupOpen() - Starting cooldown timer as user reached limit (\(currentUsage)/\(limit))")
            startCooldown()
        } else {
            AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "startCooldownOnPopupOpen() - User has usage available (\(currentUsage)/\(limit)), no cooldown needed")
        }
    }
    
    // MARK: - Abstract methods to be overridden
    func getCurrentUsageCount() -> Int {
        fatalError("Must be overridden by subclass")
    }
    
    func getLimit() -> Int {
        fatalError("Must be overridden by subclass")
    }
    
    func getCooldownDuration() -> TimeInterval {
        fatalError("Must be overridden by subclass")
    }
    
    func setUsageCount(_ count: Int) {
        fatalError("Must be overridden by subclass")
    }
    
    func getCooldownStartTime() -> Int64 {
        fatalError("Must be overridden by subclass")
    }
    
    func setCooldownStartTime(_ time: Int64) {
        fatalError("Must be overridden by subclass")
    }
}
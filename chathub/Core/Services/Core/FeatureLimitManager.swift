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
        
        // If over limit, check if cooldown has expired
        if !isInCooldown() {
            // Cooldown has expired, reset usage count for fresh start
            AppLogger.log(tag: "LOG-APP: BaseFeatureLimitManager", message: "canPerformAction() - Cooldown expired, resetting usage count from \(currentUsage) to 0")
            resetCooldown()
            return true
        }
        
        return false
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
        
        // Start cooldown when we reach the limit 
        if currentUsage + 1 >= getLimit() && !isInCooldown() {
            startCooldown()
        }
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
    }
    
    func startCooldown() {
        let currentTime = Int64(Date().timeIntervalSince1970)
        setCooldownStartTime(currentTime)
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
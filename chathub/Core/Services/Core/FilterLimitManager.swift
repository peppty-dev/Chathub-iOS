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
        return messagingSessionManager.filterUsageCount
    }
    
    override func getLimit() -> Int {
        return messagingSessionManager.freeFilterLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return messagingSessionManager.freeFilterCooldownSeconds
    }
    
    override func setUsageCount(_ count: Int) {
        messagingSessionManager.filterUsageCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return messagingSessionManager.filterLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        messagingSessionManager.filterLimitCooldownStartTime = time
    }
    
    // MARK: - Filter-Specific Methods
    
    /// Check if filter action can be performed and return detailed result
    func checkFilterLimit() -> FeatureLimitResult {
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
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
        return messagingSessionManager.searchUsageCount
    }
    
    override func getLimit() -> Int {
        return messagingSessionManager.freeSearchLimit
    }
    
    override func getCooldownDuration() -> TimeInterval {
        return messagingSessionManager.freeSearchCooldownSeconds
    }
    
    override func setUsageCount(_ count: Int) {
        messagingSessionManager.searchUsageCount = count
    }
    
    override func getCooldownStartTime() -> Int64 {
        return messagingSessionManager.searchLimitCooldownStartTime
    }
    
    override func setCooldownStartTime(_ time: Int64) {
        messagingSessionManager.searchLimitCooldownStartTime = time
    }
    
    // MARK: - Search-Specific Methods
    
    /// Check if search action can be performed and return detailed result
    func checkSearchLimit() -> FeatureLimitResult {
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
}
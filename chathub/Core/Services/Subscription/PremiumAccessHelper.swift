import Foundation

/**
 * PremiumAccessHelper - Centralized premium access utility
 * This class provides a unified way to check premium status throughout the app
 * and serves as a migration bridge from legacy premium checks to the new subscription system
 */
class PremiumAccessHelper {
    
    /**
     * Main premium access check - USE THIS INSTEAD OF:
     * - SessionManager.shared.premiumActive
     * - UserDefaults.standard.bool(forKey: "premium_active")
     * - Direct premium_active checks
     */
    static var hasPremiumAccess: Bool {
        return SubscriptionSessionManager.shared.hasPremiumAccess()
    }
    
    /**
     * Backwards compatibility - matches SessionManager.shared.premiumActive
     */
    static var isPremiumActive: Bool {
        return SubscriptionSessionManager.shared.isPremiumActive()
    }
    
    /**
     * Check specific tier access
     */
    static var hasLiteAccess: Bool {
        return SubscriptionSessionManager.shared.hasLiteAccess()
    }
    
    static var hasPlusAccess: Bool {
        return SubscriptionSessionManager.shared.hasPlusAccess()
    }
    
    static var hasProAccess: Bool {
        return SubscriptionSessionManager.shared.hasProAccess()
    }
    
    static var hasPlusOrProAccess: Bool {
        return SubscriptionSessionManager.shared.hasPlusOrProAccess()
    }
    
    /**
     * Get current subscription tier
     */
    static var currentTier: String {
        return SubscriptionSessionManager.shared.getSubscriptionTier()
    }
    
    /**
     * Get current subscription status
     */
    static var currentStatus: String {
        return SubscriptionSessionManager.shared.getSubscriptionStatus()
    }
    
    /**
     * Check if user is in grace period
     */
    static var isInGracePeriod: Bool {
        return SubscriptionSessionManager.shared.isInGracePeriod()
    }
    
    /**
     * Check if user is on account hold
     */
    static var isOnAccountHold: Bool {
        return SubscriptionSessionManager.shared.isOnAccountHold()
    }
    
    /**
     * Log current premium status for debugging
     */
    static func logCurrentStatus() {
        SubscriptionHelper.logPremiumStatus(SubscriptionSessionManager.shared)
    }
}

// MARK: - Migration Helper Extensions

extension SessionManager {
    /**
     * DEPRECATED: Use PremiumAccessHelper.hasPremiumAccess instead
     * This property is maintained for backwards compatibility only
     */
    @available(*, deprecated, message: "Use PremiumAccessHelper.hasPremiumAccess instead")
    var premiumAccessDeprecated: Bool {
        return PremiumAccessHelper.hasPremiumAccess
    }
}

extension UserDefaults {
    /**
     * DEPRECATED: Use PremiumAccessHelper.hasPremiumAccess instead
     * Direct UserDefaults premium checks should be migrated to the subscription system
     */
    @available(*, deprecated, message: "Use PremiumAccessHelper.hasPremiumAccess instead")
    func premiumActiveDeprecated() -> Bool {
        return PremiumAccessHelper.hasPremiumAccess
    }
} 
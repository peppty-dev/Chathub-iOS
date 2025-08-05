import Foundation

/**
 * Standardized constants for subscription-related functionality
 * Centralizes all constants related to:
 * - Subscription IDs for App Store products
 * - Base plan IDs for subscription offers
 * - Subscription tiers (lite, plus, pro)
 * - Subscription periods (weekly, monthly, yearly)
 * - Subscription status values
 * - Time limits for various subscription tiers
 */
struct SubscriptionConstants {
    
    // MARK: - Product IDs (iOS App Store format)
    static let LITE_SUBSCRIPTION_ID = "com.peppty.ChatApp.lite"
    static let PLUS_SUBSCRIPTION_ID = "com.peppty.ChatApp.plus" 
    static let PRO_SUBSCRIPTION_ID = "com.peppty.ChatApp.pro"
    
    // MARK: - Base plan IDs
    static let LITE_WEEKLY_PLAN = "chathub-lite-weekly"
    static let LITE_MONTHLY_PLAN = "chathub-lite-monthly"
    static let LITE_YEARLY_PLAN = "chathub-lite-yearly"
    static let PLUS_WEEKLY_PLAN = "chathub-plus-weekly"
    static let PLUS_MONTHLY_PLAN = "chathub-plus-monthly"
    static let PLUS_YEARLY_PLAN = "chathub-plus-yearly"
    static let PRO_WEEKLY_PLAN = "chathub-pro-weekly"
    static let PRO_MONTHLY_PLAN = "chathub-pro-monthly"
    static let PRO_YEARLY_PLAN = "chathub-pro-yearly"
    
    // MARK: - Subscription tiers
    static let TIER_LITE = "lite"
    static let TIER_PLUS = "plus"
    static let TIER_PRO = "pro"
    static let TIER_NONE = "none"
    
    // MARK: - Subscription periods
    static let PERIOD_WEEKLY = "weekly"
    static let PERIOD_MONTHLY = "monthly"
    static let PERIOD_YEARLY = "yearly"
    
    // MARK: - Subscription status values
    static let STATUS_ACTIVE = "active"
    static let STATUS_INACTIVE = "inactive"
    static let STATUS_GRACE_PERIOD = "grace_period"
    static let STATUS_ACCOUNT_HOLD = "account_hold"
    static let STATUS_CANCELED = "canceled"
    static let STATUS_EXPIRED = "expired"
    static let STATUS_PENDING = "pending"
    static let STATUS_PAUSED = "paused"
    
    // MARK: - Keys for data processing
    static let KEY_TIER = "tier"
    static let KEY_PERIOD = "period"
    static let KEY_PLAN_ID = "planId"
    
    // MARK: - Time limits for different tiers
    static let LITE_TIME_LIMIT = 14400  // 4 hours
    static let PLUS_TIME_LIMIT = 28800  // 8 hours
    static let UNLIMITED_TIME = Int.max
    static let NO_TIME = 0
    
    // MARK: - Price display formats
    static let WEEKLY_PRICE_FORMAT = "%@%.0f"
    static let MONTHLY_PRICE_FORMAT = "%@%.0f"
    static let YEARLY_PRICE_FORMAT = "%@%.0f"
    
    // MARK: - Grace period and account hold durations
    static let GRACE_PERIOD_DURATION: Int64 = 3 * 24 * 60 * 60 * 1000  // 3 days in milliseconds
    static let ACCOUNT_HOLD_DURATION: Int64 = 30 * 24 * 60 * 60 * 1000  // 30 days in milliseconds
    
    // MARK: - Helper Methods
    
    /// Extracts the subscription period from a basePlanId for the purpose of price caching.
    /// This function should only be used when caching prices, not for display or session storage.
    static func getPeriodForPriceCachingFromBasePlanId(_ basePlanId: String?) -> String? {
        guard let basePlanId = basePlanId?.lowercased() else { return nil }
        if basePlanId.contains("week") { return PERIOD_WEEKLY }
        if basePlanId.contains("month") { return PERIOD_MONTHLY }
        if basePlanId.contains("year") { return PERIOD_YEARLY }
        return nil
    }
    
    /// Extracts the subscription period from a basePlanId for the purpose of UI display.
    /// This function should only be used for UI, not for caching or session storage.
    static func getPeriodForUIFromBasePlanId(_ basePlanId: String?) -> String? {
        guard let basePlanId = basePlanId?.lowercased() else { return nil }
        if basePlanId.contains("week") { return PERIOD_WEEKLY }
        if basePlanId.contains("month") { return PERIOD_MONTHLY }
        if basePlanId.contains("year") { return PERIOD_YEARLY }
        return nil
    }
    
    /// Gets all product IDs as a set for StoreKit requests
    static var allProductIDs: Set<String> {
        return [
            LITE_SUBSCRIPTION_ID,
            PLUS_SUBSCRIPTION_ID,
            PRO_SUBSCRIPTION_ID
        ]
    }
    
    /// Gets base plan ID from product ID and period
    static func getBasePlanId(productId: String, period: String) -> String? {
        let tierFromProductId = getTierFromProductId(productId)
        return getBasePlanId(tier: tierFromProductId, period: period)
    }
    
    /// Gets base plan ID from tier and period
    static func getBasePlanId(tier: String, period: String) -> String? {
        switch (tier.lowercased(), period.lowercased()) {
        case (TIER_LITE, PERIOD_WEEKLY): return LITE_WEEKLY_PLAN
        case (TIER_LITE, PERIOD_MONTHLY): return LITE_MONTHLY_PLAN
        case (TIER_LITE, PERIOD_YEARLY): return LITE_YEARLY_PLAN
        case (TIER_PLUS, PERIOD_WEEKLY): return PLUS_WEEKLY_PLAN
        case (TIER_PLUS, PERIOD_MONTHLY): return PLUS_MONTHLY_PLAN
        case (TIER_PLUS, PERIOD_YEARLY): return PLUS_YEARLY_PLAN
        case (TIER_PRO, PERIOD_WEEKLY): return PRO_WEEKLY_PLAN
        case (TIER_PRO, PERIOD_MONTHLY): return PRO_MONTHLY_PLAN
        case (TIER_PRO, PERIOD_YEARLY): return PRO_YEARLY_PLAN
        default: return nil
        }
    }
    
    /// Extracts tier from product ID
    static func getTierFromProductId(_ productId: String) -> String {
        let lowercased = productId.lowercased()
        if lowercased.contains("lite") { return TIER_LITE }
        if lowercased.contains("plus") { return TIER_PLUS }
        if lowercased.contains("pro") { return TIER_PRO }
        return TIER_NONE
    }
    
    /// Gets product ID from tier
    static func getProductId(tier: String) -> String? {
        switch tier.lowercased() {
        case TIER_LITE: return LITE_SUBSCRIPTION_ID
        case TIER_PLUS: return PLUS_SUBSCRIPTION_ID
        case TIER_PRO: return PRO_SUBSCRIPTION_ID
        default: return nil
        }
    }
    
    // Private init to prevent instantiation
    private init() {}
} 
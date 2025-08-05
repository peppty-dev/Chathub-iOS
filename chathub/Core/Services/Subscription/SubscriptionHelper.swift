import Foundation

/**
 * Helper class for premium subscription management and verification
 * Provides methods to initiate verification and validate premium status
 * iOS equivalent of Android's SubscriptionHelper.java
 */
struct SubscriptionHelper {
    
    // Private init to prevent instantiation (Android parity)
    private init() {}
    
    // MARK: - Expiry Time Calculation (Android Parity)
    
    /**
     * Calculates subscription expiry time based on purchase time and subscription period
     *
     * @param purchaseTime Purchase timestamp in milliseconds
     * @param period       Subscription period (weekly, monthly, yearly)
     * @return Expiry timestamp in milliseconds
     */
    static func calculateExpiryTime(_ purchaseTime: Int64, period: String) -> Int64 {
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: "calculateExpiryTime() called with purchaseTime=\(purchaseTime), period=\(period)")
        
        if period.isEmpty {
            // Default to monthly - using Calendar for accurate month calculation
            let calendar = Calendar.current
            let purchaseDate = Date(timeIntervalSince1970: TimeInterval(purchaseTime / 1000))
            let expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
            return Int64(expiryDate.timeIntervalSince1970 * 1000)
        }
        
        let calendar = Calendar.current
        let purchaseDate = Date(timeIntervalSince1970: TimeInterval(purchaseTime / 1000))
        
        switch period.lowercased() {
        case SubscriptionConstants.PERIOD_WEEKLY:
            let expiryDate = calendar.date(byAdding: .weekOfYear, value: 1, to: purchaseDate) ?? purchaseDate
            return Int64(expiryDate.timeIntervalSince1970 * 1000)
        case SubscriptionConstants.PERIOD_YEARLY:
            let expiryDate = calendar.date(byAdding: .year, value: 1, to: purchaseDate) ?? purchaseDate
            return Int64(expiryDate.timeIntervalSince1970 * 1000)
        case SubscriptionConstants.PERIOD_MONTHLY:
            let expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
            return Int64(expiryDate.timeIntervalSince1970 * 1000)
        default:
            // Use Calendar for accurate month calculation
            let expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
            return Int64(expiryDate.timeIntervalSince1970 * 1000)
        }
    }
    
    // MARK: - Time Formatting (Android Parity)
    
    /**
     * Gets a human-readable string for the time remaining in a subscription
     *
     * @param expiryTime Expiry timestamp in milliseconds
     * @return Human-readable string describing time remaining
     */
    static func getTimeRemainingString(_ expiryTime: Int64) -> String {
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: "getTimeRemainingString() called with expiryTime=\(expiryTime)")
        
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        
        if currentTime >= expiryTime {
            return "Expired"
        }
        
        let remainingMillis = expiryTime - currentTime
        let days = remainingMillis / (24 * 60 * 60 * 1000)
        
        if days > 30 {
            let months = days / 30
            return "\(months) \(months == 1 ? "month" : "months") remaining"
        } else if days > 0 {
            return "\(days) \(days == 1 ? "day" : "days") remaining"
        } else {
            let hours = remainingMillis / (60 * 60 * 1000)
            return "\(hours) \(hours == 1 ? "hour" : "hours") remaining"
        }
    }
    
    // MARK: - Status Logging (Android Parity)
    
    /**
     * Logs the current premium status from SubscriptionSessionManager for debugging
     *
     * @param subSessionManager The subscription session manager to read premium status from
     */
    static func logPremiumStatus(_ subSessionManager: SubscriptionSessionManager) {
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: "logPremiumStatus() called")
        
        let status = """
        Premium Status (from SubscriptionSessionManager Cache):
        - Subscription Active: \(subSessionManager.isSubscriptionActive())
        - Subscription Tier: \(subSessionManager.getSubscriptionTier())
        - Subscription Period: \(subSessionManager.getSubscriptionPeriod())
        - Subscription Start: \(Date(timeIntervalSince1970: TimeInterval(subSessionManager.getSubscriptionStartTime() / 1000)))
        - Grace Period: \(subSessionManager.isInGracePeriod())
        - Account Hold: \(subSessionManager.isOnAccountHold())
        - Auto Renewing: \(subSessionManager.isAutoRenewing())
        - Product ID: \(subSessionManager.getProductId() ?? "nil")
        - Base Plan ID: \(subSessionManager.getBasePlanId() ?? "nil")
        """
        
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: status)
    }
    
    // MARK: - Plan Name Formatting (Android Parity)
    
    /**
     * Formats a user-friendly plan name from tier and period
     *
     * @param tier The subscription tier (lite, plus, pro)
     * @param period The subscription period (weekly, monthly, yearly)
     * @return Formatted plan name string
     */
    static func formatPlanName(_ tier: String, period: String) -> String {
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: "formatPlanName() called with tier=\(tier), period=\(period)")
        
        if tier.isEmpty || period.isEmpty || tier == SubscriptionConstants.TIER_NONE {
            return "None"
        }
        
        let formattedTier = tier.prefix(1).uppercased() + tier.dropFirst()
        let formattedPeriod = period.prefix(1).uppercased() + period.dropFirst()
        
        return "\(formattedTier) (\(formattedPeriod))"
    }
    
    /**
     * Formats a timestamp into a readable date string
     *
     * @param timeMillis Timestamp in milliseconds
     * @return Formatted date string
     */
    static func formatDate(_ timeMillis: Int64) -> String {
        AppLogger.log(tag: "LOG-APP: SubscriptionHelper", message: "formatDate() called with timeMillis=\(timeMillis)")
        
        if timeMillis <= 0 { return "N/A" }
        
        let date = Date(timeIntervalSince1970: TimeInterval(timeMillis / 1000))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale.current
        
        return formatter.string(from: date)
    }
    
    // MARK: - Grace Period Formatting (Android Parity)
    
    /**
     * Formats the user-friendly message explaining the grace period status.
     *
     * @param remainingMillis Time remaining in the grace period in milliseconds.
     * @return A message string for the grace period.
     */
    static func formatGracePeriodMessage(_ remainingMillis: Int64) -> String {
        if remainingMillis <= 0 {
            return "Grace period has ended"
        }
        
        let days = remainingMillis / (24 * 60 * 60 * 1000)
        if days > 0 {
            return "Grace period: \(days) \(days == 1 ? "day" : "days") remaining"
        } else {
            let hours = remainingMillis / (60 * 60 * 1000)
            return "Grace period: \(hours) \(hours == 1 ? "hour" : "hours") remaining"
        }
    }
    
    /**
     * Formats the user-friendly message explaining the account hold status.
     *
     * @param remainingMillis Time remaining in the account hold in milliseconds.
     * @return A message string for the account hold.
     */
    static func formatAccountHoldMessage(_ remainingMillis: Int64) -> String {
        if remainingMillis <= 0 {
            return "Account hold has ended"
        }
        
        let days = remainingMillis / (24 * 60 * 60 * 1000)
        if days > 0 {
            return "Account on hold: \(days) \(days == 1 ? "day" : "days") remaining"
        } else {
            let hours = remainingMillis / (60 * 60 * 1000)
            return "Account on hold: \(hours) \(hours == 1 ? "hour" : "hours") remaining"
        }
    }
    
    // MARK: - Subscription Validation (Android Parity)
    
    /**
     * Validates if a subscription state represents an active premium subscription
     *
     * @param state The subscription state to validate
     * @return True if the subscription provides premium access
     */
    static func isValidPremiumSubscription(_ state: SubscriptionState) -> Bool {
        return state.isActive && 
               state.tier != SubscriptionConstants.TIER_NONE &&
               !state.isExpired()
    }
    
    /**
     * Gets the appropriate time limit for a subscription tier
     *
     * @param tier The subscription tier
     * @return Time limit in seconds for the tier
     */
    static func getTimeLimitForTier(_ tier: String) -> Int {
        switch tier.lowercased() {
        case SubscriptionConstants.TIER_LITE:
            return SubscriptionConstants.LITE_TIME_LIMIT
        case SubscriptionConstants.TIER_PLUS:
            return SubscriptionConstants.PLUS_TIME_LIMIT
        case SubscriptionConstants.TIER_PRO:
            return SubscriptionConstants.UNLIMITED_TIME
        default:
            return SubscriptionConstants.NO_TIME
        }
    }
} 
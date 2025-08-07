import Foundation
import Combine

// MARK: - Notification Extension
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}

class SubscriptionSessionManager: ObservableObject {
    static let shared = SubscriptionSessionManager()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys (Android Parity)
    private let PREF_SUBSCRIPTION_IS_ACTIVE = "pref_subscription_is_active"
    private let PREF_SUBSCRIPTION_TIER = "pref_subscription_tier"
    private let PREF_SUBSCRIPTION_PERIOD = "pref_subscription_period"
    private let PREF_SUBSCRIPTION_STATUS = "pref_subscription_status"
    private let PREF_SUBSCRIPTION_START_AT = "pref_subscription_start_at"
    private let PREF_SUBSCRIPTION_EXPIRY_AT = "pref_subscription_expiry_at"
    private let PREF_SUBSCRIPTION_IS_AUTO_RENEWING = "pref_subscription_is_auto_renewing"
    private let PREF_SUBSCRIPTION_PRODUCT_ID = "pref_subscription_product_id"
    private let PREF_SUBSCRIPTION_PURCHASE_TOKEN = "pref_subscription_purchase_token"
    private let PREF_SUBSCRIPTION_BASE_PLAN_ID = "pref_subscription_base_plan_id"
    private let PREF_SUBSCRIPTION_LAST_UPDATED = "pref_subscription_last_updated"
    
    // Grace Period Keys (Android Parity)
    private let PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD = "pref_subscription_is_in_grace_period"
    private let PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT = "pref_subscription_grace_period_end_at"
    
    // Account Hold Keys (Android Parity)
    private let PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD = "pref_subscription_is_on_account_hold"
    private let PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT = "pref_subscription_account_hold_end_at"
    
    // Price Caching Keys (Android Parity)
    private let SUBSCRIPTION_PRICE_PREFIX = "subscription_price_"
    private let SUBSCRIPTION_PRICE_MICROS_PREFIX = "subscription_price_micros_"
    private let PREF_PRICE_CACHE_TIMESTAMP = "pref_price_cache_timestamp"
    
    // Pending Subscription Keys (Android Parity)
    private let PREF_SUBSCRIPTION_PENDING_TIER = "subscription_pending_tier"
    private let PREF_SUBSCRIPTION_PENDING_PLAN_ID = "subscription_pending_plan_id"
    private let PREF_SUBSCRIPTION_PENDING_PERIOD = "subscription_pending_period"
    
    // Billing Query Throttling Keys (Android Parity)
    private let PREF_BILLING_LAST_QUERY = "pref_billing_last_query"

    // MARK: - Main State Update (Android Parity)
    
    /// Updates the local cache from the SubscriptionState received from Firestore.
    /// This is the primary method for keeping subscription data in sync with backend.
    func updateFromSubscriptionState(
        isActive: Bool,
        tier: String,
        period: String,
        status: String,
        startTimeMillis: Int64,
        expiryTimeMillis: Int64?,
        willAutoRenew: Bool,
        productId: String,
        purchaseToken: String?,
        basePlanId: String?,
        gracePeriodEndMillis: Int64 = 0,
        accountHoldEndMillis: Int64 = 0
    ) {
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "updateFromSubscriptionState() Updating subscription state: active=\(isActive), tier=\(tier), period=\(period)")
        
        defaults.set(isActive, forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
        defaults.set(tier, forKey: PREF_SUBSCRIPTION_TIER)
        defaults.set(period, forKey: PREF_SUBSCRIPTION_PERIOD)
        defaults.set(status, forKey: PREF_SUBSCRIPTION_STATUS)
        defaults.set(startTimeMillis, forKey: PREF_SUBSCRIPTION_START_AT)
        
        if let expiryTime = expiryTimeMillis {
            defaults.set(expiryTime, forKey: PREF_SUBSCRIPTION_EXPIRY_AT)
        }
        
        defaults.set(willAutoRenew, forKey: PREF_SUBSCRIPTION_IS_AUTO_RENEWING)
        defaults.set(productId, forKey: PREF_SUBSCRIPTION_PRODUCT_ID)
        defaults.set(purchaseToken, forKey: PREF_SUBSCRIPTION_PURCHASE_TOKEN)
        defaults.set(basePlanId, forKey: PREF_SUBSCRIPTION_BASE_PLAN_ID)
        defaults.set(Date().timeIntervalSince1970 * 1000, forKey: PREF_SUBSCRIPTION_LAST_UPDATED)
        
        // Handle grace period
        if gracePeriodEndMillis > 0 {
            defaults.set(true, forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
            defaults.set(gracePeriodEndMillis, forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT)
        } else {
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
            defaults.set(0, forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT)
        }
        
        // Handle account hold
        if accountHoldEndMillis > 0 {
            defaults.set(true, forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
            defaults.set(accountHoldEndMillis, forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT)
        } else {
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
            defaults.set(0, forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT)
        }
        
        defaults.synchronize()
        
        // Reset time allocations on subscription renewal/update
        TimeAllocationManager.shared.markSubscriptionRenewal()
        
        // Auto-sync with SessionManager for backwards compatibility
        syncWithSessionManager()
    }

    // MARK: - Basic Getters (Android Parity)
    var isSubscribed: Bool {
        return defaults.bool(forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
    }
    
    func isSubscriptionActive() -> Bool {
        return defaults.bool(forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
    }
    
    func getSubscriptionTier() -> String {
        return defaults.string(forKey: PREF_SUBSCRIPTION_TIER) ?? SubscriptionConstants.TIER_NONE
    }
    
    func getSubscriptionPeriod() -> String {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PERIOD) ?? "none"
    }
    
    func getSubscriptionStatus() -> String {
        // Android parity: dynamic status calculation
        if isOnAccountHold() { return SubscriptionConstants.STATUS_ACCOUNT_HOLD }
        if isInGracePeriod() { return SubscriptionConstants.STATUS_GRACE_PERIOD }
        if isSubscriptionActive() { return SubscriptionConstants.STATUS_ACTIVE }
        return defaults.string(forKey: PREF_SUBSCRIPTION_STATUS) ?? SubscriptionConstants.STATUS_INACTIVE
    }
    
    func getSubscriptionStartTime() -> Int64 {
        return Int64(defaults.double(forKey: PREF_SUBSCRIPTION_START_AT))
    }
    
    func getSubscriptionExpiryTime() -> Int64 {
        return Int64(defaults.double(forKey: PREF_SUBSCRIPTION_EXPIRY_AT))
    }
    
    func isAutoRenewing() -> Bool {
        return defaults.bool(forKey: PREF_SUBSCRIPTION_IS_AUTO_RENEWING)
    }
    
    func getProductId() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PRODUCT_ID)
    }
    
    func getPurchaseToken() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PURCHASE_TOKEN)
    }
    
    func getBasePlanId() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_BASE_PLAN_ID)
    }
    
    func getLastUpdatedTime() -> Int64 {
        return Int64(defaults.double(forKey: PREF_SUBSCRIPTION_LAST_UPDATED))
    }
    
    // MARK: - Individual Setters (Android Parity)
    
    func setSubscriptionTier(_ tier: String) {
        let safeTier = tier.isEmpty ? SubscriptionConstants.TIER_NONE : tier
        defaults.set(safeTier, forKey: PREF_SUBSCRIPTION_TIER)
        defaults.synchronize()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    func setSubscriptionPeriod(_ period: String) {
        let safePeriod = period.isEmpty ? "none" : period
        defaults.set(safePeriod, forKey: PREF_SUBSCRIPTION_PERIOD)
        defaults.synchronize()
    }
    
    func setSubscriptionStartTime(_ startTime: Int64) {
        defaults.set(Double(startTime), forKey: PREF_SUBSCRIPTION_START_AT)
        defaults.synchronize()
    }
    
    func setSubscriptionActive(_ active: Bool) {
        defaults.set(active, forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
        if !active {
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
            if !isOnAccountHold() && !isInGracePeriod() {
                defaults.set(SubscriptionConstants.STATUS_INACTIVE, forKey: PREF_SUBSCRIPTION_STATUS)
            }
        }
        defaults.synchronize()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    func setSubscriptionStatus(_ status: String) {
        let safeStatus = status.isEmpty ? SubscriptionConstants.STATUS_INACTIVE : status
        defaults.set(safeStatus, forKey: PREF_SUBSCRIPTION_STATUS)
        defaults.synchronize()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    // MARK: - Tier-Specific Checkers (Android Parity)
    
    /// Check if user has EXACT Lite subscription (for analytics/debugging only)
    func isUserExactlySubscribedToLite() -> Bool {
        return isSubscriptionActive() && getSubscriptionTier().lowercased() == SubscriptionConstants.TIER_LITE
    }
    
    /// Check if user has EXACT Plus subscription (for analytics/debugging only)
    func isUserExactlySubscribedToPlus() -> Bool {
        return isSubscriptionActive() && getSubscriptionTier().lowercased() == SubscriptionConstants.TIER_PLUS
    }
    
    /// Check if user has EXACT Pro subscription (for analytics/debugging only)
    func isUserExactlySubscribedToPro() -> Bool {
        return isSubscriptionActive() && getSubscriptionTier().lowercased() == SubscriptionConstants.TIER_PRO
    }
    
    // MARK: - Tier Inheritance Checkers (CLEAR NAMING)
    
    /// Check if user has Lite tier access or higher (includes Lite, Plus, Pro)
    func hasLiteTierOrHigher() -> Bool {
        guard isSubscriptionActive() else { return false }
        let tier = getSubscriptionTier().lowercased()
        return tier == SubscriptionConstants.TIER_LITE || 
               tier == SubscriptionConstants.TIER_PLUS || 
               tier == SubscriptionConstants.TIER_PRO
    }
    
    /// Check if user has Plus tier access or higher (includes Plus, Pro)
    func hasPlusTierOrHigher() -> Bool {
        guard isSubscriptionActive() else { return false }
        let tier = getSubscriptionTier().lowercased()
        return tier == SubscriptionConstants.TIER_PLUS || 
               tier == SubscriptionConstants.TIER_PRO
    }
    
    /// Check if user has Pro tier access (Pro only)
    func hasProTier() -> Bool {
        guard isSubscriptionActive() else { return false }
        let tier = getSubscriptionTier().lowercased()
        return tier == SubscriptionConstants.TIER_PRO
    }
    
    // MARK: - Backward Compatibility (DEPRECATED)
    
    /// @deprecated Use hasLiteTierOrHigher() instead - this method name is misleading
    @available(*, deprecated, message: "Use hasLiteTierOrHigher() instead. This method includes Plus and Pro tiers.")
    func isUserSubscribedToLite() -> Bool {
        return hasLiteTierOrHigher()
    }
    
    /// @deprecated Use hasPlusTierOrHigher() instead - this method name is misleading  
    @available(*, deprecated, message: "Use hasPlusTierOrHigher() instead. This method includes Pro tier.")
    func isUserSubscribedToPlus() -> Bool {
        return hasPlusTierOrHigher()
    }
    
    /// @deprecated Use hasProTier() instead for clarity
    @available(*, deprecated, message: "Use hasProTier() instead for better clarity.")
    func isUserSubscribedToPro() -> Bool {
        return hasProTier()
    }
    
    // MARK: - Grace Period Methods (Android Parity)
    
    func isInGracePeriod() -> Bool {
        let flag = defaults.bool(forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
        let endTime = Int64(defaults.double(forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT))
        return flag && (endTime > Int64(Date().timeIntervalSince1970 * 1000))
    }
    
    func setInGracePeriod(_ inGracePeriod: Bool, gracePeriodEnd: Int64) {
        defaults.set(inGracePeriod, forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
        defaults.set(Double(inGracePeriod ? gracePeriodEnd : 0), forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT)
        if inGracePeriod {
            defaults.set(true, forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
            defaults.set(SubscriptionConstants.STATUS_GRACE_PERIOD, forKey: PREF_SUBSCRIPTION_STATUS)
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
        }
        defaults.synchronize()
    }
    
    func getGracePeriodEnd() -> Int64 {
        return Int64(defaults.double(forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT))
    }
    
    // MARK: - Account Hold Methods (Android Parity)
    
    func isOnAccountHold() -> Bool {
        let flag = defaults.bool(forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
        let endTime = Int64(defaults.double(forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT))
        return flag && (endTime > Int64(Date().timeIntervalSince1970 * 1000))
    }
    
    func setOnAccountHold(_ onHold: Bool, holdEnd: Int64) {
        defaults.set(onHold, forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
        defaults.set(Double(onHold ? holdEnd : 0), forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT)
        if onHold {
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
            defaults.set(SubscriptionConstants.STATUS_ACCOUNT_HOLD, forKey: PREF_SUBSCRIPTION_STATUS)
            defaults.set(false, forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
        }
        defaults.synchronize()
    }
    
    func getAccountHoldEnd() -> Int64 {
        return Int64(defaults.double(forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT))
    }
    
    // MARK: - Price Caching Methods (Android Parity)
    
    func setSubscriptionPrice(_ productId: String, period: String, formattedPrice: String, priceInMicros: Int64) {
        let priceKey = "\(SUBSCRIPTION_PRICE_PREFIX)\(productId)_\(period)"
        let microsKey = "\(SUBSCRIPTION_PRICE_MICROS_PREFIX)\(productId)_\(period)"
        defaults.set(formattedPrice, forKey: priceKey)
        defaults.set(Double(priceInMicros), forKey: microsKey)
        defaults.synchronize()
    }
    
    func getSubscriptionPrice(_ productId: String, period: String) -> String? {
        let priceKey = "\(SUBSCRIPTION_PRICE_PREFIX)\(productId)_\(period)"
        return defaults.string(forKey: priceKey)
    }
    
    func getSubscriptionPriceMicros(_ productId: String, period: String) -> Int64 {
        let microsKey = "\(SUBSCRIPTION_PRICE_MICROS_PREFIX)\(productId)_\(period)"
        return Int64(defaults.double(forKey: microsKey))
    }
    
    func updatePriceCacheTimestamp() {
        defaults.set(Date().timeIntervalSince1970 * 1000, forKey: PREF_PRICE_CACHE_TIMESTAMP)
        defaults.synchronize()
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "updatePriceCacheTimestamp() Price cache timestamp updated")
    }
    
    // MARK: - Pending Subscription Methods (Android Parity)
    
    func getPendingTier() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PENDING_TIER)
    }
    
    func setPendingTier(_ tier: String?) {
        if let tier = tier {
            defaults.set(tier, forKey: PREF_SUBSCRIPTION_PENDING_TIER)
        } else {
            defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_TIER)
        }
        defaults.synchronize()
    }
    
    func getPendingPlanId() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PENDING_PLAN_ID)
    }
    
    func setPendingPlanId(_ planId: String?) {
        if let planId = planId {
            defaults.set(planId, forKey: PREF_SUBSCRIPTION_PENDING_PLAN_ID)
        } else {
            defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PLAN_ID)
        }
        defaults.synchronize()
    }
    
    func getPendingPeriod() -> String? {
        return defaults.string(forKey: PREF_SUBSCRIPTION_PENDING_PERIOD)
    }
    
    func setPendingPeriod(_ period: String?) {
        if let period = period {
            defaults.set(period, forKey: PREF_SUBSCRIPTION_PENDING_PERIOD)
        } else {
            defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PERIOD)
        }
        defaults.synchronize()
    }
    
    func clearPendingSubscriptionDetails() {
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_TIER)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PLAN_ID)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PERIOD)
        defaults.synchronize()
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "clearPendingSubscriptionDetails() Cleared pending subscription details")
    }
    
    // MARK: - Complete Session Clearing (Android Parity)
    
    /// Clears all subscription session data - Android parity method for account removal
    /// ANDROID PARITY: Matches SubscriptionSessionManager clearing in RemoveAccountActivity
    func clearAllSubscriptionData() {
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "clearAllSubscriptionData() Starting complete subscription session clearing (Android parity)")
        
        // Clear main subscription state
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_IS_ACTIVE)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_TIER)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PERIOD)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_STATUS)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_START_AT)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_EXPIRY_AT)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_IS_AUTO_RENEWING)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PRODUCT_ID)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PURCHASE_TOKEN)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_BASE_PLAN_ID)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_LAST_UPDATED)
        
        // Clear grace period state
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_IS_IN_GRACE_PERIOD)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_GRACE_PERIOD_END_AT)
        
        // Clear account hold state
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_IS_ON_ACCOUNT_HOLD)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_ACCOUNT_HOLD_END_AT)
        
        // Clear price cache
        defaults.removeObject(forKey: PREF_PRICE_CACHE_TIMESTAMP)
        
        // Clear all cached product prices (iterate through possible product IDs)
        let possibleProductIds = [
            "lite_monthly", "lite_yearly",
            "plus_monthly", "plus_yearly", 
            "pro_monthly", "pro_yearly"
        ]
        
        for productId in possibleProductIds {
            let priceKey = "\(SUBSCRIPTION_PRICE_PREFIX)\(productId)"
            let microsKey = "\(SUBSCRIPTION_PRICE_MICROS_PREFIX)\(productId)"
            defaults.removeObject(forKey: priceKey)
            defaults.removeObject(forKey: microsKey)
        }
        
        // Clear pending subscription details
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_TIER)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PLAN_ID)
        defaults.removeObject(forKey: PREF_SUBSCRIPTION_PENDING_PERIOD)
        
        // Clear billing query throttling
        defaults.removeObject(forKey: PREF_BILLING_LAST_QUERY)
        
        defaults.synchronize()
        
        // ANDROID PARITY: Update SessionManager to clear legacy premium flags
        SessionManager.shared.premiumActive = false
        SessionManager.shared.synchronize()
        
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "clearAllSubscriptionData() Complete subscription session clearing finished (Android parity)")
    }
    
    // MARK: - Billing Query Throttling Methods (Android Parity)
    
    func getLastBillingQueryTime() -> Int64 {
        return Int64(defaults.double(forKey: PREF_BILLING_LAST_QUERY))
    }
    
    func updateLastBillingQueryTime(_ timestamp: Int64) {
        defaults.set(Double(timestamp), forKey: PREF_BILLING_LAST_QUERY)
        defaults.synchronize()
    }
    
    // MARK: - State Construction (Android Parity)
    
    func getCurrentSubscriptionState() -> SubscriptionState {
        return SubscriptionState(
            isActive: isSubscriptionActive(),
            tier: getSubscriptionTier(),
            period: getSubscriptionPeriod(),
            status: getSubscriptionStatus(),
            gracePeriodEndMillis: getGracePeriodEnd(),
            accountHoldEndMillis: getAccountHoldEnd(),
            willAutoRenew: isAutoRenewing(),
            expiryTimeMillis: getSubscriptionExpiryTime(),
            startTimeMillis: getSubscriptionStartTime(),
            productId: getProductId(),
            purchaseToken: getPurchaseToken(),
            basePlanId: getBasePlanId()
        )
    }
    
    // MARK: - Logging Helper (Android Parity)
    
    func logCurrentSubscriptionStatus() {
        let status = """
        Subscription Status (from SubscriptionSessionManager Cache):
        - Subscription Active: \(isSubscriptionActive())
        - Subscription Tier: \(getSubscriptionTier())
        - Subscription Period: \(getSubscriptionPeriod())
        - Subscription Status: \(getSubscriptionStatus())
        - Subscription Start: \(Date(timeIntervalSince1970: TimeInterval(getSubscriptionStartTime() / 1000)))
        - Grace Period: \(isInGracePeriod())
        - Account Hold: \(isOnAccountHold())
        - Auto Renewing: \(isAutoRenewing())
        - Product ID: \(getProductId() ?? "nil")
        - Base Plan ID: \(getBasePlanId() ?? "nil")
        """
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "logCurrentSubscriptionStatus() \(status)")
    }

    // MARK: - Premium Access Unified Check (Android Parity)
    
    /**
     * Returns whether the user has premium access, considering all subscription states
     * including grace periods and account holds (Android parity)
     *
     * @return true if user has premium access
     */
    func hasPremiumAccess() -> Bool {
        // Check if subscription is active
        if !isSubscriptionActive() {
            return false
        }
        
        // Check if tier is valid (not none)
        let tier = getSubscriptionTier()
        if tier == SubscriptionConstants.TIER_NONE || tier.isEmpty {
            return false
        }
        
        // Grace period users still have premium access
        if isInGracePeriod() {
            return true
        }
        
        // Account hold users do NOT have premium access
        if isOnAccountHold() {
            return false
        }
        
        return true
    }
    
    /**
     * Backwards compatibility method - matches SessionManager.shared.premiumActive
     * This method should be used instead of direct UserDefaults checks
     */
    func isPremiumActive() -> Bool {
        return hasPremiumAccess()
    }
    
    /**
     * Check if user has specific tier access (Android parity with tier inheritance)
     */
    func hasLiteAccess() -> Bool {
        return hasPremiumAccess() && hasLiteTierOrHigher()
    }
    
    func hasPlusAccess() -> Bool {
        return hasPremiumAccess() && hasPlusTierOrHigher()
    }
    
    func hasProAccess() -> Bool {
        return hasPremiumAccess() && hasProTier()
    }
    
    /**
     * Check if user has Plus or Pro access (commonly used for advanced features)
     */
    func hasPlusOrProAccess() -> Bool {
        return hasPlusAccess() || hasProAccess()
    }
    
    /**
     * Update SessionManager.shared.premiumActive for backwards compatibility
     * This should be called whenever subscription state changes
     */
    func syncWithSessionManager() {
        let premiumStatus = hasPremiumAccess()
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "syncWithSessionManager() Updating SessionManager.premiumActive to: \(premiumStatus)")
        SessionManager.shared.premiumActive = premiumStatus
        SessionManager.shared.synchronize()
    }
    
    // MARK: - Additional Price Caching Methods (Android Parity - for SubscriptionSystemTest)
    
    /// Save product price with formatted price and micros - Android parity
    func saveProductPrice(_ productId: String, price: String, priceMicros: Int64) {
        let priceKey = "\(SUBSCRIPTION_PRICE_PREFIX)\(productId)"
        let microsKey = "\(SUBSCRIPTION_PRICE_MICROS_PREFIX)\(productId)"
        defaults.set(price, forKey: priceKey)
        defaults.set(Double(priceMicros), forKey: microsKey)
        updatePriceCacheTimestamp()
        defaults.synchronize()
        AppLogger.log(tag: "LOG-APP: SubscriptionSessionManager", message: "saveProductPrice() Saved price for \(productId): \(price) (\(priceMicros) micros)")
    }
    
    /// Get formatted product price - Android parity
    func getProductPrice(_ productId: String) -> String? {
        let priceKey = "\(SUBSCRIPTION_PRICE_PREFIX)\(productId)"
        return defaults.string(forKey: priceKey)
    }
    
    /// Get product price in micros - Android parity
    func getProductPriceMicros(_ productId: String) -> Int64 {
        let microsKey = "\(SUBSCRIPTION_PRICE_MICROS_PREFIX)\(productId)"
        return Int64(defaults.double(forKey: microsKey))
    }
    
    /// Get price cache timestamp - Android parity
    func getPriceCacheTimestamp() -> Int64 {
        return Int64(defaults.double(forKey: PREF_PRICE_CACHE_TIMESTAMP))
    }
} 
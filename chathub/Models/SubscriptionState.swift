import Foundation

/**
 * Data class that holds the confirmed subscription state
 * iOS equivalent of Android's SubscriptionState.java
 */
struct SubscriptionState {
    let isActive: Bool
    let tier: String
    let period: String
    let status: String
    let gracePeriodEndMillis: Int64
    let accountHoldEndMillis: Int64
    let willAutoRenew: Bool
    let expiryTimeMillis: Int64
    let startTimeMillis: Int64
    let productId: String?
    let purchaseToken: String?
    let basePlanId: String?
    
    init(
        isActive: Bool,
        tier: String,
        period: String,
        status: String,
        gracePeriodEndMillis: Int64,
        accountHoldEndMillis: Int64,
        willAutoRenew: Bool,
        expiryTimeMillis: Int64,
        startTimeMillis: Int64,
        productId: String?,
        purchaseToken: String?,
        basePlanId: String?
    ) {
        self.isActive = isActive
        self.tier = tier.isEmpty ? SubscriptionConstants.TIER_NONE : tier
        self.period = period.isEmpty ? "none" : period
        self.status = status.isEmpty ? SubscriptionConstants.STATUS_INACTIVE : status
        self.gracePeriodEndMillis = gracePeriodEndMillis
        self.accountHoldEndMillis = accountHoldEndMillis
        self.willAutoRenew = willAutoRenew
        self.expiryTimeMillis = expiryTimeMillis
        self.startTimeMillis = startTimeMillis
        self.productId = productId
        self.purchaseToken = purchaseToken
        self.basePlanId = basePlanId
    }
    
    /// Factory method to create an inactive subscription state (Android parity)
    static func inactive() -> SubscriptionState {
        return SubscriptionState(
            isActive: false,
            tier: SubscriptionConstants.TIER_NONE,
            period: "none",
            status: SubscriptionConstants.STATUS_INACTIVE,
            gracePeriodEndMillis: 0,
            accountHoldEndMillis: 0,
            willAutoRenew: false,
            expiryTimeMillis: 0,
            startTimeMillis: 0,
            productId: nil,
            purchaseToken: nil,
            basePlanId: nil
        )
    }
    
    // MARK: - Status Check Methods (Android Parity)
    
    func isInGracePeriod() -> Bool {
        return status == SubscriptionConstants.STATUS_GRACE_PERIOD &&
               (gracePeriodEndMillis > 0 && Int64(Date().timeIntervalSince1970 * 1000) < gracePeriodEndMillis)
    }
    
    func isOnHold() -> Bool {
        return status == SubscriptionConstants.STATUS_ACCOUNT_HOLD &&
               (accountHoldEndMillis > 0 && Int64(Date().timeIntervalSince1970 * 1000) < accountHoldEndMillis)
    }
    
    func isExpired() -> Bool {
        if status == SubscriptionConstants.STATUS_EXPIRED { return true }
        return !isActive && expiryTimeMillis > 0 && Int64(Date().timeIntervalSince1970 * 1000) > expiryTimeMillis
    }
    
    func isCancelled() -> Bool {
        if status == SubscriptionConstants.STATUS_CANCELED { return true }
        return !willAutoRenew && !isExpired() && isActive
    }
    
    // MARK: - Utility Methods (Android Parity)
    
    /// Gets the time remaining on the subscription in milliseconds
    func getRemainingTimeMillis() -> Int64 {
        if !isActive { return 0 }
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        return max(0, expiryTimeMillis - currentTime)
    }
    
    /// Checks if the subscription is about to expire soon (within 3 days)
    func isExpiringWithin3Days() -> Bool {
        let remainingTime = getRemainingTimeMillis()
        return remainingTime > 0 && remainingTime < (3 * 24 * 60 * 60 * 1000)
    }
    
    /// Returns whether the user has premium access, considering all subscription states including grace periods
    func hasPremiumAccess() -> Bool {
        return isActive && tier != SubscriptionConstants.TIER_NONE
    }
}

// MARK: - Equatable (for testing and comparison)
extension SubscriptionState: Equatable {
    static func == (lhs: SubscriptionState, rhs: SubscriptionState) -> Bool {
        return lhs.isActive == rhs.isActive &&
               lhs.tier == rhs.tier &&
               lhs.period == rhs.period &&
               lhs.status == rhs.status &&
               lhs.gracePeriodEndMillis == rhs.gracePeriodEndMillis &&
               lhs.accountHoldEndMillis == rhs.accountHoldEndMillis &&
               lhs.willAutoRenew == rhs.willAutoRenew &&
               lhs.expiryTimeMillis == rhs.expiryTimeMillis &&
               lhs.startTimeMillis == rhs.startTimeMillis &&
               lhs.productId == rhs.productId &&
               lhs.purchaseToken == rhs.purchaseToken &&
               lhs.basePlanId == rhs.basePlanId
    }
}

// MARK: - CustomStringConvertible (for debugging)
extension SubscriptionState: CustomStringConvertible {
    var description: String {
        return """
        SubscriptionState(
            isActive: \(isActive),
            tier: \(tier),
            period: \(period),
            status: \(status),
            gracePeriodEndMillis: \(gracePeriodEndMillis),
            accountHoldEndMillis: \(accountHoldEndMillis),
            willAutoRenew: \(willAutoRenew),
            expiryTimeMillis: \(expiryTimeMillis),
            startTimeMillis: \(startTimeMillis),
            productId: \(productId ?? "nil"),
            purchaseToken: \(purchaseToken ?? "nil"),
            basePlanId: \(basePlanId ?? "nil")
        )
        """
    }
} 
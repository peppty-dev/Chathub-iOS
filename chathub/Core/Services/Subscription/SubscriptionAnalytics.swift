import Foundation
import FirebaseAnalytics

/**
 * Helper class for tracking detailed subscription analytics events
 * iOS equivalent of Android's SubscriptionAnalytics.java
 */
class SubscriptionAnalytics {
    
    // MARK: - Singleton Instance (Android Parity)
    static let shared = SubscriptionAnalytics()
    
    // MARK: - Analytics Event Constants (Android Parity)
    static let EVENT_SUBSCRIPTION_VIEW = "premium_view"
    static let EVENT_SUBSCRIPTION_ATTEMPT = "subscription_attempt"
    static let EVENT_SUBSCRIPTION_PURCHASE = "subscription_purchase"
    static let EVENT_SUBSCRIPTION_RENEWAL = "subscription_renewal"
    static let EVENT_SUBSCRIPTION_PERIOD_CHANGE = "subscription_period_change"
    static let EVENT_NEW_SUBSCRIPTION = "new_subscription"
    static let EVENT_SUBSCRIPTION_ERROR = "subscription_error"
    static let EVENT_CANCELLATION_ATTEMPT = "cancellation_attempt"
    static let EVENT_GRACE_PERIOD_ENTERED = "grace_period_entered"
    static let EVENT_ACCOUNT_HOLD_ENTERED = "account_hold_entered"
    static let EVENT_PAYMENT_FAILED = "payment_failed"
    
    // MARK: - Properties
    private let sessionManager: SessionManager
    private let subscriptionSessionManager: SubscriptionSessionManager
    
    // MARK: - Initialization
    init(sessionManager: SessionManager, subscriptionSessionManager: SubscriptionSessionManager) {
        self.sessionManager = sessionManager
        self.subscriptionSessionManager = subscriptionSessionManager
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "SubscriptionAnalytics initialized")
    }
    
    // MARK: - Convenience Initializer (Android Parity)
    convenience init() {
        self.init(
            sessionManager: SessionManager.shared,
            subscriptionSessionManager: SubscriptionSessionManager.shared
        )
    }
    
    // MARK: - Analytics Event Tracking (Android Parity)
    
    /**
     * Tracks when the subscription/premium view is opened
     */
         func trackSubscriptionView(source: String? = nil) {
         var parameters = createBaseParameters()
         if let source = source {
             parameters["source"] = source
         }
        
        Analytics.logEvent(Self.EVENT_SUBSCRIPTION_VIEW, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionView() Event logged with source: \(source ?? "nil")")
    }
    
    /**
     * Tracks when a user attempts to start a subscription purchase
     */
         func trackSubscriptionAttempt(tier: String, period: String, productId: String? = nil) {
         var parameters = createBaseParameters()
         parameters["tier"] = tier
         parameters["period"] = period
         parameters["product_id"] = productId ?? ""
        
        Analytics.logEvent(Self.EVENT_SUBSCRIPTION_ATTEMPT, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionAttempt() Event logged for tier: \(tier), period: \(period)")
    }
    
    /**
     * Tracks successful subscription purchase
     */
    func trackSubscriptionPurchase(
        tier: String,
        period: String,
        productId: String,
        purchaseToken: String? = nil,
        price: String? = nil,
        currency: String? = nil,
        isUpgrade: Bool = false,
        isDowngrade: Bool = false,
        previousTier: String? = nil
         ) {
         var parameters = createBaseParameters()
         parameters["tier"] = tier
         parameters["period"] = period
         parameters["product_id"] = productId
         parameters["purchase_token"] = purchaseToken ?? ""
         parameters["price"] = price ?? ""
         parameters["currency"] = currency ?? "USD"
         parameters["is_upgrade"] = isUpgrade
         parameters["is_downgrade"] = isDowngrade
         parameters["previous_tier"] = previousTier ?? ""
        
        Analytics.logEvent(Self.EVENT_SUBSCRIPTION_PURCHASE, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionPurchase() Event logged for tier: \(tier), period: \(period), isUpgrade: \(isUpgrade)")
    }
    
    /**
     * Tracks subscription renewal events
     */
         func trackSubscriptionRenewal(tier: String, period: String, renewalCount: Int = 0) {
         var parameters = createBaseParameters()
         parameters["tier"] = tier
         parameters["period"] = period
         parameters["renewal_count"] = renewalCount
        
        Analytics.logEvent(Self.EVENT_SUBSCRIPTION_RENEWAL, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionRenewal() Event logged for tier: \(tier), renewalCount: \(renewalCount)")
    }
    
    /**
     * Tracks subscription period changes (e.g., monthly to yearly)
     */
    func trackSubscriptionPeriodChange(
        fromTier: String,
        fromPeriod: String,
        toTier: String,
        toPeriod: String
    ) {
                 var parameters = createBaseParameters()
         parameters["from_tier"] = fromTier
         parameters["from_period"] = fromPeriod
         parameters["to_tier"] = toTier
         parameters["to_period"] = toPeriod

         Analytics.logEvent(Self.EVENT_SUBSCRIPTION_PERIOD_CHANGE, parameters: parameters)
         AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionPeriodChange() Event logged from \(fromTier)-\(fromPeriod) to \(toTier)-\(toPeriod)")
     }
     
     /**
      * Tracks new subscription events (first-time subscribers)
      */
     func trackNewSubscription(tier: String, period: String, daysSinceInstall: Int = 0) {
         var parameters = createBaseParameters()
         parameters["tier"] = tier
         parameters["period"] = period
         parameters["days_since_install"] = daysSinceInstall

         Analytics.logEvent(Self.EVENT_NEW_SUBSCRIPTION, parameters: parameters)
         AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackNewSubscription() Event logged for tier: \(tier), daysSinceInstall: \(daysSinceInstall)")
     }
     
     /**
      * Tracks subscription errors
      */
     func trackSubscriptionError(
         errorType: String,
         errorMessage: String,
         tier: String? = nil,
         period: String? = nil
     ) {
         var parameters = createBaseParameters()
         parameters["error_type"] = errorType
         parameters["error_message"] = errorMessage
         parameters["tier"] = tier ?? ""
         parameters["period"] = period ?? ""
        
        Analytics.logEvent(Self.EVENT_SUBSCRIPTION_ERROR, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackSubscriptionError() Event logged for errorType: \(errorType)")
    }
    
    /**
     * Tracks cancellation attempts
     */
    func trackCancellationAttempt(tier: String, period: String, reason: String? = nil) {
        var parameters = createBaseParameters()
        parameters["tier"] = tier
        parameters["period"] = period
        parameters["cancellation_reason"] = reason ?? ""
        
        Analytics.logEvent(Self.EVENT_CANCELLATION_ATTEMPT, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackCancellationAttempt() Event logged for tier: \(tier), reason: \(reason ?? "nil")")
    }
    
    /**
     * Tracks when a subscription enters grace period
     */
    func trackGracePeriodEntered(tier: String, period: String, gracePeriodDays: Int) {
        var parameters = createBaseParameters()
        parameters["tier"] = tier
        parameters["period"] = period
        parameters["grace_period_days"] = gracePeriodDays
        
        Analytics.logEvent(Self.EVENT_GRACE_PERIOD_ENTERED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackGracePeriodEntered() Event logged for tier: \(tier), gracePeriodDays: \(gracePeriodDays)")
    }
    
    /**
     * Tracks when a subscription is put on account hold
     */
    func trackAccountHoldEntered(tier: String, period: String, holdReason: String? = nil) {
        var parameters = createBaseParameters()
        parameters["tier"] = tier
        parameters["period"] = period
        parameters["hold_reason"] = holdReason ?? ""
        
        Analytics.logEvent(Self.EVENT_ACCOUNT_HOLD_ENTERED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackAccountHoldEntered() Event logged for tier: \(tier), holdReason: \(holdReason ?? "nil")")
    }
    
    /**
     * Tracks payment failures
     */
    func trackPaymentFailed(
        tier: String,
        period: String,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        var parameters = createBaseParameters()
        parameters["tier"] = tier
        parameters["period"] = period
        parameters["error_code"] = errorCode ?? ""
        parameters["error_message"] = errorMessage ?? ""
        
        Analytics.logEvent(Self.EVENT_PAYMENT_FAILED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SubscriptionAnalytics", message: "trackPaymentFailed() Event logged for tier: \(tier), errorCode: \(errorCode ?? "nil")")
    }
    
    // MARK: - Helper Methods (Android Parity)
    
    /**
     * Creates base parameters that are included in all analytics events
     */
    private func createBaseParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // User information
        parameters["user_id"] = sessionManager.userId ?? ""
        parameters["is_anonymous"] = (sessionManager.emailAddress?.isEmpty ?? true)
        
        // Current subscription state
        parameters["current_tier"] = subscriptionSessionManager.getSubscriptionTier()
        parameters["current_period"] = subscriptionSessionManager.getSubscriptionPeriod()
        parameters["is_currently_subscribed"] = subscriptionSessionManager.isSubscriptionActive()
        parameters["subscription_status"] = subscriptionSessionManager.getSubscriptionStatus()
        
        // App information
        parameters["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        parameters["platform"] = "iOS"
        
        // Timestamps
        parameters["timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        
        return parameters
    }
    
    /**
     * Calculates days since app install for analytics
     */
    private func getDaysSinceInstall() -> Int {
        // This would need to be stored during app first launch
        // For now, return 0 as placeholder
        return 0
    }
    
    /**
     * Gets subscription duration in days for analytics
     */
    private func getSubscriptionDurationDays() -> Int {
        let startTime = subscriptionSessionManager.getSubscriptionStartTime()
        if startTime <= 0 { return 0 }
        
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let durationMillis = currentTime - startTime
        return Int(durationMillis / (24 * 60 * 60 * 1000))
    }
    
    // MARK: - Batch Analytics (Android Parity)
    
    /**
     * Tracks a complete subscription flow from view to purchase
     */
    func trackSubscriptionFlow(
        tier: String,
        period: String,
        source: String,
        success: Bool,
        errorMessage: String? = nil
    ) {
        // Track the view
        trackSubscriptionView(source: source)
        
        // Track the attempt
        trackSubscriptionAttempt(tier: tier, period: period)
        
        // Track the result
        if success {
            trackSubscriptionPurchase(tier: tier, period: period, productId: "")
        } else if let error = errorMessage {
            trackSubscriptionError(errorType: "purchase_failed", errorMessage: error, tier: tier, period: period)
        }
    }
} 
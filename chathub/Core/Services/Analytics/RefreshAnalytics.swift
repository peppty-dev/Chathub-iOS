import Foundation
import FirebaseAnalytics

/**
 * Comprehensive analytics tracking for Refresh Feature
 * Tracks user behavior, conversion funnel, and business metrics
 * iOS equivalent of Android's refresh analytics implementation
 */
class RefreshAnalytics {
    
    // MARK: - Singleton Instance
    static let shared = RefreshAnalytics()
    
    // MARK: - Analytics Event Constants (iOS-specific naming)
    static let EVENT_REFRESH_BUTTON_TAPPED = "ios_refresh_button_tapped"
    static let EVENT_REFRESH_POPUP_SHOWN = "ios_refresh_popup_shown"
    static let EVENT_REFRESH_POPUP_DISMISSED = "ios_refresh_popup_dismissed"
    static let EVENT_REFRESH_PERFORMED = "ios_refresh_performed"
    static let EVENT_REFRESH_BLOCKED_LIMIT_REACHED = "ios_refresh_blocked_limit_reached"
    static let EVENT_REFRESH_BLOCKED_COOLDOWN = "ios_refresh_blocked_cooldown"
    static let EVENT_REFRESH_SUBSCRIPTION_BUTTON_TAPPED = "ios_refresh_subscription_button_tapped"
    static let EVENT_REFRESH_LIMIT_RESET = "ios_refresh_limit_reset"
    static let EVENT_REFRESH_NEW_USER_BYPASS = "ios_refresh_new_user_bypass"
    static let EVENT_REFRESH_LITE_SUBSCRIBER_BYPASS = "ios_refresh_lite_subscriber_bypass"
    static let EVENT_REFRESH_COOLDOWN_COMPLETED = "ios_refresh_cooldown_completed"
    static let EVENT_REFRESH_PRICING_DISPLAYED = "ios_refresh_pricing_displayed"
    
    // MARK: - Parameter Keys (iOS-specific naming)
    static let PARAM_USER_TYPE = "ios_user_type"
    static let PARAM_SUBSCRIPTION_STATUS = "ios_subscription_status"
    static let PARAM_CURRENT_USAGE = "ios_current_usage"
    static let PARAM_USAGE_LIMIT = "ios_usage_limit"
    static let PARAM_REMAINING_COOLDOWN = "ios_remaining_cooldown_seconds"
    static let PARAM_IS_LIMIT_REACHED = "ios_is_limit_reached"
    static let PARAM_IS_NEW_USER = "ios_is_new_user"
    static let PARAM_NEW_USER_TIME_REMAINING = "ios_new_user_time_remaining_seconds"
    static let PARAM_POPUP_TRIGGER_REASON = "ios_popup_trigger_reason"
    static let PARAM_REFRESH_SOURCE = "ios_refresh_source"
    static let PARAM_SUBSCRIPTION_PRICE = "ios_subscription_price_displayed"
    static let PARAM_TIME_SINCE_LAST_REFRESH = "ios_time_since_last_refresh_seconds"
    static let PARAM_SESSION_REFRESH_COUNT = "ios_session_refresh_count"
    static let PARAM_CONVERSION_FUNNEL_STEP = "ios_conversion_funnel_step"
    
    // MARK: - User Type Values (iOS-specific naming)
    static let USER_TYPE_LITE_SUBSCRIBER = "ios_lite_subscriber"
    static let USER_TYPE_NEW_USER = "ios_new_user"
    static let USER_TYPE_FREE_USER = "ios_free_user"
    
    // MARK: - Properties
    private let sessionManager: SessionManager
    private let subscriptionSessionManager: SubscriptionSessionManager
    private let userSessionManager: UserSessionManager
    private var sessionRefreshCount: Int = 0
    private var lastRefreshTime: TimeInterval = 0
    
    // MARK: - Initialization
    init(sessionManager: SessionManager = SessionManager.shared,
         subscriptionSessionManager: SubscriptionSessionManager = SubscriptionSessionManager.shared,
         userSessionManager: UserSessionManager = UserSessionManager.shared) {
        self.sessionManager = sessionManager
        self.subscriptionSessionManager = subscriptionSessionManager
        self.userSessionManager = userSessionManager
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "RefreshAnalytics initialized")
    }
    
    // MARK: - Core Refresh Events
    
    /**
     * Tracks when user taps the refresh button
     */
    func trackRefreshButtonTapped(userType: String, currentUsage: Int, limit: Int, isLimitReached: Bool) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_IS_LIMIT_REACHED] = isLimitReached
        parameters[Self.PARAM_REFRESH_SOURCE] = "manual_button"
        parameters[Self.PARAM_SESSION_REFRESH_COUNT] = sessionRefreshCount
        parameters[Self.PARAM_TIME_SINCE_LAST_REFRESH] = lastRefreshTime > 0 ? Int(Date().timeIntervalSince1970 - lastRefreshTime) : 0
        
        Analytics.logEvent(Self.EVENT_REFRESH_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshButtonTapped() - userType: \(userType), usage: \(currentUsage)/\(limit)")
    }
    
    /**
     * Tracks when refresh popup is shown to user
     */
    func trackRefreshPopupShown(userType: String, currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, triggerReason: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_POPUP_TRIGGER_REASON] = triggerReason
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_exposure"
        
        Analytics.logEvent(Self.EVENT_REFRESH_POPUP_SHOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshPopupShown() - reason: \(triggerReason), cooldown: \(remainingCooldown)s")
    }
    
    /**
     * Tracks when refresh popup is dismissed
     */
    func trackRefreshPopupDismissed(userType: String, dismissMethod: String, timeSpentInPopup: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters["ios_dismiss_method"] = dismissMethod // "background_tap", "close_button", "refresh_action", "subscription_action"
        parameters["ios_time_spent_seconds"] = Int(timeSpentInPopup)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_dismissed"
        
        Analytics.logEvent(Self.EVENT_REFRESH_POPUP_DISMISSED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshPopupDismissed() - method: \(dismissMethod), time: \(timeSpentInPopup)s")
    }
    
    /**
     * Tracks successful refresh action
     */
    func trackRefreshPerformed(userType: String, currentUsage: Int, limit: Int, isFirstRefreshOfSession: Bool) {
        sessionRefreshCount += 1
        lastRefreshTime = Date().timeIntervalSince1970
        
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_SESSION_REFRESH_COUNT] = sessionRefreshCount
        parameters["ios_is_first_refresh_of_session"] = isFirstRefreshOfSession
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "refresh_completed"
        
        Analytics.logEvent(Self.EVENT_REFRESH_PERFORMED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshPerformed() - userType: \(userType), sessionCount: \(sessionRefreshCount)")
    }
    
    /**
     * Tracks when refresh is blocked due to limit reached
     */
    func trackRefreshBlockedLimitReached(currentUsage: Int, limit: Int, cooldownDuration: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_FREE_USER
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters["ios_cooldown_duration_seconds"] = Int(cooldownDuration)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "limit_reached"
        
        Analytics.logEvent(Self.EVENT_REFRESH_BLOCKED_LIMIT_REACHED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshBlockedLimitReached() - usage: \(currentUsage)/\(limit)")
    }
    
    /**
     * Tracks when refresh is blocked due to active cooldown
     */
    func trackRefreshBlockedCooldown(remainingCooldown: TimeInterval, currentUsage: Int, limit: Int) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_FREE_USER
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "cooldown_active"
        
        Analytics.logEvent(Self.EVENT_REFRESH_BLOCKED_COOLDOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshBlockedCooldown() - remaining: \(remainingCooldown)s")
    }
    
    // MARK: - Subscription Conversion Events
    
    /**
     * Tracks when user taps subscription button in refresh popup
     */
    func trackSubscriptionButtonTapped(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, priceDisplayed: String?) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_FREE_USER
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_SUBSCRIPTION_PRICE] = priceDisplayed ?? ""
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "subscription_intent"
        parameters["ios_conversion_source"] = "refresh_limit_popup"
        
        Analytics.logEvent(Self.EVENT_REFRESH_SUBSCRIPTION_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackSubscriptionButtonTapped() - price: \(priceDisplayed ?? "nil")")
    }
    
    /**
     * Tracks when subscription pricing is displayed in popup
     */
    func trackPricingDisplayed(price: String, currency: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_SUBSCRIPTION_PRICE] = price
        parameters["ios_currency_code"] = currency
        parameters["ios_pricing_context"] = "refresh_popup"
        
        Analytics.logEvent(Self.EVENT_REFRESH_PRICING_DISPLAYED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackPricingDisplayed() - price: \(price) \(currency)")
    }
    
    // MARK: - User Segment Events
    
    /**
     * Tracks when new user bypasses refresh limits
     */
    func trackNewUserBypass(timeRemainingInFreePeriod: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_NEW_USER
        parameters[Self.PARAM_IS_NEW_USER] = true
        parameters[Self.PARAM_NEW_USER_TIME_REMAINING] = Int(timeRemainingInFreePeriod)
        parameters[Self.PARAM_SESSION_REFRESH_COUNT] = sessionRefreshCount
        
        Analytics.logEvent(Self.EVENT_REFRESH_NEW_USER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackNewUserBypass() - time remaining: \(timeRemainingInFreePeriod)s")
    }
    
    /**
     * Tracks when Lite subscriber bypasses refresh limits
     */
    func trackLiteSubscriberBypass(subscriptionTier: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_LITE_SUBSCRIBER
        parameters["ios_subscription_tier"] = subscriptionTier
        parameters[Self.PARAM_SESSION_REFRESH_COUNT] = sessionRefreshCount
        
        Analytics.logEvent(Self.EVENT_REFRESH_LITE_SUBSCRIBER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackLiteSubscriberBypass() - tier: \(subscriptionTier)")
    }
    
    // MARK: - System Events
    
    /**
     * Tracks when refresh limits are automatically reset after cooldown
     */
    func trackRefreshLimitReset(previousUsage: Int, limit: Int, cooldownDuration: TimeInterval) {
        var parameters = createBaseParameters()
        parameters["ios_previous_usage"] = previousUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters["ios_cooldown_duration_seconds"] = Int(cooldownDuration)
        parameters["ios_reset_trigger"] = "automatic_cooldown_expiry"
        
        Analytics.logEvent(Self.EVENT_REFRESH_LIMIT_RESET, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackRefreshLimitReset() - previous usage: \(previousUsage)")
    }
    
    /**
     * Tracks when cooldown period completes
     */
    func trackCooldownCompleted(totalCooldownDuration: TimeInterval, usageBeforeCooldown: Int) {
        var parameters = createBaseParameters()
        parameters["ios_cooldown_duration_seconds"] = Int(totalCooldownDuration)
        parameters["ios_usage_before_cooldown"] = usageBeforeCooldown
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "cooldown_completed"
        
        Analytics.logEvent(Self.EVENT_REFRESH_COOLDOWN_COMPLETED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "trackCooldownCompleted() - duration: \(totalCooldownDuration)s")
    }
    
    // MARK: - Helper Methods
    
    /**
     * Creates base parameters included in all refresh analytics events
     */
    private func createBaseParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // User information
        parameters["ios_user_id"] = sessionManager.userId ?? ""
        parameters["ios_is_anonymous"] = (sessionManager.emailAddress?.isEmpty ?? true)
        
        // Subscription information
        parameters[Self.PARAM_SUBSCRIPTION_STATUS] = subscriptionSessionManager.getSubscriptionTier()
        parameters["ios_is_lite_subscriber"] = subscriptionSessionManager.isUserSubscribedToLite()
        parameters["ios_subscription_active"] = subscriptionSessionManager.isSubscriptionActive()
        
        // New user information
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = sessionManager.newUserFreePeriodSeconds
        let isNewUser = firstAccountTime > 0 && newUserPeriod > 0 && 
                       (Date().timeIntervalSince1970 - firstAccountTime) < TimeInterval(newUserPeriod)
        parameters[Self.PARAM_IS_NEW_USER] = isNewUser
        
        if isNewUser {
            let remainingTime = TimeInterval(newUserPeriod) - (Date().timeIntervalSince1970 - firstAccountTime)
            parameters[Self.PARAM_NEW_USER_TIME_REMAINING] = Int(max(0, remainingTime))
        }
        
        // App and session information
        parameters["ios_app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        parameters["ios_platform"] = "iOS"
        parameters["ios_timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        parameters["ios_session_id"] = generateSessionId()
        
        // Refresh configuration
        parameters["ios_refresh_limit_config"] = sessionManager.freeRefreshLimit
        parameters["ios_refresh_cooldown_config"] = Int(sessionManager.freeRefreshCooldownSeconds)
        
        return parameters
    }
    
    /**
     * Generates a simple session identifier
     */
    private func generateSessionId() -> String {
        return "ios_session_\(Int(Date().timeIntervalSince1970))"
    }
    
    /**
     * Determines user type for analytics
     */
    func getUserType() -> String {
        if subscriptionSessionManager.isUserSubscribedToLite() {
            return Self.USER_TYPE_LITE_SUBSCRIBER
        }
        
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = sessionManager.newUserFreePeriodSeconds
        let isNewUser = firstAccountTime > 0 && newUserPeriod > 0 && 
                       (Date().timeIntervalSince1970 - firstAccountTime) < TimeInterval(newUserPeriod)
        
        return isNewUser ? Self.USER_TYPE_NEW_USER : Self.USER_TYPE_FREE_USER
    }
    
    /**
     * Resets session counters (call when app becomes active)
     */
    func resetSessionCounters() {
        sessionRefreshCount = 0
        lastRefreshTime = 0
        AppLogger.log(tag: "LOG-APP: RefreshAnalytics", message: "resetSessionCounters() - Session counters reset")
    }
}
import Foundation
import FirebaseAnalytics

/**
 * Comprehensive analytics tracking for Search Feature
 * Tracks user behavior, conversion funnel, and business metrics
 * iOS equivalent of Android's search analytics implementation
 * Follows RefreshAnalytics pattern for consistency
 */
class SearchAnalytics {
    
    // MARK: - Singleton Instance
    static let shared = SearchAnalytics()
    
    // MARK: - Analytics Event Constants (iOS-specific naming)
    static let EVENT_SEARCH_BUTTON_TAPPED = "ios_search_button_tapped"
    static let EVENT_SEARCH_POPUP_SHOWN = "ios_search_popup_shown"
    static let EVENT_SEARCH_POPUP_DISMISSED = "ios_search_popup_dismissed"
    static let EVENT_SEARCH_PERFORMED = "ios_search_performed"
    static let EVENT_SEARCH_BLOCKED_LIMIT_REACHED = "ios_search_blocked_limit_reached"
    static let EVENT_SEARCH_BLOCKED_COOLDOWN = "ios_search_blocked_cooldown"
    static let EVENT_SEARCH_SUBSCRIPTION_BUTTON_TAPPED = "ios_search_subscription_button_tapped"
    static let EVENT_SEARCH_LIMIT_RESET = "ios_search_limit_reset"
    static let EVENT_SEARCH_NEW_USER_BYPASS = "ios_search_new_user_bypass"
    static let EVENT_SEARCH_LITE_SUBSCRIBER_BYPASS = "ios_search_lite_subscriber_bypass"
    static let EVENT_SEARCH_COOLDOWN_COMPLETED = "ios_search_cooldown_completed"
    static let EVENT_SEARCH_PRICING_DISPLAYED = "ios_search_pricing_displayed"
    
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
    static let PARAM_SEARCH_QUERY = "ios_search_query"
    static let PARAM_SEARCH_RESULTS_COUNT = "ios_search_results_count"
    static let PARAM_SUBSCRIPTION_PRICE = "ios_subscription_price_displayed"
    static let PARAM_TIME_SINCE_LAST_SEARCH = "ios_time_since_last_search_seconds"
    static let PARAM_SESSION_SEARCH_COUNT = "ios_session_search_count"
    static let PARAM_CONVERSION_FUNNEL_STEP = "ios_conversion_funnel_step"
    static let PARAM_SEARCH_SUCCESS = "ios_search_success"
    
    // MARK: - User Type Values (iOS-specific naming)
    static let USER_TYPE_LITE_SUBSCRIBER = "ios_lite_subscriber"
    static let USER_TYPE_NEW_USER = "ios_new_user"
    static let USER_TYPE_FREE_USER = "ios_free_user"
    
    // MARK: - Properties
    private let sessionManager: SessionManager
    private let subscriptionSessionManager: SubscriptionSessionManager
    private let userSessionManager: UserSessionManager
    private var sessionSearchCount: Int = 0
    private var lastSearchTime: TimeInterval = 0
    
    // MARK: - Initialization
    init(sessionManager: SessionManager = SessionManager.shared,
         subscriptionSessionManager: SubscriptionSessionManager = SubscriptionSessionManager.shared,
         userSessionManager: UserSessionManager = UserSessionManager.shared) {
        self.sessionManager = sessionManager
        self.subscriptionSessionManager = subscriptionSessionManager
        self.userSessionManager = userSessionManager
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "SearchAnalytics initialized")
    }
    
    // MARK: - Core Search Events
    
    /**
     * Tracks when user performs a search
     */
    func trackSearchButtonTapped(userType: String, currentUsage: Int, limit: Int, isLimitReached: Bool, searchQuery: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_IS_LIMIT_REACHED] = isLimitReached
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_SESSION_SEARCH_COUNT] = sessionSearchCount
        parameters[Self.PARAM_TIME_SINCE_LAST_SEARCH] = lastSearchTime > 0 ? Int(Date().timeIntervalSince1970 - lastSearchTime) : 0
        
        Analytics.logEvent(Self.EVENT_SEARCH_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchButtonTapped() Event logged for query: \(searchQuery)")
    }
    
    /**
     * Tracks when search popup is shown
     */
    func trackSearchPopupShown(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, triggerReason: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_POPUP_TRIGGER_REASON] = triggerReason
        parameters[Self.PARAM_IS_LIMIT_REACHED] = currentUsage >= limit
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_shown"
        
        Analytics.logEvent(Self.EVENT_SEARCH_POPUP_SHOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchPopupShown() Event logged - reason: \(triggerReason)")
    }
    
    /**
     * Tracks when search popup is dismissed
     */
    func trackSearchPopupDismissed(dismissMethod: String, timeSpentInPopup: TimeInterval, userAction: String) {
        var parameters = createBaseParameters()
        parameters["ios_dismiss_method"] = dismissMethod
        parameters["ios_time_spent_in_popup_seconds"] = Int(timeSpentInPopup)
        parameters["ios_user_action"] = userAction
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_dismissed"
        
        Analytics.logEvent(Self.EVENT_SEARCH_POPUP_DISMISSED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchPopupDismissed() Event logged - method: \(dismissMethod)")
    }
    
    /**
     * Tracks successful search execution
     */
    func trackSearchPerformed(searchQuery: String, resultsCount: Int, success: Bool, userType: String) {
        sessionSearchCount += 1
        lastSearchTime = Date().timeIntervalSince1970
        
        var parameters = createBaseParameters()
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_SEARCH_RESULTS_COUNT] = resultsCount
        parameters[Self.PARAM_SEARCH_SUCCESS] = success
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_SESSION_SEARCH_COUNT] = sessionSearchCount
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "search_completed"
        
        Analytics.logEvent(Self.EVENT_SEARCH_PERFORMED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchPerformed() Event logged - query: \(searchQuery), results: \(resultsCount)")
    }
    
    /**
     * Tracks when search is blocked due to limit reached
     */
    func trackSearchBlockedLimitReached(currentUsage: Int, limit: Int, searchQuery: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "blocked_limit_reached"
        
        Analytics.logEvent(Self.EVENT_SEARCH_BLOCKED_LIMIT_REACHED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchBlockedLimitReached() Event logged - usage: \(currentUsage)/\(limit)")
    }
    
    /**
     * Tracks when search is blocked due to cooldown
     */
    func trackSearchBlockedCooldown(remainingCooldown: TimeInterval, searchQuery: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "blocked_cooldown"
        
        Analytics.logEvent(Self.EVENT_SEARCH_BLOCKED_COOLDOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchBlockedCooldown() Event logged - remaining: \(Int(remainingCooldown))s")
    }
    
    /**
     * Tracks when user taps subscription button from search popup
     */
    func trackSearchSubscriptionButtonTapped(currentUsage: Int, limit: Int, pricingDisplayed: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_SUBSCRIPTION_PRICE] = pricingDisplayed
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "subscription_intent"
        
        Analytics.logEvent(Self.EVENT_SEARCH_SUBSCRIPTION_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchSubscriptionButtonTapped() Event logged - pricing: \(pricingDisplayed)")
    }
    
    /**
     * Tracks when new user bypasses search limits
     */
    func trackSearchNewUserBypass(remainingFreeTime: TimeInterval, searchQuery: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_NEW_USER_TIME_REMAINING] = Int(remainingFreeTime)
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_NEW_USER
        
        Analytics.logEvent(Self.EVENT_SEARCH_NEW_USER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchNewUserBypass() Event logged - remaining time: \(Int(remainingFreeTime))s")
    }
    
    /**
     * Tracks when Lite subscriber bypasses search limits
     */
    func trackSearchLiteSubscriberBypass(searchQuery: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_SEARCH_QUERY] = searchQuery.count <= 50 ? searchQuery : String(searchQuery.prefix(50))
        parameters[Self.PARAM_USER_TYPE] = Self.USER_TYPE_LITE_SUBSCRIBER
        
        Analytics.logEvent(Self.EVENT_SEARCH_LITE_SUBSCRIBER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchLiteSubscriberBypass() Event logged for Lite subscriber")
    }
    
    /**
     * Tracks when search limit is automatically reset
     */
    func trackSearchLimitReset(resetReason: String) {
        var parameters = createBaseParameters()
        parameters["ios_reset_reason"] = resetReason
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "limit_reset"
        
        Analytics.logEvent(Self.EVENT_SEARCH_LIMIT_RESET, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchLimitReset() Event logged - reason: \(resetReason)")
    }
    
    /**
     * Tracks when cooldown period completes
     */
    func trackSearchCooldownCompleted(totalCooldownDuration: TimeInterval) {
        var parameters = createBaseParameters()
        parameters["ios_cooldown_duration_seconds"] = Int(totalCooldownDuration)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "cooldown_completed"
        
        Analytics.logEvent(Self.EVENT_SEARCH_COOLDOWN_COMPLETED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackSearchCooldownCompleted() Event logged - duration: \(Int(totalCooldownDuration))s")
    }
    
    /**
     * Tracks when subscription pricing is displayed in popup
     */
    func trackPricingDisplayed(price: String, currency: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_SUBSCRIPTION_PRICE] = price
        parameters["ios_currency_code"] = currency
        parameters["ios_pricing_context"] = "search_popup"
        
        Analytics.logEvent(Self.EVENT_SEARCH_PRICING_DISPLAYED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: SearchAnalytics", message: "trackPricingDisplayed() - price: \(price) \(currency)")
    }
    
    // MARK: - Helper Methods
    
    /**
     * Creates base parameters included in all analytics events
     */
    private func createBaseParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // User information
        parameters["ios_user_id"] = userSessionManager.userId ?? ""
        parameters["ios_is_anonymous"] = (userSessionManager.emailAddress?.isEmpty ?? true)
        
        // Current subscription state
        parameters[Self.PARAM_SUBSCRIPTION_STATUS] = subscriptionSessionManager.isUserSubscribedToLite() ? "lite" : "free"
        parameters["ios_is_currently_subscribed"] = subscriptionSessionManager.isUserSubscribedToLite()
        
        // App information
        parameters["ios_app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        parameters["ios_platform"] = "iOS"
        
        // Timestamps
        parameters["ios_timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        
        // Search-specific context
        parameters[Self.PARAM_CURRENT_USAGE] = sessionManager.searchUsageCount
        parameters[Self.PARAM_USAGE_LIMIT] = sessionManager.freeSearchLimit
        
        return parameters
    }
    
    /**
     * Gets current user type for analytics (public interface)
     */
    func getUserType() -> String {
        return getCurrentUserType()
    }
    
    /**
     * Gets current user type for analytics (internal implementation)
     */
    private func getCurrentUserType() -> String {
        if subscriptionSessionManager.isUserSubscribedToLite() {
            return Self.USER_TYPE_LITE_SUBSCRIBER
        } else if isNewUser() {
            return Self.USER_TYPE_NEW_USER
        } else {
            return Self.USER_TYPE_FREE_USER
        }
    }
    
    /**
     * Checks if user is in new user free period
     */
    private func isNewUser() -> Bool {
        let firstAccountTime = userSessionManager.firstAccountCreatedTime
        let newUserPeriod = sessionManager.newUserFreePeriodSeconds
        
        if firstAccountTime <= 0 || newUserPeriod <= 0 {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - firstAccountTime
        
        return elapsed < TimeInterval(newUserPeriod)
    }
}
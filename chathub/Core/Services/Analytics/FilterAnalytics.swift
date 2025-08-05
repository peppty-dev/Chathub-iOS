import Foundation
import FirebaseAnalytics

/**
 * Comprehensive analytics tracking for Filter Feature
 * Tracks user behavior, conversion funnel, and business metrics
 * iOS equivalent of Android's filter analytics implementation
 * Follows RefreshAnalytics pattern for consistency
 */
class FilterAnalytics {
    
    // MARK: - Singleton Instance
    static let shared = FilterAnalytics()
    
    // MARK: - Analytics Event Constants (iOS-specific naming)
    static let EVENT_FILTER_BUTTON_TAPPED = "ios_filter_button_tapped"
    static let EVENT_FILTER_POPUP_SHOWN = "ios_filter_popup_shown"
    static let EVENT_FILTER_POPUP_DISMISSED = "ios_filter_popup_dismissed"
    static let EVENT_FILTER_PERFORMED = "ios_filter_performed"
    static let EVENT_FILTER_BLOCKED_LIMIT_REACHED = "ios_filter_blocked_limit_reached"
    static let EVENT_FILTER_BLOCKED_COOLDOWN = "ios_filter_blocked_cooldown"
    static let EVENT_FILTER_SUBSCRIPTION_BUTTON_TAPPED = "ios_filter_subscription_button_tapped"
    static let EVENT_FILTER_LIMIT_RESET = "ios_filter_limit_reset"
    static let EVENT_FILTER_NEW_USER_BYPASS = "ios_filter_new_user_bypass"
    static let EVENT_FILTER_LITE_SUBSCRIBER_BYPASS = "ios_filter_lite_subscriber_bypass"
    static let EVENT_FILTER_COOLDOWN_COMPLETED = "ios_filter_cooldown_completed"
    static let EVENT_FILTER_PRICING_DISPLAYED = "ios_filter_pricing_displayed"
    
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
    static let PARAM_FILTER_SOURCE = "ios_filter_source"
    static let PARAM_FILTER_CRITERIA = "ios_filter_criteria"
    static let PARAM_FILTER_COUNT = "ios_filter_count"
    static let PARAM_DISMISSAL_METHOD = "ios_dismissal_method"
    static let PARAM_TIME_SPENT_IN_POPUP = "ios_time_spent_in_popup_seconds"
    static let PARAM_SUBSCRIPTION_PRICE = "ios_subscription_price"
    static let PARAM_CURRENCY = "ios_currency"
    
    // MARK: - Dependencies
    private let userSessionManager: UserSessionManager
    private let subscriptionSessionManager: SubscriptionSessionManager
    private let sessionManager: SessionManager
    
    // MARK: - Initialization
    init(userSessionManager: UserSessionManager = UserSessionManager.shared,
         subscriptionSessionManager: SubscriptionSessionManager = SubscriptionSessionManager.shared,
         sessionManager: SessionManager = SessionManager.shared) {
        self.userSessionManager = userSessionManager
        self.subscriptionSessionManager = subscriptionSessionManager
        self.sessionManager = sessionManager
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "FilterAnalytics initialized")
    }
    
    // MARK: - User Type Detection
    func getUserType() -> String {
        if subscriptionSessionManager.isUserSubscribedToLite() {
            return "lite_subscriber"
        } else if subscriptionSessionManager.isUserSubscribedToPlus() {
            return "plus_subscriber"
        } else if subscriptionSessionManager.isUserSubscribedToPro() {
            return "pro_subscriber"
        } else if isNewUser() {
            return "new_user"
        } else {
            return "free_user"
        }
    }
    
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
    
    // MARK: - Core Analytics Events
    
    func trackFilterButtonTapped(source: String) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_FILTER_SOURCE: source,
            FilterAnalytics.PARAM_IS_NEW_USER: isNewUser()
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackFilterButtonTapped() - Source: \(source), UserType: \(getUserType())")
    }
    
    func trackFilterPopupShown(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, triggerReason: String) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_CURRENT_USAGE: currentUsage,
            FilterAnalytics.PARAM_USAGE_LIMIT: limit,
            FilterAnalytics.PARAM_REMAINING_COOLDOWN: Int(remainingCooldown),
            FilterAnalytics.PARAM_IS_LIMIT_REACHED: currentUsage >= limit,
            FilterAnalytics.PARAM_IS_NEW_USER: isNewUser(),
            FilterAnalytics.PARAM_POPUP_TRIGGER_REASON: triggerReason
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_POPUP_SHOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackFilterPopupShown() - Usage: \(currentUsage)/\(limit), Cooldown: \(remainingCooldown)s")
    }
    
    func trackFilterPopupDismissed(userType: String, dismissMethod: String, timeSpentInPopup: TimeInterval) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: userType,
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_DISMISSAL_METHOD: dismissMethod,
            FilterAnalytics.PARAM_TIME_SPENT_IN_POPUP: Int(timeSpentInPopup)
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_POPUP_DISMISSED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackFilterPopupDismissed() - Method: \(dismissMethod), TimeSpent: \(timeSpentInPopup)s")
    }
    
    func trackFilterPerformed(currentUsage: Int, limit: Int, filterCriteria: [String: Any]) {
        var parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_CURRENT_USAGE: currentUsage,
            FilterAnalytics.PARAM_USAGE_LIMIT: limit,
            FilterAnalytics.PARAM_FILTER_COUNT: filterCriteria.count
        ]
        
        // Add filter criteria details
        if let gender = filterCriteria["gender"] as? String, !gender.isEmpty {
            parameters["ios_filter_gender"] = gender
        }
        if let country = filterCriteria["country"] as? String, !country.isEmpty {
            parameters["ios_filter_country"] = country
        }
        if let language = filterCriteria["language"] as? String, !language.isEmpty {
            parameters["ios_filter_language"] = language
        }
        if let nearby = filterCriteria["nearby"] as? Bool {
            parameters["ios_filter_nearby"] = nearby
        }
        if let minAge = filterCriteria["min_age"] as? Int {
            parameters["ios_filter_min_age"] = minAge
        }
        if let maxAge = filterCriteria["max_age"] as? Int {
            parameters["ios_filter_max_age"] = maxAge
        }
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_PERFORMED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackFilterPerformed() - Usage: \(currentUsage)/\(limit), Criteria count: \(filterCriteria.count)")
    }
    
    func trackFilterBlocked(reason: String, currentUsage: Int, limit: Int, remainingCooldown: TimeInterval) {
        let event = reason == "limit_reached" ? FilterAnalytics.EVENT_FILTER_BLOCKED_LIMIT_REACHED : FilterAnalytics.EVENT_FILTER_BLOCKED_COOLDOWN
        
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_CURRENT_USAGE: currentUsage,
            FilterAnalytics.PARAM_USAGE_LIMIT: limit,
            FilterAnalytics.PARAM_REMAINING_COOLDOWN: Int(remainingCooldown),
            FilterAnalytics.PARAM_IS_LIMIT_REACHED: currentUsage >= limit
        ]
        
        Analytics.logEvent(event, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackFilterBlocked() - Reason: \(reason), Usage: \(currentUsage)/\(limit)")
    }
    
    func trackSubscriptionButtonTapped(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, priceDisplayed: String?) {
        var parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_CURRENT_USAGE: currentUsage,
            FilterAnalytics.PARAM_USAGE_LIMIT: limit,
            FilterAnalytics.PARAM_REMAINING_COOLDOWN: Int(remainingCooldown),
            FilterAnalytics.PARAM_IS_LIMIT_REACHED: currentUsage >= limit
        ]
        
        if let price = priceDisplayed {
            parameters[FilterAnalytics.PARAM_SUBSCRIPTION_PRICE] = price
            parameters[FilterAnalytics.PARAM_CURRENCY] = "USD"
        }
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_SUBSCRIPTION_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackSubscriptionButtonTapped() - Price: \(priceDisplayed ?? "nil"), Usage: \(currentUsage)/\(limit)")
    }
    
    func trackNewUserBypass(timeRemaining: TimeInterval) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_IS_NEW_USER: true,
            FilterAnalytics.PARAM_NEW_USER_TIME_REMAINING: Int(timeRemaining)
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_NEW_USER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackNewUserBypass() - TimeRemaining: \(timeRemaining)s")
    }
    
    func trackLiteSubscriberBypass() {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus()
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_LITE_SUBSCRIBER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackLiteSubscriberBypass() - UserType: \(getUserType())")
    }
    
    func trackPricingDisplayed(price: String, currency: String) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_SUBSCRIPTION_PRICE: price,
            FilterAnalytics.PARAM_CURRENCY: currency
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_PRICING_DISPLAYED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackPricingDisplayed() - Price: \(price) \(currency)")
    }
    
    func trackLimitReset(previousUsage: Int, limit: Int) {
        let parameters: [String: Any] = [
            FilterAnalytics.PARAM_USER_TYPE: getUserType(),
            FilterAnalytics.PARAM_SUBSCRIPTION_STATUS: subscriptionSessionManager.getSubscriptionStatus(),
            FilterAnalytics.PARAM_CURRENT_USAGE: 0,
            FilterAnalytics.PARAM_USAGE_LIMIT: limit,
            "ios_previous_usage": previousUsage
        ]
        
        Analytics.logEvent(FilterAnalytics.EVENT_FILTER_LIMIT_RESET, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: FilterAnalytics", message: "trackLimitReset() - Reset from \(previousUsage) to 0, Limit: \(limit)")
    }
}
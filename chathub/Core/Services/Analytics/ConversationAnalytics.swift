import Foundation
import FirebaseAnalytics

/**
 * Comprehensive analytics tracking for Conversation Feature
 * Tracks user behavior, conversion funnel, and business metrics
 * iOS equivalent of Android's conversation analytics implementation
 */
class ConversationAnalytics {
    
    // MARK: - Singleton Instance
    static let shared = ConversationAnalytics()
    
    // MARK: - Analytics Event Constants (iOS-specific naming)
    static let EVENT_CONVERSATION_BUTTON_TAPPED = "ios_conversation_button_tapped"
    static let EVENT_CONVERSATION_POPUP_SHOWN = "ios_conversation_popup_shown"
    static let EVENT_CONVERSATION_POPUP_DISMISSED = "ios_conversation_popup_dismissed"
    static let EVENT_CONVERSATION_PERFORMED = "ios_conversation_performed"
    static let EVENT_CONVERSATION_BLOCKED_LIMIT_REACHED = "ios_conversation_blocked_limit_reached"
    static let EVENT_CONVERSATION_BLOCKED_COOLDOWN = "ios_conversation_blocked_cooldown"
    static let EVENT_CONVERSATION_SUBSCRIPTION_BUTTON_TAPPED = "ios_conversation_subscription_button_tapped"
    static let EVENT_CONVERSATION_LIMIT_RESET = "ios_conversation_limit_reset"
    static let EVENT_CONVERSATION_NEW_USER_BYPASS = "ios_conversation_new_user_bypass"
    static let EVENT_CONVERSATION_PLUS_SUBSCRIBER_BYPASS = "ios_conversation_plus_subscriber_bypass"
    static let EVENT_CONVERSATION_COOLDOWN_COMPLETED = "ios_conversation_cooldown_completed"
    static let EVENT_CONVERSATION_PRICING_DISPLAYED = "ios_conversation_pricing_displayed"
    
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
    static let PARAM_CONVERSATION_SOURCE = "ios_conversation_source"
    static let PARAM_SESSION_CONVERSATION_COUNT = "ios_session_conversation_count"
    static let PARAM_TIME_SINCE_LAST_CONVERSATION = "ios_time_since_last_conversation_seconds"
    static let PARAM_CONVERSION_FUNNEL_STEP = "ios_conversion_funnel_step"
    static let PARAM_PRICE_DISPLAYED = "ios_price_displayed"
    static let PARAM_CURRENCY = "ios_currency"
    
    // MARK: - Session Tracking Variables
    private var sessionConversationCount: Int = 0
    private var lastConversationTime: TimeInterval = 0
    
    private init() {}
    
    // MARK: - Helper Functions
    
    private func createBaseParameters() -> [String: Any] {
        let subscriptionManager = SubscriptionSessionManager.shared
        let userSessionManager = UserSessionManager.shared
        
        return [
            Self.PARAM_SUBSCRIPTION_STATUS: subscriptionManager.getSubscriptionStatus(),
            Self.PARAM_IS_NEW_USER: ConversationLimitManagerNew.shared.isNewUser(),
            "ios_app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "ios_platform": "iOS",
            "ios_session_id": UUID().uuidString
        ]
    }
    
    // MARK: - Public Analytics Methods
    
    /**
     * Tracks when user taps the conversation button
     */
    func trackConversationButtonTapped(userType: String, currentUsage: Int, limit: Int, isLimitReached: Bool) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_IS_LIMIT_REACHED] = isLimitReached
        parameters[Self.PARAM_CONVERSATION_SOURCE] = "profile_view_button"
        parameters[Self.PARAM_SESSION_CONVERSATION_COUNT] = sessionConversationCount
        parameters[Self.PARAM_TIME_SINCE_LAST_CONVERSATION] = lastConversationTime > 0 ? Int(Date().timeIntervalSince1970 - lastConversationTime) : 0
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationButtonTapped() - userType: \(userType), usage: \(currentUsage)/\(limit)")
    }
    
    /**
     * Tracks when conversation popup is shown to user
     */
    func trackConversationPopupShown(userType: String, currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, triggerReason: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_POPUP_TRIGGER_REASON] = triggerReason
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_exposure"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_POPUP_SHOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationPopupShown() - reason: \(triggerReason), cooldown: \(remainingCooldown)s")
    }
    
    /**
     * Tracks when conversation popup is dismissed
     */
    func trackConversationPopupDismissed(userType: String, dismissMethod: String, timeSpentInPopup: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters["ios_dismiss_method"] = dismissMethod // "background_tap", "close_button", "conversation_action", "subscription_action"
        parameters["ios_time_spent_seconds"] = Int(timeSpentInPopup)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "popup_dismissed"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_POPUP_DISMISSED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationPopupDismissed() - method: \(dismissMethod), time: \(timeSpentInPopup)s")
    }
    
    /**
     * Tracks successful conversation action
     */
    func trackConversationPerformed(userType: String, currentUsage: Int, limit: Int, isFirstConversationOfSession: Bool) {
        sessionConversationCount += 1
        lastConversationTime = Date().timeIntervalSince1970
        
        var parameters = createBaseParameters()
        parameters[Self.PARAM_USER_TYPE] = userType
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_SESSION_CONVERSATION_COUNT] = sessionConversationCount
        parameters["ios_is_first_conversation_of_session"] = isFirstConversationOfSession
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "conversation_completed"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_PERFORMED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationPerformed() - userType: \(userType), sessionCount: \(sessionConversationCount)")
    }
    
    /**
     * Tracks when conversation is blocked due to limit reached
     */
    func trackConversationBlockedLimitReached(currentUsage: Int, limit: Int, cooldownDuration: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(cooldownDuration)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "blocked_limit_reached"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_BLOCKED_LIMIT_REACHED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationBlockedLimitReached() - usage: \(currentUsage)/\(limit), cooldown: \(cooldownDuration)s")
    }
    
    /**
     * Tracks when conversation is blocked due to active cooldown
     */
    func trackConversationBlockedCooldown(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "blocked_cooldown_active"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_BLOCKED_COOLDOWN, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationBlockedCooldown() - remaining: \(remainingCooldown)s")
    }
    
    /**
     * Tracks when subscription button is tapped
     */
    func trackSubscriptionButtonTapped(currentUsage: Int, limit: Int, remainingCooldown: TimeInterval, priceDisplayed: String?) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = currentUsage
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters[Self.PARAM_REMAINING_COOLDOWN] = Int(remainingCooldown)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "subscription_button_tapped"
        
        if let price = priceDisplayed {
            parameters[Self.PARAM_PRICE_DISPLAYED] = price
        }
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_SUBSCRIPTION_BUTTON_TAPPED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackSubscriptionButtonTapped() - price: \(priceDisplayed ?? "none")")
    }
    
    /**
     * Tracks when conversation limit is reset after cooldown
     */
    func trackConversationLimitReset(previousUsage: Int, limit: Int) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CURRENT_USAGE] = 0 // Reset to 0
        parameters[Self.PARAM_USAGE_LIMIT] = limit
        parameters["ios_previous_usage"] = previousUsage
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "limit_reset"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_LIMIT_RESET, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackConversationLimitReset() - previous: \(previousUsage), limit: \(limit)")
    }
    
    /**
     * Tracks when new user bypasses conversation limits
     */
    func trackNewUserBypass(newUserTimeRemaining: TimeInterval) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_NEW_USER_TIME_REMAINING] = Int(newUserTimeRemaining)
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "new_user_bypass"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_NEW_USER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackNewUserBypass() - time remaining: \(newUserTimeRemaining)s")
    }
    
    /**
     * Tracks when Plus subscriber bypasses conversation limits
     */
    func trackPlusSubscriberBypass() {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "plus_subscriber_bypass"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_PLUS_SUBSCRIBER_BYPASS, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackPlusSubscriberBypass()")
    }
    
    /**
     * Tracks when cooldown period completes
     */
    func trackCooldownCompleted(totalCooldownDuration: TimeInterval, conversationLimit: Int) {
        var parameters = createBaseParameters()
        parameters["ios_cooldown_duration_seconds"] = Int(totalCooldownDuration)
        parameters[Self.PARAM_USAGE_LIMIT] = conversationLimit
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "cooldown_completed"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_COOLDOWN_COMPLETED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackCooldownCompleted() - duration: \(totalCooldownDuration)s")
    }
    
    /**
     * Tracks when pricing is displayed to user
     */
    func trackPricingDisplayed(price: String, currency: String) {
        var parameters = createBaseParameters()
        parameters[Self.PARAM_PRICE_DISPLAYED] = price
        parameters[Self.PARAM_CURRENCY] = currency
        parameters[Self.PARAM_CONVERSION_FUNNEL_STEP] = "pricing_displayed"
        
        Analytics.logEvent(Self.EVENT_CONVERSATION_PRICING_DISPLAYED, parameters: parameters)
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "trackPricingDisplayed() - price: \(price) \(currency)")
    }
    
    // MARK: - Utility Methods
    
    /**
     * Gets current user type for analytics
     */
    func getUserType() -> String {
        let subscriptionManager = SubscriptionSessionManager.shared
        
        if subscriptionManager.isUserSubscribedToPlus() {
            return "plus_subscriber"
        } else if subscriptionManager.isUserSubscribedToLite() {
            return "lite_subscriber"
        } else if ConversationLimitManagerNew.shared.isNewUser() {
            return "new_user"
        } else {
            return "free_user"
        }
    }
    
    /**
     * Resets session tracking variables (called on app restart)
     */
    func resetSessionData() {
        sessionConversationCount = 0
        lastConversationTime = 0
        AppLogger.log(tag: "LOG-APP: ConversationAnalytics", message: "resetSessionData() Session analytics data reset")
    }
}
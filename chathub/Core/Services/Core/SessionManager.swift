//
//  SessionManager.swift
//  ChatHub
//
//  Created by Gemini on 2024-07-26.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import Combine
import FirebaseAuth

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    internal let defaults = UserDefaults.standard

    private init() {}

    deinit {
        // Clean up any resources and ensure proper cleanup
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "SessionManager deinit called - cleaning up resources")
    }

    // MARK: - Keys
    internal enum Keys {
        // User Core Data Keys - Matching Android SessionManager exactly
        static let userId = "userId"
        static let userName = "userName"
        static let userAge = "userAge"
        static let userGender = "userGender"
        static let userCountry = "userCountry"
        static let userLanguage = "userLanguage"
        static let userProfilePhoto = "userProfilePhoto"
        static let deviceId = "deviceId"
        static let deviceToken = "deviceToken"
        static let macAddress = "macAddress"
        static let userIPv4 = "userIPv4"
        static let userIPv6 = "userIPv6"
        static let packageName = "packageName"
        static let lastLoginTime = "lastLoginTime"
        static let privacyPolicyAccepted = "privacyPolicyAccepted"
        static let welcomeTimer = "welcomeTimer"
        static let lastMessageReceivedTime = "lastMessageReceivedTime"
        static let freeMessageTime = "freeMessageTime"
        static let userWarningCount = "userWarningCount"
        static let isUserBanned = "isUserBanned"
        static let isSubscriptionActive = "isSubscriptionActive"
        static let moveToInboxSelected = "moveToInboxSelected"
        static let callSeconds = "callSeconds"
        static let emailAddress = "emailAddress"
        static let isAccountCreated = "isAccountCreated"
        static let accountCreatedTime = "accountCreatedTime"
        static let emailVerified = "emailVerified"
        static let userRetrievedCity = "userRetrievedCity"
        
        // Premium/Subscription Keys
        static let premiumActive = "premium_active"
        static let subscriptionTier = "subscription_tier"
        static let subscriptionExpiry = "subscription_expiry"
        static let isPremiumActive = "is_premium_active"
        
        // Settings Keys - Matching Android exactly
        static let hapticEnabled = "haptic_enabled"
        
        // Filter Keys - Matching Android exactly
        static let filterMinAge = "filter_min_age"
        static let filterMaxAge = "filter_max_age"
        static let filterGender = "filter_gender"
        static let filterCountry = "filter_country"
        static let filterLanguage = "filter_language"
        static let filterNearbyOnly = "filter_nearby_only"
        static let onlineUsersRefreshTime = "online_users_refresh_time"
        
        // Terms and Privacy Keys
        static let termsContent = "termsContent"
        
        // Messaging Keys
        static let lastUserMessagePrefix = "lastUserMessage_"
        
        // Reporting Keys
        static let reportedImages = "reportedImages"
        static let repeatedImageReportsSBTime = "repeatedImageReportsSBTime"
        static let repeatedImageReportsTimeArray = "repeatedImageReportsTimeArray"
        
        // Feature Control Keys - From existing SessionManager
        static let extraFeaturesEnabled = "EXTRA_FEATURES_ENABLED"
        static let liveEnabled = "LIVEENABLED"
        static let liveAppVersion = "LIVEAPPVERSION"
        static let updateMandatory = "UPDATEMANDATORY"
        static let maintenance = "MAINTENANCE"
        static let updateDetails = "UPDATE_DETAILS"
        static let adIntervalSeconds = "AD_INTERVAL_SECONDS"
        static let adIntervalSecondsWoman = "AD_INTERVAL_SECONDS_WOMAN"
        static let enableInFeedAds = "ENABLE_IN_FEED_ADS"
        static let inFeedAdsCount = "MREC_COUNT_IN_FEED"
        static let inFeedAdsCountWoman = "inFeedAdsCountWoman"
        static let appActivityCount = "APP_ACTIVITY_COUNT"
        static let maxChatsForRateUsRequest = "MAX_CHATS_FOR_RATEUS_REQUEST"
        static let maxRateUsRequests = "MAX_RATEUS_REQUESTS"
        static let aiChatEnabled = "AI_CHAT_ENABLED"
        static let aiChatEnabledWoman = "AI_CHAT_ENABLED_WOMAN"
        static let maxIdleSecondsForAiChatEnabling = "MAX_IDLE_TIME_FOR_AI_ENABLING"
        static let minOfflineSecondsForAiChatEnabling = "LEAST_OFFLINE_SECONDS_FOR_AI_ENABLING"
        static let aiChatBotURL = "AI_CHAT_BOT_URL"
        static let newUserFreePeriodSeconds = "new_user_free_period_ms"
        static let featureMonetizationPopUpCoolDownSeconds = "FEATURE_MONETIZATION_POP_UP_COOL_DOWN_SECONDS"
        static let freeMessagesLimit = "free_user_message_limit"
        static let freeMessagesCooldownSeconds = "free_user_message_cooldown_minutes"
        static let freeConversationsLimit = "free_user_conversation_limit"
        static let freeConversationsCooldownSeconds = "free_user_conversation_cooldown_minutes"
        static let conversationsStartedCount = "conversations_started_count"
        static let conversationLimitCooldownStartTime = "conversation_limit_cooldown_start_time"
        static let freeRefreshLimit = "free_user_refresh_limit"
        static let freeRefreshCooldownSeconds = "free_user_refresh_cooldown_seconds"
        static let refreshUsageCount = "refresh_usage_count"
        static let refreshLimitCooldownStartTime = "refresh_limit_cooldown_start_time"
        static let freeFilterLimit = "free_user_filter_limit"
        static let freeFilterCooldownSeconds = "free_user_filter_cooldown_seconds"
        static let filterUsageCount = "filter_usage_count"
        static let filterLimitCooldownStartTime = "filter_limit_cooldown_start_time"
        static let freeSearchLimit = "free_user_search_limit"
        static let freeSearchCooldownSeconds = "free_user_search_cooldown_seconds"
        static let searchUsageCount = "search_usage_count"
        static let searchLimitCooldownStartTime = "search_limit_cooldown_start_time"
        static let keyUserGender = "user_gender"
        static let profanityWordsVersion = "PROFANITYWORDSVERSION"
        static let profanityWords = "PROFANITYWORDS"
        static let profanityAppNameWordsVersion = "PROFANITY_APP_NAME_WORDS_VERSION"
        static let profanityAppNameWords = "PROFANITY_APP_NAME_WORDS"
        static let aiChatIds = "AI_CHAT_IDS"
        static let messagesUntilAd = "MESSAGES_UNTIL_AD"
        static let activityResumedCount = "ACTIVITY_RESUMED_COUNT"
        static let lastFeatureMonetizationPopupTime = "LAST_FEATURE_MONETIZATION_POP_UP_COOL_DOWN_SECONDS"
        static let featureMonetizationPopupCooldown = "feature_monetization_popup_cooldown_seconds"
        static let firstAccountCreatedTime = "device_first_account_time"
        
        // Missing Keys for Complete Migration
        static let userOnline = "UserOnline"
        static let userImage = "userImage"
        static let reportedUsers = "reportedUsers"
        static let blockedUsers = "blockedUsers"
        static let repeatedUserReportsTimeArray = "repeatedUserReportsTimeArray"
        static let repeatedUserReportsSBTime = "repeatedUserReportsSBTime"
        static let ratingTries = "ratingTries"
        static let interestTags = "interestTags"
        static let interestSentence = "interestSentence"
        static let interestTime = "interestTime"


        static let chatLastTime = "chatLastTime"
        static let notificationLastTime = "notificationLastTime"
        static let emailverified = "emailverified"
        static let liteSubscriptionActive = "lite_subscription_active"
        static let plusSubscriptionActive = "plus_subscription_active"
        static let proSubscriptionActive = "pro_subscription_active"
        static let totalNoOfMessageReceived = "totalNoOfMessageReceived"
        static let totalNoOfMessageSent = "totalNoOfMessageSent"
        static let userReportBlockedUntil = "USER_REPORT_BLOCKED_UNTIL"
        static let canReportSB = "CAN_REPORT_SB"
        static let userReportTimesList = "USER_REPORT_TIMES_LIST"
        static let userReportTimes = "USER_REPORT_TIMES"
        
        // Report Warning Keys
        static let showRepeatedReportsWarning = "SHOW_REPEATED_REPORTS_WARNING"
        static let canReportShowWarningCooldownUntilTimestamp = "CAN_REPORT_SHOW_WARNING_COOLDOWN_UNTIL_TIMESTAMP"
        static let userTotalReports = "USER_TOTAL_REPORTS"
        static let userLastReportTimestamp = "USER_LAST_REPORT_TIMESTAMP"
        static let showMultipleReportsWarning = "SHOW_MULTIPLE_REPORTS_WARNING"
        static let multipleReportsShowWarningCooldownUntilTimestamp = "MULTIPLE_REPORTS_SHOW_WARNING_COOLDOWN_UNTIL_TIMESTAMP"
        
        // IP Details Keys
        static let userRetrievedIp = "userRetrievedIp"
        static let userRetrievedState = "userRetrievedState"
        static let userRetrievedCountry = "userRetrievedCountry"
        
        // Filter Keys
        static let onlineUserFilter = "OnlineUserFilter"
        
        // Additional Warning Keys (matching AppSettingsKeys)
        static let showTimeMismatchWarning = "showTimeMismatchWarning"
        static let showAdPolicyWarning = "showAdPolicyWarning"
        static let showTextModerationWarning = "showTextModerationWarning"
        static let showImageModerationWarning = "showImageModerationWarning"
        // REMOVED: integrity warning and validation keys - device integrity checks removed for iOS
        
        // Missing Android Parity Keys

        
        // Live Call Timer Keys (Android Parity)
        static let liveSeconds = "liveSeconds"
        
        // Notification Keys (Android Parity)
        static let notificationsEnabled = "NOTIFICATIONSENABLED"
        
        // Ban Status Keys (Android Parity)
        static let deviceIdBanned = "deviceIdBanned"
        static let macIdBanned = "macIdBanned"
        static let ipIdBanned = "ipIdBanned"
        
        // MARK: - CoreData Migration Keys
        // These keys are added for CoreData to UserDefaults migration
        
        // Ban/Block Management Keys (Block entity migration)
        static let banReason = "banReason"
        static let banTime = "banTime"
        
        // Theme Settings Keys (DarkMode entity migration)
        static let themeMode = "themeMode"
        
        // Filter Settings Keys (Filter entity migration)
        static let filterCity = "filterCity"
        static let filterThenValue = "filterThenValue"
        
        // Ad Management Keys (Ad entities migration)
        static let userAdsCount = "userAdsCount"
        static let bannerFailedCount = "bannerFailedCount"
        static let bannerLoadedStatus = "bannerLoadedStatus"
        
        // Reporting System Keys (Report entities migration)
        static let reportedVideoUsers = "reportedVideoUsers"
        static let reportedLobbyUsers = "reportedLobbyUsers"
        
        // Random Chat Keys - REMOVED (functionality not needed)
        
        // Miscellaneous Keys (Various entities migration)
        static let deleteDataEnabled = "deleteDataEnabled"
        static let noAdsDate = "noAdsDate"
        static let pollIds = "pollIds"
        static let myProfileTime = "myProfileTime"
        
        // Cache and Counter Keys (Cache entities migration)
        static let badWordsCount = "badWordsCount"
        static let forreviewIncoming = "forreviewIncoming"
        static let forreviewOutgoing = "forreviewOutgoing"

        
        // Call State Keys (Incomingcall entity migration)
        static let incomingCallerId = "incomingCallerId"
        static let incomingCallerName = "incomingCallerName"
        static let incomingChannelName = "incomingChannelName"
        static let inCall = "inCall"
        
        // Random Chat Report/Timing Keys - REMOVED (functionality not needed)
        
        // Audio Report Keys (AudioReport entity migration)
        static let audioReportTime = "audioReportTime"
        
        // Newly added keys
        static let profanityFirebaseInitialized = "PROFANITY_FIREBASE_INITIALIZED"
        static let hiveTextModerationScore = "HIVE_TEXT_MODERATION_SCORE"
        static let textModerationIssueSB = "TEXT_MODERATION_ISSUE_SB"
        static let textModerationIssueCoolDownTime = "TEXT_MODERATION_ISSUE_COOL_DOWN_TIME"
    }

    // MARK: - User Session Data Properties
    
    var userId: String? {
        get { defaults.string(forKey: Keys.userId) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userId)
            } else {
                defaults.removeObject(forKey: Keys.userId)
            }
        }
    }
    
    var userName: String? {
        get { defaults.string(forKey: Keys.userName) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userName)
            } else {
                defaults.removeObject(forKey: Keys.userName)
            }
        }
    }
    
    var userAge: String? {
        get { defaults.string(forKey: Keys.userAge) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userAge)
            } else {
                defaults.removeObject(forKey: Keys.userAge)
            }
        }
    }
    
    var userGender: String? {
        get { defaults.string(forKey: Keys.userGender) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userGender)
            } else {
                defaults.removeObject(forKey: Keys.userGender)
            }
        }
    }
    
    var userCountry: String? {
        get { defaults.string(forKey: Keys.userCountry) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userCountry)
            } else {
                defaults.removeObject(forKey: Keys.userCountry)
            }
        }
    }
    
    var userLanguage: String? {
        get { defaults.string(forKey: Keys.userLanguage) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userLanguage)
            } else {
                defaults.removeObject(forKey: Keys.userLanguage)
            }
        }
    }
    
    var userProfilePhoto: String? {
        get { defaults.string(forKey: Keys.userProfilePhoto) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userProfilePhoto)
            } else {
                defaults.removeObject(forKey: Keys.userProfilePhoto)
            }
        }
    }
    
    var userRetrievedCity: String? {
        get { defaults.string(forKey: Keys.userRetrievedCity) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userRetrievedCity)
            } else {
                defaults.removeObject(forKey: Keys.userRetrievedCity)
            }
        }
    }
    
    var deviceId: String? {
        get { defaults.string(forKey: Keys.deviceId) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.deviceId)
            } else {
                defaults.removeObject(forKey: Keys.deviceId)
            }
        }
    }
    
    var deviceToken: String? {
        get { defaults.string(forKey: Keys.deviceToken) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.deviceToken)
            } else {
                defaults.removeObject(forKey: Keys.deviceToken)
            }
        }
    }
    
    var macAddress: String? {
        get { defaults.string(forKey: Keys.macAddress) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.macAddress)
            } else {
                defaults.removeObject(forKey: Keys.macAddress)
            }
        }
    }
    
    var userIPv4: String? {
        get { defaults.string(forKey: Keys.userIPv4) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userIPv4)
            } else {
                defaults.removeObject(forKey: Keys.userIPv4)
            }
        }
    }
    
    var userIPv6: String? {
        get { defaults.string(forKey: Keys.userIPv6) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userIPv6)
            } else {
                defaults.removeObject(forKey: Keys.userIPv6)
            }
        }
    }
    
    var packageName: String? {
        get { defaults.string(forKey: Keys.packageName) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.packageName)
            } else {
                defaults.removeObject(forKey: Keys.packageName)
            }
        }
    }
    
    var lastLoginTime: TimeInterval {
        get { defaults.double(forKey: Keys.lastLoginTime) }
        set { defaults.set(newValue, forKey: Keys.lastLoginTime) }
    }
    
    var privacyPolicyAccepted: Bool {
        get { defaults.bool(forKey: Keys.privacyPolicyAccepted) }
        set { defaults.set(newValue, forKey: Keys.privacyPolicyAccepted) }
    }
    
    var welcomeTimer: TimeInterval {
        get { defaults.double(forKey: Keys.welcomeTimer) }
        set { defaults.set(newValue, forKey: Keys.welcomeTimer) }
    }
    
    var lastMessageReceivedTime: TimeInterval {
        get { defaults.double(forKey: Keys.lastMessageReceivedTime) }
        set { defaults.set(newValue, forKey: Keys.lastMessageReceivedTime) }
    }
    
    var freeMessageTime: Int64 {
        get { Int64(defaults.double(forKey: Keys.freeMessageTime)) }
        set { defaults.set(Double(newValue), forKey: Keys.freeMessageTime) }
    }
    
    var userWarningCount: Int {
        get { defaults.integer(forKey: Keys.userWarningCount) }
        set { defaults.set(newValue, forKey: Keys.userWarningCount) }
    }
    
    var isUserBanned: Bool {
        get { defaults.bool(forKey: Keys.isUserBanned) }
        set { defaults.set(newValue, forKey: Keys.isUserBanned) }
    }
    
    var isSubscriptionActive: Bool {
        get { defaults.bool(forKey: Keys.isSubscriptionActive) }
        set { defaults.set(newValue, forKey: Keys.isSubscriptionActive) }
    }
    
    var moveToInboxSelected: Bool {
        get { defaults.bool(forKey: Keys.moveToInboxSelected) }
        set { defaults.set(newValue, forKey: Keys.moveToInboxSelected) }
    }
    
    var callSeconds: Int {
        get { defaults.integer(forKey: Keys.callSeconds) }
        set { defaults.set(newValue, forKey: Keys.callSeconds) }
    }
    
    var emailAddress: String? {
        get { defaults.string(forKey: Keys.emailAddress) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.emailAddress)
            } else {
                defaults.removeObject(forKey: Keys.emailAddress)
            }
        }
    }
    
    var isAccountCreated: Bool {
        get { defaults.bool(forKey: Keys.isAccountCreated) }
        set { defaults.set(newValue, forKey: Keys.isAccountCreated) }
    }
    
    var accountCreatedTime: TimeInterval {
        get { defaults.double(forKey: Keys.accountCreatedTime) }
        set { defaults.set(newValue, forKey: Keys.accountCreatedTime) }
    }
    
    var emailVerified: Bool {
        get { defaults.bool(forKey: Keys.emailVerified) }
        set { defaults.set(newValue, forKey: Keys.emailVerified) }
    }
    
    // MARK: - Premium/Subscription Properties
    
    var premiumActive: Bool {
        get { defaults.bool(forKey: Keys.premiumActive) }
        set { defaults.set(newValue, forKey: Keys.premiumActive) }
    }
    
    var subscriptionTier: String {
        get { defaults.string(forKey: Keys.subscriptionTier) ?? "none" }
        set { defaults.set(newValue, forKey: Keys.subscriptionTier) }
    }
    
    var subscriptionExpiry: Int64 {
        get { defaults.object(forKey: Keys.subscriptionExpiry) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.subscriptionExpiry) }
    }
    
    var isPremiumActive: Bool {
        get { defaults.bool(forKey: Keys.isPremiumActive) }
        set { defaults.set(newValue, forKey: Keys.isPremiumActive) }
    }
    
    // MARK: - Settings Properties
    
    var hapticEnabled: Bool {
        get { 
            // Default to true if not set (Android parity)
            if defaults.object(forKey: Keys.hapticEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.hapticEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.hapticEnabled) }
    }
    
    // MARK: - Filter Properties
    
    var filterMinAge: String? {
        get { defaults.string(forKey: Keys.filterMinAge) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.filterMinAge)
            } else {
                defaults.removeObject(forKey: Keys.filterMinAge)
            }
        }
    }
    
    var filterMaxAge: String? {
        get { defaults.string(forKey: Keys.filterMaxAge) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.filterMaxAge)
            } else {
                defaults.removeObject(forKey: Keys.filterMaxAge)
            }
        }
    }
    
    var filterGender: String? {
        get { defaults.string(forKey: Keys.filterGender) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.filterGender)
            } else {
                defaults.removeObject(forKey: Keys.filterGender)
            }
        }
    }
    
    var filterCountry: String? {
        get { defaults.string(forKey: Keys.filterCountry) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.filterCountry)
            } else {
                defaults.removeObject(forKey: Keys.filterCountry)
            }
        }
    }
    
    var filterLanguage: String? {
        get { defaults.string(forKey: Keys.filterLanguage) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.filterLanguage)
            } else {
                defaults.removeObject(forKey: Keys.filterLanguage)
            }
        }
    }
    
    var filterNearbyOnly: Bool {
        get { defaults.bool(forKey: Keys.filterNearbyOnly) }
        set { defaults.set(newValue, forKey: Keys.filterNearbyOnly) }
    }
    
    var onlineUsersRefreshTime: Int64 {
        get { defaults.object(forKey: Keys.onlineUsersRefreshTime) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.onlineUsersRefreshTime) }
    }
    
    // MARK: - Online Users Refresh Helper Methods (Android Parity)
    
    /// Checks if online users need to be refreshed from Firebase - Android parity
    /// Returns true if more than 30 minutes (1800 seconds) have passed since last refresh
    func shouldRefreshOnlineUsersFromFirebase() -> Bool {
        let currentTimeSeconds = Int64(Date().timeIntervalSince1970)
        let lastRefreshTime = onlineUsersRefreshTime
        let timeDifference = currentTimeSeconds - lastRefreshTime
        
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "shouldRefreshOnlineUsersFromFirebase() currentTime: \(currentTimeSeconds), lastRefresh: \(lastRefreshTime), diff: \(timeDifference)")
        
        // Refresh if more than 30 minutes (1800 seconds) have passed - matching Android logic exactly
        return timeDifference > 1800
    }
    
    /// Sets the online users refresh time to current timestamp - Android parity
    func setOnlineUsersRefreshTime() {
        let currentTimeSeconds = Int64(Date().timeIntervalSince1970)
        onlineUsersRefreshTime = currentTimeSeconds
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setOnlineUsersRefreshTime() set to: \(currentTimeSeconds)")
    }
    
    /// Gets the online users refresh time - Android parity
    func getOnlineUsersRefreshTime() -> Int64 {
        return onlineUsersRefreshTime
    }
    
    // MARK: - Terms and Privacy Properties
    
    var termsContent: String? {
        get { defaults.string(forKey: Keys.termsContent) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.termsContent)
            } else {
                defaults.removeObject(forKey: Keys.termsContent)
            }
        }
    }
    
    // MARK: - Reporting Properties
    
    var reportedImages: String? {
        get { defaults.string(forKey: Keys.reportedImages) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.reportedImages)
            } else {
                defaults.removeObject(forKey: Keys.reportedImages)
            }
        }
    }
    
    var repeatedImageReportsSBTime: TimeInterval {
        get { defaults.double(forKey: Keys.repeatedImageReportsSBTime) }
        set { defaults.set(newValue, forKey: Keys.repeatedImageReportsSBTime) }
    }
    
    var repeatedImageReportsTimeArray: [TimeInterval] {
        get { defaults.array(forKey: Keys.repeatedImageReportsTimeArray) as? [TimeInterval] ?? [] }
        set { defaults.set(newValue, forKey: Keys.repeatedImageReportsTimeArray) }
    }

    // MARK: - Feature Control Properties - Already exist, keep them as is
    
    var extraFeaturesEnabled: Bool {
        get { defaults.bool(forKey: Keys.extraFeaturesEnabled, default: true) }
        set { defaults.set(newValue, forKey: Keys.extraFeaturesEnabled) }
    }



    // MARK: - Live Communication Settings

    var liveEnabled: Bool {
        get { defaults.bool(forKey: Keys.liveEnabled, default: true) }
        set { defaults.set(newValue, forKey: Keys.liveEnabled) }
    }
    
    // MARK: - Live Call Timer Settings (Android Parity)
    
    var liveSeconds: Int64 {
        get { defaults.object(forKey: Keys.liveSeconds) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.liveSeconds) }
    }
    
    // MARK: - App Version and Update Settings
    
    var liveAppVersion: Int64 {
        get { defaults.object(forKey: Keys.liveAppVersion) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.liveAppVersion) }
    }
    
    var updateMandatory: Bool {
        get { defaults.bool(forKey: Keys.updateMandatory) }
        set { defaults.set(newValue, forKey: Keys.updateMandatory) }
    }
    
    var maintenance: Bool {
        get { defaults.bool(forKey: Keys.maintenance) }
        set { defaults.set(newValue, forKey: Keys.maintenance) }
    }
    
    var updateDetails: String? {
        get { defaults.string(forKey: Keys.updateDetails) }
        set { defaults.set(newValue, forKey: Keys.updateDetails) }
    }
    
    // MARK: - Advertisement Settings
    
    var adIntervalSeconds: Int64 {
        get { defaults.object(forKey: Keys.adIntervalSeconds) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.adIntervalSeconds) }
    }
    
    var adIntervalSecondsWoman: Int64 {
        get { defaults.object(forKey: Keys.adIntervalSecondsWoman) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.adIntervalSecondsWoman) }
    }
    
    var enableInFeedAds: Bool {
        get { defaults.bool(forKey: Keys.enableInFeedAds) }
        set { defaults.set(newValue, forKey: Keys.enableInFeedAds) }
    }
    
    var inFeedAdsCount: Int64 {
        get { defaults.object(forKey: Keys.inFeedAdsCount) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.inFeedAdsCount) }
    }
    
    var inFeedAdsCountWoman: Int64 {
        get { defaults.object(forKey: Keys.inFeedAdsCountWoman) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.inFeedAdsCountWoman) }
    }
    
    // MARK: - App Analytics and Rating Settings
    
    var appActivityCount: Int64 {
        get { defaults.object(forKey: Keys.appActivityCount) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.appActivityCount) }
    }
    
    var maxChatsForRateUsRequest: Int64 {
        get { defaults.object(forKey: Keys.maxChatsForRateUsRequest) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.maxChatsForRateUsRequest) }
    }
    
    var maxRateUsRequests: Int64 {
        get { defaults.object(forKey: Keys.maxRateUsRequests) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.maxRateUsRequests) }
    }
    
    // MARK: - AI Chat Configuration Settings
    
    var aiChatEnabled: Bool {
        get { defaults.bool(forKey: Keys.aiChatEnabled) }
        set { defaults.set(newValue, forKey: Keys.aiChatEnabled) }
    }
    
    var aiChatEnabledWoman: Bool {
        get { defaults.bool(forKey: Keys.aiChatEnabledWoman) }
        set { defaults.set(newValue, forKey: Keys.aiChatEnabledWoman) }
    }
    
    var maxIdleSecondsForAiChatEnabling: Int64 {
        get { defaults.object(forKey: Keys.maxIdleSecondsForAiChatEnabling) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.maxIdleSecondsForAiChatEnabling) }
    }
    
    var minOfflineSecondsForAiChatEnabling: Int64 {
        get { defaults.object(forKey: Keys.minOfflineSecondsForAiChatEnabling) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.minOfflineSecondsForAiChatEnabling) }
    }
    
    var aiChatBotURL: String? {
        get { defaults.string(forKey: Keys.aiChatBotURL) }
        set { defaults.set(newValue, forKey: Keys.aiChatBotURL) }
    }
    
    // MARK: - Monetization and Limits Settings
    
    var newUserFreePeriodSeconds: Int64 {
        get { defaults.object(forKey: Keys.newUserFreePeriodSeconds) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.newUserFreePeriodSeconds) }
    }
    
    var featureMonetizationPopUpCoolDownSeconds: Int64 {
        get { defaults.object(forKey: Keys.featureMonetizationPopUpCoolDownSeconds) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.featureMonetizationPopUpCoolDownSeconds) }
    }
    
    // MARK: - Free User Message Limit Settings
    
    var freeMessagesLimit: Int {
        get { defaults.integer(forKey: Keys.freeMessagesLimit) }
        set { defaults.set(newValue, forKey: Keys.freeMessagesLimit) }
    }
    
    var freeMessagesCooldownSeconds: Int {
        get { defaults.integer(forKey: Keys.freeMessagesCooldownSeconds) }
        set { defaults.set(newValue, forKey: Keys.freeMessagesCooldownSeconds) }
    }
    
    // MARK: - Free User Conversation Limit Settings
    
    var freeConversationsLimit: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeConversationsLimit)
            // Provide reasonable default if not set from remote config (Android parity)
            return value > 0 ? value : 2
        }
        set { defaults.set(newValue, forKey: Keys.freeConversationsLimit) }
    }
    
    var freeConversationsCooldownSeconds: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeConversationsCooldownSeconds)
            // Provide reasonable default if not set from remote config (Android parity)
            return value > 0 ? value : 30
        }
        set { defaults.set(newValue, forKey: Keys.freeConversationsCooldownSeconds) }
    }
    
    var conversationsStartedCount: Int {
        get { defaults.integer(forKey: Keys.conversationsStartedCount) }
        set { defaults.set(newValue, forKey: Keys.conversationsStartedCount) }
    }
    
    var conversationLimitCooldownStartTime: Int64 {
        get { defaults.object(forKey: Keys.conversationLimitCooldownStartTime) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.conversationLimitCooldownStartTime) }
    }
    
    // MARK: - Refresh Limit Settings
    
    var freeRefreshLimit: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeRefreshLimit)
            return value > 0 ? value : 2 // Default to 2 refreshes
        }
        set { defaults.set(newValue, forKey: Keys.freeRefreshLimit) }
    }
    
    var freeRefreshCooldownSeconds: TimeInterval {
        get { 
            let value = defaults.double(forKey: Keys.freeRefreshCooldownSeconds)
            return value > 0 ? value : 120 // Default to 2 minutes
        }
        set { defaults.set(newValue, forKey: Keys.freeRefreshCooldownSeconds) }
    }
    
    var refreshUsageCount: Int {
        get { defaults.integer(forKey: Keys.refreshUsageCount) }
        set { defaults.set(newValue, forKey: Keys.refreshUsageCount) }
    }
    
    var refreshLimitCooldownStartTime: Int64 {
        get { defaults.object(forKey: Keys.refreshLimitCooldownStartTime) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.refreshLimitCooldownStartTime) }
    }
    
    // MARK: - Filter Limit Settings
    
    var freeFilterLimit: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeFilterLimit)
            return value > 0 ? value : 2 // Default to 2 filter applications (matches refresh)
        }
        set { defaults.set(newValue, forKey: Keys.freeFilterLimit) }
    }
    
    var freeFilterCooldownSeconds: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeFilterCooldownSeconds)
            return value > 0 ? value : 120 // Default to 2 minutes (matches refresh)
        }
        set { defaults.set(newValue, forKey: Keys.freeFilterCooldownSeconds) }
    }
    
    var filterUsageCount: Int {
        get { defaults.integer(forKey: Keys.filterUsageCount) }
        set { defaults.set(newValue, forKey: Keys.filterUsageCount) }
    }
    
    var filterLimitCooldownStartTime: Int64 {
        get { defaults.object(forKey: Keys.filterLimitCooldownStartTime) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.filterLimitCooldownStartTime) }
    }
    
    // MARK: - Search Limit Settings
    
    var freeSearchLimit: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeSearchLimit)
            return value > 0 ? value : 2 // Default to 2 searches (matches refresh/filter)
        }
        set { defaults.set(newValue, forKey: Keys.freeSearchLimit) }
    }
    
    // MARK: - Debug Methods
    
    /// Debug method to check all feature states
    func debugAllFeatureStates() -> String {
        let refreshUsage = refreshUsageCount
        let refreshCooldownStart = refreshLimitCooldownStartTime
        let refreshLimit = freeRefreshLimit
        
        let filterUsage = filterUsageCount
        let filterCooldownStart = filterLimitCooldownStartTime
        let filterLimit = freeFilterLimit
        
        let searchUsage = searchUsageCount
        let searchCooldownStart = searchLimitCooldownStartTime
        let searchLimit = freeSearchLimit
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        
        return """
        === FEATURE STATES DEBUG ===
        REFRESH: usage=\(refreshUsage)/\(refreshLimit), cooldownStart=\(refreshCooldownStart), currentTime=\(currentTime)
        FILTER:  usage=\(filterUsage)/\(filterLimit), cooldownStart=\(filterCooldownStart), currentTime=\(currentTime)
        SEARCH:  usage=\(searchUsage)/\(searchLimit), cooldownStart=\(searchCooldownStart), currentTime=\(currentTime)
        """
    }
    
    var freeSearchCooldownSeconds: Int {
        get { 
            let value = defaults.integer(forKey: Keys.freeSearchCooldownSeconds)
            return value > 0 ? value : 120 // Default to 2 minutes (matches refresh/filter)
        }
        set { defaults.set(newValue, forKey: Keys.freeSearchCooldownSeconds) }
    }
    
    var searchUsageCount: Int {
        get { defaults.integer(forKey: Keys.searchUsageCount) }
        set { defaults.set(newValue, forKey: Keys.searchUsageCount) }
    }
    
    var searchLimitCooldownStartTime: Int64 {
        get { defaults.object(forKey: Keys.searchLimitCooldownStartTime) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.searchLimitCooldownStartTime) }
    }
    
    // MARK: - User Properties
    
    var keyUserGender: String? {
        get { defaults.string(forKey: Keys.keyUserGender) }
        set { defaults.set(newValue, forKey: Keys.keyUserGender) }
    }

    // MARK: - Profanity Settings
    
    var profanityWordsVersion: Int64 {
        get { defaults.object(forKey: Keys.profanityWordsVersion) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.profanityWordsVersion) }
    }
    
    var profanityWords: String? {
        get { defaults.string(forKey: Keys.profanityWords) }
        set { defaults.set(newValue, forKey: Keys.profanityWords) }
    }
    
    var profanityAppNameWordsVersion: Int64 {
        get { defaults.object(forKey: Keys.profanityAppNameWordsVersion) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.profanityAppNameWordsVersion) }
    }
    
    var profanityAppNameWords: String? {
        get { defaults.string(forKey: Keys.profanityAppNameWords) }
        set { defaults.set(newValue, forKey: Keys.profanityAppNameWords) }
    }
    
    var profanityFirebaseInitialized: Bool {
        get { defaults.bool(forKey: Keys.profanityFirebaseInitialized) }
        set { defaults.set(newValue, forKey: Keys.profanityFirebaseInitialized) }
    }
    
    // MARK: - Text Moderation (Android Parity)
    
    var hiveTextModerationScore: Int {
        get { defaults.integer(forKey: Keys.hiveTextModerationScore) }
        set { defaults.set(newValue, forKey: Keys.hiveTextModerationScore) }
    }
    
    var textModerationIssueSB: Bool {
        get { defaults.bool(forKey: Keys.textModerationIssueSB) }
        set { defaults.set(newValue, forKey: Keys.textModerationIssueSB) }
    }
    
    var textModerationIssueCoolDownTime: Int64 {
        get { Int64(defaults.double(forKey: Keys.textModerationIssueCoolDownTime)) }
        set { defaults.set(Double(newValue), forKey: Keys.textModerationIssueCoolDownTime) }
    }
    
    // MARK: - Missing Properties for iOS Parity
    
    var aiChatIds: [String] {
        get { 
            if let data = defaults.data(forKey: Keys.aiChatIds),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                return ids
            }
            return []
        }
        set { 
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.aiChatIds)
            }
        }
    }
    
    var messagesUntilAd: Int {
        get { defaults.integer(forKey: Keys.messagesUntilAd) }
        set { defaults.set(newValue, forKey: Keys.messagesUntilAd) }
    }
    
    var activityResumedCount: Int64 {
        get { defaults.object(forKey: Keys.activityResumedCount) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.activityResumedCount) }
    }
    
    var lastFeatureMonetizationPopupTime: TimeInterval {
        get { defaults.double(forKey: Keys.lastFeatureMonetizationPopupTime) }
        set { defaults.set(newValue, forKey: Keys.lastFeatureMonetizationPopupTime) }
    }
    
    var featureMonetizationPopupCooldown: TimeInterval {
        get { defaults.double(forKey: Keys.featureMonetizationPopupCooldown) }
        set { defaults.set(newValue, forKey: Keys.featureMonetizationPopupCooldown) }
    }
    
    var firstAccountCreatedTime: TimeInterval {
        get { defaults.double(forKey: Keys.firstAccountCreatedTime) }
        set { defaults.set(newValue, forKey: Keys.firstAccountCreatedTime) }
    }
    
    // MARK: - Android Parity Methods for Feature Monetization
    
    /// Android parity method: setLastFeatureMoneitzationPopUpTimeInSeconds
    /// Used in onRewarded callbacks to update the last popup time
    func setLastFeatureMoneitzationPopUpTimeInSeconds(_ timeInSeconds: TimeInterval) {
        lastFeatureMonetizationPopupTime = timeInSeconds
        synchronize()
    }
    
    /// Android parity method: getLastFeatureMoneitzationPopUpTimeInSeconds
    /// Used in shouldShowFeatureMoneitzationPopUp checks
    func getLastFeatureMoneitzationPopUpTimeInSeconds() -> TimeInterval {
        return lastFeatureMonetizationPopupTime
    }
    
    /// Android parity method: getFeatureMonetizationPopUpCoolDownSeconds
    /// Used in shouldShowFeatureMoneitzationPopUp checks
    func getFeatureMonetizationPopUpCoolDownSeconds() -> TimeInterval {
        return featureMonetizationPopupCooldown
    }
    
    /// Android parity method: setFeatureMonetizationPopUpCoolDownSeconds
    /// Used to set the cooldown period from Firebase Remote Config
    func setFeatureMonetizationPopUpCoolDownSeconds(_ cooldownSeconds: TimeInterval) {
        featureMonetizationPopupCooldown = cooldownSeconds
        synchronize()
    }
    
    // MARK: - Additional Missing Properties for Complete Migration
    
    var userOnline: Bool {
        get { defaults.bool(forKey: Keys.userOnline) }
        set { defaults.set(newValue, forKey: Keys.userOnline) }
    }
    
    var userImage: String? {
        get { defaults.string(forKey: Keys.userImage) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userImage)
            } else {
                defaults.removeObject(forKey: Keys.userImage)
            }
        }
    }
    
    var reportedUsers: String? {
        get { defaults.string(forKey: Keys.reportedUsers) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.reportedUsers)
            } else {
                defaults.removeObject(forKey: Keys.reportedUsers)
            }
        }
    }
    

    

    
    var blockedUsers: String? {
        get { defaults.string(forKey: Keys.blockedUsers) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.blockedUsers)
            } else {
                defaults.removeObject(forKey: Keys.blockedUsers)
            }
        }
    }
    
    var repeatedUserReportsTimeArray: [TimeInterval] {
        get { defaults.array(forKey: Keys.repeatedUserReportsTimeArray) as? [TimeInterval] ?? [] }
        set { defaults.set(newValue, forKey: Keys.repeatedUserReportsTimeArray) }
    }
    
    var repeatedUserReportsSBTime: TimeInterval {
        get { defaults.double(forKey: Keys.repeatedUserReportsSBTime) }
        set { defaults.set(newValue, forKey: Keys.repeatedUserReportsSBTime) }
    }
    
    var ratingTries: Int {
        get { defaults.integer(forKey: Keys.ratingTries) }
        set { defaults.set(newValue, forKey: Keys.ratingTries) }
    }
    
    var interestTags: [String] {
        get { defaults.stringArray(forKey: Keys.interestTags) ?? [] }
        set { defaults.set(newValue, forKey: Keys.interestTags) }
    }
    
    var interestSentence: String? {
        get { defaults.string(forKey: Keys.interestSentence) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.interestSentence)
            } else {
                defaults.removeObject(forKey: Keys.interestSentence)
            }
        }
    }
    
    var interestTime: Int {
        get { defaults.integer(forKey: Keys.interestTime) }
        set { defaults.set(newValue, forKey: Keys.interestTime) }
    }
    
    // MARK: - Firebase Sync Timestamps
    

    
    var chatLastTime: Double {
        get { defaults.double(forKey: Keys.chatLastTime) }
        set { defaults.set(newValue, forKey: Keys.chatLastTime) }
    }
    
    var notificationLastTime: Any? {
        get { defaults.object(forKey: Keys.notificationLastTime) }
        set { defaults.set(newValue, forKey: Keys.notificationLastTime) }
    }
    
    // MARK: - Additional User Properties
    
    var emailverified: Double {
        get { defaults.double(forKey: Keys.emailverified) }
        set { defaults.set(newValue, forKey: Keys.emailverified) }
    }
    
    // MARK: - Subscription Types
    
    var liteSubscriptionActive: Bool {
        get { defaults.bool(forKey: Keys.liteSubscriptionActive) }
        set { defaults.set(newValue, forKey: Keys.liteSubscriptionActive) }
    }
    
    var plusSubscriptionActive: Bool {
        get { defaults.bool(forKey: Keys.plusSubscriptionActive) }
        set { defaults.set(newValue, forKey: Keys.plusSubscriptionActive) }
    }
    
    var proSubscriptionActive: Bool {
        get { defaults.bool(forKey: Keys.proSubscriptionActive) }
        set { defaults.set(newValue, forKey: Keys.proSubscriptionActive) }
    }
    
    // MARK: - Android Parity Methods
    
    /// Android parity method - delegates to SubscriptionSessionManager
    func isUserSubscribedToPro() -> Bool {
        return SubscriptionSessionManager.shared.isUserSubscribedToPro()
    }
    
    // MARK: - Message Tracking
    
    var totalNoOfMessageReceived: Int {
        get { defaults.integer(forKey: Keys.totalNoOfMessageReceived) }
        set { defaults.set(newValue, forKey: Keys.totalNoOfMessageReceived) }
    }
    
    var totalNoOfMessageSent: Int {
        get { defaults.integer(forKey: Keys.totalNoOfMessageSent) }
        set { defaults.set(newValue, forKey: Keys.totalNoOfMessageSent) }
    }
    
    // MARK: - User Report Management
    
    var userReportBlockedUntil: TimeInterval {
        get { defaults.double(forKey: Keys.userReportBlockedUntil) }
        set { defaults.set(newValue, forKey: Keys.userReportBlockedUntil) }
    }
    
    var canReportSB: Bool {
        get { defaults.bool(forKey: Keys.canReportSB) }
        set { defaults.set(newValue, forKey: Keys.canReportSB) }
    }
    
    var userReportTimesList: [TimeInterval] {
        get { defaults.array(forKey: Keys.userReportTimesList) as? [TimeInterval] ?? [] }
        set { defaults.set(newValue, forKey: Keys.userReportTimesList) }
    }
    
    var userReportTimes: Int {
        get { defaults.integer(forKey: Keys.userReportTimes) }
        set { defaults.set(newValue, forKey: Keys.userReportTimes) }
    }
    
    // MARK: - Android Parity Methods
    
    /// Android parity method: Check if user can report (matches Android getCanReportSB())
    /// DELEGATES to ModerationSettingsSessionManager for better separation of concerns
    func getCanReportSB() -> Bool {
        return !ModerationSettingsSessionManager.shared.isUserBlockedFromReporting()
    }
    

    
    /// Android parity method: Save user report blocked until timestamp (matches Android saveUserReportBlockedUntil())
    func saveUserReportBlockedUntil(_ timestamp: TimeInterval) {
        userReportBlockedUntil = timestamp
        synchronize()
    }
    

    
    // MARK: - Report Warning Properties
    
    var showRepeatedReportsWarning: Bool {
        get { defaults.bool(forKey: Keys.showRepeatedReportsWarning) }
        set { defaults.set(newValue, forKey: Keys.showRepeatedReportsWarning) }
    }
    
    var canReportShowWarningCooldownUntilTimestamp: TimeInterval {
        get { defaults.double(forKey: Keys.canReportShowWarningCooldownUntilTimestamp) }
        set { defaults.set(newValue, forKey: Keys.canReportShowWarningCooldownUntilTimestamp) }
    }
    
    var userTotalReports: Int {
        get { defaults.integer(forKey: Keys.userTotalReports) }
        set { defaults.set(newValue, forKey: Keys.userTotalReports) }
    }
    
    var userLastReportTimestamp: TimeInterval {
        get { defaults.double(forKey: Keys.userLastReportTimestamp) }
        set { defaults.set(newValue, forKey: Keys.userLastReportTimestamp) }
    }
    
    var showMultipleReportsWarning: Bool {
        get { defaults.bool(forKey: Keys.showMultipleReportsWarning) }
        set { defaults.set(newValue, forKey: Keys.showMultipleReportsWarning) }
    }
    
    var multipleReportsShowWarningCooldownUntilTimestamp: TimeInterval {
        get { defaults.double(forKey: Keys.multipleReportsShowWarningCooldownUntilTimestamp) }
        set { defaults.set(newValue, forKey: Keys.multipleReportsShowWarningCooldownUntilTimestamp) }
    }
    
    // MARK: - IP Details Properties
    
    var userRetrievedIp: String? {
        get { defaults.string(forKey: Keys.userRetrievedIp) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userRetrievedIp)
            } else {
                defaults.removeObject(forKey: Keys.userRetrievedIp)
            }
        }
    }
    
    var userRetrievedState: String? {
        get { defaults.string(forKey: Keys.userRetrievedState) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userRetrievedState)
            } else {
                defaults.removeObject(forKey: Keys.userRetrievedState)
            }
        }
    }
    
    var userRetrievedCountry: String? {
        get { defaults.string(forKey: Keys.userRetrievedCountry) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.userRetrievedCountry)
            } else {
                defaults.removeObject(forKey: Keys.userRetrievedCountry)
            }
        }
    }
    
    // MARK: - Filter Properties
    
    var onlineUserFilterData: Data? {
        get { defaults.data(forKey: Keys.onlineUserFilter) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.onlineUserFilter)
            } else {
                defaults.removeObject(forKey: Keys.onlineUserFilter)
            }
        }
    }
    
    // MARK: - Additional Warning Properties
    
    var showTimeMismatchWarning: Bool {
        get { defaults.bool(forKey: Keys.showTimeMismatchWarning) }
        set { defaults.set(newValue, forKey: Keys.showTimeMismatchWarning) }
    }
    
    var showAdPolicyWarning: Bool {
        get { defaults.bool(forKey: Keys.showAdPolicyWarning) }
        set { defaults.set(newValue, forKey: Keys.showAdPolicyWarning) }
    }
    
    var showTextModerationWarning: Bool {
        get { defaults.bool(forKey: Keys.showTextModerationWarning) }
        set { defaults.set(newValue, forKey: Keys.showTextModerationWarning) }
    }
    
    var showImageModerationWarning: Bool {
        get { defaults.bool(forKey: Keys.showImageModerationWarning) }
        set { defaults.set(newValue, forKey: Keys.showImageModerationWarning) }
    }
    
    // REMOVED: showIntegrityWarning - device integrity checks removed for iOS
    
    // MARK: - Android Parity Warning Methods (matching Android SessionManager exactly)
    
    /// Android parity method for getTimeMismatchedShowWarning()
    func getTimeMismatchedShowWarning() -> Bool {
        return showTimeMismatchWarning
    }
    
    /// Android parity method for getAdPolicyViolatedShowWarning()
    func getAdPolicyViolatedShowWarning() -> Bool {
        return showAdPolicyWarning
    }
    
    /// Android parity method for getCanReportShowWarning() - DELEGATES to ModerationSettingsSessionManager
    func getCanReportShowWarning() -> Bool {
        return ModerationSettingsSessionManager.shared.shouldShowRepeatedReportsWarning()
    }
    
    /// Android parity method for getMultipleReportsShowWarning() - DELEGATES to ModerationSettingsSessionManager
    func getMultipleReportsShowWarning() -> Bool {
        return ModerationSettingsSessionManager.shared.shouldShowMultipleReportsWarning()
    }
    
    /// Android parity method for getTextModerationIssueShowWarning() - DELEGATES to ModerationSettingsSessionManager
    func getTextModerationIssueShowWarning() -> Bool {
        return ModerationSettingsSessionManager.shared.showTextModerationWarning
    }
    
    /// Android parity method for getImageModerationIssueShowWarning() - DELEGATES to ModerationSettingsSessionManager
    func getImageModerationIssueShowWarning() -> Bool {
        return ModerationSettingsSessionManager.shared.showImageModerationWarning
    }
    
    // REMOVED: All integrity properties - device integrity checks removed for iOS

    // MARK: - Message Management Methods
    
    func getLastUserMessage(for chatId: String) -> String? {
        return defaults.string(forKey: Keys.lastUserMessagePrefix + chatId)
    }
    
    func setLastUserMessage(_ message: String, for chatId: String) {
        defaults.set(message, forKey: Keys.lastUserMessagePrefix + chatId)
    }
    
    func removeLastUserMessage(for chatId: String) {
        defaults.removeObject(forKey: Keys.lastUserMessagePrefix + chatId)
    }
    
    // MARK: - Session Management Methods
    
    /// Clears all user session data while preserving app settings
    /// ANDROID PARITY: Matches SessionManager.EraseAllData() exactly
    func clearUserSession() {
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() starting complete session cleanup (Android EraseAllData parity)")
        
        // ANDROID PARITY: Stop all Firebase services when user logs out (like Android WorkManager cleanup)
        FirebaseServices.sharedInstance.closeListner()
        
        // ANDROID PARITY: Stop subscription listener manager on logout (like Android stopListener())
        SubscriptionListenerManager.shared.stopListener()
        
        // CRITICAL FIX: Clean up ProfanityService Firebase app to prevent duplicate configuration
        ProfanityService.shared.cleanupFirebaseApp()
        
        // ANDROID PARITY: Clear ALL UserDefaults like Android's editor.clear() + editor.commit()
        // This matches exactly what Android SessionManager.EraseAllData() does
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
            defaults.synchronize()
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() cleared entire UserDefaults domain")
        } else {
            // Fallback: If bundle identifier is nil (extremely rare), clear known keys individually
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() WARNING: Bundle identifier is nil, clearing known keys individually")
            clearAllKnownKeys()
        }
        
        // ANDROID PARITY: Sign out from Firebase like Android's EraseAllData()
        do {
            if Auth.auth().currentUser != nil {
                try Auth.auth().signOut()
                AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() Firebase sign out successful")
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() Firebase sign out error: \(error.localizedDescription)")
            // Continue with cleanup even if sign out fails
        }
        
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "clearUserSession() complete session cleanup finished (Android parity)")
    }
    
    /// Clears all filter data
    func clearFilters() {
        let filterKeys = [
            Keys.filterMinAge, Keys.filterMaxAge, Keys.filterGender,
            Keys.filterCountry, Keys.filterLanguage, Keys.filterNearbyOnly,
            Keys.onlineUsersRefreshTime
        ]
        
        for key in filterKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
    
    /// Android parity: Clears all filter data and returns success status
    func clearAllFilters() -> Bool {
        let filterKeys = [
            Keys.filterMinAge, Keys.filterMaxAge, Keys.filterGender,
            Keys.filterCountry, Keys.filterLanguage, Keys.filterNearbyOnly,
            Keys.onlineUsersRefreshTime
        ]
        
        for key in filterKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        return true // Always returns true as clearing UserDefaults keys cannot fail
    }
    
    /// Synchronizes UserDefaults - Android parity method
    func synchronize() {
        defaults.synchronize()
    }
    
    /// Creates a login session - Android parity method with input validation
    func createLoginSession(userId: String, userName: String, userGender: String, userAge: String, userCountry: String, profilePic: String, deviceId: String, deviceToken: String) {
        // Input validation
        guard !userId.isEmpty, userId.count <= 100 else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "createLoginSession() ERROR: Invalid userId")
            return
        }
        
        guard !userName.isEmpty, userName.count <= 50 else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "createLoginSession() ERROR: Invalid userName")
            return
        }
        
        guard !deviceId.isEmpty, deviceId.count <= 100 else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "createLoginSession() ERROR: Invalid deviceId")
            return
        }
        
        // Validate age if provided
        if !userAge.isEmpty, let age = Int(userAge), age < 13 || age > 120 {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "createLoginSession() WARNING: Age out of valid range: \(age)")
        }
        
        // Sanitize inputs
        self.userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userGender = userGender.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userAge = userAge.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userCountry = userCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userProfilePhoto = profilePic.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviceToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastLoginTime = Date().timeIntervalSince1970
        
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "createLoginSession() Session created successfully for user: \(userName)")
    }
    
    /// Helper method to clear all known keys if bundle identifier is nil
    private func clearAllKnownKeys() {
        // Clear all keys defined in the Keys enum
        let mirror = Mirror(reflecting: Keys.self)
        for child in mirror.children {
            if let keyValue = child.value as? String {
                defaults.removeObject(forKey: keyValue)
            }
        }
        defaults.synchronize()
    }
    
    /// Checks if user is logged in - Android parity method
    func isLoggedIn() -> Bool {
        return userId != nil && !(userId?.isEmpty ?? true)
    }
    
    /// Enhanced session validation with comprehensive checks
    func isSessionValid() -> Bool {
        guard let id = userId, !id.isEmpty else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "isSessionValid() - No valid user ID")
            return false
        }
        
        guard let deviceId = deviceId, !deviceId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "isSessionValid() - No valid device ID")
            return false
        }
        
        // Check if session is too old (optional - 30 days)
        let sessionAge = Date().timeIntervalSince1970 - lastLoginTime
        if sessionAge > 30 * 24 * 60 * 60 { // 30 days
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "isSessionValid() - Session older than 30 days")
            return false
        }
        
        return true
    }
    
    /// Validates and refreshes session data
    func validateAndRefreshSession() -> Bool {
        guard isSessionValid() else {
            AppLogger.log(tag: "LOG-APP: SessionManager", message: "validateAndRefreshSession() - Session invalid, clearing")
            clearUserSession()
            return false
        }
        
        // Update last accessed time
        lastLoginTime = Date().timeIntervalSince1970
        synchronize()
        
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "validateAndRefreshSession() - Session validated and refreshed")
        return true
    }
    
    // MARK: - Ban Status Methods (Android Parity)
    
    /// Gets device ID ban status - Android getDeviceIdBanned() equivalent
    var deviceIdBanned: Bool {
        get { defaults.bool(forKey: Keys.deviceIdBanned) }
        set { defaults.set(newValue, forKey: Keys.deviceIdBanned) }
    }
    
    /// Sets device ID ban status - Android setDeviceIdBanned() equivalent
    func setDeviceIdBanned(_ banned: Bool) {
        deviceIdBanned = banned
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setDeviceIdBanned() device ban status set to: \(banned)")
    }
    
    /// Gets device ID ban status - Android getDeviceIdBanned() equivalent
    func getDeviceIdBanned() -> Bool {
        return deviceIdBanned
    }
    
    /// Gets MAC ID ban status - Android getMacIdBanned() equivalent
    var macIdBanned: Bool {
        get { defaults.bool(forKey: Keys.macIdBanned) }
        set { defaults.set(newValue, forKey: Keys.macIdBanned) }
    }
    
    /// Sets MAC ID ban status - Android setMacIdBanned() equivalent
    func setMacIdBanned(_ banned: Bool) {
        macIdBanned = banned
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setMacIdBanned() MAC ban status set to: \(banned)")
    }
    
    /// Gets MAC ID ban status - Android getMacIdBanned() equivalent
    func getMacIdBanned() -> Bool {
        return macIdBanned
    }
    
    /// Gets IP ID ban status - Android getIpIdBanned() equivalent
    var ipIdBanned: Bool {
        get { defaults.bool(forKey: Keys.ipIdBanned) }
        set { defaults.set(newValue, forKey: Keys.ipIdBanned) }
    }
    
    /// Sets IP ID ban status - Android setIpIdBanned() equivalent
    func setIpIdBanned(_ banned: Bool) {
        ipIdBanned = banned
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setIpIdBanned() IP ban status set to: \(banned)")
    }
    
    /// Gets IP ID ban status - Android getIpIdBanned() equivalent
    func getIpIdBanned() -> Bool {
        return ipIdBanned
    }
    
    // MARK: - Anonymous User Detection (Android Parity)
    
    /// Checks if the current logged-in user is anonymous.
    /// Android parity: SessionManager.isAnonymousUser() method
    /// @return true if the user is anonymous, false otherwise or if no user is logged in.
    func isAnonymousUser() -> Bool {
        let currentUser = Auth.auth().currentUser
        let isAnonymous = currentUser?.isAnonymous ?? false
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "isAnonymousUser() returning: \(isAnonymous)")
        return isAnonymous
    }
    
    // MARK: - Message Limit Methods
    
    func getMessageLimitCooldownStartTime(otherUserId: String) -> Int64 {
        return defaults.object(forKey: "message_limit_cooldown_start_time_\(otherUserId)") as? Int64 ?? 0
    }
    
    func setMessageLimitCooldownStartTime(otherUserId: String, time: Int64) {
        defaults.set(time, forKey: "message_limit_cooldown_start_time_\(otherUserId)")
        synchronize()
    }
    
    func getMessageCount(otherUserId: String) -> Int {
        return defaults.integer(forKey: "message_count_\(otherUserId)")
    }
    
    func setMessageCount(otherUserId: String, count: Int) {
        defaults.set(count, forKey: "message_count_\(otherUserId)")
        synchronize()
    }
    
    // MARK: - Notification Methods (Android Parity)
    
    /// Gets the notification enabled state - Android parity method
    func getNotificationsEnabled() -> Bool {
        return defaults.bool(forKey: Keys.notificationsEnabled, default: true)
    }
    
    /// Sets the notification enabled state - Android parity method
    func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.notificationsEnabled)
        synchronize()
    }

    // MARK: - Android Parity Methods (Missing methods causing build errors)
    
    /// Gets user name - Android getUserName() equivalent
    func getUserName() -> String? {
        return userName
    }
    
    /// Gets user ID - Android getUserID() equivalent  
    func getUserID() -> String? {
        return userId
    }
    
    /// Gets user retrieved city - Android getUserRetrievedCity() equivalent
    func getUserRetrievedCity() -> String? {
        return userRetrievedCity
    }
    
    /// Gets language selected by user - Android getLanguageSelectedUser() equivalent
    func getLanguageSelectedUser() -> String? {
        return userLanguage
    }

    // MARK: - Additional Android Parity Warning Methods (matching Android SessionManager exactly)
    
    // MARK: - Image Moderation Properties (Android Parity)
    
    /// Gets multiple reports SB status - Android getMultipleReportsSB() equivalent
    var multipleReportsSB: Bool {
        get { defaults.bool(forKey: "MULTIPLE_REPORTS_SB") }
        set { defaults.set(newValue, forKey: "MULTIPLE_REPORTS_SB") }
    }
    
    /// Gets image moderation issue SB status - Android getImageModerationIssueSB() equivalent
    var imageModerationIssueSB: Bool {
        get { defaults.bool(forKey: "IMAGE_MODERATION_ISSUE_SB") }
        set { defaults.set(newValue, forKey: "IMAGE_MODERATION_ISSUE_SB") }
    }
    
    /// Gets Hive image moderation score - Android getHiveImageModerationScore() equivalent
    var hiveImageModerationScore: Int {
        get { defaults.integer(forKey: AppSettingsKeys.hiveImageModerationScore) }
        set { 
            defaults.set(newValue, forKey: AppSettingsKeys.hiveImageModerationScore)
            defaults.synchronize()
        }
    }
    
    /// Sets Hive image moderation score - Android setHiveImageModerationScore() equivalent
    func setHiveImageModerationScore(_ score: Int) {
        hiveImageModerationScore = score
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setHiveImageModerationScore() score set to: \(score)")
    }
    
    /// Gets Hive image moderation score - Android getHiveImageModerationScore() equivalent
    func getHiveImageModerationScore() -> Int {
        return hiveImageModerationScore
    }
    
    // MARK: - AI Training Data Methods (Android Parity)
    
    /// Gets AI chatbot URL - Android getAiChatBotURL() equivalent
    func getAiChatBotURL() -> String? {
        return defaults.string(forKey: AppSettingsKeys.aiChatBotURL)
    }
    
    /// Sets AI chatbot URL - Android setAiChatBotURL() equivalent
    func setAiChatBotURL(_ url: String) {
        defaults.set(url, forKey: AppSettingsKeys.aiChatBotURL)
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setAiChatBotURL() URL set to: \(url)")
    }
    
    // MARK: - Report Tracking Methods (Android Parity) - DELEGATED TO SPECIALIZED MANAGERS
    
    /// Gets reported users string - Android getReportedUsers() equivalent
    /// DELEGATES to ModerationSettingsSessionManager for better separation of concerns
    func getReportedUsers() -> String {
        let reportedUsersList = ModerationSettingsSessionManager.shared.getReportedUsersList()
        return reportedUsersList.joined(separator: ",")
    }
    
    /// Sets reported users string - Android setReportedUsers() equivalent
    /// DELEGATES to ModerationSettingsSessionManager for better separation of concerns
    func setReportedUsers(_ reportedUsers: String) {
        let usersList = reportedUsers.components(separatedBy: ",").filter { !$0.isEmpty }
        ModerationSettingsSessionManager.shared.setReportedUsersList(usersList)
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setReportedUsers() delegated to ModerationSettingsSessionManager")
    }
    
    // MARK: - Call State Methods (Android Parity)
    
    /// Gets channel name - Android getChannelName() equivalent
    func getChannelName() -> String {
        return defaults.string(forKey: "channelName") ?? ""
    }
    
    /// Sets channel name - Android setChannelName() equivalent
    func setChannelName(_ channelName: String) {
        defaults.set(channelName, forKey: "channelName")
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setChannelName() channel name set to: \(channelName)")
    }
    
    // MARK: - User Profile Methods (Android Parity)
    
    /// Gets user profile pic - Android getUserProfilePic() equivalent
    func getUserProfilePic() -> String {
        return userProfilePhoto ?? ""
    }
    
    // MARK: - Static Methods (Android Parity)
    
    /// Gets key user gender - Android getKeyUserGender() equivalent
    static func getKeyUserGender() -> String {
        return UserDefaults.standard.string(forKey: Keys.keyUserGender) ?? ""
    }
    
    /// Sets key user gender - Android setKeyUserGender() equivalent
    static func setKeyUserGender(_ gender: String) {
        UserDefaults.standard.set(gender, forKey: Keys.keyUserGender)
        UserDefaults.standard.synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setKeyUserGender() gender set to: \(gender)")
    }
}

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        return self.object(forKey: key) as? Bool ?? defaultValue
    }
} 
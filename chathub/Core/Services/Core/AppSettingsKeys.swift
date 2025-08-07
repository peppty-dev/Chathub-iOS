import Foundation

struct AppSettingsKeys {
    // App Version and Update Settings
    static let liveAppVersion = "liveAppVersionCode" // normalized name used in Firebase
    static let isUpdateMandatory = "isUpdateMandatory"
    static let isMaintenanceMode = "isMaintenanceMode"
    static let updateDetails = "updateMessage"

    // Feature Toggle Settings
    // removed extra features flag

    // Direct Communication Settings
    static let isLiveEnabled = "isLiveEnabled"

    // Advertisement Settings
    // removed ad-related keys

    // App Analytics and Rating Settings
    static let appActivityCountForRateUs = "appActivityCountForRateUs"
    static let maxChatsForRateUsRequest = "minChatsBeforeRatePrompt"
    static let maxRateUsRequests = "maxRatePrompts"

    // Monetization and Limits Settings
    static let newUserFreePeriodSeconds = "freeTrialEndsAtSeconds"
    static let featureMonetizationPopUpCoolDownSeconds = "featureMonetizationPopupCooldownSeconds"

    // Free User Message Limit Settings
    static let freeMessagesLimit = "freeMessagesLimit"
    static let freeMessagesCooldownSeconds = "freeMessagesCooldownSeconds"

    // Free User Conversation Limit Settings
    static let freeConversationsLimit = "freeConversationsLimit"
    static let freeConversationsCooldownSeconds = "freeConversationsCooldownSeconds"

    // User Gender Key (ensure this matches the key used elsewhere for storing user gender)
    static let userGender = "userGender" // From search, "userGender" is used

    // Warning Screen Flags
    static let isUserBanned = "isUserBanned" // Potentially also check CoreData for full ban logic
    static let showAdPolicyWarning = "showAdPolicyWarning"
    // REMOVED: showIntegrityWarning - device integrity checks removed for iOS
    static let showRepeatedReportsWarning = "showRepeatedReportsWarning"
    static let showReportedWarning = "showReportedWarning"
    static let showTextModerationWarning = "showTextModerationWarning"
    static let showImageModerationWarning = "showImageModerationWarning"
    static let showTimeMismatchWarning = "showTimeMismatchWarning"
    static let showMultipleReportsWarning = "showMultipleReportsWarning"

    // Keys for 'Can Report' logic (mimicking Android's AppOpenManager)
    static let userReportBlockedUntilTimestamp = "userReportBlockedUntilTimestamp"
    static let userReportTimesList = "userReportTimesList"
    static let canReportShowWarningCooldownUntilTimestamp = "canReportShowWarningCooldownUntilTimestamp"

    // Keys for 'Multiple Reports' warning logic
    static let userTotalReports = "userTotalReports"
    static let userLastReportTimestamp = "userLastReportTimestamp"
    static let multipleReportsShowWarningCooldownUntilTimestamp = "multipleReportsShowWarningCooldownUntilTimestamp"

    // Keys for 'Text Moderation' warning logic
    static let hiveTextModerationScore = "hiveTextModerationScore"
    static let textModerationIssueShowWarningCooldownUntilTimestamp = "textModerationIssueShowWarningCooldownUntilTimestamp"

    // Keys for 'Image Moderation' warning logic
    static let hiveImageModerationScore = "hiveImageModerationScore"
    static let imageModerationIssueShowWarningCooldownUntilTimestamp = "imageModerationIssueShowWarningCooldownUntilTimestamp"

    // Keys for 'Ad Policy Violation' warning logic (revisiting from Step 13)
    static let adPolicyViolatedDetectedTimestamp = "adPolicyViolatedDetectedTimestamp" // When the Ad SDK flagged the violation
    static let adPolicyShowWarningCooldownUntilTimestamp = "adPolicyShowWarningCooldownUntilTimestamp" // Cooldown for WarningScreen to show this

    // Keys for 'Time Mismatch' warning logic
    static let timeMismatchServerTime = "timeMismatchServerTime"
    static let timeMismatchServerPullSystemTime = "timeMismatchServerPullSystemTime"
    static let timeMismatchShowWarningCooldownUntilTimestamp = "timeMismatchShowWarningCooldownUntilTimestamp"

    // Key for Storing Profanity App Names Set from Secondary Firebase
    static let profanityAppNamesSet = "profanityAppNamesSet"

    // New key for Android parity
    static let isAiChatEnabled = "isAiChatEnabled"
    static let maxIdleSecondsForAiChatEnabling = "aiChatEnableMaxIdleSeconds" // normalized
    static let minOfflineSecondsForAiChatEnabling = "aiChatEnableMinOfflineSeconds" // normalized
    static let aiChatBotURL = "aiChatbotUrl" // normalized
} 
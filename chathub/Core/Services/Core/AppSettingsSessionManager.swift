//
//  AppSettingsSessionManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import Combine

/// AppSettingsSessionManager - Handles only app configuration and feature flags
/// Extracted from SessionManager for better separation of concerns
class AppSettingsSessionManager: ObservableObject {
    static let shared = AppSettingsSessionManager()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys for App Settings Only
    private enum Keys {
        // Feature Control Keys
        static let extraFeaturesEnabled = "EXTRA_FEATURES_ENABLED"
        static let liveEnabled = "LIVEENABLED"
        static let liveAppVersion = "LIVEAPPVERSION"
        static let updateMandatory = "UPDATEMANDATORY"
        static let maintenance = "MAINTENANCE"
        static let updateDetails = "UPDATE_DETAILS"
        
        // Ad Configuration Keys - REMOVED (advertising functionality removed)
        
        // App Behavior Keys
        static let appActivityCount = "APP_ACTIVITY_COUNT"
        static let maxChatsForRateUsRequest = "MAX_CHATS_FOR_RATEUS_REQUEST"
        static let maxRateUsRequests = "MAX_RATEUS_REQUESTS"
        static let activityResumedCount = "ACTIVITY_RESUMED_COUNT"
        
        // AI Configuration Keys
        static let aiChatEnabled = "AI_CHAT_ENABLED"
        static let aiChatEnabledWoman = "AI_CHAT_ENABLED_WOMAN"
        static let maxIdleSecondsForAiChatEnabling = "MAX_IDLE_TIME_FOR_AI_ENABLING"
        static let minOfflineSecondsForAiChatEnabling = "LEAST_OFFLINE_SECONDS_FOR_AI_ENABLING"
        static let aiChatBotURL = "AI_CHAT_BOT_URL"
        static let aiChatIds = "AI_CHAT_IDS"
        
        // Feature Monetization Keys
        static let featureMonetizationPopUpCoolDownSeconds = "FEATURE_MONETIZATION_POP_UP_COOL_DOWN_SECONDS"
        static let lastFeatureMonetizationPopupTime = "LAST_FEATURE_MONETIZATION_POP_UP_COOL_DOWN_SECONDS"
        static let featureMonetizationPopupCooldown = "feature_monetization_popup_cooldown_seconds"
        
        // App Settings Keys
        static let hapticEnabled = "haptic_enabled"
        static let notificationsEnabled = "NOTIFICATIONSENABLED"
        static let themeMode = "themeMode"
        static let deleteDataEnabled = "deleteDataEnabled"
        
        // Terms and Content Keys
        static let termsContent = "termsContent"
        
        // Cache and Performance Keys
        static let badWordsCount = "badWordsCount"
        static let pollIds = "pollIds"
        
        // Warning Display Keys
        static let showTimeMismatchWarning = "showTimeMismatchWarning"
        static let ratingTries = "ratingTries"
        
        // Ad Management Keys - REMOVED (advertising functionality removed)
        
        // Timing Keys
        static let chatLastTime = "chatLastTime"
        static let notificationLastTime = "notificationLastTime"
        static let myProfileTime = "myProfileTime"
        static let audioReportTime = "audioReportTime"
        static let welcomeTimer = "welcomeTimer"
    }

    // MARK: - Feature Control Properties
    
    var extraFeaturesEnabled: Bool {
        get { defaults.bool(forKey: Keys.extraFeaturesEnabled) }
        set { defaults.set(newValue, forKey: Keys.extraFeaturesEnabled) }
    }
    
    var liveEnabled: Bool {
        get { defaults.bool(forKey: Keys.liveEnabled) }
        set { defaults.set(newValue, forKey: Keys.liveEnabled) }
    }
    
    var liveAppVersion: String? {
        get { defaults.string(forKey: Keys.liveAppVersion) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.liveAppVersion)
            } else {
                defaults.removeObject(forKey: Keys.liveAppVersion)
            }
        }
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
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.updateDetails)
            } else {
                defaults.removeObject(forKey: Keys.updateDetails)
            }
        }
    }
    
    // MARK: - Ad Configuration Properties (Removed - migrated to limit-based system)
    
    // MARK: - App Behavior Properties
    
    var appActivityCount: Int {
        get { defaults.integer(forKey: Keys.appActivityCount) }
        set { defaults.set(newValue, forKey: Keys.appActivityCount) }
    }
    
    var maxChatsForRateUsRequest: Int {
        get { defaults.integer(forKey: Keys.maxChatsForRateUsRequest) }
        set { defaults.set(newValue, forKey: Keys.maxChatsForRateUsRequest) }
    }
    
    var maxRateUsRequests: Int {
        get { defaults.integer(forKey: Keys.maxRateUsRequests) }
        set { defaults.set(newValue, forKey: Keys.maxRateUsRequests) }
    }
    
    var activityResumedCount: Int64 {
        get { defaults.object(forKey: Keys.activityResumedCount) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.activityResumedCount) }
    }
    
    // MARK: - AI Configuration Properties
    
    var aiChatEnabled: Bool {
        get { defaults.bool(forKey: Keys.aiChatEnabled) }
        set { defaults.set(newValue, forKey: Keys.aiChatEnabled) }
    }
    
    var aiChatEnabledWoman: Bool {
        get { defaults.bool(forKey: Keys.aiChatEnabledWoman) }
        set { defaults.set(newValue, forKey: Keys.aiChatEnabledWoman) }
    }
    
    var maxIdleSecondsForAiChatEnabling: Int {
        get { defaults.integer(forKey: Keys.maxIdleSecondsForAiChatEnabling) }
        set { defaults.set(newValue, forKey: Keys.maxIdleSecondsForAiChatEnabling) }
    }
    
    var minOfflineSecondsForAiChatEnabling: Int {
        get { defaults.integer(forKey: Keys.minOfflineSecondsForAiChatEnabling) }
        set { defaults.set(newValue, forKey: Keys.minOfflineSecondsForAiChatEnabling) }
    }
    
    var aiChatBotURL: String? {
        get { defaults.string(forKey: Keys.aiChatBotURL) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.aiChatBotURL)
            } else {
                defaults.removeObject(forKey: Keys.aiChatBotURL)
            }
        }
    }
    
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
    
    // MARK: - Feature Monetization Properties
    
    var featureMonetizationPopUpCoolDownSeconds: TimeInterval {
        get { defaults.double(forKey: Keys.featureMonetizationPopUpCoolDownSeconds) }
        set { defaults.set(newValue, forKey: Keys.featureMonetizationPopUpCoolDownSeconds) }
    }
    
    var lastFeatureMonetizationPopupTime: TimeInterval {
        get { defaults.double(forKey: Keys.lastFeatureMonetizationPopupTime) }
        set { defaults.set(newValue, forKey: Keys.lastFeatureMonetizationPopupTime) }
    }
    
    var featureMonetizationPopupCooldown: TimeInterval {
        get { defaults.double(forKey: Keys.featureMonetizationPopupCooldown) }
        set { defaults.set(newValue, forKey: Keys.featureMonetizationPopupCooldown) }
    }
    
    // MARK: - App Settings Properties
    
    var hapticEnabled: Bool {
        get { defaults.bool(forKey: Keys.hapticEnabled) }
        set { defaults.set(newValue, forKey: Keys.hapticEnabled) }
    }
    
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }
    
    var themeMode: String? {
        get { defaults.string(forKey: Keys.themeMode) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.themeMode)
            } else {
                defaults.removeObject(forKey: Keys.themeMode)
            }
        }
    }
    
    var deleteDataEnabled: Bool {
        get { defaults.bool(forKey: Keys.deleteDataEnabled) }
        set { defaults.set(newValue, forKey: Keys.deleteDataEnabled) }
    }
    
    // MARK: - Terms and Content Properties
    
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
    
    // MARK: - Cache and Performance Properties
    
    var badWordsCount: Int {
        get { defaults.integer(forKey: Keys.badWordsCount) }
        set { defaults.set(newValue, forKey: Keys.badWordsCount) }
    }
    
    var pollIds: [String] {
        get { defaults.stringArray(forKey: Keys.pollIds) ?? [] }
        set { defaults.set(newValue, forKey: Keys.pollIds) }
    }
    
    // MARK: - Warning Display Properties
    
    var showTimeMismatchWarning: Bool {
        get { defaults.bool(forKey: Keys.showTimeMismatchWarning) }
        set { defaults.set(newValue, forKey: Keys.showTimeMismatchWarning) }
    }
    
    // showAdPolicyWarning property removed - migrated to limit-based system
    
    var ratingTries: Int {
        get { defaults.integer(forKey: Keys.ratingTries) }
        set { defaults.set(newValue, forKey: Keys.ratingTries) }
    }
    
    // MARK: - Ad Management Properties (Removed - migrated to limit-based system)
    
    // MARK: - Timing Properties
    
    var chatLastTime: TimeInterval {
        get { defaults.double(forKey: Keys.chatLastTime) }
        set { defaults.set(newValue, forKey: Keys.chatLastTime) }
    }
    
    var notificationLastTime: TimeInterval {
        get { defaults.double(forKey: Keys.notificationLastTime) }
        set { defaults.set(newValue, forKey: Keys.notificationLastTime) }
    }
    
    var myProfileTime: TimeInterval {
        get { defaults.double(forKey: Keys.myProfileTime) }
        set { defaults.set(newValue, forKey: Keys.myProfileTime) }
    }
    
    var audioReportTime: TimeInterval {
        get { defaults.double(forKey: Keys.audioReportTime) }
        set { defaults.set(newValue, forKey: Keys.audioReportTime) }
    }
    
    var welcomeTimer: TimeInterval {
        get { defaults.double(forKey: Keys.welcomeTimer) }
        set { defaults.set(newValue, forKey: Keys.welcomeTimer) }
    }
    
    // MARK: - App Configuration Management Methods
    
    /// Load remote configuration from Firebase
    func loadRemoteConfig() {
        AppLogger.log(tag: "LOG-APP: AppSettingsSessionManager", message: "loadRemoteConfig() - Loading remote configuration")
        
        // This method would be called by AppSettingsService to update settings
        // Implementation would be in AppSettingsService
    }
    
    /// Check if a feature is enabled
    func isFeatureEnabled(_ feature: AppFeature) -> Bool {
        switch feature {
        case .extraFeatures:
            return extraFeaturesEnabled
        case .live:
            return liveEnabled
        case .aiChat:
            return aiChatEnabled
        case .inFeedAds:
            return false // Always disabled - migrated to limit-based system
        case .haptics:
            return hapticEnabled
        case .notifications:
            return notificationsEnabled
        case .deleteData:
            return deleteDataEnabled
        }
    }
    
    /// Android parity method: setLastFeatureMoneitzationPopUpTimeInSeconds
    func setLastFeatureMoneitzationPopUpTimeInSeconds(_ timeInSeconds: TimeInterval) {
        lastFeatureMonetizationPopupTime = timeInSeconds
        synchronize()
    }
    
    /// Android parity method: getLastFeatureMoneitzationPopUpTimeInSeconds
    func getLastFeatureMoneitzationPopUpTimeInSeconds() -> TimeInterval {
        return lastFeatureMonetizationPopupTime
    }
    
    /// Android parity method: getFeatureMonetizationPopUpCoolDownSeconds
    func getFeatureMonetizationPopUpCoolDownSeconds() -> TimeInterval {
        return featureMonetizationPopupCooldown
    }
    
    /// Android parity method: setFeatureMonetizationPopUpCoolDownSeconds
    func setFeatureMonetizationPopUpCoolDownSeconds(_ cooldownSeconds: TimeInterval) {
        featureMonetizationPopupCooldown = cooldownSeconds
        synchronize()
    }
    
    /// Check if app is in maintenance mode
    func isMaintenanceModeEnabled() -> Bool {
        return maintenance
    }
    
    /// Check if update is mandatory
    func isUpdateMandatory() -> Bool {
        return updateMandatory
    }
    
    // Ad-related methods removed - migrated to limit-based system
    
    /// Check if AI chat is enabled for user gender
    func isAiChatEnabled(for userGender: String?) -> Bool {
        if userGender?.lowercased() == "female" {
            return aiChatEnabledWoman
        } else {
            return aiChatEnabled
        }
    }
    
    /// Reset app settings to defaults
    func resetToDefaults() {
        AppLogger.log(tag: "LOG-APP: AppSettingsSessionManager", message: "resetToDefaults() - Resetting app settings to defaults")
        
        // Reset feature flags
        extraFeaturesEnabled = false
        liveEnabled = false
        updateMandatory = false
        maintenance = false
        
        // Ad settings removed - migrated to limit-based system
        
        // Reset AI settings
        aiChatEnabled = false
        aiChatEnabledWoman = false
        maxIdleSecondsForAiChatEnabling = 0
        minOfflineSecondsForAiChatEnabling = 0
        
        // Reset app preferences
        hapticEnabled = true // Default to enabled
        notificationsEnabled = true // Default to enabled
        
        synchronize()
    }
    
    /// Clear all app settings
    func clearAppSettings() {
        AppLogger.log(tag: "LOG-APP: AppSettingsSessionManager", message: "clearAppSettings() - Clearing all app settings")
        let keysToRemove = [
            Keys.extraFeaturesEnabled,
            Keys.liveEnabled,
            Keys.liveAppVersion,
            Keys.updateMandatory,
            Keys.maintenance,
            Keys.updateDetails,
            // Ad-related keys removed - migrated to limit-based system
            Keys.appActivityCount,
            Keys.maxChatsForRateUsRequest,
            Keys.maxRateUsRequests,
            Keys.activityResumedCount,
            Keys.aiChatEnabled,
            Keys.aiChatEnabledWoman,
            Keys.maxIdleSecondsForAiChatEnabling,
            Keys.minOfflineSecondsForAiChatEnabling,
            Keys.aiChatBotURL,
            Keys.aiChatIds,
            Keys.featureMonetizationPopUpCoolDownSeconds,
            Keys.lastFeatureMonetizationPopupTime,
            Keys.featureMonetizationPopupCooldown,
            Keys.hapticEnabled,
            Keys.notificationsEnabled,
            Keys.themeMode,
            Keys.deleteDataEnabled,
            Keys.termsContent,
            Keys.badWordsCount,
            Keys.pollIds,
            Keys.showTimeMismatchWarning,
            // Ad-related keys removed - migrated to limit-based system
            Keys.ratingTries,
            Keys.chatLastTime,
            Keys.notificationLastTime,
            Keys.myProfileTime,
            Keys.audioReportTime,
            Keys.welcomeTimer
        ]
        
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        synchronize()
    }
    
    /// Synchronize UserDefaults
    func synchronize() {
        defaults.synchronize()
    }
}

// MARK: - App Feature Enum

enum AppFeature {
    case extraFeatures
    case live
    case aiChat
    case inFeedAds
    case haptics
    case notifications
    case deleteData
} 
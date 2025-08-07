//
//  AppSettingsDebugPopulator.swift
//  ChatHub
//
//  Created by Assistant on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Debug utility to populate Firebase AppSettings with default values
/// Use this to quickly set up default app settings in Firebase without manually editing the console
class AppSettingsDebugPopulator {
    static let shared = AppSettingsDebugPopulator()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Populates Firebase AppSettings document with default values
    /// Call this once during development to set up initial app settings
    func populateDefaultAppSettings() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "populateDefaultAppSettings() Could not find bundle identifier")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "populateDefaultAppSettings() Populating default settings for: \(bundleIdentifier)")
        
        let defaultSettings: [String: Any] = [
            // App Version and Update Settings
            "liveAppVersionCode": getCurrentBuildNumber(),
            "isUpdateMandatory": false,
            "isMaintenanceMode": false,
            "updateMessage": "Bug fixes and performance improvements",
            
            // Direct Communication Settings
            "isLiveEnabled": true,
            
            // App Analytics and Rating Settings
            "minChatsBeforeRatePrompt": 15,
            "maxRatePrompts": 3,
            
            // AI Chat Configuration Settings (Gender-specific)
            "isAiChatEnabled": true,
            "isAiChatEnabledFemale": true,
            "aiChatEnableMaxIdleSeconds": 60, // 1 minute
            "aiChatEnableMinOfflineSeconds": 60, // 1 minute
            "aiChatbotUrl": "",
            
            // Monetization and Limits Settings
            "freeTrialEndsAtSeconds": 3600, // 1 hour
            "featureMonetizationPopupCooldownSeconds": 300, // 5 minutes
            
            // Free User Message Limit Settings
            "freeMessagesLimit": 15,
            "freeMessagesCooldownSeconds": 300, // 5 minutes
            
            // Free User Conversation Limit Settings
            "freeConversationsLimit": 5,
            "freeConversationsCooldownSeconds": 600, // 10 minutes
            
            // Shadow Ban (Text Moderation) Settings
            "textModerationShadowBanLockDurationSeconds": 900, // 15 minutes
            
            // Free User Refresh Limit Settings
            "freeRefreshLimit": 2,
            "freeRefreshCooldownSeconds": 300, // 5 minutes
            
            // Free User Filter Limit Settings
            "freeFilterLimit": 1,
            "freeFilterCooldownSeconds": 600, // 10 minutes
            
            // Free User Search Limit Settings
            "freeSearchLimit": 2,
            "freeSearchCooldownSeconds": 300 // 5 minutes
        ]
        
        // Set the document in Firebase
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .setData(defaultSettings, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "populateDefaultAppSettings() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "populateDefaultAppSettings() Successfully populated default app settings")
                    
                    // Log all the values that were set
                    self.logSettingsValues(defaultSettings)
                }
            }
    }
    
    /// Updates only the build number in Firebase (useful for app updates)
    func updateBuildNumber() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "updateBuildNumber() Could not find bundle identifier")
            return
        }
        
        let buildNumber = getCurrentBuildNumber()
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "updateBuildNumber() Updating to build: \(buildNumber)")
        
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .updateData(["liveAppVersionCode": buildNumber]) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "updateBuildNumber() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "updateBuildNumber() Successfully updated build number to: \(buildNumber)")
                }
            }
    }
    
    /// Enables maintenance mode (useful for app maintenance)
    func enableMaintenanceMode(message: String = "App is under maintenance. Please try again later.") {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMaintenanceMode() Could not find bundle identifier")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMaintenanceMode() Enabling maintenance mode")
        
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .updateData([
                "isMaintenanceMode": true,
                "updateMessage": message
            ]) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMaintenanceMode() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMaintenanceMode() Successfully enabled maintenance mode")
                }
            }
    }
    
    /// Disables maintenance mode
    func disableMaintenanceMode() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMaintenanceMode() Could not find bundle identifier")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMaintenanceMode() Disabling maintenance mode")
        
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .updateData([
                "isMaintenanceMode": false,
                "updateMessage": "Bug fixes and performance improvements"
            ]) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMaintenanceMode() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMaintenanceMode() Successfully disabled maintenance mode")
                }
            }
    }
    
    /// Forces update for all users
    func enableMandatoryUpdate(message: String = "Please update to the latest version to continue using the app.") {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMandatoryUpdate() Could not find bundle identifier")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMandatoryUpdate() Enabling mandatory update")
        
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .updateData([
                "isUpdateMandatory": true,
                "updateMessage": message
            ]) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMandatoryUpdate() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "enableMandatoryUpdate() Successfully enabled mandatory update")
                }
            }
    }
    
    /// Disables mandatory update
    func disableMandatoryUpdate() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMandatoryUpdate() Could not find bundle identifier")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMandatoryUpdate() Disabling mandatory update")
        
        db.collection("AppSettings")
            .document(bundleIdentifier)
            .updateData(["isUpdateMandatory": false]) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMandatoryUpdate() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "disableMandatoryUpdate() Successfully disabled mandatory update")
                }
            }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the current build number from the app bundle
    private func getCurrentBuildNumber() -> Int {
        if let buildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           let buildNumber = Int(buildString) {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "getCurrentBuildNumber() Using current build number: \(buildNumber)")
            return buildNumber
        }
        
        // Fallback: try CFBundleShortVersionString if CFBundleVersion fails
        if let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            // Extract numeric parts from version string (e.g., "1.2.3" -> 123)
            let numericVersion = versionString.replacingOccurrences(of: ".", with: "")
            if let versionNumber = Int(numericVersion) {
                AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "getCurrentBuildNumber() Using version string as build: \(versionNumber)")
                return versionNumber
            }
        }
        
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "getCurrentBuildNumber() Could not find build number, using default: 1")
        return 1 // Default build number if not found
    }
    
    /// Logs all the settings values that were set
    private func logSettingsValues(_ settings: [String: Any]) {
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "=== DEFAULT APP SETTINGS ===")
        for (key, value) in settings.sorted(by: { $0.key < $1.key }) {
            AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "\(key): \(value)")
        }
        AppLogger.log(tag: "LOG-APP: AppSettingsDebugPopulator", message: "=== END SETTINGS ===")
    }
}

// MARK: - Debug Usage Extension

#if DEBUG
extension AppSettingsDebugPopulator {
    /// Convenience method to call from anywhere during development
    /// Add this to your app launch or a debug menu
    static func setupDefaultSettings() {
        AppSettingsDebugPopulator.shared.populateDefaultAppSettings()
    }
    
    /// Quick method to update build number during development
    static func updateBuild() {
        AppSettingsDebugPopulator.shared.updateBuildNumber()
    }
    
    /// Quick method to enable maintenance mode
    static func maintenanceOn(_ message: String = "App is under maintenance. Please try again later.") {
        AppSettingsDebugPopulator.shared.enableMaintenanceMode(message: message)
    }
    
    /// Quick method to disable maintenance mode
    static func maintenanceOff() {
        AppSettingsDebugPopulator.shared.disableMaintenanceMode()
    }
    
    /// Quick method to force update
    static func forceUpdate(_ message: String = "Please update to the latest version to continue using the app.") {
        AppSettingsDebugPopulator.shared.enableMandatoryUpdate(message: message)
    }
    
    /// Quick method to disable forced update
    static func allowOldVersions() {
        AppSettingsDebugPopulator.shared.disableMandatoryUpdate()
    }
}
#endif

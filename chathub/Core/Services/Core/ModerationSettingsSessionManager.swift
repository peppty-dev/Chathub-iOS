//
//  ModerationSettingsSessionManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import Combine

/// ModerationSettingsSessionManager - Handles only content moderation and user reporting settings
/// Extracted from SessionManager for better separation of concerns
class ModerationSettingsSessionManager: ObservableObject {
    static let shared = ModerationSettingsSessionManager()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys for Moderation Settings Only
    private enum Keys {
        // Profanity Management Keys
        static let profanityWordsVersion = "PROFANITYWORDSVERSION"
        static let profanityWords = "PROFANITYWORDS"
        static let profanityAppNameWordsVersion = "PROFANITY_APP_NAME_WORDS_VERSION"
        static let profanityAppNameWords = "PROFANITY_APP_NAME_WORDS"
        static let profanityFirebaseInitialized = "PROFANITY_FIREBASE_INITIALIZED"
        
        // Text Moderation Keys
        static let hiveTextModerationScore = "HIVE_TEXT_MODERATION_SCORE"
        static let textModerationIssueSB = "TEXT_MODERATION_ISSUE_SB"
        static let textModerationIssueCoolDownTime = "TEXT_MODERATION_ISSUE_COOL_DOWN_TIME"
        static let showTextModerationWarning = "showTextModerationWarning"
        
        // Image Moderation Keys
        static let showImageModerationWarning = "showImageModerationWarning"
        
        // User Warning Keys
        static let userWarningCount = "userWarningCount"
        
        // User Reporting Keys
        static let reportedUsers = "reportedUsers"
        static let reportedImages = "reportedImages"
        static let repeatedUserReportsTimeArray = "repeatedUserReportsTimeArray"
        static let repeatedUserReportsSBTime = "repeatedUserReportsSBTime"
        static let repeatedImageReportsTimeArray = "repeatedImageReportsTimeArray"
        static let repeatedImageReportsSBTime = "repeatedImageReportsSBTime"
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
        
        // Review System Keys
        static let forreviewIncoming = "forreviewIncoming"
        static let forreviewOutgoing = "forreviewOutgoing"
        
        // Blocked Users Keys
        static let blockedUsers = "blockedUsers"
        static let reportedVideoUsers = "reportedVideoUsers"
        static let reportedLobbyUsers = "reportedLobbyUsers"
        
        // Ban Management Keys
        static let isUserBanned = "isUserBanned"
        static let banReason = "banReason"
        static let banTime = "banTime"
        static let isDeviceIdBanned = "isDeviceIdBanned"
        static let isMacIdBanned = "isMacIdBanned"
        static let isIpIdBanned = "isIpIdBanned"
    }

    // MARK: - Profanity Management Properties
    
    var profanityWordsVersion: Int64 {
        get { defaults.object(forKey: Keys.profanityWordsVersion) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.profanityWordsVersion) }
    }
    
    var profanityWords: String? {
        get { defaults.string(forKey: Keys.profanityWords) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.profanityWords)
            } else {
                defaults.removeObject(forKey: Keys.profanityWords)
            }
        }
    }
    
    var profanityAppNameWordsVersion: Int64 {
        get { defaults.object(forKey: Keys.profanityAppNameWordsVersion) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.profanityAppNameWordsVersion) }
    }
    
    var profanityAppNameWords: String? {
        get { defaults.string(forKey: Keys.profanityAppNameWords) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.profanityAppNameWords)
            } else {
                defaults.removeObject(forKey: Keys.profanityAppNameWords)
            }
        }
    }
    
    var profanityFirebaseInitialized: Bool {
        get { defaults.bool(forKey: Keys.profanityFirebaseInitialized) }
        set { defaults.set(newValue, forKey: Keys.profanityFirebaseInitialized) }
    }
    
    // MARK: - Text Moderation Properties
    
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
    
    var showTextModerationWarning: Bool {
        get { defaults.bool(forKey: Keys.showTextModerationWarning) }
        set { defaults.set(newValue, forKey: Keys.showTextModerationWarning) }
    }
    
    // MARK: - Image Moderation Properties
    
    var showImageModerationWarning: Bool {
        get { defaults.bool(forKey: Keys.showImageModerationWarning) }
        set { defaults.set(newValue, forKey: Keys.showImageModerationWarning) }
    }
    
    var imageModerationIssueSB: Bool {
        get { defaults.bool(forKey: "IMAGE_MODERATION_ISSUE_SB") }
        set { defaults.set(newValue, forKey: "IMAGE_MODERATION_ISSUE_SB") }
    }
    
    var hiveImageModerationScore: Int {
        get { defaults.integer(forKey: "HIVE_IMAGE_MODERATION_SCORE") }
        set { defaults.set(newValue, forKey: "HIVE_IMAGE_MODERATION_SCORE") }
    }
    
    var imageModerationIssueCoolDownTime: Int64 {
        get { Int64(defaults.double(forKey: "IMAGE_MODERATION_ISSUE_COOL_DOWN_TIME")) }
        set { defaults.set(Double(newValue), forKey: "IMAGE_MODERATION_ISSUE_COOL_DOWN_TIME") }
    }
    
    // MARK: - User Warning Properties
    
    var userWarningCount: Int {
        get { defaults.integer(forKey: Keys.userWarningCount) }
        set { defaults.set(newValue, forKey: Keys.userWarningCount) }
    }
    
    // MARK: - User Reporting Properties
    
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
    
    var repeatedImageReportsTimeArray: [TimeInterval] {
        get { defaults.array(forKey: Keys.repeatedImageReportsTimeArray) as? [TimeInterval] ?? [] }
        set { defaults.set(newValue, forKey: Keys.repeatedImageReportsTimeArray) }
    }
    
    var repeatedImageReportsSBTime: TimeInterval {
        get { defaults.double(forKey: Keys.repeatedImageReportsSBTime) }
        set { defaults.set(newValue, forKey: Keys.repeatedImageReportsSBTime) }
    }
    
    var userReportBlockedUntil: TimeInterval {
        get { defaults.double(forKey: Keys.userReportBlockedUntil) }
        set { defaults.set(newValue, forKey: Keys.userReportBlockedUntil) }
    }
    
    var canReportSB: Bool {
        get { defaults.bool(forKey: Keys.canReportSB) }
        set { defaults.set(newValue, forKey: Keys.canReportSB) }
    }
    
    var userReportTimesList: [String] {
        get { defaults.stringArray(forKey: Keys.userReportTimesList) ?? [] }
        set { defaults.set(newValue, forKey: Keys.userReportTimesList) }
    }
    
    var userReportTimes: Int {
        get { defaults.integer(forKey: Keys.userReportTimes) }
        set { defaults.set(newValue, forKey: Keys.userReportTimes) }
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
    
    // MARK: - Review System Properties
    
    var forreviewIncoming: Int {
        get { defaults.integer(forKey: Keys.forreviewIncoming) }
        set { defaults.set(newValue, forKey: Keys.forreviewIncoming) }
    }
    
    var forreviewOutgoing: Int {
        get { defaults.integer(forKey: Keys.forreviewOutgoing) }
        set { defaults.set(newValue, forKey: Keys.forreviewOutgoing) }
    }
    
    var reportedVideoUsers: String? {
        get { defaults.string(forKey: Keys.reportedVideoUsers) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.reportedVideoUsers)
            } else {
                defaults.removeObject(forKey: Keys.reportedVideoUsers)
            }
        }
    }
    
    var reportedLobbyUsers: String? {
        get { defaults.string(forKey: Keys.reportedLobbyUsers) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.reportedLobbyUsers)
            } else {
                defaults.removeObject(forKey: Keys.reportedLobbyUsers)
            }
        }
    }
    
    // MARK: - Moderation Management Methods
    
    /// Check if user is currently blocked from reporting
    func isUserBlockedFromReporting() -> Bool {
        let currentTime = Date().timeIntervalSince1970
        return userReportBlockedUntil > currentTime
    }
    
    /// Get remaining report block time in seconds
    func getRemainingReportBlockTime() -> TimeInterval {
        let currentTime = Date().timeIntervalSince1970
        let remainingTime = userReportBlockedUntil - currentTime
        return max(0, remainingTime)
    }
    
    /// Block user from reporting for specified duration
    func blockUserFromReporting(for duration: TimeInterval) {
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "blockUserFromReporting() - Blocking user for \(duration) seconds")
        
        let currentTime = Date().timeIntervalSince1970
        userReportBlockedUntil = currentTime + duration
        canReportSB = false
        synchronize()
    }
    
    /// Increment user warning count
    func incrementUserWarningCount() {
        userWarningCount += 1
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "incrementUserWarningCount() - Warning count: \(userWarningCount)")
        synchronize()
    }
    
    /// Add user to reported list
    func addUserToReportedList(_ userId: String) {
        var reportedList = getReportedUsersList()
        if !reportedList.contains(userId) {
            reportedList.append(userId)
            setReportedUsersList(reportedList)
            AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "addUserToReportedList() - Added user: \(userId)")
        }
    }
    
    /// Get list of reported users
    func getReportedUsersList() -> [String] {
        guard let reportedString = reportedUsers, !reportedString.isEmpty else {
            return []
        }
        return reportedString.components(separatedBy: ",")
    }
    
    /// Set list of reported users
    func setReportedUsersList(_ users: [String]) {
        reportedUsers = users.joined(separator: ",")
        synchronize()
    }
    
    /// Add user to blocked list
    func addUserToBlockedList(_ userId: String) {
        var blockedList = getBlockedUsersList()
        if !blockedList.contains(userId) {
            blockedList.append(userId)
            setBlockedUsersList(blockedList)
            AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "addUserToBlockedList() - Added user: \(userId)")
        }
    }
    
    /// Get list of blocked users
    func getBlockedUsersList() -> [String] {
        guard let blockedString = blockedUsers, !blockedString.isEmpty else {
            return []
        }
        return blockedString.components(separatedBy: ",")
    }
    
    /// Set list of blocked users
    func setBlockedUsersList(_ users: [String]) {
        blockedUsers = users.joined(separator: ",")
        synchronize()
    }
    
    /// Check if user is blocked
    func isUserBlocked(_ userId: String) -> Bool {
        let blockedList = getBlockedUsersList()
        return blockedList.contains(userId)
    }
    
    /// Check if user has been reported
    func isUserReported(_ userId: String) -> Bool {
        let reportedList = getReportedUsersList()
        return reportedList.contains(userId)
    }
    
    /// Update text moderation score
    func updateTextModerationScore(_ score: Int) {
        hiveTextModerationScore = score
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "updateTextModerationScore() - Score: \(score)")
        
        // Check if score requires warning
        if score >= 5 { // Threshold for showing warning
            showTextModerationWarning = true
        }
        
        synchronize()
    }
    
    /// Reset text moderation score
    func resetTextModerationScore() {
        hiveTextModerationScore = 0
        showTextModerationWarning = false
        textModerationIssueSB = false
        textModerationIssueCoolDownTime = 0
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "resetTextModerationScore() - Reset moderation score")
        synchronize()
    }
    
    /// Check if should show repeated reports warning
    func shouldShowRepeatedReportsWarning() -> Bool {
        if !showRepeatedReportsWarning {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        return canReportShowWarningCooldownUntilTimestamp < currentTime
    }
    
    /// Set repeated reports warning shown
    func setRepeatedReportsWarningShown() {
        showRepeatedReportsWarning = false
        canReportShowWarningCooldownUntilTimestamp = Date().timeIntervalSince1970 + (24 * 60 * 60) // 24 hours cooldown
        synchronize()
    }
    
    /// Check if should show multiple reports warning
    func shouldShowMultipleReportsWarning() -> Bool {
        if !showMultipleReportsWarning {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        return multipleReportsShowWarningCooldownUntilTimestamp < currentTime
    }
    
    /// Set multiple reports warning shown
    func setMultipleReportsWarningShown() {
        showMultipleReportsWarning = false
        multipleReportsShowWarningCooldownUntilTimestamp = Date().timeIntervalSince1970 + (24 * 60 * 60) // 24 hours cooldown
        synchronize()
    }
    
    /// Update profanity words
    func updateProfanityWords(_ words: String, version: Int64) {
        profanityWords = words
        profanityWordsVersion = version
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "updateProfanityWords() - Updated to version: \(version)")
        synchronize()
    }
    
    /// Update profanity app name words
    func updateProfanityAppNameWords(_ words: String, version: Int64) {
        profanityAppNameWords = words
        profanityAppNameWordsVersion = version
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "updateProfanityAppNameWords() - Updated to version: \(version)")
        synchronize()
    }
    
    /// Clear all moderation data
    func clearModerationData() {
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "clearModerationData() - Clearing all moderation data")
        
        // Clear text moderation
        hiveTextModerationScore = 0
        showTextModerationWarning = false
        textModerationIssueSB = false
        textModerationIssueCoolDownTime = 0
        
        // Clear image moderation
        showImageModerationWarning = false
        
        // Clear user warnings
        userWarningCount = 0
        
        // Clear reporting data
        reportedUsers = nil
        reportedImages = nil
        blockedUsers = nil
        repeatedUserReportsTimeArray = []
        repeatedUserReportsSBTime = 0
        repeatedImageReportsTimeArray = []
        repeatedImageReportsSBTime = 0
        userReportBlockedUntil = 0
        canReportSB = true
        userReportTimesList = []
        userReportTimes = 0
        
        // Clear warning states
        showRepeatedReportsWarning = false
        canReportShowWarningCooldownUntilTimestamp = 0
        userTotalReports = 0
        userLastReportTimestamp = 0
        showMultipleReportsWarning = false
        multipleReportsShowWarningCooldownUntilTimestamp = 0
        
        // Clear review data
        forreviewIncoming = 0
        forreviewOutgoing = 0
        reportedVideoUsers = nil
        reportedLobbyUsers = nil
        
        synchronize()
    }
    
    // MARK: - Ban Management Properties
    
    var isUserBanned: Bool {
        get { defaults.bool(forKey: Keys.isUserBanned) }
        set { defaults.set(newValue, forKey: Keys.isUserBanned) }
    }
    
    var banReason: String? {
        get { defaults.string(forKey: Keys.banReason) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.banReason)
            } else {
                defaults.removeObject(forKey: Keys.banReason)
            }
        }
    }
    
    var banTime: String? {
        get { defaults.string(forKey: Keys.banTime) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.banTime)
            } else {
                defaults.removeObject(forKey: Keys.banTime)
            }
        }
    }
    
    var isDeviceIdBanned: Bool {
        get { defaults.bool(forKey: Keys.isDeviceIdBanned) }
        set { defaults.set(newValue, forKey: Keys.isDeviceIdBanned) }
    }
    
    var isMacIdBanned: Bool {
        get { defaults.bool(forKey: Keys.isMacIdBanned) }
        set { defaults.set(newValue, forKey: Keys.isMacIdBanned) }
    }
    
    var isIpIdBanned: Bool {
        get { defaults.bool(forKey: Keys.isIpIdBanned) }
        set { defaults.set(newValue, forKey: Keys.isIpIdBanned) }
    }
    
    /// Synchronize UserDefaults
    func synchronize() {
        defaults.synchronize()
    }
    
    /// Clear moderation settings - compatibility method that calls clearModerationData()
    func clearModerationSettings() {
        AppLogger.log(tag: "LOG-APP: ModerationSettingsSessionManager", message: "clearModerationSettings() called - delegating to clearModerationData()")
        clearModerationData()
    }
} 
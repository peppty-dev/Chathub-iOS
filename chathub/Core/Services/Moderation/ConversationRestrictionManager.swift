//
//  ConversationRestrictionManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation

/// ConversationRestrictionManager - Handles conversation start restrictions for app name violations
/// Implements temporary restrictions to prevent abuse while maintaining user experience
class ConversationRestrictionManager {
    
    // MARK: - Singleton
    static let shared = ConversationRestrictionManager()
    private init() {}
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    
    // MARK: - Constants
    private struct Constants {
        static let restrictionDurationMinutes = 30 // 30 minutes restriction
        static let maxViolationsBeforeLongRestriction = 3
        static let longRestrictionDurationHours = 24 // 24 hours for repeat offenders
    }
    
    private struct Keys {
        static let conversationRestrictionEnd = "conversation_restriction_end"
        static let appNameViolationCount = "app_name_violation_count"
        static let lastViolationTime = "last_app_name_violation_time"
        static let isLongRestriction = "is_long_restriction_active"
    }
    
    // MARK: - Public API
    
    /// Apply conversation restriction for app name violation
    func applyRestrictionForAppNameViolation() {
        let currentTime = Date().timeIntervalSince1970
        let violationCount = getViolationCount() + 1
        
        AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "applyRestrictionForAppNameViolation() - Violation count: \(violationCount)")
        
        // Update violation tracking
        defaults.set(violationCount, forKey: Keys.appNameViolationCount)
        defaults.set(currentTime, forKey: Keys.lastViolationTime)
        
        let restrictionDuration: TimeInterval
        let isLongRestriction: Bool
        
        if violationCount >= Constants.maxViolationsBeforeLongRestriction {
            // Long restriction for repeat offenders
            restrictionDuration = TimeInterval(Constants.longRestrictionDurationHours * 3600)
            isLongRestriction = true
            AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Applying long restriction (24h) for repeat violations")
        } else {
            // Standard restriction
            restrictionDuration = TimeInterval(Constants.restrictionDurationMinutes * 60)
            isLongRestriction = false
            AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Applying standard restriction (30m)")
        }
        
        let restrictionEnd = currentTime + restrictionDuration
        defaults.set(restrictionEnd, forKey: Keys.conversationRestrictionEnd)
        defaults.set(isLongRestriction, forKey: Keys.isLongRestriction)
        
        AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Conversation restriction applied until: \(Date(timeIntervalSince1970: restrictionEnd))")
    }
    
    /// Check if user is currently restricted from starting conversations
    func isConversationRestricted() -> (restricted: Bool, remainingTime: TimeInterval, reason: String) {
        let currentTime = Date().timeIntervalSince1970
        let restrictionEnd = defaults.double(forKey: Keys.conversationRestrictionEnd)
        
        if restrictionEnd > currentTime {
            let remainingTime = restrictionEnd - currentTime
            let isLong = defaults.bool(forKey: Keys.isLongRestriction)
            let reason = isLong ? "Repeated app name violations" : "App name violation"
            
            AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "User is restricted - remaining time: \(remainingTime)s")
            return (true, remainingTime, reason)
        } else {
            // Restriction expired, clean up
            if restrictionEnd > 0 {
                clearRestriction()
                AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Restriction expired and cleared")
            }
            return (false, 0, "")
        }
    }
    
    /// Get remaining restriction time in minutes
    func getRemainingRestrictionMinutes() -> Int {
        let (restricted, remainingTime, _) = isConversationRestricted()
        return restricted ? Int(ceil(remainingTime / 60)) : 0
    }
    
    /// Get user-friendly restriction message
    func getRestrictionMessage() -> String? {
        let (restricted, remainingTime, reason) = isConversationRestricted()
        
        guard restricted else { return nil }
        
        let minutes = Int(ceil(remainingTime / 60))
        let hours = minutes / 60
        
        if hours > 0 {
            return "You cannot start new conversations for \(hours) hour(s) and \(minutes % 60) minute(s) due to \(reason.lowercased())."
        } else {
            return "You cannot start new conversations for \(minutes) minute(s) due to \(reason.lowercased())."
        }
    }
    
    /// Clear current restriction (admin override or expiration)
    func clearRestriction() {
        defaults.removeObject(forKey: Keys.conversationRestrictionEnd)
        defaults.removeObject(forKey: Keys.isLongRestriction)
        AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Conversation restriction cleared")
    }
    
    /// Reset violation count (typically after long period of good behavior)
    func resetViolationCount() {
        defaults.removeObject(forKey: Keys.appNameViolationCount)
        defaults.removeObject(forKey: Keys.lastViolationTime)
        AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Violation count reset")
    }
    
    // MARK: - Private Methods
    
    private func getViolationCount() -> Int {
        let count = defaults.integer(forKey: Keys.appNameViolationCount)
        let lastViolationTime = defaults.double(forKey: Keys.lastViolationTime)
        let currentTime = Date().timeIntervalSince1970
        
        // Reset count if last violation was more than 7 days ago
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 3600
        if currentTime - lastViolationTime > sevenDaysInSeconds {
            AppLogger.log(tag: "LOG-APP: ConversationRestrictionManager", message: "Resetting violation count due to time passage")
            resetViolationCount()
            return 0
        }
        
        return count
    }
    
    // MARK: - Convenience Methods
    
    /// Check if user can start a new conversation
    func canStartNewConversation() -> Bool {
        return !isConversationRestricted().restricted
    }
    
    /// Get restriction status for UI display
    func getRestrictionStatus() -> (canStart: Bool, message: String?) {
        let (restricted, _, _) = isConversationRestricted()
        let message = restricted ? getRestrictionMessage() : nil
        return (!restricted, message)
    }
}

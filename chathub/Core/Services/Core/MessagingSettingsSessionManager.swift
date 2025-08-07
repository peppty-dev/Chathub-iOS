//
//  MessagingSettingsSessionManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import Combine

/// MessagingSettingsSessionManager - Handles only messaging limits and subscription settings
/// Extracted from SessionManager for better separation of concerns
class MessagingSettingsSessionManager: ObservableObject {
    static let shared = MessagingSettingsSessionManager()
    private let defaults = UserDefaults.standard

    private init() {
        // Initialize @Published properties from UserDefaults
        self.isSubscriptionActive = defaults.bool(forKey: Keys.isSubscriptionActive)
    }

    // MARK: - Keys for Messaging Settings Only
    private enum Keys {
        // Message Tracking Keys (conversation-specific data)
        static let lastMessageReceivedTime = "lastMessageReceivedTime"
        static let freeMessageTime = "freeMessageTime"
        static let totalNoOfMessageReceived = "totalNoOfMessageReceived"
        static let totalNoOfMessageSent = "totalNoOfMessageSent"
        static let lastUserMessagePrefix = "lastUserMessage_"
        
        // Subscription Keys
        static let isSubscriptionActive = "isSubscriptionActive"
        static let premiumActive = "premium_active"
        static let subscriptionTier = "subscription_tier"
        static let subscriptionExpiry = "subscription_expiry"
        static let isPremiumActive = "is_premium_active"
        static let liteSubscriptionActive = "lite_subscription_active"
        static let plusSubscriptionActive = "plus_subscription_active"
        static let proSubscriptionActive = "pro_subscription_active"
        
        // Calling Keys
        static let callSeconds = "callSeconds"
        static let liveSeconds = "liveSeconds"
        static let incomingCallerId = "incomingCallerId"
        static let incomingCallerName = "incomingCallerName"
        static let incomingChannelName = "incomingChannelName"
        static let inCall = "inCall"
        
        // Settings Keys
        static let moveToInboxSelected = "moveToInboxSelected"
    }

        // MARK: - Message Tracking Properties (conversation-specific data)
    
    var lastMessageReceivedTime: TimeInterval {
        get { defaults.double(forKey: Keys.lastMessageReceivedTime) }
        set { defaults.set(newValue, forKey: Keys.lastMessageReceivedTime) }
    }
    
    var freeMessageTime: TimeInterval {
        get { defaults.double(forKey: Keys.freeMessageTime) }
        set { defaults.set(newValue, forKey: Keys.freeMessageTime) }
    }
    
    var totalNoOfMessageReceived: Int {
        get { defaults.integer(forKey: Keys.totalNoOfMessageReceived) }
        set { defaults.set(newValue, forKey: Keys.totalNoOfMessageReceived) }
    }
    
    var totalNoOfMessageSent: Int {
        get { defaults.integer(forKey: Keys.totalNoOfMessageSent) }
        set { defaults.set(newValue, forKey: Keys.totalNoOfMessageSent) }
    }
    
    // MARK: - Subscription Properties
    
    @Published var isSubscriptionActive: Bool {
        didSet {
            objectWillChange.send()
            defaults.set(isSubscriptionActive, forKey: Keys.isSubscriptionActive)
        }
    }
    
    var premiumActive: Bool {
        get { defaults.bool(forKey: Keys.premiumActive) }
        set { defaults.set(newValue, forKey: Keys.premiumActive) }
    }
    
    var subscriptionTier: String? {
        get { defaults.string(forKey: Keys.subscriptionTier) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.subscriptionTier)
            } else {
                defaults.removeObject(forKey: Keys.subscriptionTier)
            }
        }
    }
    
    var subscriptionExpiry: Int64 {
        get { defaults.object(forKey: Keys.subscriptionExpiry) as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: Keys.subscriptionExpiry) }
    }
    
    var isPremiumActive: Bool {
        get { defaults.bool(forKey: Keys.isPremiumActive) }
        set { defaults.set(newValue, forKey: Keys.isPremiumActive) }
    }
    
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
    
    // MARK: - Calling Properties
    
    var callSeconds: Int {
        get { defaults.integer(forKey: Keys.callSeconds) }
        set { defaults.set(newValue, forKey: Keys.callSeconds) }
    }
    
    var liveSeconds: Int {
        get { defaults.integer(forKey: Keys.liveSeconds) }
        set { defaults.set(newValue, forKey: Keys.liveSeconds) }
    }
    
    var incomingCallerId: String? {
        get { defaults.string(forKey: Keys.incomingCallerId) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.incomingCallerId)
            } else {
                defaults.removeObject(forKey: Keys.incomingCallerId)
            }
        }
    }
    
    var incomingCallerName: String? {
        get { defaults.string(forKey: Keys.incomingCallerName) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.incomingCallerName)
            } else {
                defaults.removeObject(forKey: Keys.incomingCallerName)
            }
        }
    }
    
    var incomingChannelName: String? {
        get { defaults.string(forKey: Keys.incomingChannelName) }
        set { 
            if let value = newValue {
                defaults.set(value, forKey: Keys.incomingChannelName)
            } else {
                defaults.removeObject(forKey: Keys.incomingChannelName)
            }
        }
    }
    
    var inCall: Bool {
        get { defaults.bool(forKey: Keys.inCall) }
        set { defaults.set(newValue, forKey: Keys.inCall) }
    }
    
    // MARK: - Settings Properties
    
    var moveToInboxSelected: Bool {
        get { defaults.bool(forKey: Keys.moveToInboxSelected) }
        set { defaults.set(newValue, forKey: Keys.moveToInboxSelected) }
    }
    
    // MARK: - Global Message Counting (For Rating System Only)
    
    /// Global message counting - used ONLY for rating system triggers
    /// These count total messages across ALL conversations
    /// totalNoOfMessageSent: Global count of all sent messages  
    /// totalNoOfMessageReceived: Global count of all received messages
    
    /// Check if user has active subscription
    func hasActiveSubscription() -> Bool {
        return isSubscriptionActive || 
               premiumActive || 
               isPremiumActive || 
               liteSubscriptionActive || 
               plusSubscriptionActive || 
               proSubscriptionActive
    }
    
    /// Get current subscription tier
    func getCurrentSubscriptionTier() -> String {
        if proSubscriptionActive {
            return "pro"
        } else if plusSubscriptionActive {
            return "plus"
        } else if liteSubscriptionActive {
            return "lite"
        } else if premiumActive || isPremiumActive {
            return "premium"
        } else {
            return "free"
        }
    }
    
    /// Check if user is in free period
    func isInFreePeriod() -> Bool {
        let currentTime = Date().timeIntervalSince1970
        let freePeriodEnd = TimeInterval(SessionManager.shared.newUserFreePeriodSeconds)
        return currentTime < freePeriodEnd
    }
    
    /// Check if user can send more messages
    func canSendMessage() -> Bool {
        // Premium users can always send messages
        if hasActiveSubscription() {
            return true
        }
        
        // Check if user is in free period
        if isInFreePeriod() {
            return true
        }
        
        // Check message limit and cooldown for free users
        let currentTime = Date().timeIntervalSince1970
        // Use SessionManager for limit configs (consistency with other limit features)
        let messagesCooldownEnd = freeMessageTime + TimeInterval(SessionManager.shared.freeMessagesCooldownSeconds)
        
        if currentTime > messagesCooldownEnd {
            // Cooldown period has passed, reset message count
            resetMessageLimits()
            return true
        }
        
        return totalNoOfMessageSent < SessionManager.shared.freeMessagesLimit
    }
    

    
    /// Increment GLOBAL message count (for rating system only)
    /// This counts total messages across ALL conversations
    func incrementMessageCount() {
        totalNoOfMessageSent += 1
        if freeMessageTime == 0 {
            freeMessageTime = Date().timeIntervalSince1970
        }
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "incrementMessageCount() - GLOBAL Messages sent: \(totalNoOfMessageSent)")
        synchronize()
    }
    

    
    /// Reset message limits (called when cooldown expires)
    func resetMessageLimits() {
        totalNoOfMessageSent = 0
        freeMessageTime = 0
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "resetMessageLimits() - Message limits reset")
        synchronize()
    }
    

    
    /// Get remaining messages in current period
    func getRemainingMessages() -> Int {
        if hasActiveSubscription() || isInFreePeriod() {
            return Int.max // Unlimited
        }
        
        // Use SessionManager for limit configs (consistency with other limit features)
        return max(0, SessionManager.shared.freeMessagesLimit - totalNoOfMessageSent)
    }
    

    
    /// Get time remaining until message cooldown expires
    func getMessageCooldownTimeRemaining() -> TimeInterval {
        if hasActiveSubscription() || isInFreePeriod() {
            return 0
        }
        
        let currentTime = Date().timeIntervalSince1970
        // Use SessionManager for limit configs (consistency with other limit features)
        let cooldownEnd = freeMessageTime + TimeInterval(SessionManager.shared.freeMessagesCooldownSeconds)
        return max(0, cooldownEnd - currentTime)
    }
    
    // MARK: - Per-User Message Counting (For Message Limit Popup)
    
    /// Get message count for specific user (used for message limit popup)
    func getMessageCount(otherUserId: String) -> Int {
        let count = defaults.integer(forKey: "message_count_\(otherUserId)")
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "getMessageCount() User \(otherUserId) has sent \(count) messages")
        return count
    }
    
    /// Set message count for specific user (used for message limit popup)
    func setMessageCount(otherUserId: String, count: Int) {
        defaults.set(count, forKey: "message_count_\(otherUserId)")
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "setMessageCount() Set message count for user \(otherUserId): \(count)")
        synchronize()
    }
    
    /// Increment message count for specific user (used for message limit popup)
    func incrementMessageCount(otherUserId: String) {
        let currentCount = getMessageCount(otherUserId: otherUserId)
        setMessageCount(otherUserId: otherUserId, count: currentCount + 1)
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "incrementMessageCount() Incremented count for user \(otherUserId): \(currentCount) -> \(currentCount + 1)")
    }
    
    /// Get message limit cooldown start time for specific user
    func getMessageLimitCooldownStartTime(otherUserId: String) -> Int64 {
        let time = defaults.object(forKey: "message_limit_cooldown_start_time_\(otherUserId)") as? Int64 ?? 0
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "getMessageLimitCooldownStartTime() User \(otherUserId) cooldown start time: \(time)")
        return time
    }
    
    /// Set message limit cooldown start time for specific user
    func setMessageLimitCooldownStartTime(otherUserId: String, time: Int64) {
        defaults.set(time, forKey: "message_limit_cooldown_start_time_\(otherUserId)")
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "setMessageLimitCooldownStartTime() Set cooldown start time for user \(otherUserId): \(time)")
        synchronize()
    }
    
    /// Reset message limits for specific user (called when cooldown expires)
    func resetMessageLimits(otherUserId: String) {
        setMessageCount(otherUserId: otherUserId, count: 0)
        setMessageLimitCooldownStartTime(otherUserId: otherUserId, time: 0)
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "resetMessageLimits() Reset limits for user \(otherUserId)")
    }
    

    
    /// Store last message for user
    func setLastUserMessage(_ message: String, for userId: String) {
        let key = Keys.lastUserMessagePrefix + userId
        defaults.set(message, forKey: key)
        synchronize()
    }
    
    /// Get last message for user
    func getLastUserMessage(for userId: String) -> String? {
        let key = Keys.lastUserMessagePrefix + userId
        return defaults.string(forKey: key)
    }
    
    /// Update subscription status
    func updateSubscriptionStatus(tier: String, isActive: Bool, expiry: Int64) {
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "updateSubscriptionStatus() - Tier: \(tier), Active: \(isActive)")
        
        // Clear all subscription flags first
        liteSubscriptionActive = false
        plusSubscriptionActive = false
        proSubscriptionActive = false
        premiumActive = false
        isPremiumActive = false
        
        // Set the appropriate subscription flag
        switch tier.lowercased() {
        case "lite":
            liteSubscriptionActive = isActive
        case "plus":
            plusSubscriptionActive = isActive
        case "pro":
            proSubscriptionActive = isActive
        case "premium":
            premiumActive = isActive
            isPremiumActive = isActive
        default:
            break
        }
        
        // Update general subscription status
        isSubscriptionActive = isActive
        subscriptionTier = tier
        subscriptionExpiry = expiry
        
        // Reset limits if subscription is active
        if isActive {
            resetMessageLimits()
        }
        
        synchronize()
    }
    
    /// Check if subscription has expired
    func isSubscriptionExpired() -> Bool {
        if !hasActiveSubscription() {
            return true
        }
        
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        return subscriptionExpiry > 0 && currentTime > subscriptionExpiry
    }
    
    /// Set incoming call details
    func setIncomingCall(callerId: String, callerName: String, channelName: String) {
        incomingCallerId = callerId
        incomingCallerName = callerName
        incomingChannelName = channelName
        inCall = true
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "setIncomingCall() - Caller: \(callerName)")
        synchronize()
    }
    
    /// Clear incoming call details
    func clearIncomingCall() {
        incomingCallerId = nil
        incomingCallerName = nil
        incomingChannelName = nil
        inCall = false
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "clearIncomingCall() - Call details cleared")
        synchronize()
    }
    
    /// Add call seconds
    func addCallSeconds(_ seconds: Int) {
        callSeconds += seconds
        liveSeconds += seconds
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "addCallSeconds() - Total: \(callSeconds)")
        
        // Also update time allocations using TimeAllocationManager
        TimeAllocationManager.shared.replenishCallSecondsIfNeeded()
        
        synchronize()
    }
    
    /// Clear all messaging data (for logout)
    func clearMessagingData() {
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "clearMessagingData() - Clearing all messaging data")
        
        // Clear message tracking
        lastMessageReceivedTime = 0
        freeMessageTime = 0
        totalNoOfMessageReceived = 0
        totalNoOfMessageSent = 0
        
        // Clear conversation tracking (now handled by SessionManager)
        
        // Clear subscription status
        isSubscriptionActive = false
        premiumActive = false
        isPremiumActive = false
        liteSubscriptionActive = false
        plusSubscriptionActive = false
        proSubscriptionActive = false
        subscriptionTier = nil
        subscriptionExpiry = 0
        
        // Clear call data
        callSeconds = 0
        liveSeconds = 0
        clearIncomingCall()
        
        // Clear settings
        moveToInboxSelected = false
        
        // Clear last messages (would need to iterate through all user keys)
        // This is complex, so we'll leave it for now
        
        synchronize()
    }
    
    /// Synchronize UserDefaults
    func synchronize() {
        defaults.synchronize()
    }
    
    /// Clear messaging settings - compatibility method that calls clearMessagingData()
    func clearMessagingSettings() {
        AppLogger.log(tag: "LOG-APP: MessagingSettingsSessionManager", message: "clearMessagingSettings() called - delegating to clearMessagingData()")
        clearMessagingData()
    }
} 
//
//  UserSessionManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import Combine
import FirebaseAuth

/// UserSessionManager - Handles only user identity and profile data
/// Extracted from SessionManager for better separation of concerns
class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()
    private let defaults = UserDefaults.standard

    private init() {
        // Initialize @Published properties from UserDefaults
        self.userId = defaults.string(forKey: Keys.userId)
        self.userName = defaults.string(forKey: Keys.userName)
    }

    // MARK: - Keys for User Session Data Only
    private enum Keys {
        // User Core Identity Keys
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
        static let emailAddress = "emailAddress"
        static let isAccountCreated = "isAccountCreated"
        static let accountCreatedTime = "accountCreatedTime"
        static let emailVerified = "emailVerified"
        static let userRetrievedCity = "userRetrievedCity"
        static let userRetrievedIp = "userRetrievedIp"
        static let userRetrievedState = "userRetrievedState"
        static let userRetrievedCountry = "userRetrievedCountry"
        static let firstAccountCreatedTime = "device_first_account_time"
        
        // User Status Keys
        static let userOnline = "UserOnline"
        static let isUserBanned = "isUserBanned"
        static let welcomeTimer = "welcomeTimer"
        
        // User Filter Preferences
        static let filterMinAge = "filter_min_age"
        static let filterMaxAge = "filter_max_age"
        static let filterGender = "filter_gender"
        static let filterCountry = "filter_country"
        static let filterLanguage = "filter_language"
        static let filterNearbyOnly = "filter_nearby_only"
        static let onlineUsersRefreshTime = "online_users_refresh_time"
        static let onlineUserFilter = "OnlineUserFilter"
        
        // User Interaction Preferences
        static let interestTags = "interestTags"
        static let interestSentence = "interestSentence"
        static let interestTime = "interestTime"
        
        // Ban Status Keys
        static let deviceIdBanned = "deviceIdBanned"
        static let macIdBanned = "macIdBanned"
        static let ipIdBanned = "ipIdBanned"
        static let banReason = "banReason"
        static let banTime = "banTime"
    }

    // MARK: - User Core Identity Properties
    
    @Published var userId: String? {
        didSet {
            // Remove manual objectWillChange.send() - @Published handles this automatically
            if let value = userId {
                defaults.set(value, forKey: Keys.userId)
            } else {
                defaults.removeObject(forKey: Keys.userId)
            }
        }
    }
    
    @Published var userName: String? {
        didSet {
            // Remove manual objectWillChange.send() - @Published handles this automatically
            if let value = userName {
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
    
    var firstAccountCreatedTime: TimeInterval {
        get { defaults.double(forKey: Keys.firstAccountCreatedTime) }
        set { defaults.set(newValue, forKey: Keys.firstAccountCreatedTime) }
    }
    
    // MARK: - User Status Properties
    
    var userOnline: Bool {
        get { defaults.bool(forKey: Keys.userOnline) }
        set { defaults.set(newValue, forKey: Keys.userOnline) }
    }
    
    var isUserBanned: Bool {
        get { defaults.bool(forKey: Keys.isUserBanned) }
        set { defaults.set(newValue, forKey: Keys.isUserBanned) }
    }
    
    var welcomeTimer: TimeInterval {
        get { defaults.double(forKey: Keys.welcomeTimer) }
        set { defaults.set(newValue, forKey: Keys.welcomeTimer) }
    }
    
    // MARK: - User Location Data
    
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
    
    // MARK: - Filter Preferences
    
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
    
    var onlineUsersRefreshTime: TimeInterval {
        get { defaults.double(forKey: Keys.onlineUsersRefreshTime) }
        set { defaults.set(newValue, forKey: Keys.onlineUsersRefreshTime) }
    }
    
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
    
    // MARK: - User Interests
    
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
    
    var interestTime: TimeInterval {
        get { defaults.double(forKey: Keys.interestTime) }
        set { defaults.set(newValue, forKey: Keys.interestTime) }
    }
    
    // MARK: - Ban Status
    
    var deviceIdBanned: Bool {
        get { defaults.bool(forKey: Keys.deviceIdBanned) }
        set { defaults.set(newValue, forKey: Keys.deviceIdBanned) }
    }
    
    var macIdBanned: Bool {
        get { defaults.bool(forKey: Keys.macIdBanned) }
        set { defaults.set(newValue, forKey: Keys.macIdBanned) }
    }
    
    var ipIdBanned: Bool {
        get { defaults.bool(forKey: Keys.ipIdBanned) }
        set { defaults.set(newValue, forKey: Keys.ipIdBanned) }
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
    
    var banTime: TimeInterval {
        get { defaults.double(forKey: Keys.banTime) }
        set { defaults.set(newValue, forKey: Keys.banTime) }
    }
    
    // MARK: - User Session Management Methods
    
    /// Check if user is logged in
    func isLoggedIn() -> Bool {
        // Simplified logic with guard statement for better clarity
        guard let id = userId, !id.isEmpty else {
            return false
        }
        return true
    }
    
    /// Check if user is anonymous (no account created)
    func isAnonymousUser() -> Bool {
        return !isAccountCreated || userId?.isEmpty == true
    }
    
    /// Clear user session data (logout)
    func logout() {
        AppLogger.log(tag: "LOG-APP: UserSessionManager", message: "logout() - Clearing user session data")
        
        // Clear user identity
        userId = nil
        userName = nil
        userAge = nil
        userGender = nil
        userCountry = nil
        userLanguage = nil
        userProfilePhoto = nil
        emailAddress = nil
        
        // Clear user status
        userOnline = false
        isUserBanned = false
        isAccountCreated = false
        
        // Clear preferences
        interestTags = []
        interestSentence = nil
        
        // Don't clear device-specific data (deviceId, etc.)
        
        synchronize()
    }
    
    /// Check if online users need refresh (30+ minutes)
    func shouldRefreshOnlineUsersFromFirebase() -> Bool {
        let lastRefresh = onlineUsersRefreshTime
        let thirtyMinutesAgo = Date().timeIntervalSince1970 - (30 * 60)
        return lastRefresh < thirtyMinutesAgo
    }
    
    /// Set online users refresh time
    func setOnlineUsersRefreshTime() {
        onlineUsersRefreshTime = Date().timeIntervalSince1970
        synchronize()
    }
    
    /// Android parity: Clears all filter data and returns success status
    func clearAllFilters() -> Bool {
        let filterKeys = [
            Keys.filterMinAge, Keys.filterMaxAge, Keys.filterGender,
            Keys.filterCountry, Keys.filterLanguage, Keys.filterNearbyOnly
            // NOTE: Keys.onlineUsersRefreshTime is NOT cleared here - it should persist
            // independently of filter changes to prevent unnecessary data reloading
        ]
        
        for key in filterKeys {
            defaults.removeObject(forKey: key)
        }
        synchronize()
        return true // Always returns true as clearing UserDefaults keys cannot fail
    }
    
    /// Synchronize UserDefaults
    func synchronize() {
        defaults.synchronize()
    }
    
    // MARK: - Clear Methods for Compatibility
    
    /// Clear user session - compatibility method that calls logout()
    func clearUserSession() {
        AppLogger.log(tag: "LOG-APP: UserSessionManager", message: "clearUserSession() called - delegating to logout()")
        logout()
    }
} 
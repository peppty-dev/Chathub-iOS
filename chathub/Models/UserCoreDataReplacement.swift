import Foundation

/// UserCoreDataReplacement struct to replace UserCoreData entity
/// Provides user profile data from SessionManager UserDefaults storage
/// Ensures 100% Android parity with SessionManager keys
struct UserCoreDataReplacement {
    let userId: String?
    let username: String?
    let age: String?
    let gender: String?
    let country: String?
    let language: String?
    let image: String?
    let deviceId: String?
    let deviceToken: String?
    
    /// Initialize UserCoreDataReplacement from SessionManager data
    init() {
        let sessionManager = SessionManager.shared
        self.userId = sessionManager.userId
        self.username = sessionManager.userName
        self.age = sessionManager.userAge
        self.gender = sessionManager.userGender
        self.country = sessionManager.userCountry
        self.language = sessionManager.userLanguage
        self.image = sessionManager.userProfilePhoto
        self.deviceId = sessionManager.deviceId
        self.deviceToken = sessionManager.deviceToken
    }
    
    /// Initialize UserCoreDataReplacement with specific values
    init(userId: String?, username: String?, age: String?, gender: String?, country: String?, language: String?, image: String?, deviceId: String?, deviceToken: String?) {
        self.userId = userId
        self.username = username
        self.age = age
        self.gender = gender
        self.country = country
        self.language = language
        self.image = image
        self.deviceId = deviceId
        self.deviceToken = deviceToken
    }
    
    /// Save current profile data to SessionManager
    func save() {
        let sessionManager = SessionManager.shared
        sessionManager.userId = self.userId
        sessionManager.userName = self.username
        sessionManager.userAge = self.age
        sessionManager.userGender = self.gender
        sessionManager.userCountry = self.country
        sessionManager.userLanguage = self.language
        sessionManager.userProfilePhoto = self.image
        sessionManager.deviceId = self.deviceId
        sessionManager.deviceToken = self.deviceToken
        
        AppLogger.log(tag: "LOG-APP: UserCoreDataReplacement", message: "save() Profile data saved to SessionManager")
    }
    
    /// Check if profile has essential data
    var isValid: Bool {
        return userId != nil && !(userId?.isEmpty ?? true) && 
               username != nil && !(username?.isEmpty ?? true)
    }
    
    /// Get current user profile from SessionManager
    static func current() -> UserCoreDataReplacement {
        return UserCoreDataReplacement()
    }
    
    /// Clear user profile data from SessionManager
    static func clear() {
        let sessionManager = SessionManager.shared
        sessionManager.userId = nil
        sessionManager.userName = nil
        sessionManager.userAge = nil
        sessionManager.userGender = nil
        sessionManager.userCountry = nil
        sessionManager.userLanguage = nil
        sessionManager.userProfilePhoto = nil
        sessionManager.deviceId = nil
        sessionManager.deviceToken = nil
        
        AppLogger.log(tag: "LOG-APP: UserCoreDataReplacement", message: "clear() Profile data cleared from SessionManager")
    }
}

// MARK: - UserCoreDataReplacement Extensions for Compatibility

extension UserCoreDataReplacement {
    /// Compatibility properties to match CoreData UserCoreData entity exactly
    var user_id: String? { return userId }
    var user_name: String? { return username }
    var user_age: String? { return age }
    var user_gender: String? { return gender }
    var user_country: String? { return country }
    var user_language: String? { return language }
    var user_image: String? { return image }
    var devid: String? { return deviceId }
    var device_token: String? { return deviceToken }
    
    /// Additional compatibility properties for AIMessageService
    var name: String? { return username }
    var interests: String? { 
        // Return user interests from SessionManager if available
        // For now, return empty string as interests are not stored in current schema
        return ""
    }
    var profilePictureURL: String? { return image }
} 
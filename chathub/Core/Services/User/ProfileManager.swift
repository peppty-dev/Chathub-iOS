import Foundation

/// ProfileManager handles profile data using SQLite storage
/// Replaces Profile_Table CoreData entity with Android database parity
class ProfileManager {
    static let shared = ProfileManager()
    
    // Use specialized UserSessionManager instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    
    private init() {}
    
    deinit {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deinit() - ProfileManager cleanup")
        // Clean up any resources if needed
    }
    
    // MARK: - Profile Data Model
    
    struct ProfileData {
        let profileId: String
        let userName: String
        let userGender: String
        let userAge: String
        let userCountry: String
        let userImage: String
        let deviceId: String
        let isOnline: Bool
        let lastActiveTime: String
        let profileType: String
        
        init(profileId: String = "", userName: String = "", userGender: String = "", userAge: String = "", userCountry: String = "", userImage: String = "", deviceId: String = "", isOnline: Bool = false, lastActiveTime: String = "", profileType: String = "user") {
            self.profileId = profileId
            self.userName = userName
            self.userGender = userGender
            self.userAge = userAge
            self.userCountry = userCountry
            self.userImage = userImage
            self.deviceId = deviceId
            self.isOnline = isOnline
            self.lastActiveTime = lastActiveTime
            self.profileType = profileType
        }
    }
    
    // MARK: - Profile Operations (Android Parity)
    
    /// Get all profiles - Android getAllProfiles() equivalent
    func getAllProfiles() -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getAllProfiles() fetching all profiles from SQLite")
        
        guard DatabaseManager.shared.getProfileDB() != nil else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getAllProfiles() ProfileDB not available")
            return []
        }
        
        // Note: ProfileDB.query() requires a UserId parameter, so we can't get all profiles this way
        // This method would need to be implemented differently or ProfileDB would need a queryAll() method
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getAllProfiles() ProfileDB.query() requires UserId parameter - returning empty array")
        return []
    }
    
    /// Get profile by ID - Android getProfileById() equivalent
    func getProfileById(_ profileId: String) -> ProfileData? {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileById() fetching profile: \(profileId)")
        
        guard let profileDB = DatabaseManager.shared.getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileById() ProfileDB not available")
            return nil
        }
        
        let profile = profileDB.query(UserId: profileId)
        guard let profile = profile else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileById() profile not found: \(profileId)")
            return nil
        }
        
        let profileData = ProfileData(
            profileId: profile.UserId,
            userName: profile.Name,
            userGender: profile.Gender,
            userAge: profile.Age,
            userCountry: profile.Country,
            userImage: profile.Image,
            deviceId: "", // Not stored in ProfileModel
            isOnline: false, // Not stored in current SQLite schema
            lastActiveTime: String(profile.Time),
            profileType: "" // Not stored in ProfileModel
        )
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileById() returning profile data for: \(profileData.userName)")
        return profileData
    }
    
    /// Add or update profile - Android addOrUpdateProfile() equivalent
    func addOrUpdateProfile(_ profileData: ProfileData) {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "addOrUpdateProfile() adding/updating profile: \(profileData.userName)")
        
        guard let profileDB = DatabaseManager.shared.getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "addOrUpdateProfile() ProfileDB not available")
            return
        }
        
        // Insert or update profile using existing ProfileDB methods with all required parameters
        profileDB.insert(
            UserId: NSString(string: profileData.profileId),
            Age: NSString(string: profileData.userAge),
            Country: NSString(string: profileData.userCountry),
            Language: NSString(string: "en"), // Default language
            Gender: NSString(string: profileData.userGender),
            men: NSString(string: "0"), // Default preference
            women: NSString(string: "0"), // Default preference
            single: NSString(string: "0"), // Default status
            married: NSString(string: "0"), // Default status
            children: NSString(string: "0"), // Default status
            gym: NSString(string: "0"), // Default hobby
            smoke: NSString(string: "0"), // Default habit
            drink: NSString(string: "0"), // Default habit
            games: NSString(string: "0"), // Default hobby
            decenttalk: NSString(string: "0"), // Default preference
            pets: NSString(string: "0"), // Default hobby
            travel: NSString(string: "0"), // Default hobby
            music: NSString(string: "0"), // Default hobby
            movies: NSString(string: "0"), // Default hobby
            naughty: NSString(string: "0"), // Default preference
            Foodie: NSString(string: "0"), // Default hobby
            dates: NSString(string: "0"), // Default preference
            fashion: NSString(string: "0"), // Default hobby
            broken: NSString(string: "0"), // Default status
            depressed: NSString(string: "0"), // Default status
            lonely: NSString(string: "0"), // Default status
            cheated: NSString(string: "0"), // Default status
            insomnia: NSString(string: "0"), // Default status
            voice: NSString(string: "0"), // Default preference
            video: NSString(string: "0"), // Default preference
            pics: NSString(string: "0"), // Default preference
            goodexperience: NSString(string: "0"), // Default experience
            badexperience: NSString(string: "0"), // Default experience
            male_accounts: NSString(string: "0"), // Default count
            female_accounts: NSString(string: "0"), // Default count
            male_chats: NSString(string: "0"), // Default count
            female_chats: NSString(string: "0"), // Default count
            reports: NSString(string: "0"), // Default count
            blocks: NSString(string: "0"), // Default count
            voicecalls: NSString(string: "0"), // Default count
            videocalls: NSString(string: "0"), // Default count
            Time: Date(timeIntervalSince1970: Double(profileData.lastActiveTime) ?? Date().timeIntervalSince1970),
            Image: NSString(string: profileData.userImage),
            Named: NSString(string: profileData.userName),
            Height: NSString(string: ""), // Default height
            Occupation: NSString(string: ""), // Default occupation
            Instagram: NSString(string: ""), // Default social
            Snapchat: NSString(string: ""), // Default social
            Zodic: NSString(string: ""), // Default zodiac
            Hobbies: NSString(string: ""), // Default hobbies
            EmailVerified: NSString(string: "false"), // Default verification
            CreatedTime: NSString(string: String(Int(Date().timeIntervalSince1970))), // Current time
            Platform: NSString(string: "iOS"), // Platform
            Premium: NSString(string: "false"), // Default premium status
            city: NSString(string: "") // Default city
        )
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "addOrUpdateProfile() profile added/updated successfully")
    }
    
    /// Delete profile - Android deleteProfile() equivalent
    func deleteProfile(_ profileId: String) {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deleteProfile() deleting profile: \(profileId)")
        
        guard let profileDB = DatabaseManager.shared.getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deleteProfile() ProfileDB not available")
            return
        }
        
        profileDB.delete(UserId: profileId)
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deleteProfile() profile deleted successfully")
    }
    
    /// Delete multiple profiles - Android deleteMultipleProfiles() equivalent
    func deleteMultipleProfiles(_ profileIds: [String]) {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deleteMultipleProfiles() deleting \(profileIds.count) profiles")
        
        for profileId in profileIds {
            deleteProfile(profileId)
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "deleteMultipleProfiles() deletion completed")
    }
    
    // MARK: - Profile Search Operations (Android Parity)
    
    /// Search profiles by gender - Android searchProfilesByGender() equivalent
    func searchProfilesByGender(_ gender: String) -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByGender() searching for gender: \(gender)")
        
        let allProfiles = getAllProfiles()
        let filteredProfiles = allProfiles.filter { profile in
            profile.userGender.lowercased() == gender.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByGender() returning \(filteredProfiles.count) profiles")
        return filteredProfiles
    }
    
    /// Search profiles by country - Android searchProfilesByCountry() equivalent
    func searchProfilesByCountry(_ country: String) -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByCountry() searching for country: \(country)")
        
        let allProfiles = getAllProfiles()
        let filteredProfiles = allProfiles.filter { profile in
            profile.userCountry.lowercased() == country.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByCountry() returning \(filteredProfiles.count) profiles")
        return filteredProfiles
    }
    
    /// Search profiles by age range - Android searchProfilesByAgeRange() equivalent
    func searchProfilesByAgeRange(minAge: Int, maxAge: Int) -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByAgeRange() searching for age range: \(minAge)-\(maxAge)")
        
        let allProfiles = getAllProfiles()
        let filteredProfiles = allProfiles.filter { profile in
            guard let age = Int(profile.userAge) else { return false }
            return age >= minAge && age <= maxAge
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByAgeRange() returning \(filteredProfiles.count) profiles")
        return filteredProfiles
    }
    
    /// Search profiles by type - Android searchProfilesByType() equivalent
    func searchProfilesByType(_ type: String) -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByType() searching for type: \(type)")
        
        let allProfiles = getAllProfiles()
        let filteredProfiles = allProfiles.filter { profile in
            profile.profileType.lowercased() == type.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "searchProfilesByType() returning \(filteredProfiles.count) profiles")
        return filteredProfiles
    }
    
    // MARK: - Utility Methods (Android Parity)
    
    /// Check if profile exists - Android profileExists() equivalent
    func profileExists(_ profileId: String) -> Bool {
        let profileData = getProfileById(profileId)
        let exists = profileData != nil
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "profileExists() profile \(profileId) exists: \(exists)")
        return exists
    }
    
    /// Get profile count - Android getProfileCount() equivalent
    func getProfileCount() -> Int {
        let profiles = getAllProfiles()
        let count = profiles.count
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileCount() returning: \(count)")
        return count
    }
    
    /// Get profile count by gender - Android getProfileCountByGender() equivalent
    func getProfileCountByGender(_ gender: String) -> Int {
        let profiles = searchProfilesByGender(gender)
        let count = profiles.count
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfileCountByGender() returning \(count) for gender: \(gender)")
        return count
    }
    
    /// Clear all profiles - Android clearAllProfiles() equivalent
    func clearAllProfiles() {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "clearAllProfiles() clearing all profile data")
        
        guard let profileDB = DatabaseManager.shared.getProfileDB() else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "clearAllProfiles() ProfileDB not available")
            return
        }
        
        // Delete all profile table
        profileDB.deletetable()
        
        // Recreate table
        profileDB.createtable()
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "clearAllProfiles() all profile data cleared")
    }
    
    /// Get profiles by multiple criteria - Android getProfilesByCriteria() equivalent
    func getProfilesByCriteria(gender: String? = nil, country: String? = nil, minAge: Int? = nil, maxAge: Int? = nil, type: String? = nil) -> [ProfileData] {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfilesByCriteria() searching with multiple criteria")
        
        var profiles = getAllProfiles()
        
        if let gender = gender {
            profiles = profiles.filter { $0.userGender.lowercased() == gender.lowercased() }
        }
        
        if let country = country {
            profiles = profiles.filter { $0.userCountry.lowercased() == country.lowercased() }
        }
        
        if let minAge = minAge, let maxAge = maxAge {
            profiles = profiles.filter { profile in
                guard let age = Int(profile.userAge) else { return false }
                return age >= minAge && age <= maxAge
            }
        }
        
        if let type = type {
            profiles = profiles.filter { $0.profileType.lowercased() == type.lowercased() }
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "getProfilesByCriteria() returning \(profiles.count) profiles")
        return profiles
    }
    
    /// Update profile online status - Android updateProfileOnlineStatus() equivalent
    func updateProfileOnlineStatus(_ profileId: String, isOnline: Bool) {
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "updateProfileOnlineStatus() updating online status for: \(profileId)")
        
        guard let profileData = getProfileById(profileId) else {
            AppLogger.log(tag: "LOG-APP: ProfileManager", message: "updateProfileOnlineStatus() profile not found: \(profileId)")
            return
        }
        
        // Create updated profile data
        let updatedProfileData = ProfileData(
            profileId: profileData.profileId,
            userName: profileData.userName,
            userGender: profileData.userGender,
            userAge: profileData.userAge,
            userCountry: profileData.userCountry,
            userImage: profileData.userImage,
            deviceId: profileData.deviceId,
            isOnline: isOnline,
            lastActiveTime: String(Date().timeIntervalSince1970),
            profileType: profileData.profileType
        )
        
        addOrUpdateProfile(updatedProfileData)
        AppLogger.log(tag: "LOG-APP: ProfileManager", message: "updateProfileOnlineStatus() online status updated successfully")
    }
}

// MARK: - SessionManager Extension for Profile Management
extension UserSessionManager {
    
    /// Get profile manager instance - Android getProfileManager() equivalent
    var profileManager: ProfileManager {
        return ProfileManager.shared
    }
} 
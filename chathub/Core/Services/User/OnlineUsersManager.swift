import Foundation

/// OnlineUsersManager handles online user data using SQLite storage
/// Replaces OnlineUsers CoreData entity with Android database parity
class OnlineUsersManager {
    static let shared = OnlineUsersManager()
    
    // Use specialized UserSessionManager instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    
    private init() {}
    
    // MARK: - Online User Data Model
    
    struct OnlineUserData {
        let userId: String
        let userName: String
        let userGender: String
        let userAge: String
        let userCountry: String
        let userImage: String
        let deviceId: String
        let lastActiveTime: String
        let isOnline: Bool
        let userType: String
        
        init(userId: String = "", userName: String = "", userGender: String = "", userAge: String = "", userCountry: String = "", userImage: String = "", deviceId: String = "", lastActiveTime: String = "", isOnline: Bool = true, userType: String = "user") {
            self.userId = userId
            self.userName = userName
            self.userGender = userGender
            self.userAge = userAge
            self.userCountry = userCountry
            self.userImage = userImage
            self.deviceId = deviceId
            self.lastActiveTime = lastActiveTime
            self.isOnline = isOnline
            self.userType = userType
        }
    }
    
    // MARK: - Online User Operations (Android Parity)
    
    /// Get all online users - Android getAllOnlineUsers() equivalent
    func getAllOnlineUsers() -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getAllOnlineUsers() fetching all online users from SQLite")
        
        guard let onlineUsersDB = DatabaseManager.shared.getOnlineUsersDB() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getAllOnlineUsers() OnlineUsersDB not available")
            return []
        }
        
        let sqliteUsers = onlineUsersDB.query()
        let userDataArray = sqliteUsers.map { user in
            OnlineUserData(
                userId: user.user_id,
                userName: user.user_name,
                userGender: user.user_gender,
                userAge: "", // Not stored in current SQLite schema
                userCountry: user.user_country,
                userImage: user.user_image,
                deviceId: user.user_device_id,
                lastActiveTime: String(user.user_last_time_seen),
                isOnline: true, // Assume online since they're in the online users table
                userType: "user" // Default type
            )
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getAllOnlineUsers() returning \(userDataArray.count) online users")
        return userDataArray
    }
    
    /// Get online user by ID - Android getOnlineUserById() equivalent
    func getOnlineUserById(_ userId: String) -> OnlineUserData? {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserById() fetching user: \(userId)")
        
        guard let onlineUsersDB = DatabaseManager.shared.getOnlineUsersDB() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserById() OnlineUsersDB not available")
            return nil
        }
        
        let sqliteUsers = onlineUsersDB.query()
        guard let user = sqliteUsers.first(where: { $0.user_id == userId }) else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserById() user not found: \(userId)")
            return nil
        }
        
        let userData = OnlineUserData(
            userId: user.user_id,
            userName: user.user_name,
            userGender: user.user_gender,
            userAge: "", // Not stored in current SQLite schema
            userCountry: user.user_country,
            userImage: user.user_image,
            deviceId: user.user_device_id,
            lastActiveTime: String(user.user_last_time_seen),
            isOnline: true,
            userType: "user" // Default type
        )
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserById() returning user data for: \(userData.userName)")
        return userData
    }
    
    /// Add or update online user - Android addOrUpdateOnlineUser() equivalent
    func addOrUpdateOnlineUser(_ userData: OnlineUserData) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "addOrUpdateOnlineUser() adding/updating user: \(userData.userName)")
        
        guard let onlineUsersDB = DatabaseManager.shared.getOnlineUsersDB() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "addOrUpdateOnlineUser() OnlineUsersDB not available")
            return
        }
        
        // Create OnlineUser object for insertion
        let onlineUser = OnlineUser(
            id: userData.userId,
            name: userData.userName,
            age: userData.userAge,
            country: userData.userCountry,
            gender: userData.userGender,
            isOnline: userData.isOnline,
            language: "", // Not available in OnlineUserData
            lastTimeSeen: Date(timeIntervalSince1970: Double(userData.lastActiveTime) ?? Date().timeIntervalSince1970),
            deviceId: userData.deviceId,
            profileImage: userData.userImage
        )
        
        onlineUsersDB.insertUser(onlineUser)
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "addOrUpdateOnlineUser() user added/updated successfully")
    }
    
    /// Remove online user - Android removeOnlineUser() equivalent
    func removeOnlineUser(_ userId: String) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "removeOnlineUser() removing user: \(userId)")
        
        guard let onlineUsersDB = DatabaseManager.shared.getOnlineUsersDB() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "removeOnlineUser() OnlineUsersDB not available")
            return
        }
        
        onlineUsersDB.deleteUser(userId)
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "removeOnlineUser() user removed successfully")
    }
    
    /// Remove multiple online users - Android removeMultipleOnlineUsers() equivalent
    func removeMultipleOnlineUsers(_ userIds: [String]) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "removeMultipleOnlineUsers() removing \(userIds.count) users")
        
        for userId in userIds {
            removeOnlineUser(userId)
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "removeMultipleOnlineUsers() removal completed")
    }
    
    // MARK: - Online User Search Operations (Android Parity)
    
    /// Search online users by gender - Android searchOnlineUsersByGender() equivalent
    func searchOnlineUsersByGender(_ gender: String) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByGender() searching for gender: \(gender)")
        
        let allUsers = getAllOnlineUsers()
        let filteredUsers = allUsers.filter { user in
            user.userGender.lowercased() == gender.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByGender() returning \(filteredUsers.count) users")
        return filteredUsers
    }
    
    /// Search online users by country - Android searchOnlineUsersByCountry() equivalent
    func searchOnlineUsersByCountry(_ country: String) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByCountry() searching for country: \(country)")
        
        let allUsers = getAllOnlineUsers()
        let filteredUsers = allUsers.filter { user in
            user.userCountry.lowercased() == country.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByCountry() returning \(filteredUsers.count) users")
        return filteredUsers
    }
    
    /// Search online users by age range - Android searchOnlineUsersByAgeRange() equivalent
    func searchOnlineUsersByAgeRange(minAge: Int, maxAge: Int) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByAgeRange() searching for age range: \(minAge)-\(maxAge)")
        
        let allUsers = getAllOnlineUsers()
        let filteredUsers = allUsers.filter { user in
            guard let age = Int(user.userAge) else { return false }
            return age >= minAge && age <= maxAge
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByAgeRange() returning \(filteredUsers.count) users")
        return filteredUsers
    }
    
    /// Search online users by type - Android searchOnlineUsersByType() equivalent
    func searchOnlineUsersByType(_ type: String) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByType() searching for type: \(type)")
        
        let allUsers = getAllOnlineUsers()
        let filteredUsers = allUsers.filter { user in
            user.userType.lowercased() == type.lowercased()
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "searchOnlineUsersByType() returning \(filteredUsers.count) users")
        return filteredUsers
    }
    
    // MARK: - Utility Methods (Android Parity)
    
    /// Check if user is online - Android isUserOnline() equivalent
    func isUserOnline(_ userId: String) -> Bool {
        let userData = getOnlineUserById(userId)
        let isOnline = userData != nil
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "isUserOnline() user \(userId) online: \(isOnline)")
        return isOnline
    }
    
    /// Get online user count - Android getOnlineUserCount() equivalent
    func getOnlineUserCount() -> Int {
        let users = getAllOnlineUsers()
        let count = users.count
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserCount() returning: \(count)")
        return count
    }
    
    /// Get online user count by gender - Android getOnlineUserCountByGender() equivalent
    func getOnlineUserCountByGender(_ gender: String) -> Int {
        let users = searchOnlineUsersByGender(gender)
        let count = users.count
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUserCountByGender() returning \(count) for gender: \(gender)")
        return count
    }
    
    /// Clear all online users - Android clearAllOnlineUsers() equivalent
    func clearAllOnlineUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "clearAllOnlineUsers() clearing all online user data")
        
        guard let onlineUsersDB = DatabaseManager.shared.getOnlineUsersDB() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "clearAllOnlineUsers() OnlineUsersDB not available")
            return
        }
        
        onlineUsersDB.clearAllUsers()
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "clearAllOnlineUsers() all online user data cleared")
    }
    
    /// Get online users by multiple criteria - Android getOnlineUsersByCriteria() equivalent
    func getOnlineUsersByCriteria(gender: String? = nil, country: String? = nil, minAge: Int? = nil, maxAge: Int? = nil, type: String? = nil) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUsersByCriteria() searching with multiple criteria")
        
        var users = getAllOnlineUsers()
        
        if let gender = gender {
            users = users.filter { $0.userGender.lowercased() == gender.lowercased() }
        }
        
        if let country = country {
            users = users.filter { $0.userCountry.lowercased() == country.lowercased() }
        }
        
        if let minAge = minAge, let maxAge = maxAge {
            users = users.filter { user in
                guard let age = Int(user.userAge) else { return false }
                return age >= minAge && age <= maxAge
            }
        }
        
        if let type = type {
            users = users.filter { $0.userType.lowercased() == type.lowercased() }
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getOnlineUsersByCriteria() returning \(users.count) users")
        return users
    }
    
    /// Update user last active time - Android updateUserLastActiveTime() equivalent
    func updateUserLastActiveTime(_ userId: String) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "updateUserLastActiveTime() updating last active time for: \(userId)")
        
        guard let userData = getOnlineUserById(userId) else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "updateUserLastActiveTime() user not found: \(userId)")
            return
        }
        
        // Create updated user data
        let updatedUserData = OnlineUserData(
            userId: userData.userId,
            userName: userData.userName,
            userGender: userData.userGender,
            userAge: userData.userAge,
            userCountry: userData.userCountry,
            userImage: userData.userImage,
            deviceId: userData.deviceId,
            lastActiveTime: String(Date().timeIntervalSince1970),
            isOnline: userData.isOnline,
            userType: userData.userType
        )
        
        addOrUpdateOnlineUser(updatedUserData)
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "updateUserLastActiveTime() last active time updated successfully")
    }
    
    /// Get recently active users - Android getRecentlyActiveUsers() equivalent
    func getRecentlyActiveUsers(withinMinutes: Int = 5) -> [OnlineUserData] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getRecentlyActiveUsers() fetching users active within \(withinMinutes) minutes")
        
        let allUsers = getAllOnlineUsers()
        let cutoffTime = Date().timeIntervalSince1970 - TimeInterval(withinMinutes * 60)
        
        let recentUsers = allUsers.filter { user in
            guard let lastActiveTime = Double(user.lastActiveTime) else { return false }
            return lastActiveTime >= cutoffTime
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersManager", message: "getRecentlyActiveUsers() returning \(recentUsers.count) recently active users")
        return recentUsers
    }
}

// MARK: - SessionManager Extension for Online Users Management
extension UserSessionManager {
    
    /// Get online users manager instance - Android getOnlineUsersManager() equivalent
    var onlineUsersManager: OnlineUsersManager {
        return OnlineUsersManager.shared
    }
} 
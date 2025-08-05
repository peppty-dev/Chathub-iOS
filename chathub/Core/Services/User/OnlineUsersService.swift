import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// OnlineUsersService - iOS equivalent of Android OnlineUsersWorker
/// Provides online users fetching functionality with 100% Android parity
class OnlineUsersService {
    
    // MARK: - Singleton
    static let shared = OnlineUsersService()
    private init() {}
    
    deinit {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "deinit() - OnlineUsersService cleanup")
        // Clean up database query if needed
        databaseQuery = nil
    }
    
    // MARK: - Properties (Android Parity)
    private let userSessionManager = UserSessionManager.shared
    // TODO: Remove when authentication methods are moved to proper service
    private let sessionManager = SessionManager.shared
    private let database = Firestore.firestore()
    private var databaseQuery: Query?
    
    // MARK: - Public Methods (Android Parity)
    
    /// Fetches online users - Android doWork() equivalent
    /// - Parameters:
    ///   - lastOnlineUserTime: Last timestamp for pagination
    ///   - completion: Completion handler with success status
    func fetchOnlineUsers(
        lastOnlineUserTime: String? = nil,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "fetchOnlineUsers() lastOnlineUserTime: \(lastOnlineUserTime ?? "nil")")
        
        // Clear existing entries before fetching new ones - Android parity
        clearExistingOnlineUsers()
        
        // Build query based on filters - Android parity
        if userSessionManager.filterNearbyOnly {
            AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "fetchOnlineUsers() nearby selected, user city: \(userSessionManager.userRetrievedCity ?? "unknown")")
            
            databaseQuery = buildQuery(
                gender: userSessionManager.filterGender,
                country: userSessionManager.filterCountry,
                language: userSessionManager.userLanguage,
                city: userSessionManager.userRetrievedCity ?? ""
            ).limit(to: 10)
            
            guard let query = databaseQuery else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "CRITICAL: databaseQuery is nil for nearby users, unable to fetch")
                completion(false)
                return
            }
            getAllUsers(query: query, lastOnlineUserTime: lastOnlineUserTime, completion: completion)
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "fetchOnlineUsers() nearby not selected")
            
            databaseQuery = buildQuery(
                gender: userSessionManager.filterGender,
                country: userSessionManager.filterCountry,
                language: userSessionManager.userLanguage,
                city: ""
            ).limit(to: 10)
            
            guard let query = databaseQuery else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "CRITICAL: databaseQuery is nil for global users, unable to fetch")
                completion(false)
                return
            }
            getAllUsers(query: query, lastOnlineUserTime: lastOnlineUserTime, completion: completion)
        }
    }
    
    /// Refreshes online users list
    func refreshOnlineUsers(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "refreshOnlineUsers() forcing refresh")
        fetchOnlineUsers(lastOnlineUserTime: nil, completion: completion)
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Builds Firebase query for users - Android FirebaseDabaseRefrence.GetUserQueryRef() equivalent
    private func buildQuery(
        gender: String?,
        country: String?,
        language: String?,
        city: String?
    ) -> Query {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "buildQuery() building Firestore query with filters")
        
        let collection = Firestore.firestore().collection("Users")
        var query: Query = collection
        
        // Apply gender filter - Android parity
        if let gender = gender, !gender.isEmpty {
            query = query.whereField("User_gender", isEqualTo: gender)
        }
        
        // Apply country filter - Android parity
        if let country = country, !country.isEmpty {
            query = query.whereField("User_country", isEqualTo: country)
        }
        
        // Apply language filter - Android parity
        if let language = language, !language.isEmpty {
            query = query.whereField("User_language", isEqualTo: language)
        }
        
        // Apply city filter - Android parity
        if let city = city, !city.isEmpty {
            query = query.whereField("User_city", isEqualTo: city)
        }
        
        // Order by last seen time - Android parity
        query = query.order(by: "last_time_seen", descending: true)
        
        return query
    }
    
    /// Fetches all users with query - Android getAllUsers() equivalent
    private func getAllUsers(query: Query, lastOnlineUserTime: String?, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "getAllUsers() query: \(query), lastOnlineUserTime: \(lastOnlineUserTime ?? "nil")")
        
        // Parse and validate timestamp - Android parity
        var finalQuery = query
        do {
            if let lastTime = lastOnlineUserTime,
               !lastTime.isEmpty && lastTime != "null" && lastTime != "0" && !lastTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "getAllUsers() lastTime exists")
                let millisecond = Int64(lastTime)! * 1000
                let timestamp = Timestamp(seconds: millisecond / 1000, nanoseconds: 0)
                finalQuery = query.whereField("last_time_seen", isGreaterThan: timestamp)
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "getAllUsers() lastTime does not exist, using 24 hours ago")
                // Use current time minus 24 hours to get recent online users - Android parity
                let currentTime = Date().timeIntervalSince1970
                let oneDayAgo = currentTime - (24 * 60 * 60) // 24 hours in seconds
                let timestamp = Timestamp(seconds: Int64(oneDayAgo), nanoseconds: 0)
                finalQuery = query.whereField("last_time_seen", isGreaterThan: timestamp)
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "getAllUsers() error parsing lastTime: \(error.localizedDescription)")
            // Use current time minus 24 hours as fallback - Android parity
            let currentTime = Date().timeIntervalSince1970
            let oneDayAgo = currentTime - (24 * 60 * 60)
            let timestamp = Timestamp(seconds: Int64(oneDayAgo), nanoseconds: 0)
            finalQuery = query.whereField("last_time_seen", isGreaterThan: timestamp)
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "getAllUsers() executing query")
        executeQueryWithRetry(query: finalQuery, retryCount: 0, completion: completion)
    }
    
    /// Executes query with retry logic - Android parity
    private func executeQueryWithRetry(query: Query, retryCount: Int, completion: @escaping (Bool) -> Void) {
        let maxRetries = 3
        let retryDelayMs: TimeInterval = 1.0 // 1 second
        
        query.getDocuments { [weak self] querySnapshot, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                if let firestoreError = error as? FirestoreErrorCode,
                   firestoreError.code == .permissionDenied {
                    
                    if retryCount < maxRetries {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "executeQueryWithRetry() permission denied, retry attempt \(retryCount + 1)")
                        
                        // Refresh auth token if needed - Android parity
                        self.sessionManager.refreshAuthTokenIfNeeded()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelayMs) {
                            self.executeQueryWithRetry(query: query, retryCount: retryCount + 1, completion: completion)
                        }
                    } else {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "executeQueryWithRetry() max retries exceeded for permission denied error")
                        completion(false)
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "executeQueryWithRetry() query failed with error: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "executeQueryWithRetry() query successful")
                self.processQueryResults(querySnapshot: querySnapshot, completion: completion)
            }
        }
    }
    
    /// Processes query results - Android processQueryResults() equivalent
    private func processQueryResults(querySnapshot: QuerySnapshot?, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "processQueryResults() processing results")
        
        guard let querySnapshot = querySnapshot else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "processQueryResults() no query snapshot")
            completion(false)
            return
        }
        
        var processedCount = 0
        
        for document in querySnapshot.documents {
            let data = document.data()
            
            // Skip if username is null - Android parity
            guard let userName = data["User_name"] as? String, !userName.isEmpty else {
                continue
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "processQueryResults() online user: \(userName)")
            
            // Age filtering - Android parity
            if let userAgeString = data["User_age"] as? String,
               let userAge = Int(userAgeString) {
                
                if let minAgeString = userSessionManager.filterMinAge,
                   let minAge = Int(minAgeString),
                   minAge > 0 && minAge > userAge {
                    continue
                }
                
                if let maxAgeString = userSessionManager.filterMaxAge,
                   let maxAge = Int(maxAgeString),
                   maxAge > 0 && maxAge < userAge {
                    continue
                }
            }
            
            // Skip if no User_id or if it's current user - Android parity
            guard let userId = data["User_id"] as? String,
                  !userId.isEmpty,
                  userId != userSessionManager.userId else {
                continue
            }
            
            // Get decent time with error handling - Android parity
            let userDecentTime: Int64 = {
                if let decentTime = data["IamDecentTime"] as? Int64 {
                    return decentTime
                } else {
                    return 0
                }
            }()
            
            // Get last seen time with validation - Android parity
            let userLastTimeSeen: Int64 = {
                if let timestamp = data["last_time_seen"] as? Timestamp {
                    let timestampSeconds = timestamp.seconds
                    let serverCurrentTime = Int64(Date().timeIntervalSince1970)
                    let timeBuffer: Int64 = 5 * 60 // 5 minutes buffer
                    
                    // Validate timestamp is within reasonable bounds - Android parity
                    if timestampSeconds > (serverCurrentTime + timeBuffer) {
                        // If user has manipulated time to future, penalize by setting to 30 days ago
                        return serverCurrentTime - 30 * 24 * 60 * 60
                    } else if timestampSeconds < (serverCurrentTime - 30 * 24 * 60 * 60) {
                        // If older than 30 days, set to 30 days ago
                        return serverCurrentTime - 30 * 24 * 60 * 60
                    } else {
                        return timestampSeconds
                    }
                } else {
                    // Default to 30 days ago if no timestamp
                    return Int64(Date().timeIntervalSince1970) - 30 * 24 * 60 * 60
                }
            }()
            
            // Insert or update user in local database - Android parity
            insertOrUpdateUser(
                userId: userId,
                userName: userName,
                userImage: data["User_image"] as? String ?? "",
                userGender: data["User_gender"] as? String ?? "",
                userCountry: data["User_country"] as? String ?? "",
                userDeviceId: data["User_device_id"] as? String ?? "",
                userDeviceToken: data["User_device_token"] as? String ?? "",
                userArea: data["User_area"] as? String ?? "",
                userCity: data["User_city"] as? String ?? "",
                userState: data["User_state"] as? String ?? "",
                userDecentTime: userDecentTime,
                userLastTimeSeen: userLastTimeSeen
            )
            
            processedCount += 1
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "processQueryResults() processed \(processedCount) users")
        completion(processedCount > 0)
    }
    
    /// Inserts or updates user in local database - Android insertOrUpdateUser() equivalent
    private func insertOrUpdateUser(
        userId: String,
        userName: String,
        userImage: String,
        userGender: String,
        userCountry: String,
        userDeviceId: String,
        userDeviceToken: String,
        userArea: String,
        userCity: String,
        userState: String,
        userDecentTime: Int64,
        userLastTimeSeen: Int64
    ) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "insertOrUpdateUser() userId: \(userId), userName: \(userName)")
        
        // Use OnlineUsersManager instead of CoreData
        let onlineUsersManager = OnlineUsersManager.shared
        
        let userData = OnlineUsersManager.OnlineUserData(
            userId: userId,
            userName: userName,
            userGender: userGender,
            userAge: "", // Not available from Firebase data
            userCountry: userCountry,
            userImage: userImage,
            deviceId: userDeviceId,
            lastActiveTime: String(userLastTimeSeen),
            isOnline: true,
            userType: "user"
        )
        
        onlineUsersManager.addOrUpdateOnlineUser(userData)
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "insertOrUpdateUser() user data saved successfully for: \(userId)")
    }
    
    /// Clears existing online users - Android parity
    private func clearExistingOnlineUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "clearExistingOnlineUsers() clearing existing entries")
        
        // Use AsyncClass to clear online users database (same as before)
        DatabaseCleanupService.shared.deleteOnlineUsersOnly()
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersService", message: "clearExistingOnlineUsers() cleared existing users using AsyncClass")
    }
}

// MARK: - SessionManager Extension for Online Users Filters (Android Parity)
extension SessionManager {
    
    /// Gets nearby filters setting - Android getUserNearByFilters() equivalent
    func getUserNearByFilters() -> Bool {
        return UserDefaults.standard.bool(forKey: "userNearByFilters")
    }
    
    /// Sets nearby filters setting - Android setUserNearByFilters() equivalent
    func setUserNearByFilters(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "userNearByFilters")
        synchronize()
    }
    
    /// Gets filter gender - Android getFilterGender() equivalent
    func getFilterGender() -> String {
        return UserDefaults.standard.string(forKey: "filterGender") ?? "both"
    }
    
    /// Sets filter gender - Android setFilterGender() equivalent
    func setFilterGender(_ gender: String) {
        UserDefaults.standard.set(gender, forKey: "filterGender")
        synchronize()
    }
    
    /// Gets filter country - Android getFilterCountry() equivalent
    func getFilterCountry() -> String {
        return UserDefaults.standard.string(forKey: "filterCountry") ?? ""
    }
    
    /// Sets filter country - Android setFilterCountry() equivalent
    func setFilterCountry(_ country: String) {
        UserDefaults.standard.set(country, forKey: "filterCountry")
        synchronize()
    }
    
    /// Gets start age filter - Android getStartAgeFilter() equivalent
    func getStartAgeFilter() -> Int {
        return UserDefaults.standard.integer(forKey: "startAgeFilter")
    }
    
    /// Sets start age filter - Android setStartAgeFilter() equivalent
    func setStartAgeFilter(_ age: Int) {
        UserDefaults.standard.set(age, forKey: "startAgeFilter")
        synchronize()
    }
    
    /// Gets end age filter - Android getEndAgeFilter() equivalent
    func getEndAgeFilter() -> Int {
        return UserDefaults.standard.integer(forKey: "endAgeFilter")
    }
    
    /// Sets end age filter - Android setEndAgeFilter() equivalent
    func setEndAgeFilter(_ age: Int) {
        UserDefaults.standard.set(age, forKey: "endAgeFilter")
        synchronize()
    }
    
    /// Refreshes auth token if needed - Android refreshAuthTokenIfNeeded() equivalent
    func refreshAuthTokenIfNeeded() {
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "refreshAuthTokenIfNeeded() refreshing authentication token")
        
        // Force token refresh
        Auth.auth().currentUser?.getIDTokenForcingRefresh(true) { token, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SessionManager", message: "refreshAuthTokenIfNeeded() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: SessionManager", message: "refreshAuthTokenIfNeeded() token refreshed successfully")
            }
        }
    }
} 
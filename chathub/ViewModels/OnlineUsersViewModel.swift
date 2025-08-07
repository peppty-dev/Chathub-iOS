import Foundation
import Combine
import FirebaseFirestore

struct OnlineUser: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var age: String
    var country: String
    var gender: String
    var isOnline: Bool
    var language: String
    var lastTimeSeen: Date
    var deviceId: String
    var profileImage: String
}

struct OnlineUserFilter: Codable {
    var male: Bool = false
    var female: Bool = false
    var country: String = ""
    var language: String = ""
    var minAge: String = ""
    var maxAge: String = ""
    var nearby: String = ""
    
    // Custom initializer for direct filter application
    init(male: Bool = false, female: Bool = false, country: String = "", language: String = "", minAge: String = "", maxAge: String = "", nearby: String = "") {
        self.male = male
        self.female = female
        self.country = country
        self.language = language
        self.minAge = minAge
        self.maxAge = maxAge
        self.nearby = nearby
    }
}

class OnlineUsersViewModel: ObservableObject {
    @Published var users: [OnlineUser] = []
    @Published var filter: OnlineUserFilter = OnlineUserFilter()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasMore: Bool = true

    private let filterKey = "OnlineUserFilterKey"
    private var cancellables = Set<AnyCancellable>()
    private let onlineUsersDB = OnlineUsersDB.shared
    private let pageSize = 10
    private var currentPage = 0

    // Use specialized session managers and service layer instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let appSettingsSessionManager = AppSettingsSessionManager.shared
    private let userFilterService = UserFilterService.shared

    init() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "init() - Initializing OnlineUsersViewModel")
        loadFilter()
        
        // CRITICAL FIX: Clean up any corrupted data on startup
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "init() - Cleaning up corrupted data")
        onlineUsersDB.clearCorruptedData()
        
        // ANDROID PARITY FIX: Don't load data automatically in init() - this prevents unnecessary loading animations
        // Data will be loaded when fetchUsers() is called from onAppear
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "init() - Initialization complete, data will be loaded on demand")
    }

    /// Load users from local SQLite database (matching Android pattern)
    func loadUsersFromLocalDatabase() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Starting local database load")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Current filter: male=\(filter.male), female=\(filter.female), country='\(filter.country)', language='\(filter.language)'")
        
        // CRITICAL FIX: Local database queries should be INSTANT with no loading state or background threading
        // This prevents the flicker sequence: no data → loading → data
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Loading from local database INSTANTLY on main thread")
        
        // Get users from local database (similar to Android Room query) - SYNCHRONOUSLY
        let localUsers = self.onlineUsersDB.query()
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Retrieved \(localUsers.count) users from database")
        
        // Apply filters
        let filteredUsers = self.applyLocalFilters(to: localUsers)
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - After filtering: \(filteredUsers.count) users")
        
        // Convert to OnlineUser objects
        let allOnlineUsers = filteredUsers.compactMap { user -> OnlineUser? in
            // Skip empty or invalid users
            guard !user.user_name.isEmpty && !user.user_id.isEmpty else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Skipping user with empty name or ID: name='\(user.user_name)', id='\(user.user_id)'")
                return nil
            }
            
            return OnlineUser(
                id: user.user_id,
                name: user.user_name,
                age: "", // Age not available in Android structure
                country: user.user_country,
                gender: user.user_gender,
                isOnline: true, // Assume online if in database
                language: "", // Language not available in Android structure
                lastTimeSeen: Date(timeIntervalSince1970: TimeInterval(user.user_last_time_seen)),
                deviceId: user.user_device_id,
                profileImage: user.user_image
            )
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Converted \(allOnlineUsers.count) valid users")
        
        // CRITICAL FIX: Update UI INSTANTLY on main thread - no DispatchQueue.main.async
        // This ensures users see data immediately without any flicker
        if self.users.isEmpty {
            // First load - show initial page
            self.users = Array(allOnlineUsers.prefix(self.pageSize))
            self.currentPage = 1
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - First load: \(self.users.count) users")
        } else {
            // Subsequent loads - merge new users while preserving existing ones and scroll position
            let existingUserIds = Set(self.users.map { $0.id })
            let newUsers = allOnlineUsers.filter { user in
                !existingUserIds.contains(user.id)
            }
            
            if !newUsers.isEmpty {
                // Add new users to the beginning of the list (most recent first)
                self.users.insert(contentsOf: newUsers, at: 0)
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Merged \(newUsers.count) new users, total: \(self.users.count)")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - No new users to merge, maintaining existing \(self.users.count) users")
            }
        }
        
        self.hasMore = allOnlineUsers.count > self.users.count
        self.isLoading = false // Always ensure loading is off after local database load
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadUsersFromLocalDatabase() - Updated UI with \(self.users.count) users, hasMore: \(self.hasMore)")
    }

    /// Refresh users from local SQLite database with complete replacement (for filters and explicit refreshes)
    private func refreshUsersFromLocalDatabase() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Starting complete refresh from local database")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Current filter: male=\(filter.male), female=\(filter.female), country='\(filter.country)', language='\(filter.language)'")
        
        // ANDROID PARITY: Only show loading for explicit refreshes (like filters), not for regular database queries
        isLoading = true
        currentPage = 0
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { 
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Self is nil, aborting")
                return 
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Background thread started, querying database")
            
            // Get users from local database (similar to Android Room query)
            let localUsers = self.onlineUsersDB.query()
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Retrieved \(localUsers.count) users from database")
            
            // Log first few users for debugging
            for (index, user) in localUsers.prefix(5).enumerated() {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - DB User \(index + 1): '\(user.user_name)', gender: '\(user.user_gender)', country: '\(user.user_country)'")
            }
            
            // Apply filters
            let filteredUsers = self.applyLocalFilters(to: localUsers)
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - After filtering: \(filteredUsers.count) users")
            
            // Convert to OnlineUser objects and paginate
            let onlineUsers = filteredUsers.prefix(self.pageSize).compactMap { user -> OnlineUser? in
                // Skip empty or invalid users
                guard !user.user_name.isEmpty && !user.user_id.isEmpty else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Skipping user with empty name or ID: name='\(user.user_name)', id='\(user.user_id)'")
                    return nil
                }
                
                return OnlineUser(
                    id: user.user_id,
                    name: user.user_name,
                    age: "", // Age not available in Android structure
                    country: user.user_country,
                    gender: user.user_gender,
                    isOnline: true, // Assume online if in database
                    language: "", // Language not available in Android structure
                    lastTimeSeen: Date(timeIntervalSince1970: TimeInterval(user.user_last_time_seen)),
                    deviceId: user.user_device_id,
                    profileImage: user.user_image
                )
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - Converted \(onlineUsers.count) valid users for UI")
            
            DispatchQueue.main.async {
                // Complete replacement for filters and explicit refreshes
                self.users = Array(onlineUsers)
                self.hasMore = filteredUsers.count > self.pageSize
                self.isLoading = false // Always turn off loading after refresh
                self.currentPage = 1
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "refreshUsersFromLocalDatabase() - UI updated with \(self.users.count) users, hasMore: \(self.hasMore)")
            }
        }
    }

    /// Load more users from local database (pagination from local DB, not Firebase)
    func fetchMoreUsers() {
        guard hasMore, !isLoading else { 
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Skipping fetch: hasMore=\(hasMore), isLoading=\(isLoading)")
            return 
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Loading page \(currentPage + 1) from local database")
        
        isLoading = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { 
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Self is nil, aborting")
                return 
            }
            
            // Get all users from local database
            let localUsers = self.onlineUsersDB.query()
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Retrieved \(localUsers.count) users from database")
            
            // Apply filters
            let filteredUsers = self.applyLocalFilters(to: localUsers)
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - After filtering: \(filteredUsers.count) users")
            
            // Calculate pagination range
            let startIndex = self.currentPage * self.pageSize
            let endIndex = min(startIndex + self.pageSize, filteredUsers.count)
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Pagination: startIndex=\(startIndex), endIndex=\(endIndex)")
            
            guard startIndex < filteredUsers.count else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - No more users to fetch")
                DispatchQueue.main.async {
                    self.hasMore = false
                    self.isLoading = false
                }
                return
            }
            
            // Get next page of users
            let nextPageUsers = Array(filteredUsers[startIndex..<endIndex]).compactMap { user -> OnlineUser? in
                // Skip empty or invalid users
                guard !user.user_name.isEmpty && !user.user_id.isEmpty else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Skipping user with empty name or ID: name='\(user.user_name)', id='\(user.user_id)'")
                    return nil
                }
                
                return OnlineUser(
                    id: user.user_id,
                    name: user.user_name,
                    age: "", // Age not available in Android structure
                    country: user.user_country,
                    gender: user.user_gender,
                    isOnline: true, // Assume online if in database
                    language: "", // Language not available in Android structure
                    lastTimeSeen: Date(timeIntervalSince1970: TimeInterval(user.user_last_time_seen)),
                    deviceId: user.user_device_id,
                    profileImage: user.user_image
                )
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Got \(nextPageUsers.count) new users")
            
            DispatchQueue.main.async {
                // *** CRITICAL FIX: Prevent duplicates during pagination ***
                // Get existing user IDs to avoid duplicates
                let existingUserIds = Set(self.users.compactMap { $0.id })
                
                // Filter out users that already exist in the current list
                let uniqueNewUsers = nextPageUsers.filter { user in
                    !existingUserIds.contains(user.id)
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Filtered out \(nextPageUsers.count - uniqueNewUsers.count) duplicate users")
                
                if !uniqueNewUsers.isEmpty {
                    self.users.append(contentsOf: uniqueNewUsers)
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Added \(uniqueNewUsers.count) unique users, total: \(self.users.count)")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - No new unique users to add")
                }
                
                self.hasMore = endIndex < filteredUsers.count
                self.isLoading = false
                self.currentPage += 1
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchMoreUsers() - Pagination complete, hasMore: \(self.hasMore)")
            }
        }
    }

    /// Initial data load - only loads if no data exists, respects 30-minute refresh logic
    /// This is the proper method to call from onAppear - it won't unnecessarily reload data
    func initialLoadIfNeeded() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "initialLoadIfNeeded() - Checking if initial load is needed")
        
        // Only fetch if we have no data at all
        if users.isEmpty {
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "initialLoadIfNeeded() - No data present, calling fetchUsers")
            fetchUsers()
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "initialLoadIfNeeded() - Data already present (\(users.count) users), no action needed")
        }
    }
    
    /// Load users with Android parity logic - only fetch from Firebase when needed
    /// Matches Android OnlineUserListFragment.getOnlineUsers() logic exactly
    func fetchUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Starting with Android parity logic")
        
        // CRITICAL FIX: First check if we have any local data at all
        // Load from local database to see what we have
        loadUsersFromLocalDatabase()
        
        // CRITICAL FIX: Always force Firebase sync if database is empty, regardless of refresh time
        // This ensures we get data on first launch or after database corruption
        let needsFirebaseSync = users.isEmpty || userSessionManager.shouldRefreshOnlineUsersFromFirebase()
        
        if needsFirebaseSync {
            if users.isEmpty {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - No local data found, forcing Firebase sync for initial load")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Refresh time exceeded (30+ minutes), showing loading and triggering Firebase sync")
            }
            
            // ENHANCEMENT: Clear filters during periodic refresh for fresh data
            if !users.isEmpty {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Clearing filters for fresh periodic refresh")
                let filtersClearedSuccess = userSessionManager.clearAllFilters()
                if filtersClearedSuccess {
                    // Reset local filter object to match cleared state
                    self.filter = OnlineUserFilter()
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Filters cleared successfully during periodic refresh")
                }
            }
            
            // ANDROID PARITY: Only show loading when we actually need to fetch from Firebase
            isLoading = true
            
            // Trigger background Firebase sync (similar to Android OnlineUsersWorker)
            triggerBackgroundDataSync {
                DispatchQueue.main.async {
                    // Update refresh time after successful sync (matching Android)
                    self.userSessionManager.setOnlineUsersRefreshTime()
                    
                    // After sync, reload from the local database to update the UI
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Firebase sync complete, reloading from local DB")
                    self.loadUsersFromLocalDatabase()
                    
                    // CRITICAL FIX: Reset loading state after sync is complete
                    self.isLoading = false
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Loading state reset after sync completion")
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "fetchUsers() - Refresh time not exceeded and have local data (\(users.count) users), using cached data only")
            
            // CRITICAL FIX: Never show loading when using cached data - this prevents flicker
            // Local database queries should be instant like other apps
            self.isLoading = false
        }
    }
    
    /// Force refresh from Firebase (for filters only) - Android parity
    /// Clears database before refresh to ensure filter changes are applied correctly
    func forceRefreshUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "forceRefreshUsers() - Force refreshing from Firebase (filters)")
        
        // Clear local database before applying new filter (matching Android behavior)
        clearOnlineUsersDatabase()
        
        // Show loading state immediately since we cleared the database
        DispatchQueue.main.async {
            self.isLoading = true
            self.users = [] // Clear the UI immediately
        }
        
        // Trigger background Firebase sync (similar to Android OnlineUsersWorker)
        triggerBackgroundDataSync {
            // Update refresh time after successful sync (matching Android)
            self.userSessionManager.setOnlineUsersRefreshTime()
            
            // After sync, reload from the local database to update the UI
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "forceRefreshUsers() - Firebase sync complete, reloading from local DB")
            self.refreshUsersFromLocalDatabase()
        }
    }

    /// Manual refresh from Firebase (for refresh button only) - keeps existing users in database
    /// This provides a smoother user experience without clearing existing data
    func manualRefreshUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "manualRefreshUsers() - Manual refresh from Firebase (keeping existing users)")
        
        // Don't clear database for manual refresh - keep existing users for better UX
        // Just show loading state
        DispatchQueue.main.async {
            self.isLoading = true
            // Don't clear users array - keep existing data visible during refresh
        }
        
        // Trigger background Firebase sync (similar to Android OnlineUsersWorker)
        triggerBackgroundDataSync {
            // Update refresh time after successful sync (matching Android)
            self.userSessionManager.setOnlineUsersRefreshTime()
            
            // After sync, reload from the local database to update the UI
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "manualRefreshUsers() - Firebase sync complete, reloading from local DB")
            self.refreshUsersFromLocalDatabase()
        }
    }

    /// Apply filter with fresh Firebase sync (behaves like refresh)
    func applyFilter(_ newFilter: OnlineUserFilter) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyFilter() Applying new filter with fresh Firebase sync")
        
        self.filter = newFilter
        saveFilter()
        
        // Force refresh from Firebase with new filters (matching Android behavior)
        forceRefreshUsers()
    }

    /// Clear filter locally without any data reload
    /// Use this when user resets filters - only clears filter state, no data changes
    func clearFilterLocallyOnly() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "clearFilterLocallyOnly() Clearing filters locally without any data reload")
        
        // Clear filter object and save to preferences
        self.filter = OnlineUserFilter()
        saveFilter()
        
        // IMPORTANT: Do NOT reload data here - only clear filter state
        // The user list should remain exactly as it was, showing the same users
        // No database queries, no Firebase calls, no data changes whatsoever
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "clearFilterLocallyOnly() Filters cleared - data unchanged as requested")
    }
    
    // REMOVED: clearFilter() method - was a security loophole that allowed bypassing rate limits
    // Use clearFilterLocallyOnly() for user actions instead

    // REMOVED: refreshFiltersFromSessionManager() - was causing unnecessary Firebase refreshes
    // Use applyFilter() directly instead

    // MARK: - Private Helper Methods
    
    /// Apply filters to local user array (similar to Android age filtering logic)
    private func applyLocalFilters(to users: [Users]) -> [Users] {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Starting filter with \(users.count) users")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filter settings: male=\(filter.male), female=\(filter.female), country='\(filter.country)', language='\(filter.language)', nearby='\(filter.nearby)'")
        
        let filteredUsers = users.filter { user in
            let f = filter
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Checking user: '\(user.user_name)', gender: '\(user.user_gender)', country: '\(user.user_country)'")
            
            // Gender filter
            if f.male && !f.female && user.user_gender.lowercased() != "male" {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': male filter active but user is '\(user.user_gender)'")
                return false
            }
            if f.female && !f.male && user.user_gender.lowercased() != "female" {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': female filter active but user is '\(user.user_gender)'")
                return false
            }
            
            // Country filter
            if !f.country.isEmpty && user.user_country != f.country {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': country filter '\(f.country)' but user is from '\(user.user_country)'")
                return false
            }
            
            // Language filter
            if !f.language.isEmpty && user.user_language != f.language {
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': language filter '\(f.language)' but user language is '\(user.user_language)'")
                return false
            }
            
            // Age filtering - convert strings to integers for comparison
            if !f.minAge.isEmpty, let minAge = Int(f.minAge), let userAge = Int(user.user_age) {
                if userAge < minAge {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': user age \(userAge) below minimum \(minAge)")
                    return false
                }
            }
            if !f.maxAge.isEmpty, let maxAge = Int(f.maxAge), let userAge = Int(user.user_age) {
                if userAge > maxAge {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': user age \(userAge) above maximum \(maxAge)")
                    return false
                }
            }
            
            // Nearby filter - f.nearby is "yes" when nearby only is enabled
            if f.nearby == "yes" {
                // Get current user's city for comparison (matches Android pattern)
                let currentUserCity = UserSessionManager.shared.userRetrievedCity
                
                if let userCity = currentUserCity, !userCity.isEmpty {
                    // Filter to show only users from the same city
                    if user.user_city != userCity {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered out '\(user.user_name)': nearby filter enabled, user city '\(user.user_city)' != current user city '\(userCity)'")
                        return false
                    }
                } else {
                    // If current user city is not set, log warning but don't filter
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Nearby filter enabled but current user city is not set (userRetrievedCity is empty), skipping filter for '\(user.user_name)'")
                }
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - User '\(user.user_name)' passed all filters")
            return true
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "applyLocalFilters() - Filtered \(users.count) users down to \(filteredUsers.count) users")
        return filteredUsers
    }
    
    /// Trigger background Firebase sync (similar to Android OnlineUsersWorker)
    private func triggerBackgroundDataSync(completion: (() -> Void)? = nil) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Starting Firebase sync")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Self is nil, aborting")
                completion?()
                return 
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Background thread started")
            
            // This mimics Android's OnlineUsersWorker behavior
            var query: Query = Firestore.firestore().collection("Users")
                .order(by: "last_time_seen", descending: true)
                .limit(to: 50) // Increased limit to get more users initially
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Created base query with limit 50")
            
            // Apply filters to the background query
            let f = self.filter
            var maledata = f.male
            var femaledata = f.female
            if f.male && f.female {
                maledata = false
                femaledata = false
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Applying filters: male=\(maledata), female=\(femaledata), country='\(f.country)', language='\(f.language)', nearby='\(f.nearby)'")
            
            if maledata {
                query = query.whereField("User_gender", isEqualTo: "Male")
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Added male filter")
            }
            if femaledata {
                query = query.whereField("User_gender", isEqualTo: "Female")
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Added female filter")
            }
            if !f.country.isEmpty {
                query = query.whereField("User_country", isEqualTo: f.country)
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Added country filter: \(f.country)")
            }
            if !f.language.isEmpty {
                query = query.whereField("user_language", isEqualTo: f.language)
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Added language filter: \(f.language)")
            }
            if !f.nearby.isEmpty {
                query = query.whereField("user_city", isEqualTo: f.nearby)
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Added nearby filter: \(f.nearby)")
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Executing Firebase query")
            
            query.getDocuments { [weak self] snapshot, error in
                guard let self = self else { 
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Self is nil in completion handler")
                    completion?()
                    return 
                }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Firebase error: \(error.localizedDescription)")
                    completion?()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - No documents received from Firebase")
                    completion?()
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Received \(documents.count) documents from Firebase")
                
                let currentUserId = userSessionManager.userId
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Current user ID: \(currentUserId ?? "nil")")
                
                var insertedCount = 0
                var skippedCount = 0
                
                // Store in local database (similar to Android OnlineUsersWorker.insertOrUpdateUser)
                for (index, doc) in documents.enumerated() {
                    let data = doc.data()
                    let name = data["User_name"] as? String ?? ""
                    let id = data["User_id"] as? String ?? doc.documentID
                    let gender = data["User_gender"] as? String ?? ""
                    let _ = data["User_age"] as? String ?? ""
                    let country = data["User_country"] as? String ?? ""
                    let _ = data["user_language"] as? String ?? ""
                    let lastTimeSeen = (data["last_time_seen"] as? Timestamp)?.dateValue() ?? Date()
                    let deviceId = data["User_device_id"] as? String ?? ""
                    let _ = data["is_user_online"] as? Bool ?? false
                    let profileImage = data["User_image"] as? String ?? ""
                    
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Doc \(index + 1): name='\(name)', id='\(id)', country='\(country)', gender='\(gender)'")
                    
                    if !name.isEmpty && id != currentUserId {
                        // Use new Android-compatible insert method
                        self.onlineUsersDB.insert(
                            user_id: id,
                            user_name: name,
                            user_image: profileImage,
                            user_gender: gender,
                            user_country: country,
                            user_language: data["user_language"] as? String ?? "",
                            user_age: data["User_age"] as? String ?? "",
                            user_device_id: deviceId,
                            user_device_token: "", // Not available in Firebase data
                            user_area: "", // Not available in Firebase data
                            user_city: "", // Not available in Firebase data  
                            user_state: "", // Not available in Firebase data
                            user_decent_time: 0, // Not available in Firebase data
                            user_last_time_seen: Int64(lastTimeSeen.timeIntervalSince1970),
                            isAd: false
                        )
                        insertedCount += 1
                        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Inserted user: \(name)")
                    } else {
                        skippedCount += 1
                        let reason = name.isEmpty ? "empty name" : "same as current user"
                        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Skipped user: \(name), reason: \(reason)")
                    }
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Sync complete. Inserted: \(insertedCount), Skipped: \(skippedCount)")
                
                // Verify database state after sync
                let finalUserCount = self.onlineUsersDB.query().count
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "triggerBackgroundDataSync() - Final database count: \(finalUserCount)")
                
                // Call completion handler now that sync is done
                completion?()
            }
        }
    }

    private func saveFilter() {
        // Save filter data to UserSessionManager (individual properties)
        // This matches the Android pattern of saving each filter property individually
        if filter.male && !filter.female {
            userSessionManager.filterGender = "Male"
        } else if filter.female && !filter.male {
            userSessionManager.filterGender = "Female"
        } else {
            userSessionManager.filterGender = nil
        }
        
        userSessionManager.filterCountry = filter.country.isEmpty ? nil : filter.country
        userSessionManager.filterLanguage = filter.language.isEmpty ? nil : filter.language
        userSessionManager.filterNearbyOnly = !filter.nearby.isEmpty
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "saveFilter() - Saved filter to UserSessionManager")
    }

    private func loadFilter() {
        // Load filters from UserSessionManager individual properties (matching Android pattern)
        loadFiltersFromSessionManager()
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFilter() - Loaded filter from UserSessionManager")
    }
    
    /// Load filters from individual SessionManager properties (matching Android pattern)
    private func loadFiltersFromSessionManager() {
        // Use specialized UserSessionManager instead of monolithic SessionManager
        let userSessionManager = UserSessionManager.shared
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - SessionManager filter values:")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterGender: '\(userSessionManager.filterGender ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterCountry: '\(userSessionManager.filterCountry ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterLanguage: '\(userSessionManager.filterLanguage ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterMinAge: '\(userSessionManager.filterMinAge ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterMaxAge: '\(userSessionManager.filterMaxAge ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - filterNearbyOnly: \(userSessionManager.filterNearbyOnly)")
        
        // Load gender filter - matching Android logic
        if let savedGender = userSessionManager.filterGender, !savedGender.isEmpty {
            let gender = savedGender.lowercased()
            if gender == "female" {
                filter.female = true
                filter.male = false
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - Set female=true, male=false")
            } else if gender == "male" {
                filter.male = true
                filter.female = false
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - Set male=true, female=false")
            } else if gender == "both" {
                filter.male = true
                filter.female = true
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - Set both male=true, female=true")
            } else {
                filter.male = false
                filter.female = false
                AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - Invalid gender filter, set both to false")
            }
        } else {
            filter.male = false
            filter.female = false
            AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - No gender filter, set both to false")
        }
        
        // Load other filters
        filter.country = userSessionManager.filterCountry ?? ""
        filter.language = userSessionManager.filterLanguage ?? ""
        filter.minAge = userSessionManager.filterMinAge ?? ""
        filter.maxAge = userSessionManager.filterMaxAge ?? ""
        filter.nearby = userSessionManager.filterNearbyOnly ? "yes" : ""
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "loadFiltersFromSessionManager() - Final filter object: male=\(filter.male), female=\(filter.female), country='\(filter.country)', language='\(filter.language)', nearby='\(filter.nearby)'")
    }

    // MARK: - Database Clearing (Android Parity)
    
    /// Clears the online users database - matches Android's DeleteOnlineUsersAsyncTask behavior
    private func clearOnlineUsersDatabase() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "clearOnlineUsersDatabase() Clearing local database")
        
        // Use AsyncClass for centralized database clearing (matching Android pattern)
        DatabaseCleanupService.shared.deleteOnlineUsersOnly()
    }
    
    // MARK: - Deduplication Helper (Android Parity)
    
    /// Removes duplicate users based on user_id (matching Android's PagedListAdapter DiffUtil behavior)
    private func removeDuplicates(from users: [OnlineUser]) -> [OnlineUser] {
        var uniqueUsers: [OnlineUser] = []
        var seenUserIds: Set<String> = []
        
        for user in users {
            if !user.id.isEmpty {
                if !seenUserIds.contains(user.id) {
                    seenUserIds.insert(user.id)
                    uniqueUsers.append(user)
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "removeDuplicates() - Filtered out duplicate user: \(user.name) with ID: \(user.id)")
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "removeDuplicates() - Original count: \(users.count), Unique count: \(uniqueUsers.count), Removed duplicates: \(users.count - uniqueUsers.count)")
        return uniqueUsers
    }
    
    /// Remove duplicates from the existing users array (called during initialization and refresh)
    private func deduplicateExistingUsers() {
        let originalCount = users.count
        users = removeDuplicates(from: users)
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "deduplicateExistingUsers() - Removed \(originalCount - users.count) duplicates from existing users list")
    }
    
    /// Public method to manually trigger deduplication (for testing or external calls)
    func removeDuplicatesFromCurrentList() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersViewModel", message: "removeDuplicatesFromCurrentList() - Manually triggered deduplication")
        deduplicateExistingUsers()
    }
} 
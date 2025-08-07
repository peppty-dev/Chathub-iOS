import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class DiscoverTabViewModel: ObservableObject {
    @Published var searchResults: [SearchUser] = []
    @Published var notifications: [InAppNotificationDetails] = []
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var isLoading: Bool = false
    @Published var showEmptyState: Bool = false
    @Published var emptyStateMessage: String = ""
    @Published var showSearchResults: Bool = false // Controls which RecyclerView equivalent to show
    @Published var notificationsLoaded: Bool = false
    
    // Paging support for notifications
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreNotifications: Bool = true
    private let notificationsPageSize = 20
    private var currentNotificationsOffset = 0
    
    // Use specialized session managers instead of monolithic SessionManager
    private var userSessionManager = UserSessionManager.shared
    private var appSettingsSessionManager = AppSettingsSessionManager.shared
    private var db = Firestore.firestore()
    private var detached: Bool = false
    private var notificationListener: ListenerRegistration?
    private var searchWorkItem: DispatchWorkItem?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "DiscoverTabViewModel init()")
        setupNotificationListener()
    }
    
    deinit {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "DiscoverTabViewModel deinit()")
        notificationListener?.remove()
        searchWorkItem?.cancel()
        cancellables.removeAll()
        detached = true
    }
    
    // MARK: - Notification Management (Android Parity)
    private func setupNotificationListener() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupNotificationListener() - Now using local database via InAppNotificationsSyncService")
        
        // Load notifications from local database
        loadNotificationsFromLocalDB()
        
        // Listen for notification data changes with debouncing to prevent refresh loops
        NotificationCenter.default.publisher(for: .notificationDataChanged)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupNotificationListener() - Notification data changed, refreshing after debounce")
                self?.loadNotificationsFromLocalDB()
            }
            .store(in: &cancellables)
    }
    
    func loadNotificationsFromLocalDB() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Loading first page of notifications")
        
        // Reset paging for fresh load
        currentNotificationsOffset = 0
        hasMoreNotifications = true
        
        // Get first page of notifications (both seen and unseen)
        let localNotifications = InAppNotificationsSyncService.shared.getNotificationsFromLocalDB(
            limit: notificationsPageSize, 
            offset: currentNotificationsOffset
        )
        
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Retrieved \(localNotifications.count) notifications (first page)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show ALL notifications without any type filtering
            let allNotifications = localNotifications
            
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Displaying all \(allNotifications.count) notifications without filtering")
            
            if localNotifications.count > 0 {
                let firstNotif = localNotifications.first!
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - First notification details:")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Type: '\(firstNotif.NotificationType)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Name: '\(firstNotif.NotificationName)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  ID: '\(firstNotif.NotificationId)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Gender: '\(firstNotif.NotificationGender)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Image: '\(firstNotif.NotificationImage)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Time: '\(firstNotif.NotificationTime)'")
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "  Seen: \(firstNotif.NotificationSeen)")
            }
            
            // Store first page of notifications (both seen and unseen)
            self.notifications = allNotifications
            self.currentNotificationsOffset = allNotifications.count
            
            // Check if we have more notifications to load
            self.hasMoreNotifications = allNotifications.count == self.notificationsPageSize
            
            // Mark notifications as loaded and then check empty state
            self.notificationsLoaded = true
            self.showEmptyStateIfNeeded()
            
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Displaying \(allNotifications.count) notifications, hasMore: \(self.hasMoreNotifications)")
        }
    }
    
    func loadMoreNotifications() {
        guard hasMoreNotifications && !isLoadingMore else {
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadMoreNotifications() - Skipped (hasMore: \(hasMoreNotifications), isLoading: \(isLoadingMore))")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadMoreNotifications() - Loading more notifications from offset \(currentNotificationsOffset)")
        
        isLoadingMore = true
        
        // Get next page of notifications
        let localNotifications = InAppNotificationsSyncService.shared.getNotificationsFromLocalDB(
            limit: notificationsPageSize, 
            offset: currentNotificationsOffset
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show ALL notifications without any type filtering
            let newNotifications = localNotifications
            
            // Append new notifications to existing ones
            self.notifications.append(contentsOf: newNotifications)
            self.currentNotificationsOffset += newNotifications.count
            
            // Check if we have more notifications to load
            self.hasMoreNotifications = newNotifications.count == self.notificationsPageSize
            self.isLoadingMore = false
            
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadMoreNotifications() - Added \(newNotifications.count) notifications, total: \(self.notifications.count), hasMore: \(self.hasMoreNotifications)")
        }
    }
    
    func markNotificationsLoaded() {
        notificationsLoaded = true
        showEmptyStateIfNeeded()
    }
    
    /// Initial load method that checks if data is needed (like OnlineUsersViewModel pattern)
    func initialLoadIfNeeded() {
        AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "initialLoadIfNeeded() checking if notifications load is needed")
        
        // Check if we already have notifications data
        if notifications.isEmpty {
            AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "initialLoadIfNeeded() no notifications in memory, loading from database/Firebase")
            setupInitialData()
        } else {
            AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "initialLoadIfNeeded() already have \\(notifications.count) notifications in memory, skipping reload")
        }
    }
    
    /// Setup initial data (like the old setupView method but without forcing refresh every time)
    private func setupInitialData() {
        AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "setupInitialData() Setting up initial notifications data")
        
        // Load all notifications from local database (both seen and unseen) - instant display
        loadNotificationsFromLocalDB()
        markNotificationsLoaded()
        
        // Only refresh from Firebase if we have no data or very few notifications
        if notifications.count < 5 {
            AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "setupInitialData() Few or no notifications, refreshing from Firebase")
            refreshNotifications()
        } else {
            AppLogger.log(tag: "LOG-APP: DiscoverTabViewModel", message: "setupInitialData() Have \\(notifications.count) notifications, skipping Firebase refresh")
        }
    }
    
    func refreshNotifications() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "refreshNotifications() - Refreshing notifications from Firebase")
        
        InAppNotificationsSyncService.shared.forceSyncNotifications { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    AppLogger.log(tag: "LOG-APP: DiscoverView", message: "refreshNotifications() - Successfully refreshed notifications")
                    self.loadNotificationsFromLocalDB()
                } else {
                    AppLogger.log(tag: "LOG-APP: DiscoverView", message: "refreshNotifications() - Failed to refresh notifications")
                }
            }
        }
    }
    

    
    // MARK: - Helper Methods
    
    private func showEmptyStateIfNeeded() {
        if showSearchResults {
            // In search mode - show empty state if no search results
            if searchResults.isEmpty && !isLoading {
                showEmptyState = true
                emptyStateMessage = "No user found\nPlease try with different username"
            } else {
                showEmptyState = false
            }
        } else {
            // In notifications mode - show empty state if no notifications exist
            if notifications.isEmpty && notificationsLoaded {
                showEmptyState = true
                emptyStateMessage = "No notifications yet\nNotifications will appear here"
            } else {
                showEmptyState = false
            }
        }
        
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "showEmptyStateIfNeeded() - Mode: \(showSearchResults ? "search" : "notifications"), showEmptyState: \(showEmptyState), items: \(showSearchResults ? searchResults.count : notifications.count)")
    }
    
    // MARK: - Search Functionality (Android Parity)
    func performSearch(query: String) {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearch() searching for: \(query)")
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearchResults()
            return
        }
        
        // Cancel previous search to prevent concurrent searches
        searchWorkItem?.cancel()
        
        // Execute search immediately
        finalSearchProcess(searchQuery: query)
    }
    
    private func finalSearchProcess(searchQuery: String) {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "finalSearchProcess() \(searchQuery)")
        
        // Clear the current list
        searchResults.removeAll()
        
        // Convert search query to lowercase (Android parity)
        let lowerCaseSearchQuery = searchQuery.lowercased()
        
        isLoading = true
        
        // Prepare a list to hold results from the single query
        var tempResults: [SearchUser] = []
        
        db.collection("Users")
            .whereField("user_name_lowercase", isGreaterThanOrEqualTo: lowerCaseSearchQuery)
            .whereField("user_name_lowercase", isLessThanOrEqualTo: lowerCaseSearchQuery + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "finalSearchProcess() error: \(error.localizedDescription)")
                        self.showEmptyStateIfNeeded()
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "finalSearchProcess() no users found")
                        self.showEmptyStateIfNeeded()
                        return
                    }
                    
                    let currentUserId = self.userSessionManager.userId ?? ""
                    
                    // Clear temp results here before processing new ones
                    tempResults.removeAll()
                    
                    for document in documents {
                        let data = document.data()
                        
                        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "finalSearchProcess() username \(data["User_name"] as? String ?? "")")
                        
                        let userName = data["User_name"] as? String ?? ""
                        let userId = data["User_id"] as? String ?? ""
                        
                        // Basic validation: Ensure essential fields are present
                        if !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                           !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           userId != currentUserId {
                            
                            let user = SearchUser(
                                userId: userId,
                                deviceId: data["User_device_id"] as? String ?? "",
                                userName: userName,
                                userImage: data["User_image"] as? String ?? "",
                                userGender: data["User_gender"] as? String ?? "",
                                userAge: data["User_age"] as? String ?? "",
                                userCountry: data["User_country"] as? String ?? ""
                            )
                            
                            // Check if user (by ID) is already added to avoid duplicates
                            let alreadyAdded = tempResults.contains { $0.userId == user.userId }
                            if !alreadyAdded {
                                tempResults.append(user)
                            }
                        }
                    }
                    
                    if !self.detached {
                        // Update UI with animation disabled to prevent lag
                        withAnimation(.none) {
                            if tempResults.isEmpty {
                                self.searchResults.removeAll()
                                self.showSearchResults = false
                            } else {
                                // Update the adapter with the results from the single query
                                self.searchResults = tempResults
                                self.showSearchResults = true
                            }
                            self.showEmptyStateIfNeeded()
                        }
                    }
                }
            }
    }
    
    func clearSearchResults() {
        searchResults.removeAll()
        showSearchResults = false
        showEmptyStateIfNeeded()
    }
}
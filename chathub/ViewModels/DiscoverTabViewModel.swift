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
        
        // Listen for notification data changes
        NotificationCenter.default.publisher(for: .notificationDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupNotificationListener() - Notification data changed, refreshing")
                self?.loadNotificationsFromLocalDB()
            }
            .store(in: &cancellables)
        
        // Mark notifications as loaded
        markNotificationsLoaded()
    }
    
    func loadNotificationsFromLocalDB() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Loading notifications from local database")
        
        // Get notifications from local database via sync service
        let localNotifications = InAppNotificationsSyncService.shared.getNotificationsFromLocalDB()
        
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Retrieved \(localNotifications.count) notifications from sync service")
        
        // Debug: Log each notification
        for (index, notification) in localNotifications.enumerated() {
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Notification \(index): \(notification.NotificationName) - \(notification.NotificationType) - \(notification.NotificationTime)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let supportedTypes = InAppNotificationDetails.NotificationType.allCases.map { $0.rawValue }
            let filteredNotifications = localNotifications.filter { supportedTypes.contains($0.NotificationType) }
            
            self.notifications = filteredNotifications
            self.showEmptyStateIfNeeded()
            
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - Updated UI with \(localNotifications.count) notifications")
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "loadNotificationsFromLocalDB() - showEmptyState: \(self.showEmptyState), notificationsLoaded: \(self.notificationsLoaded)")
        }
    }
    
    func markNotificationsLoaded() {
        notificationsLoaded = true
        showEmptyStateIfNeeded()
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
            // In search mode
            if searchResults.isEmpty && !isLoading {
                showEmptyState = true
                emptyStateMessage = "No user found\nPlease try with different username"
            } else {
                showEmptyState = false
            }
        } else {
            // In notifications mode
            if notifications.isEmpty && notificationsLoaded {
                showEmptyState = true
                emptyStateMessage = "No new notification\nNew notification will appear here"
            } else {
                showEmptyState = false
            }
        }
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
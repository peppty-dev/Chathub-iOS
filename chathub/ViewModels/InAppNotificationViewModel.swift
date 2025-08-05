import Foundation
import SwiftUI
import Combine

/// iOS equivalent of Android Notifications_ViewModel
/// Observes local database changes and provides reactive data to UI
/// IMPLEMENTS: Local Database → Screen flow
class InAppNotificationViewModel: ObservableObject {
    @Published var notifications: [InAppNotificationDetails] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var showEmptyState: Bool = false
    @Published var emptyStateMessage: String = ""
    
    // Use specialized session managers for user identification
    private let userSessionManager = UserSessionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Android Parity Constants
    private static let TAG = "NotificationViewModel"
    private static let REFRESH_INTERVAL: TimeInterval = 5.0 // Refresh every 5 seconds like Android LiveData
    
    init() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() - NotificationViewModel initialized")
        setupDatabaseObservers()
        loadNotificationsFromLocalDB()
        startPeriodicRefresh()
    }
    
    deinit {
        stopPeriodicRefresh()
        cancellables.removeAll()
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "deinit() - NotificationViewModel deinitialized")
    }
    
    // MARK: - Database Observers (Android LiveData equivalent)
    
    /// Setup observers for local database changes - equivalent to Android LiveData observers
    private func setupDatabaseObservers() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setupDatabaseObservers() - Setting up local database observers")
        
        // Observe notification data changes from local database
        NotificationCenter.default.publisher(for: .notificationDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setupDatabaseObservers() - Notification data changed, refreshing from local DB")
                self?.loadNotificationsFromLocalDB()
            }
            .store(in: &cancellables)
        
        // Observe legacy notification view model changes for backward compatibility
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotificationViewModelChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setupDatabaseObservers() - Legacy notification model changed")
            self?.loadNotificationsFromLocalDB()
        }
    }
    
    /// Start periodic refresh - Android parity for continuous data updates
    private func startPeriodicRefresh() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startPeriodicRefresh() - Starting periodic refresh")
        
        stopPeriodicRefresh() // Stop any existing timer
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.REFRESH_INTERVAL, repeats: true) { [weak self] _ in
            self?.loadNotificationsFromLocalDB()
        }
    }
    
    /// Stop periodic refresh
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Data Loading (Local Database → Screen)
    
    /// Load notifications from local database only - IMPLEMENTS: Local Database → Screen
    func loadNotificationsFromLocalDB() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadNotificationsFromLocalDB() - Loading notifications from local database")
        
        isLoading = true
        
        // Get notifications from local database via sync service
        let localNotifications = InAppNotificationsSyncService.shared.getNotificationsFromLocalDB()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.notifications = localNotifications
            self.updateUnreadCount()
            self.updateEmptyState()
            self.isLoading = false
            
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadNotificationsFromLocalDB() - Loaded \(localNotifications.count) notifications from local database")
        }
    }
    
    /// Update unread count from local database - Android parity
    private func updateUnreadCount() {
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateUnreadCount() - NotificationDB not available")
            unreadCount = 0
            return
        }
        
        let count = notificationDB.getUnreadNotificationsCount()
        unreadCount = count
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateUnreadCount() - Updated unread count to: \(count)")
    }
    
    /// Update empty state based on notifications count
    private func updateEmptyState() {
        if notifications.isEmpty {
            showEmptyState = true
            emptyStateMessage = "No notifications yet"
        } else {
            showEmptyState = false
            emptyStateMessage = ""
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateEmptyState() - Show empty state: \(showEmptyState)")
    }
    
    // MARK: - User Actions (Android Parity)
    
    /// Mark all notifications as seen - equivalent to Android setNotificationsSeen()
    func markAllNotificationsAsSeen() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "markAllNotificationsAsSeen() - Marking all notifications as seen")
        
        InAppNotificationsSyncService.shared.markNotificationsAsSeenInLocalDB()
        
        // Update local state immediately for better UX
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update local notifications to mark as seen
            self.notifications = self.notifications.map { notification in
                InAppNotificationDetails(
                    NotificationName: notification.NotificationName,
                    NotificationId: notification.NotificationId,
                    NotificationTime: notification.NotificationTime,
                    NotificationType: notification.NotificationType,
                    NotificationGender: notification.NotificationGender,
                    NotificationImage: notification.NotificationImage,
                    NotificationOtherId: notification.NotificationOtherId,
                    NotificationSeen: true // Mark as seen
                )
            }
            
            self.unreadCount = 0
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "markAllNotificationsAsSeen() - Updated local state")
        }
    }
    
    /// Refresh notifications from Firebase and sync to local database
    func refreshNotifications() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "refreshNotifications() - Refreshing notifications from Firebase")
        
        isLoading = true
        
        InAppNotificationsSyncService.shared.forceSyncNotifications { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if success {
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "refreshNotifications() - Successfully refreshed notifications")
                    self.loadNotificationsFromLocalDB()
                } else {
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "refreshNotifications() - Failed to refresh notifications")
                }
            }
        }
    }
    
    /// Clear all notifications - Android parity
    func clearAllNotifications() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearAllNotifications() - Clearing all notifications")
        
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearAllNotifications() - NotificationDB not available")
            return
        }
        
        notificationDB.clearAllNotifications()
        
        // Update local state immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.notifications = []
            self.unreadCount = 0
            self.updateEmptyState()
            
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearAllNotifications() - Cleared local state")
        }
    }
    
    // MARK: - Getters (Android Parity)
    
    /// Get notifications count - equivalent to Android getNotificationsCount()
    func getNotificationsCount() -> Int {
        return notifications.count
    }
    
    /// Get unread notifications count - equivalent to Android selectNotificationsCount()
    func getUnreadNotificationsCount() -> Int {
        return unreadCount
    }
    
    /// Get notifications list - equivalent to Android getNotifications()
    func getNotifications() -> [InAppNotificationDetails] {
        return notifications
    }
    
    /// Check if notifications are empty
    func isEmpty() -> Bool {
        return notifications.isEmpty
    }
    
    /// Force refresh from local database
    func forceRefreshFromLocalDB() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "forceRefreshFromLocalDB() - Force refreshing from local database")
        loadNotificationsFromLocalDB()
    }
    
    // MARK: - Legacy Support
    
    /// Update from legacy notification model for backward compatibility
    func updateFromLegacyModel(_ legacyNotifications: [InAppNotificationDetails]?) {
        guard let legacyNotifications = legacyNotifications else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateFromLegacyModel() - No legacy notifications provided")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateFromLegacyModel() - Updating from legacy model with \(legacyNotifications.count) notifications")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only update if local database is empty (to avoid conflicts)
            if self.notifications.isEmpty {
                self.notifications = legacyNotifications
                self.updateUnreadCount()
                self.updateEmptyState()
                
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateFromLegacyModel() - Updated from legacy model")
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateFromLegacyModel() - Skipped legacy update, local database has data")
            }
        }
    }
} 

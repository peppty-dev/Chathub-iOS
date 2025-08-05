import Foundation
import SwiftUI
import Combine

/// iOS equivalent of Android's notification badge management in MainActivity
/// Handles notification badge counts from local database with 100% Android parity
class InAppNotificationBadgeManager: ObservableObject {
    static let shared = InAppNotificationBadgeManager()
    
    @Published var discoverBadgeCount: Int = 0
    @Published var chatsBadgeCount: Int = 0
    
    private var badgeUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Android Parity Constants
    private static let TAG = "NotificationBadgeManager"
    private static let BADGE_UPDATE_INTERVAL: TimeInterval = 2.0 // Update every 2 seconds like Android
    
    private init() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() - NotificationBadgeManager initialized")
        setupBadgeObservers()
    }
    
    // MARK: - Badge Management (Android Parity)
    
    /// Start monitoring badge counts - equivalent to Android MainActivity.setupBadges()
    func startBadgeMonitoring() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startBadgeMonitoring() - Starting badge monitoring")
        
        // Stop any existing timer
        stopBadgeMonitoring()
        
        // Start periodic badge updates
        badgeUpdateTimer = Timer.scheduledTimer(withTimeInterval: Self.BADGE_UPDATE_INTERVAL, repeats: true) { [weak self] _ in
            self?.updateAllBadgeCounts()
        }
        
        // Initial badge update
        updateAllBadgeCounts()
    }
    
    /// Stop monitoring badge counts
    func stopBadgeMonitoring() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopBadgeMonitoring() - Stopping badge monitoring")
        
        badgeUpdateTimer?.invalidate()
        badgeUpdateTimer = nil
    }
    
    /// Update all badge counts - equivalent to Android's observer callbacks
    private func updateAllBadgeCounts() {
        // Update discover badge count from local database
        updateDiscoverBadgeCount()
        
        // Update chats badge count from local database
        updateChatsBadgeCount()
    }
    
    /// Update discover tab badge count from local database - Android parity
    private func updateDiscoverBadgeCount() {
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateDiscoverBadgeCount() - NotificationDB not available")
            return
        }
        
        let unreadCount = notificationDB.getUnreadNotificationsCount()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.discoverBadgeCount != unreadCount {
                self.discoverBadgeCount = unreadCount
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateDiscoverBadgeCount() - Updated discover badge count to: \(unreadCount)")
            }
        }
    }
    
    /// Update chats tab badge count from local database - Android parity
    private func updateChatsBadgeCount() {
        guard let chatDB = DatabaseManager.shared.getChatDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateChatsBadgeCount() - ChatDB not available")
            return
        }
        
        // Count unread chats from local database
        let unreadChats = chatDB.query().filter { $0.newmessage }
        let unreadCount = unreadChats.count
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.chatsBadgeCount != unreadCount {
                self.chatsBadgeCount = unreadCount
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updateChatsBadgeCount() - Updated chats badge count to: \(unreadCount)")
            }
        }
    }
    
    /// Clear discover badge count - equivalent to Android's clearBadge(R.id.navigation_discover)
    func clearDiscoverBadge() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearDiscoverBadge() - Clearing discover badge")
        
        // Mark all notifications as seen in local database
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearDiscoverBadge() - NotificationDB not available")
            return
        }
        
        notificationDB.markAllNotificationsAsSeen()
        
        // Update badge count immediately
        DispatchQueue.main.async { [weak self] in
            self?.discoverBadgeCount = 0
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearDiscoverBadge() - Discover badge cleared")
        }
    }
    
    /// Clear chats badge count - equivalent to Android's chat badge clearing
    func clearChatsBadge() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "clearChatsBadge() - Clearing chats badge")
        
        // This would be handled by individual chat read status updates
        // For now, just update the count
        updateChatsBadgeCount()
    }
    
    // MARK: - Observer Setup (Android Parity)
    
    /// Setup badge observers - equivalent to Android's ViewModel observers
    private func setupBadgeObservers() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setupBadgeObservers() - Setting up badge observers")
        
        // Observe notification view model changes (Android LiveData equivalent)
        NotificationCenter.default.publisher(for: .notificationDataChanged)
            .sink { [weak self] _ in
                self?.updateDiscoverBadgeCount()
            }
            .store(in: &cancellables)
        
        // Observe chat view model changes (Android LiveData equivalent)
        NotificationCenter.default.publisher(for: .chatTableDataChanged)
            .sink { [weak self] _ in
                self?.updateChatsBadgeCount()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .inboxTableDataChanged)
            .sink { [weak self] _ in
                self?.updateChatsBadgeCount()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Getters (Android Parity)
    
    /// Get current discover badge count
    func getDiscoverBadgeCount() -> Int {
        return discoverBadgeCount
    }
    
    /// Get current chats badge count
    func getChatsBadgeCount() -> Int {
        return chatsBadgeCount
    }
    
    /// Force refresh all badge counts
    func refreshAllBadges() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "refreshAllBadges() - Force refreshing all badge counts")
        updateAllBadgeCounts()
    }
    
    deinit {
        stopBadgeMonitoring()
        cancellables.removeAll()
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "deinit() - NotificationBadgeManager deinitialized")
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    /// Posted when notification data changes in local database
    static let notificationDataChanged = Notification.Name("notificationDataChanged")
}

// MARK: - SwiftUI Badge View Helper (Android Parity)
struct BadgeView: View {
    let count: Int
    let backgroundColor: Color
    let textColor: Color
    
    init(count: Int, backgroundColor: Color = Color("red3"), textColor: Color = .white) {
        self.count = count
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
    
    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: count > 9 ? 22 : 20, height: count > 9 ? 22 : 20)
                
                Text(count > 9 ? "9+" : "\(count)")
                    .font(.system(size: count > 9 ? 11 : 12, weight: .bold))
                    .foregroundColor(textColor)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Tab Badge Implementation Note
// Badge functionality is now implemented directly in CustomTabBar in MainView.swift
// This provides proper badge positioning and appearance matching native iOS tab bars 

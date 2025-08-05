import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseCrashlytics
import UIKit

class ChatsViewModel: ObservableObject {
    @Published var chatList: [Chat] = []
    @Published var inboxChats: [Chat] = []
    @Published var inboxCount: Int = 0
    @Published var latestInboxChat: Chat?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String = ""
    
    // Android Parity: Adapter and Configuration
    @Published var adapter: ChatsListAdapter
    private let config: ChatListConfig
    
    // Android Parity: Lifecycle and Resource Management
    private var firestoreListener: ListenerRegistration?
    private let chatDB = ChatsDB.shared
    private var observerTokens: [NSObjectProtocol] = []
    private var backgroundQueue = DispatchQueue(label: "ChatsViewModel.background", qos: .background)
    var isViewActive: Bool = false
    
    // Android Parity: Paging and Data Management
    private var currentPage: Int = 0
    private var isLoadingMore: Bool = false
    private var hasMoreData: Bool = true
    
    // Use specialized session managers and service layer instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let messagingSettingsSessionManager = MessagingSettingsSessionManager.shared
    private let moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
    private let chatDataService = ChatDataService.shared
    
    init(config: ChatListConfig = .default) {
        self.config = config
        self.adapter = ChatsListAdapter(config: config)
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "init() initialized with config: pageSize=\(config.pageSize)")
        
        setupNotificationObservers()
    }
    
    deinit {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "deinit() cleaning up")
        cleanup()
    }
    
    // MARK: - Android Fragment Lifecycle Methods
    
    func setChats() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setChats() Android Fragment equivalent")
        loadChats()
    }
    
    func loadChats() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() starting")
        
        guard !isLoading else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() already loading, skipping")
            return
        }
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() Database not ready - will retry after initialization")
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadChats()
            }
            return
        }
            
        DispatchQueue.main.async {
            self.isLoading = true
            self.hasError = false
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // CRITICAL FIX: Load ALL regular chats (not paginated) - users expect to see all their chats
                let allChats = self.chatDB.query()
                
                // CRITICAL FIX: Load ALL inbox chats separately
                let inboxChats = self.chatDB.inboxquery()
                    
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() DEBUG: Regular chats from DB: \(allChats.count), Inbox chats from DB: \(inboxChats.count)")
                
                // Debug: Log first few chats from each category
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "--- Regular Chats Sample ---")
                for (index, chat) in allChats.prefix(3).enumerated() {
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "Regular chat \(index): \(chat.Name) (inbox=\(chat.inbox), ChatId=\(chat.ChatId))")
                }
                
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "--- Inbox Chats Sample ---")
                for (index, chat) in inboxChats.prefix(3).enumerated() {
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "Inbox chat \(index): \(chat.Name) (inbox=\(chat.inbox), ChatId=\(chat.ChatId))")
                }
                
                DispatchQueue.main.async {
                    // CRITICAL FIX: Use ALL chats, not paginated
                    self.chatList = allChats
                    self.inboxChats = inboxChats
                    self.adapter.submitList(allChats)
                    self.isLoading = false
                
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() completed - \(allChats.count) regular chats, \(inboxChats.count) inbox chats")
                }
                
                // Load inbox data for counter and preview
                self.loadInboxData()
                
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasError = true
                    self.errorMessage = "Failed to load chats: \(error.localizedDescription)"
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadChats() error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadMoreChats() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadMoreChats() triggered")
        
        guard !isLoadingMore && hasMoreData else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadMoreChats() skipped - isLoadingMore: \(isLoadingMore), hasMoreData: \(hasMoreData)")
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingMore = true
        }
        
        let nextPage = currentPage + 1
        loadPage(page: nextPage, isInitialLoad: false)
    }
    
    private func loadPage(page: Int, isInitialLoad: Bool) {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadPage() loading page \(page), isInitialLoad: \(isInitialLoad)")
        
        let startIndex = page * config.pageSize
        let allChats = chatDB.query()
        let pageChats = Array(allChats.dropFirst(startIndex).prefix(config.pageSize))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isInitialLoad {
                self.chatList = pageChats
                self.adapter.submitList(pageChats)
                self.isLoading = false
            } else {
                self.chatList.append(contentsOf: pageChats)
                self.adapter.submitList(self.chatList)
                self.isLoadingMore = false
            }
            
            if pageChats.count < self.config.pageSize {
                self.hasMoreData = false
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadPage() reached end of data")
            } else {
                self.currentPage = page
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadPage() completed - total chats: \(self.chatList.count)")
        }
        
        if isInitialLoad {
            loadInboxData()
        }
    }
    
    private func loadInboxData() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadInboxData() Android Fragment equivalent")
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadInboxData() Database not ready - will retry after initialization")
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadInboxData()
            }
            return
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            let inboxChats = self.chatDB.inboxquery()
            let latestInbox = self.chatDB.inboxnewquery()
            
            DispatchQueue.main.async {
                self.inboxCount = inboxChats.count
                self.latestInboxChat = latestInbox
                self.inboxChats = inboxChats
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "loadInboxData() loaded \(inboxChats.count) inbox chats")
            }
        }
    }
    
    func getInboxCounter() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxCounter() Android Fragment equivalent")
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxCounter() Database not ready - will retry after initialization")
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.getInboxCounter()
            }
            return
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
        
            let inboxChats = self.chatDB.inboxquery()
        
            DispatchQueue.main.async {
                self.inboxCount = inboxChats.count
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxCounter() found \(inboxChats.count) inbox chats")
            }
        }
    }
        
    func getInboxPreview() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxPreview() Android Fragment equivalent")
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxPreview() Database not ready - will retry after initialization")
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.getInboxPreview()
            }
            return
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            let inboxPreview = self.chatDB.inboxnewquery()
            
            DispatchQueue.main.async {
                if let preview = inboxPreview {
                    self.latestInboxChat = preview
                    
                    self.adapter.setInboxPreviewCount(
                        preview.ProfileImage,
                        preview.Gender,
                        preview.Name,
                        preview.newmessage,
                        preview.UserId,
                        preview.LastTimeStamp
                    )
                
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxPreview() found latest inbox chat: \(preview.Name)")
                } else {
                    self.latestInboxChat = nil
                    
                    self.adapter.setInboxPreviewCount("", "", "", false, "", Date(timeIntervalSince1970: 0))
                    
                    AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxPreview() no latest inbox chat found")
                }
                
                self.notifyHeaderChanged()
                
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "getInboxPreview() completed")
            }
        }
    }
    
    func notifyHeaderChanged() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "notifyHeaderChanged() Android equivalent - forcing UI refresh")
        
        // Force SwiftUI to update by triggering objectWillChange
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        
        // Also notify adapter of header changes (Android parity)
        adapter.notifyItemChanged(at: 0)
    }
    
    /// Force immediate UI refresh - iOS equivalent of Android adapter.notifyDataSetChanged()
    func forceUIRefresh() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "forceUIRefresh() Forcing complete UI refresh")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Trigger SwiftUI update
            self.objectWillChange.send()
            
            // Force adapter refresh (Android parity)
            self.adapter.notifyDataSetChanged()
            
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "forceUIRefresh() UI refresh completed")
        }
    }
    
    func clearRecyclerViewReferences() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "clearRecyclerViewReferences() Android onDestroyView equivalent")
    }
    
    func clearAdapterReference() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "clearAdapterReference() Android equivalent")
    }
    
    func removeObservers() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "removeObservers() Android equivalent")
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
    }
    
    func refreshChats() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "refreshChats() refreshing chat list")
        
        guard !isRefreshing else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "refreshChats() already refreshing, skipping")
            return
        }
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "refreshChats() Database not ready - will retry after initialization")
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshChats()
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
        currentPage = 0
        hasMoreData = true
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL FIX: Load ALL chats instead of paginated
            let chats = self.chatDB.query()
            let inboxChats = self.chatDB.inboxquery()
            
            DispatchQueue.main.async {
                // CRITICAL FIX: Use ALL chats, not paginated
                self.chatList = chats
                self.inboxChats = inboxChats
                self.adapter.submitList(chats)
                self.isRefreshing = false
                
                AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "refreshChats() completed - \(chats.count) regular chats, \(inboxChats.count) inbox chats")
            }
            
            self.loadInboxData()
        }
    }
    
    private func setupNotificationObservers() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupNotificationObservers() Android equivalent - setting up real-time database observers")
        
        // CRITICAL: Set up real-time observers for database changes (Android LiveData equivalent)
        // This enables real-time updates when ChatsSyncService modifies the database
        setupDatabaseObservers()
        
        // Set up notification center observers for app lifecycle events
        setupAppLifecycleObservers()
    }
    
    /// Set up real-time database observers - iOS equivalent of Android LiveData observers
    private func setupDatabaseObservers() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Setting up real-time database change observers")
        
        // Observer for regular chats (equivalent to Android's chats_viewModel.getChatListUsers().observe())
        let chatObserverToken = NotificationCenter.default.addObserver(
            forName: .chatTableDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Regular chats data changed - updating UI")
            
            // MODERN SWIFTUI PATTERN: Query database directly when notified of changes
            let updatedChats = self.chatDB.query()
            self.chatList = updatedChats
            self.adapter.submitList(updatedChats)
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Updated chatList with \(updatedChats.count) chats")
            
            // CRITICAL: Force SwiftUI to update the UI (iOS real-time update)
            self.objectWillChange.send()
        }
        observerTokens.append(chatObserverToken)
        
        // Observer for inbox chats (equivalent to Android's chats_viewModel.selectTotalInboxChatsCount().observe())
        let inboxObserverToken = NotificationCenter.default.addObserver(
            forName: .inboxTableDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Inbox chats data changed - updating UI")
            
            // MODERN SWIFTUI PATTERN: Query database directly when notified of changes
            let updatedInboxChats = self.chatDB.inboxquery()
            self.inboxChats = updatedInboxChats
            self.inboxCount = updatedInboxChats.count
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Updated inboxChats with \(updatedInboxChats.count) chats")
            
            // Update inbox preview (Android parity)
            self.latestInboxChat = updatedInboxChats.first
            
            // Notify adapter of header changes (Android parity)
            self.adapter.notifyItemChanged(at: 0)
            
            // CRITICAL: Force SwiftUI to update the UI (iOS real-time update)
            self.objectWillChange.send()
        }
        observerTokens.append(inboxObserverToken)
        
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupDatabaseObservers() Database observers set up successfully")
        
        // CRITICAL: Immediately sync with current database state (Android parity)
        // This ensures UI shows latest data even if no database changes occur
        syncWithCurrentDatabaseState()
    }
    
    /// Immediately sync view model with current database state
    private func syncWithCurrentDatabaseState() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "syncWithCurrentDatabaseState() Syncing with current database state")
        
        // MODERN SWIFTUI PATTERN: Query database directly instead of using global view models
        let currentChats = self.chatDB.query()
        let currentInboxChats = self.chatDB.inboxquery()
        
        self.chatList = currentChats
        self.adapter.submitList(currentChats)
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "syncWithCurrentDatabaseState() Synced chatList with \(currentChats.count) chats")
        
        self.inboxChats = currentInboxChats
        self.inboxCount = currentInboxChats.count
        self.latestInboxChat = currentInboxChats.first
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "syncWithCurrentDatabaseState() Synced inboxChats with \(currentInboxChats.count) chats")
        
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "syncWithCurrentDatabaseState() Sync completed")
    }
    
    /// Set up app lifecycle observers for proper state management
    private func setupAppLifecycleObservers() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupAppLifecycleObservers() Setting up app lifecycle observers")
        
        // Observer for app becoming active (Android onResume equivalent)
        let appActiveToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupAppLifecycleObservers() App became active - refreshing if view is active")
            
            // Only refresh if this view model is active (Android fragment lifecycle parity)
            if self.isViewActive {
                self.refreshChats()
            }
        }
        observerTokens.append(appActiveToken)
        
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "setupAppLifecycleObservers() App lifecycle observers set up successfully")
    }
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "cleanup() performing comprehensive cleanup")
        
        firestoreListener?.remove()
        firestoreListener = nil
        
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
        
        adapter.cleanup()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.chatList.removeAll()
            self.inboxChats.removeAll()
            self.inboxCount = 0
            self.latestInboxChat = nil
            self.isLoading = false
            self.isRefreshing = false
            self.hasError = false
            self.errorMessage = ""
            self.isViewActive = false
        }
        
        currentPage = 0
        isLoadingMore = false
        hasMoreData = true
        
        AppLogger.log(tag: "LOG-APP: ChatsViewModel", message: "cleanup() completed")
    }
}

// MARK: - Supporting Models and Configuration

// Chat List Configuration (Android Parity)
struct ChatListConfig {
    let pageSize: Int = 10
    let initialLoadSizeHint: Int = 20
    let prefetchDistance: Int = 10
    let enablePlaceholders: Bool = true
    
    static let `default` = ChatListConfig()
}

// Chat Row Type (Android View Type Parity)
enum ChatRowType: CaseIterable {
    case header
    case item
    case empty
    
    var layoutId: String {
        switch self {
        case .header: return "HEADER_VIEW"
        case .item: return "ITEM_VIEW" 
        case .empty: return "EMPTY_VIEW"
        }
    }
}

// Chats List Adapter (Android Adapter Parity)
class ChatsListAdapter: ObservableObject {
    @Published var chatList: [Chat] = []
    @Published var isLoadingMore: Bool = false
    
    private let config: ChatListConfig
    private let userSessionManager = UserSessionManager.shared
    private let moderationSettingsSessionManager = ModerationSettingsSessionManager.shared  // Added missing property
    
    var prefetchDistance: Int {
        return config.prefetchDistance
    }
    
    init(config: ChatListConfig) {
        self.config = config
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "init() Android RecyclerView.Adapter equivalent")
    }
    
    func submitList(_ newList: [Chat]) {
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "submitList() Android DiffUtil equivalent - \(newList.count) items")
        
        DispatchQueue.main.async { [weak self] in
            self?.chatList = newList
        }
    }
    
    func setInboxPreviewCount(_ userPhoto: String, _ userGender: String, _ userName: String, _ newMessage: Bool, _ userId: String, _ chatTime: Date) {
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "setInboxPreviewCount() userName: \(userName), newMessage: \(newMessage)")
    }
    
    func notifyItemChanged(at index: Int) {
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "notifyItemChanged() at index: \(index)")
        
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// iOS equivalent of Android adapter.notifyDataSetChanged()
    /// Forces complete refresh of all UI elements
    func notifyDataSetChanged() {
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "notifyDataSetChanged() Android equivalent - forcing complete UI refresh")
        
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    func getItemViewType(for item: Chat, at position: Int) -> ChatRowType {
        if item.ChatId == "CHATS_HEADER" {
            return .header
        }
        
        if self.moderationSettingsSessionManager.getReportedUsersList().contains(item.UserId) {
            return .empty
        }
        
        return .item
    }
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: ChatsListAdapter", message: "cleanup() Android adapter cleanup")
        
        DispatchQueue.main.async { [weak self] in
            self?.chatList.removeAll()
            self?.isLoadingMore = false
        }
    }
} 
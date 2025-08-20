import SwiftUI
import FirebaseFirestore
import FirebaseCrashlytics
import UIKit
import Foundation
import FirebaseAuth
import SDWebImageSwiftUI

// MARK: - Notification Names for Real-Time Database Updates (Android LiveData equivalent)
extension Notification.Name {
    /// Posted when ChatTable data changes (regular chats)
    static let chatTableDataChanged = Notification.Name("chatTableDataChanged")
    /// Posted when InboxTable data changes (inbox chats)
    static let inboxTableDataChanged = Notification.Name("inboxTableDataChanged")
}



struct ChatsTabView: View {
    @StateObject private var viewModel = ChatsViewModel()
    @State private var selectedFilter: ChatFilter = .all
    @State private var navigateToChat = false
    @State private var navigateToInboxView = false
    @State private var selectedChat: Chat?
    @State private var showClearConversationAlert = false
    @State private var chatToDelete: Chat?
    @State private var isLoaded = false
    @State private var isRefreshing = false
    @State private var isViewActive = false
    
    // Android Parity: Fragment lifecycle state tracking
    @State private var fragmentState: FragmentState = .created
    
    // Message limit manager (Android Parity)
    private let messageLimitManager = MessageLimitManager.shared
    private let sessionManager = SessionManager.shared
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    // Android Parity: Fragment lifecycle states
    enum FragmentState {
        case created, started, resumed, paused, stopped, destroyed
    }
    
    // Current user session (Android Parity)
    private var currentUserId: String {
        sessionManager.userId ?? ""
    }
    
    var body: some View {
        ZStack {
            // Background matching Android fragment_chats.xml
            Color("background").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Segmented Control Section
                segmentedControlSection
                
                // Main Content Area
                if viewModel.hasError {
                    // Error State (Android Parity)
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color("Red1"))
                        Text("Error Loading Chats")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("dark"))
                        Text(viewModel.errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade6"))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "Error retry button tapped")
                            viewModel.loadChats()
                        }
                        .foregroundColor(Color("ColorAccent"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading && currentChats.isEmpty {
                    // Loading State (Android Parity)  
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        Text("Loading chats...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("shade6"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentChats.isEmpty && !viewModel.isLoading {
                    // Empty State (Android Parity)
                    emptyStateView
                } else {
                    // Chat List Content
                    chatListContent
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            handleOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
        .background(
            Group {
                // Navigation to MessagesView (Android Parity: Intent to MessageTextActivity)
                NavigationLink(
                    destination: selectedChat.map { chat in
                        MessagesView(
                            chatId: chat.ChatId,
                            otherUser: ChatUser(
                                id: chat.UserId,
                                name: chat.Name,
                                profileImage: chat.ProfileImage,
                                gender: chat.Gender,
                                deviceId: chat.DeviceId,
                                isOnline: true
                            ),
                            isFromInbox: selectedFilter == .inbox, // Set based on current filter
                            onDismiss: {
                                AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "onDismiss() MessagesView dismissed - refreshing chat list")
                                
                                self.navigateToChat = false
                                
                                // Refresh chat data to show updated read status
                                self.viewModel.setChats()
                                self.viewModel.getInboxCounter()
                                self.viewModel.getInboxPreview()
                                
                                // Force UI update
                                self.viewModel.notifyHeaderChanged()
                                
                                AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "onDismiss() Chat list refresh completed")
                            }
                        )
                    },
                    isActive: $navigateToChat
                ) {
                    EmptyView()
                }
                .isDetailLink(false)
                .hidden()
                
                // Navigation to InboxView (for individual inbox messages)
                NavigationLink(
                    destination: InboxView(),
                    isActive: $navigateToInboxView
                ) {
                    EmptyView()
                }
                .isDetailLink(false)
                .hidden()
            }
        )
        .alert("Clear Conversation", isPresented: $showClearConversationAlert) {
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    clearConversationBothSides(chat: chat)
                }
                chatToDelete = nil
            }
        } message: {
            Text("Are you sure you want to clear this conversation on both sides? This action cannot be undone.")
        }
        .task {
            // Firebase Crashlytics setup
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        }
    }
    
    // MARK: - Segmented Control Section
    private var segmentedControlSection: some View {
        VStack(spacing: 0) {
            customSegmentedControl
                .padding(.horizontal, 16)
                .padding(.vertical, 8) // Changed from 16 to 8 to match People tab spacing
                .onChange(of: selectedFilter) { newFilter in
                    AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "selectedFilter changed to: \(newFilter.rawValue)")
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Filter change will be handled by computed property
                    }
                }
        }
        .background(Color("Background Color"))
    }
    
    private var customSegmentedControl: some View {
        HStack(spacing: 0) {
            chatsTabButton
            
            // Separator line between tabs
            Divider()
                .frame(width: 1.5, height: 20)
                .overlay(Color("shade6"))
            
            inboxTabButton
        }
        .padding(4)
        .background(Color("shade1"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var chatsTabButton: some View {
        Button(action: {
            selectedFilter = .all
        }) {
            HStack(spacing: 6) {
                Image(systemName: selectedFilter == .all ? "message.fill" : "message")
                    .font(.system(size: 14, weight: selectedFilter == .all ? .semibold : .medium))
                    .foregroundColor(Color("dark"))
                
                Text("Chats")
                    .font(.system(size: 16, weight: selectedFilter == .all ? .bold : .medium))
                    .foregroundColor(Color("dark"))
                    .animation(.easeInOut(duration: 0.12), value: selectedFilter)
                
                // Badge for regular chats count - Hidden as requested (count shown in main tab badge)
                if false && viewModel.chatList.filter({ $0.newmessage }).count > 0 {
                    chatsBadge
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(selectedFilter == .all ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var inboxTabButton: some View {
        Button(action: {
            selectedFilter = .inbox
        }) {
            HStack(spacing: 6) {
                Image(systemName: selectedFilter == .inbox ? "tray.fill" : "tray")
                    .font(.system(size: 14, weight: selectedFilter == .inbox ? .semibold : .medium))
                    .foregroundColor(Color("dark"))
                
                Text("Inbox")
                    .font(.system(size: 16, weight: selectedFilter == .inbox ? .bold : .medium))
                    .foregroundColor(Color("dark"))
                    .animation(.easeInOut(duration: 0.12), value: selectedFilter)
                
                // Badge for unread inbox messages count
                if viewModel.inboxChats.filter({ $0.newmessage }).count > 0 {
                    inboxBadge
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(selectedFilter == .inbox ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    

    
    private var chatsBadge: some View {
        Text("\(viewModel.chatList.filter({ $0.newmessage }).count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
    }
    
    private var inboxBadge: some View {
        Text("\(viewModel.inboxChats.filter({ $0.newmessage }).count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
    }
    
    // MARK: - Chat List Content
    private var chatListContent: some View {
        List {
            ForEach(Array(currentChats.enumerated()), id: \.element.ChatId) { index, chat in
                ChatRowView(
                    chat: chat,
                    onTap: { handleChatTap(chat: chat) },
                    onClearConversation: { 
                        chatToDelete = chat
                        showClearConversationAlert = true
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .buttonStyle(PlainButtonStyle())
                
                // Pagination trigger
                .onAppear {
                    if index == currentChats.count - 3 {
                        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "Pagination trigger at index \(index)")
                        viewModel.loadMoreChats()
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshChats()
        }
    }
    
    // MARK: - Computed Properties
    private var currentChats: [Chat] {
        switch selectedFilter {
        case .all:
            // Show all regular chats (Inbox = 0)
            // viewModel.chatList already contains only regular chats from ChatsDB.query()
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "currentChats(.all) returning \(viewModel.chatList.count) regular chats")
            return viewModel.chatList
        case .inbox:
            // Show only inbox chats (Inbox = 1)
            // viewModel.inboxChats contains only inbox chats from ChatsDB.inboxquery()
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "currentChats(.inbox) returning \(viewModel.inboxChats.count) inbox chats")
            return viewModel.inboxChats
        }
    }
    
    // MARK: - Empty State View (Dynamic based on filter)
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .inbox ? "tray" : "message")
                .font(.system(size: 48))
                .foregroundColor(Color("shade6"))
            
            Text(selectedFilter == .inbox ? "No inbox messages" : "No chats yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("dark"))
            
            Text(selectedFilter == .inbox ? 
                 "Filtered messages will appear here" : 
                 "Start a conversation to see your chats here")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("shade6"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Android Fragment Lifecycle Management
    
    private func handleOnAppear() {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppear() Fragment onResume equivalent")
        
        fragmentState = .resumed
        
        // CRITICAL DEBUG: Check authentication state
        let userId = SessionManager.shared.userId
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppear() DEBUG: userId = \(userId ?? "nil")")
        
        // CRITICAL DEBUG: Check database state
        let isDatabaseReady = DatabaseManager.shared.isDatabaseReady()
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppear() DEBUG: isDatabaseReady = \(isDatabaseReady)")
        
        // CRITICAL FIX: Only query data if user is authenticated and database is ready
        if userId != nil && isDatabaseReady {
            isViewActive = true
            viewModel.isViewActive = true
            
            // Load initial data with proper timing
            loadInitialData()
        } else {
            // CRITICAL FIX: Initialize database if not ready
            if !isDatabaseReady {
                AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppear() Database not ready - initializing")
                DatabaseManager.shared.initializeDatabase()
            }
            
            // Retry after database initialization with exponential backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.handleOnAppearRetry(attempt: 1)
            }
        }
    }
    
    private func handleOnAppearRetry(attempt: Int) {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppearRetry() attempt \(attempt)")
        
        let userId = SessionManager.shared.userId
        let isDatabaseReady = DatabaseManager.shared.isDatabaseReady()
        
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppearRetry() DEBUG: userId = \(userId ?? "nil"), isDatabaseReady = \(isDatabaseReady)")
        
        if userId != nil && isDatabaseReady {
            isViewActive = true
            viewModel.isViewActive = true
            
            // Load initial data
            loadInitialData()
        } else if attempt < 5 {
            // Retry with exponential backoff (max 5 attempts)
            let delay = min(pow(2.0, Double(attempt)), 10.0) // Cap at 10 seconds
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppearRetry() Will retry in \(delay) seconds (attempt \(attempt + 1))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.handleOnAppearRetry(attempt: attempt + 1)
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnAppearRetry() Max retry attempts reached - giving up")
            
            // Set error state
            DispatchQueue.main.async {
                self.viewModel.hasError = true
                self.viewModel.errorMessage = "Failed to initialize database after multiple attempts"
                self.viewModel.isLoading = false
            }
        }
    }
    
    private func loadInitialData() {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "loadInitialData() Starting initial data load sequence")
        
        // TEMPORARY DEBUG: Check database contents directly
        if DatabaseManager.shared.isDatabaseReady() {
            let directRegularChats = ChatsDB.shared.query()
            let directInboxChats = ChatsDB.shared.inboxquery()
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "loadInitialData() DIRECT DB CHECK: \(directRegularChats.count) regular chats, \(directInboxChats.count) inbox chats")
            
            // Log all chats in database for debugging
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "=== ALL REGULAR CHATS IN DATABASE ===")
            for (index, chat) in directRegularChats.enumerated() {
                AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "Regular \(index): \(chat.Name) | ChatId: \(chat.ChatId) | Inbox: \(chat.inbox)")
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "=== ALL INBOX CHATS IN DATABASE ===")
            for (index, chat) in directInboxChats.enumerated() {
                AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "Inbox \(index): \(chat.Name) | ChatId: \(chat.ChatId) | Inbox: \(chat.inbox)")
            }
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "=== END DATABASE CONTENTS ===")
        }
        
        viewModel.setChats()
        viewModel.getInboxCounter()
        viewModel.getInboxPreview()
        
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "loadInitialData() Initial data load sequence completed")
    }
    
    private func handleOnDisappear() {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleOnDisappear() Fragment onPause equivalent")
        
        fragmentState = .paused
    }
    
    @MainActor
    private func refreshChats() async {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "refreshChats() Android pull-to-refresh equivalent")
        viewModel.refreshChats()
    }
    
    // MARK: - Message Limit Handling (Android Parity)
    
    private func handleChatTap(chat: Chat) {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleChatTap() handling chat tap for: \(chat.ChatId) with user: \(chat.UserId)")
        
        // Validate parameters (Android parity)
        guard !chat.ChatId.isEmpty && chat.ChatId != "null" && !chat.UserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleChatTap() invalid parameters - proceeding to messages")
            openMessages(chat: chat)
            return
        }
        
        // Check subscription type first (client-side check for quick bypass)
        if subscriptionSessionManager.isUserSubscribedToPlus() || subscriptionSessionManager.isUserSubscribedToPro() {
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleChatTap() user is premium - proceeding to messages")
            openMessages(chat: chat)
            return
        }
        
        // For now, proceed directly to messages
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "handleChatTap() MessageLimitManager not implemented yet, proceeding to messages")
        openMessages(chat: chat)
    }
    
    private func openMessages(chat: Chat) {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "openMessages() opening messages for chat: \(chat.ChatId) with user: \(chat.UserId)")
        
        guard !chat.ChatId.isEmpty && chat.ChatId != "null" && !chat.UserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "openMessages() Invalid chat data - ChatId: \(chat.ChatId), UserId: \(chat.UserId)")
            return
        }
        
        selectedChat = chat
        navigateToChat = true
        
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "openMessages() Navigation initiated for chat: \(chat.ChatId)")
    }
    
    // MARK: - Clear Conversation Functionality (Android Parity)
    
    private func clearConversationBothSides(chat: Chat) {
        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "clearConversationBothSides() clearing conversation using DeleteChatService for chat: \(chat.ChatId)")
        
        DeleteChatService.shared.deleteChat(chatId: chat.ChatId) { success in
            DispatchQueue.main.async {
                if success {
                    AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "clearConversationBothSides() DeleteChatService completed successfully")
                    // Also remove from AI chat IDs if present
                    var ids = SessionManager.shared.aiChatIds
                    let trimmed = chat.ChatId.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let index = ids.firstIndex(of: trimmed) {
                        ids.remove(at: index)
                        SessionManager.shared.aiChatIds = ids
                        AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "clearConversationBothSides() removed chatId from aiChatIds: \(trimmed)")
                    }
                    viewModel.refreshChats()
                } else {
                    AppLogger.log(tag: "LOG-APP: ChatsTabView", message: "clearConversationBothSides() DeleteChatService failed")
                }
            }
        }
    }
}

// MARK: - Chat Row View
struct ChatRowView: View {
    let chat: Chat
    let onTap: () -> Void
    let onClearConversation: () -> Void
    
    var body: some View {
            Button(action: onTap) {
                HStack(spacing: 0) {
                    // Profile Image - matching DiscoverTabView sizing and positioning
                    WebImage(url: URL(string: chat.ProfileImage)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(chat.Gender.lowercased() == "female" ? "female" : "male")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .indicator(.activity)
                    .transition(.opacity)
                        .frame(width: 65, height: 65) // Increased to match DiscoverTabView
                        .clipShape(Circle())
                        .padding(.leading, 15) // Matching DiscoverTabView
                        .padding(.top, 10) // Matching DiscoverTabView
                        .padding(.bottom, 10) // Matching DiscoverTabView
                    
                // Chat Content - centered vertically
                VStack(alignment: .leading, spacing: 4) {
                    Spacer() // Top spacer for vertical centering
                    
                    // Username
                    Text(Profanity.share.removeProfanityNumbersAllowed(chat.Name))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .lineLimit(1)
                    
                    // Last message/time
                    Text(formatLastMessage(chat))
                        .font(.system(size: 13, weight: getMessageFontWeight(for: chat)))
                        .foregroundColor(getMessageColor(for: chat))
                        .lineLimit(2)
                    
                    Spacer() // Bottom spacer for vertical centering
                }
                .padding(.leading, 20) // Matching DiscoverTabView content padding
                .padding(.trailing, 15) // Matching DiscoverTabView content padding
                            
                Spacer()
                            
                // Chat Type Icon
                getChatTypeIcon(for: chat)
                    .padding(.trailing, 20) // Matching DiscoverTabView trailing padding
                }
            .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        .background(Color("background"))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete") {
                    onClearConversation()
            }
            .tint(.red)
                    }
    }
    
    private func formatLastMessage(_ chat: Chat) -> String {
        let currentUserId = UserSessionManager.shared.userId ?? ""
        
        // Determine if the last message was sent or received by current user
        let wasSentByCurrentUser: Bool
        if let lastMessageSentByUserId = chat.lastMessageSentByUserId, !lastMessageSentByUserId.isEmpty {
            // Use the Android parity field if available
            wasSentByCurrentUser = (lastMessageSentByUserId == currentUserId)
        } else if !chat.Lastsentby.isEmpty {
            // Fallback to checking Lastsentby field
            wasSentByCurrentUser = (chat.Lastsentby == currentUserId)
        } else {
            // If no sender info available, assume received for safety
            wasSentByCurrentUser = false
        }
        
        // Create appropriate prefix based on sent/received status
        let prefix: String
        if wasSentByCurrentUser {
            // Message was sent by current user
            prefix = "Sent"
        } else {
            // Message was received from other user
            prefix = chat.newmessage ? "New Message" : "Received"
        }
        
        let timeString = formatChatTime(chat.LastTimeStamp)
        return "\(prefix) · \(timeString)"
    }
    
    private func getMessageFontWeight(for chat: Chat) -> Font.Weight {
        let messageText = formatLastMessage(chat)
        
        // Bold for new messages, medium for everything else
        if messageText.hasPrefix("New Message") {
            return .bold
        } else {
            return .medium
        }
    }
    
    private func getMessageColor(for chat: Chat) -> Color {
        let messageText = formatLastMessage(chat)
        
        // Only new messages get red color, everything else is gray
        if messageText.hasPrefix("New Message") {
            return Color("Red1")  // Red for new messages only
        } else {
            return Color("shade_600")  // Gray for all other messages (sent/received)
        }
    }
    
    private func formatChatTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 5 {
            return "now"
        }
        
        if timeInterval < 60 {
            let seconds = Int(timeInterval)
            return "\(seconds)s"
        }
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        
        if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return hours == 1 ? "1h" : "\(hours)h"
        }
        
        if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return days == 1 ? "1d" : "\(days)d"
        }
        
        if timeInterval < 2592000 {
            let weeks = Int(timeInterval / 604800)
            return weeks == 1 ? "1w" : "\(weeks)w"
        }
        
        if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return months == 1 ? "1mo" : "\(months)mo"
        }
        
        let years = Int(timeInterval / 31536000)
        return years == 1 ? "1y" : "\(years)y"
    }
    
    private func getChatTypeIcon(for chat: Chat) -> some View {
        if chat.isInbox {
            return AnyView(
                Image(systemName: "tray.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("ButtonColor"))
                    .frame(width: 42, height: 42)
                    .background(Color("ButtonColor").opacity(0.1))
                    .clipShape(Circle())
            )
            } else {
            return AnyView(
                Image(systemName: "message.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("blue"))
                    .frame(width: 42, height: 42)
                    .background(Color("blue").opacity(0.1))
                    .clipShape(Circle())
            )
        }
    }
}

#Preview {
    ChatsTabView()
}


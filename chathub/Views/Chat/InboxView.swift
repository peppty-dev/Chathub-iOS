import SwiftUI
import FirebaseFirestore

struct InboxMessage: Identifiable, Codable {
    var id: String
    var userId: String
    var name: String
    var profileImage: String
    var lastMessage: String
    var timestamp: Date
    var isRead: Bool
    var messageCount: Int
    var gender: String
    var deviceId: String
    
    init(from chat: Chat) {
        self.id = chat.ChatId
        self.userId = chat.UserId
        self.name = chat.Name
        self.profileImage = chat.ProfileImage
        self.lastMessage = chat.Lastsentby
        self.timestamp = chat.LastTimeStamp
        self.isRead = !chat.newmessage
        self.messageCount = 1
        self.gender = chat.Gender
        self.deviceId = chat.DeviceId
    }
    
    init(id: String, userId: String, name: String, profileImage: String, lastMessage: String, timestamp: Date, isRead: Bool, messageCount: Int, gender: String, deviceId: String) {
        self.id = id
        self.userId = userId
        self.name = name
        self.profileImage = profileImage
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.isRead = isRead
        self.messageCount = messageCount
        self.gender = gender
        self.deviceId = deviceId
    }
}

struct InboxView: View {
    @State private var inboxMessages: [InboxMessage] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var moveToInbox: Bool = false
    @State private var isInitialLoad: Bool = true // Track if this is initial load to prevent onChange trigger
    @State private var showChatView: Bool = false
    @State private var selectedMessage: InboxMessage?
    @State private var showProfileView: Bool = false
    @State private var selectedUserId: String = ""
    @State private var showDeleteAlert: Bool = false
    @State private var messageToDelete: InboxMessage?
    
    // Session data
    @State private var userId: String = ""
    
    var body: some View {
        mainContent
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color("Background Color"))
            .onAppear {
                AppLogger.log(tag: "LOG-APP: InboxView", message: "onAppear() InboxView opened - Android InboxActivity equivalent")
                loadUserSession()
                loadInboxSettingFromSession() // Load from SessionManager first - matching Android pattern
                Task {
                    await loadInboxMessages()
                }
                isInitialLoad = false // Mark initial load complete
                
                // Sync with Firebase in background to ensure consistency
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    syncInboxSettingWithFirebase()
                }
            }
            .onDisappear {
                AppLogger.log(tag: "LOG-APP: InboxView", message: "onDisappear() InboxView closed - Android InboxActivity finish equivalent")
            }
            .onChange(of: showChatView) { newValue in
                AppLogger.log(tag: "LOG-APP: InboxView", message: "onChange(showChatView) changed to: \(newValue)")
            }
            .background(
                VStack {
                    navigationLinkBackground
                    
                    NavigationLink(
                        destination: ProfileView(otherUserId: selectedUserId),
                        isActive: $showProfileView
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            )
            .alert("Delete Conversation", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let message = messageToDelete {
                        deleteMessage(message)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this conversation? This action cannot be undone.")
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            toggleSwitchSection
            messagesList
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var toggleSwitchSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Send all adult and inappropriate messages directly into inbox.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
                
                Toggle("", isOn: $moveToInbox)
                    .labelsHidden()
                    .scaleEffect(0.9)
                    .onChange(of: moveToInbox) { newValue in
                        // Only update Firebase if this is not the initial load - matching Android pattern
                        if !isInitialLoad {
                            updateInboxSetting(newValue)
                        }
                    }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
        }
        .background(Color("shade_100"))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var messagesList: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        } else if inboxMessages.isEmpty {
            emptyStateView
        } else {
            messagesListView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        Spacer()
        VStack(spacing: 10) {
            Text("No messages")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color("dark"))
            
            Text("Inboxed messages will appear here")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("shade8"))
                .multilineTextAlignment(.center)
        }
        Spacer()
    }
    
    @ViewBuilder
    private var messagesListView: some View {
        List {
            ForEach(Array(inboxMessages.enumerated()), id: \.element.id) { index, message in
                messageRow(message: message, index: index)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadInboxMessages()
        }
    }
    
    @ViewBuilder
    private func messageRow(message: InboxMessage, index: Int) -> some View {
        InboxMessageRow(
            message: message,
            messageCount: getMessageCount(for: index),
            onTap: {
                handleMessageLimit(chatId: message.id, otherUserId: message.userId, message: message)
            },
            onProfileTap: {
                selectedUserId = message.userId
                showProfileView = true
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete") {
                messageToDelete = message
                showDeleteAlert = true
            }
            .tint(.red)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }
    
    @ViewBuilder
    private var navigationLinkBackground: some View {
        NavigationLink(
            destination: destinationView,
            isActive: $showChatView
        ) {
            EmptyView()
        }
        .isDetailLink(false)
    }
    
    @ViewBuilder
    private var destinationView: some View {
        Group {
            if let message = selectedMessage {
                MessagesView(
                    chatId: message.id,
                    otherUser: ChatUser(
                        id: message.userId,
                        name: message.name,
                        profileImage: message.profileImage,
                        gender: message.gender,
                        deviceId: message.deviceId,
                        isOnline: true
                    ),
                    isFromInbox: true, // CRITICAL: Mark this as inbox chat for Android parity
                    onDismiss: {
                        AppLogger.log(tag: "LOG-APP: InboxView", message: "MessagesView onDismiss() called - resetting showChatView")
                        DispatchQueue.main.async {
                            showChatView = false
                            selectedMessage = nil
                        }
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadUserSession() {
        userId = SessionManager.shared.userId ?? ""
        AppLogger.log(tag: "LOG-APP: InboxView", message: "loadUserSession() userId: \(userId)")
    }
    
    private func loadInboxSettingFromSession() {
        // Load from SessionManager first - matching Android's findViews() pattern
        moveToInbox = SessionManager.shared.moveToInboxSelected
        AppLogger.log(tag: "LOG-APP: InboxView", message: "loadInboxSettingFromSession() loaded from SessionManager: \(moveToInbox)")
    }
    
    private func syncInboxSettingWithFirebase() {
        // Sync with Firebase to ensure SessionManager is up to date - matching Android pattern
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("Users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let firebaseValue = data?["move_to_inbox"] as? Bool ?? false
                
                // Update SessionManager if Firebase value is different
                if SessionManager.shared.moveToInboxSelected != firebaseValue {
                    SessionManager.shared.moveToInboxSelected = firebaseValue
                    // Update UI state without triggering onChange
                    DispatchQueue.main.async {
                        isInitialLoad = true // Temporarily set to prevent onChange trigger
                        moveToInbox = firebaseValue
                        isInitialLoad = false
                    }
                    AppLogger.log(tag: "LOG-APP: InboxView", message: "syncInboxSettingWithFirebase() synced from Firebase: \(firebaseValue)")
                } else {
                    AppLogger.log(tag: "LOG-APP: InboxView", message: "syncInboxSettingWithFirebase() already in sync: \(firebaseValue)")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: InboxView", message: "syncInboxSettingWithFirebase() no document or error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
    
    private func updateInboxSetting(_ value: Bool) {
        // Update Firebase setting - matching Android's setMoveToInbox()
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        let param: [String: Any] = ["move_to_inbox": value]
        
        db.collection("Users").document(userId).setData(param, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: InboxView", message: "updateInboxSetting() Error: \(error.localizedDescription)")
                errorMessage = "Failed to update inbox setting"
            } else {
                AppLogger.log(tag: "LOG-APP: InboxView", message: "updateInboxSetting() Success: \(value)")
                // Update local session - matching Android pattern
                SessionManager.shared.moveToInboxSelected = value
            }
        }
    }
    
    @MainActor
    private func loadInboxMessages() async {
        AppLogger.log(tag: "LOG-APP: InboxView", message: "loadInboxMessages() Starting to load inbox messages")
        
        isLoading = true
        errorMessage = nil
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: InboxView", message: "loadInboxMessages() Database not ready, skipping load")
            isLoading = false
            return
        }
        
        AppLogger.log(tag: "LOG-APP: InboxView", message: "loadInboxMessages() Loading from local database - Android equivalent")
        
        // Load from local database using ChatsDB.inboxquery() - matching Android pattern
        let inboxChats = ChatsDB.shared.inboxquery()
        
        // Convert Chat objects to InboxMessage objects
        var messages: [InboxMessage] = []
        
        for chat in inboxChats {
            let message = InboxMessage(from: chat)
            messages.append(message)
        }
        
        inboxMessages = messages
        AppLogger.log(tag: "LOG-APP: InboxView", message: "loadInboxMessages() Loaded \(messages.count) messages from local database")
        
        isLoading = false
    }
    
    private func handleMessageLimit(chatId: String, otherUserId: String, message: InboxMessage) {
        // Handle message limit - matching Android's handleMessageLimit()
        AppLogger.log(tag: "LOG-APP: InboxView", message: "handleMessageLimit() chatId: \(chatId), otherUserId: \(otherUserId)")
        
        // Validate parameters
        guard !chatId.isEmpty && !otherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: InboxView", message: "handleMessageLimit() Invalid parameters - proceeding to messages")
            openMessages(message: message)
            return
        }
        
        // Check subscription type first (client-side check for quick bypass)
        if SubscriptionSessionManager.shared.isSubscribed {
            AppLogger.log(tag: "LOG-APP: InboxView", message: "handleMessageLimit() User is premium, proceeding to messages")
            openMessages(message: message)
            return
        }
        
        // TODO: Implement MessageLimitManager equivalent for iOS
        // For now, proceed directly to messages
        AppLogger.log(tag: "LOG-APP: InboxView", message: "handleMessageLimit() MessageLimitManager not implemented yet, proceeding to messages")
        openMessages(message: message)
    }
    
    private func openMessages(message: InboxMessage) {
        // Open messages - matching Android's openMessages()
        AppLogger.log(tag: "LOG-APP: InboxView", message: "openMessages() Opening chat with \(message.name)")
        selectedMessage = message
        showChatView = true
        AppLogger.log(tag: "LOG-APP: InboxView", message: "openMessages() showChatView set to: \(showChatView)")
    }
    
    private func deleteMessage(_ message: InboxMessage) {
        // Delete conversation using DeleteChatService - matching Android's clearConversationBothSide()
        guard !userId.isEmpty else { return }
        
        AppLogger.log(tag: "LOG-APP: InboxView", message: "deleteMessage() Deleting conversation using DeleteChatService with \(message.name)")
        
        // Create chat ID from user IDs (matching Android pattern)
        let chatId = "\(userId)_\(message.userId)"
        
        // Use DeleteChatService instead of manual Firebase operations
        DeleteChatService.shared.deleteChat(chatId: chatId) { success in
            DispatchQueue.main.async {
                if success {
                    AppLogger.log(tag: "LOG-APP: InboxView", message: "deleteMessage() DeleteChatService completed successfully")
                    // Remove from local array
                    self.inboxMessages.removeAll { $0.id == message.id }
                } else {
                    AppLogger.log(tag: "LOG-APP: InboxView", message: "deleteMessage() DeleteChatService failed")
                    // Could show error message to user if needed
                }
            }
        }
    }
    
    private func getMessageCount(for index: Int) -> Int {
        return index + 1
    }
}

struct InboxMessageRow: View {
    let message: InboxMessage
    let messageCount: Int
    let onTap: () -> Void
    let onProfileTap: () -> Void
    
    var body: some View {
        // Match ChatsViewHolder structure exactly
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Profile Image (65dp as per Android ChatsViewHolder)
                Button(action: onProfileTap) {
                    AsyncImage(url: URL(string: message.profileImage)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(message.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .frame(width: 65, height: 65)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color("shade_100"), lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 15)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                // Content section - matching ChatsViewHolder structure exactly
                VStack(alignment: .leading, spacing: 5) {
                    // Username (16sp, marginTop 15dp) - matching ChatsViewHolder
                    Text(Profanity.share.removeProfanityNumbersAllowed(message.name))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .lineLimit(1)
                        .padding(.top, 15)
                    
                    // Last message/time (13sp, marginTop 5dp) - matching ChatsViewHolder
                    Text(formatInboxMessage(message))
                        .font(.system(size: 13, weight: formatInboxMessage(message).hasPrefix("New Message") ? .bold : .medium))
                        .foregroundColor(formatInboxMessage(message).hasPrefix("New Message") ? Color("Red1") : Color("shade_600"))
                        .lineLimit(2)
                        .padding(.top, 5)
                    
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.trailing, 75) // Space for icon (marginEnd 75dp)
                
                Spacer()
                
                // Inbox Icon (42dp as per Android ChatsViewHolder pattern)
                Image(systemName: "tray.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("ButtonColor"))
                    .padding(10)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color("ButtonColor").opacity(0.1))
                    )
                    .padding(.trailing, 20)
            }
            .frame(minHeight: 85) // Match ChatsViewHolder layout height
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color("background"))
    }
    
    // Format inbox message similar to ChatsViewHolder's formatLastMessage
    private func formatInboxMessage(_ message: InboxMessage) -> String {
        let prefix = message.isRead ? "Received" : "New Message"
        let timeString = formatChatTime(message.timestamp)
        return "\(prefix) · \(timeString)"
    }
    
    // Use the same time formatting as ChatsViewHolder - EXACT PARITY
    private func formatChatTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // Less than 5 seconds
        if timeInterval < 5 {
            return "now"
        }
        
        // Less than a minute
        if timeInterval < 60 {
            let seconds = Int(timeInterval)
            return "\(seconds)s"
        }
        
        // Less than an hour
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        
        // Less than a day
        if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return hours == 1 ? "1h" : "\(hours)h"
        }
        
        // Less than a week
        if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return days == 1 ? "1d" : "\(days)d"
        }
        
        // Less than a month
        if timeInterval < 2592000 {
            let weeks = Int(timeInterval / 604800)
            return weeks == 1 ? "1w" : "\(weeks)w"
        }
        
        // Less than a year
        if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return months == 1 ? "1mo" : "\(months)mo"
        }
        
        // More than a year
        let years = Int(timeInterval / 31536000)
        return years == 1 ? "1y" : "\(years)y"
    }
}

#Preview {
    InboxView()
}
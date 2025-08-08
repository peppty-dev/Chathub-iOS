import SwiftUI
import FirebaseFirestore
import AVFoundation
import AgoraRtcKit
import AVFAudio
import PhotosUI



struct MessagesView: View {
    let chatId: String
    let otherUser: ChatUser
    let sessionManager: SessionManager
    let isFromInbox: Bool // NEW: Track if this chat was opened from inbox
    var onDismiss: (() -> Void)? = nil
    
    init(chatId: String, otherUser: ChatUser, sessionManager: SessionManager = SessionManager.shared, isFromInbox: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.chatId = chatId
        self.otherUser = otherUser
        self.sessionManager = sessionManager
        self.isFromInbox = isFromInbox
        self.onDismiss = onDismiss
    }
    
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var badgeManager = InAppNotificationBadgeManager.shared
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText: String = ""
    @State private var textHeight: CGFloat = 44 // Dynamic height for single-line start
    @State private var isLoading: Bool = true
    @State private var isTyping: Bool = false
    @State private var isOtherUserTyping: Bool = false

    @State private var isRecording: Bool = false

    // Text editor focus state
    @FocusState private var isTextEditorFocused: Bool

    @State private var showSubscriptionPopup: Bool = false
    @State private var showInterestStatus: Bool = false
    @State private var fullScreenImageURL: String = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    // Entry Pill (Always-on-entry alternating prompt)
    private enum EntryPillContent {
        case interest(phrase: String)
        case aboutYou(key: String, question: String)
    }
    @State private var entryPill: EntryPillContent? = nil
    @State private var aboutYouValues: [String: String] = [:]

    
    // MARK: - Call Implementation (Android Parity)
    @State private var showVoiceCallPopup: Bool = false
    @State private var showVideoCallPopup: Bool = false
    @State private var showLiveCallPopup: Bool = false
    @State private var showPermissionDialog: Bool = false
    @State private var showMakeCall: Bool = false
    @State private var permissionDialogType: PermissionType = .microphone
    @State private var showBusyToast: Bool = false
    
    // Status and Interests Section (Android Parity)
    @State private var currentUserStatus: String = "    " // Initialize with placeholder spaces to maintain view space
    
    // Animation state variables for smooth status transitions
    @State private var statusAnimationScale: CGFloat = 1.0
    @State private var statusAnimationOpacity: Double = 1.0
    @State private var previousStatusText: String = ""
    @State private var animationTrigger: Bool = false
    
    // Direct call states (Android Parity)
    @State private var isLiveOn: Bool = false
    @State private var liveTimer: Timer? = nil
    
    // Direct call UI states for enhanced overlay
    @StateObject private var liveManager = LiveCallManager()
    @State private var liveOverlayHeight: CGFloat = 0
    

    
    // AI Chat Integration
    @State private var isAIChat: Bool = false
    @State private var lastAIMessage: String = ""
    @State private var aiStatus: String = "offline"
    @State private var aiTypingTimer: Timer? = nil
    @State private var aiStatusTimer: Timer? = nil
    
    // Notification Permission Integration (New)
    @State private var showNotificationPermissionPopup: Bool = false
    @State private var hasShownNotificationPopup: Bool = false
    
    // MARK: - Message Limit State
    @State private var showMessageLimitPopup = false
    @State private var messageLimitResult: FeatureLimitResult?
    
    // Message pagination
    @State private var fetchAfter: String = ""
    @State private var isLoadingMore: Bool = false
    @State private var lastMessageIdBeforeLoad: String = "" // Track scroll position during pagination
    @State private var isFirstLoad: Bool = true // Track if this is the first load to ensure scroll to bottom
    
    // Firebase listeners
    @State private var messageListener: ListenerRegistration? = nil
    @State private var typingListener: ListenerRegistration? = nil
    @State private var statusListener: ListenerRegistration? = nil
    @State private var blockListener: ListenerRegistration? = nil
    @State private var liveListener: ListenerRegistration? = nil
    // Tracks known seen state by message ID to survive DB reloads
    @State private var messageSeenMap: [String: Bool] = [:]
    
    // Agora video/voice call integration
    @State private var agoraEngine: AgoraRtcEngineKit? = nil
    @State private var isInCall: Bool = false
    @State private var isVideoCall: Bool = false
    
    // Other user details
    @State private var otherUserInterests: [String] = []
    @State private var otherUserLastSeen: Date? = nil
    @State private var otherUserHereEnterTime: Date? = nil
    @State private var otherUserHereLeaveTime: Date? = nil
    @State private var otherUserIsOnline: Bool = false
    @State private var otherUserChattingInCurrentChat: Bool = false
    
    // Message sending restrictions
    @State private var canSendMessage: Bool = true
    
    // MARK: - Android Parity: Conversation Tracking
    @State private var conversationStarted: Bool = false
    @State private var moveToInbox: Bool = false
    @State private var messageSentThisSession: Bool = false // Android Parity: Track if message was sent (like MSGSENT)
    
    @State private var hasFullyAppeared: Bool = false
    @State private var isViewBeingDismissed: Bool = false
    
    // Current user session
    private var currentUserId: String {
        UserSessionManager.shared.userId ?? ""
    }
    
    private var currentUserName: String {
        UserSessionManager.shared.userName ?? ""
    }
    
    private var currentDeviceId: String {
        UserSessionManager.shared.deviceId ?? ""
    }
    
    private var isPremiumUser: Bool {
        MessagingSettingsSessionManager.shared.premiumActive
    }
    
    // Subscription status
    private var isProSubscriber: Bool {
        MessagingSettingsSessionManager.shared.premiumActive
    }
    
    // MARK: - View Components
    
    @State private var showUserProfile: Bool = false
    @State private var showProfileOptions: Bool = false
    @State private var navigateToInfiniteXOGame: Bool = false
    @State private var showVideoCall: Bool = false
    @State private var showAudioCall: Bool = false
    @State private var showSubscriptionView: Bool = false
    @State private var showFullScreenImage: Bool = false
    @State private var showImagePicker: Bool = false
    
    // State for sheet presentation
    private enum ActiveSheet: Identifiable {
        case videoCall, makeCall, imagePicker, subscription, fullScreenImage
        var id: Self { self }
    }
    @State private var activeSheet: ActiveSheet?
    
    @ViewBuilder
    private var ongoingCallView: some View {
        if isInCall {
            OngoingCallBarView(
                isVideoCall: isVideoCall,
                otherUserName: otherUser.name,
                onTapToView: {
                    // Navigate to the ongoing call view
                    if isVideoCall {
                        showVideoCall = true
                    } else {
                        showAudioCall = true
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var liveOverlayView: some View {
        if isLiveOn {
            LiveOverlayView(
                isLocalActive: isLiveOn,
                isRemoteActive: true, // Will be updated based on Firebase status
                isLocalSpeaking: liveManager.isLocalSpeaking,
                isRemoteSpeaking: liveManager.isRemoteSpeaking,
                localVideoView: liveManager.localVideoView,
                remoteVideoView: liveManager.remoteVideoView,
                isVideoEnabled: liveManager.isVideoEnabled,
                isMuted: liveManager.isMuted,
                otherUserName: otherUser.name,
                onCameraSwitch: { handleCameraSwitchButtonTap() },
                onVideoToggle: { handleVideoToggleButtonTap() },
                onMute: { handleMuteButtonTap() }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    liveOverlayHeight = 200
                }
            }
            .onDisappear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    liveOverlayHeight = 0
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)))
        }
    }
    

    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {  // Reduced spacing between bubbles to 2 points
                    // Show loading indicator at the top when loading more messages
                    if isLoadingMore {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading messages...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("shade6"))
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .id("loadingIndicator")
                        .flippedUpsideDown() // Flip loading indicator too
                    }
                    
                    // ANDROID PARITY: Use inverted scroll pattern for chat behavior
                    // Messages are sorted DESC, display in same order but flip the entire ScrollView
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let bottomPadding: CGFloat = (index < messages.count - 1 && messages[index].isFromCurrentUser != messages[index + 1].isFromCurrentUser) ? 10 : 2
                        EnhancedMessageBubbleView(
                            message: message,
                            currentUserId: currentUserId,
                            previousMessage: index > 0 ? messages[index - 1] : nil,
                            nextMessage: index < messages.count - 1 ? messages[index + 1] : nil
                        )
                        .flippedUpsideDown() // Flip each message back to normal orientation
                        .id(message.id)
                        .onTapGesture {
                            // Android Pattern: Only handle tap for image messages
                            if let imageUrl = message.imageUrl, !imageUrl.isEmpty {
                                AppLogger.log(tag: "LOG-APP: MessagesView", message: "Image message tapped - opening PhotoViewerView")
                                fullScreenImageURL = imageUrl
                                showFullScreenImage = true
                            }
                        }
                        .onAppear {
                            // Load more messages when approaching the top (older messages)
                            if index <= 5 {
                                AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesList onAppear() Approaching top - could load older messages (index: \(index))")
                                // In full implementation, this would fetch older messages from Firebase
                            }
                        }
                        .padding(.bottom, bottomPadding)
                    }
                }
                .padding(.vertical, 8)
            }
            .flippedUpsideDown() // Flip the entire ScrollView for inverted scrolling
            .onAppear {
                // Ensure scroll to bottom on initial appearance without delay
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onAppear() - scrolling to bottom")
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { oldCount in
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onChange() messages count changed from \(oldCount) to \(messages.count), isFirstLoad: \(isFirstLoad)")
                
                // ANDROID PARITY: With inverted scroll, scroll to first message (newest) which appears at bottom
                if (oldCount == 0 && !messages.isEmpty) || isFirstLoad {
                    // Initial load - always scroll to bottom (latest messages) without delay
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onChange() Initial load - scrolling to bottom")
                    scrollToBottom(proxy: proxy)
                    isFirstLoad = false // Mark first load as complete
                } else if messages.count > oldCount {
                    // New messages added - always scroll to bottom to show new message without delay
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onChange() New messages added - scrolling to bottom")
                    scrollToBottom(proxy: proxy)
                } else if !lastMessageIdBeforeLoad.isEmpty {
                    // Pagination occurred - maintain scroll position without delay
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onChange() Pagination - maintaining scroll position")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessageIdBeforeLoad, anchor: .top)
                    }
                    lastMessageIdBeforeLoad = "" // Reset after use
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping on messages area
                isTextEditorFocused = false
            }
        }
    }
    
    // Removed loadMoreMessagesButton - replaced with seamless scrolling

    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            // Always-on-entry pill shown above status/tags
            if let pill = entryPillView {
                pill
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)))
            }

            statusAndInterestsView

            // Inline suggestion pill above composer (still supported after send)
            if entryPill == nil, let pill = pendingInterestSuggestion {
                HStack {
                    InterestSuggestionPill(text: pill) {
                        acceptInterestSuggestion(pill)
                    } onReject: {
                        rejectInterestSuggestion(pill)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)))
            }

            inputBarView
        }
    }
    
    // MARK: - Status and Interests Section (Android Parity)
    
    @ViewBuilder
    private var statusAndInterestsView: some View {
        // Always show the container like Android layout - prevents layout jumps
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 7) { // Center alignment for consistent height views - matching live button spacing
                statusBlobView
                
                // Display interest tags directly beside status
                ForEach(getInterestTags(), id: \.self) { interest in
                    Text(interest.interestDisplayFormatted)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color("shade6"))
                        .frame(height: 37)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("shade2"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color("shade3"), lineWidth: 0.5)
                                )
                        )
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 10)
        .padding(.bottom, 5)
        .background(Color("Background Color"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color("shade3"))
                .opacity(0.3),
            alignment: .top
        )
        // Smooth content transitions only (not container appearance/disappearance)
        .animation(.easeInOut(duration: 0.3), value: currentUserStatus)
        .animation(.easeInOut(duration: 0.3), value: otherUserInterests)
    }
    
    @ViewBuilder
    private var statusBlobView: some View {
        // ANDROID PARITY: Status is always visible like live button (no empty state check)
        // currentUserStatus is initialized with placeholder and updated by Firebase
        HStack {
            Text(capitalizeWords(currentUserStatus))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(getStatusTextColor())
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .frame(height: 37) // Fixed height matching live button
        .frame(minWidth: 50) // Always apply minimum width to match live button consistency
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(getStatusGradient())
        )
        // Android Parity: Scale animation like here_pop_in.xml
        .scaleEffect(statusAnimationScale)
        .opacity(statusAnimationOpacity)
        // Smooth transitions for size changes when text changes
        .animation(.easeInOut(duration: 0.3), value: currentUserStatus)
        // Color transition animation using animation trigger
        .animation(.easeInOut(duration: 0.25), value: animationTrigger)
        // Scale animation trigger
        .animation(.easeOut(duration: 0.15), value: statusAnimationScale)
        .onChange(of: currentUserStatus) { newStatus in
            performStatusChangeAnimation(newStatus: newStatus)
        }
    }
    

    

    
    private var inputBarView: some View {
        HStack(alignment: .bottom, spacing: 7) { // Restored .bottom alignment for proper button positioning
            // Live button always visible
            liveButton
            // gamesButton - Hidden as per requirement 
            textInputFieldWithPhotoIcon
            sendButton
        }
        .padding(.horizontal, 10)
        .padding(.top, 5)
        .padding(.bottom, 10)
        .background(Color("Background Color"))
        .animation(.easeInOut(duration: 0.2), value: isTextEditorFocused) // Smooth transition animation
    }
    
    // MARK: - Live Button (Android Parity)
    
    private var liveButton: some View {
        Button(action: { handleLiveButtonTap() }) {
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 47, height: 37)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isLiveOn ? 
                            // Red gradient when activated
                            LinearGradient(
                                colors: [Color("ErrorRed"), Color("ErrorRed").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            // Plus subscription gradient when not activated
                            LinearGradient(
                                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }
    
    private var gamesButton: some View {
        Button(action: { handleGamesButtonTap() }) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("shade6"))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color("shade3"))
                        .opacity(0.4)
                )
        }
        .opacity(0.8)
    }
    

    
    private var imageButton: some View {
        Button(action: handleImageButtonTap) {
            Image(systemName: "photo")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("shade6"))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color("shade3"))
                        .opacity(0.4)
                )
        }
        .opacity(0.8)
    }
    
    private var textInputFieldWithPhotoIcon: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("shade2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("shade3"), lineWidth: 0.5)
                )
            
            HStack(alignment: .bottom, spacing: 0) {
                // Text input area
                ZStack(alignment: .topLeading) {
                    // Placeholder text (shown when TextEditor is empty)
                    if messageText.isEmpty {
                        HStack {
                            Text("Message...")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color("shade6"))
                                .padding(.leading, 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                    }
                    
                    // iOS 14+ compatible multi-line TextEditor with dynamic height - starts as single line
                    Group {
                        if #available(iOS 16.0, *) {
                            TextEditor(text: $messageText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color("dark"))
                                .autocorrectionDisabled(false) // Android Parity: textAutoCorrect enabled
                                .textInputAutocapitalization(.sentences) // Android Parity: textCapSentences
                                .frame(height: textHeight) // Dynamic height - starts at calculated height
                                .padding(.leading, 10)
                                .padding(.trailing, 4) // Minimal padding to photo button
                                .padding(.vertical, 2)
                                .background(Color.clear)
                                .scrollContentBackground(.hidden) // iOS 16+ transparent background
                                .focused($isTextEditorFocused)
                        } else {
                            TextEditor(text: $messageText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color("dark"))
                                .autocorrectionDisabled(false) // Android Parity: textAutoCorrect enabled
                                .textInputAutocapitalization(.sentences) // Android Parity: textCapSentences
                                .frame(height: textHeight) // Dynamic height - starts at calculated height
                                .padding(.leading, 10)
                                .padding(.trailing, 4) // Minimal padding to photo button
                                .padding(.vertical, 2)
                                .background(Color.clear)
                                .focused($isTextEditorFocused)
                                // iOS 14-15 use UITextView.appearance() from AppDelegate
                        }
                    }
                        .onChange(of: messageText) { newText in
                            updateTextHeight(for: newText)
                            handleTyping()
                        }
                }
                
                // Photo button inside the rounded rectangle on the right
                Button(action: handleImageButtonTap) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("shade6"))
                        .frame(width: 36, height: 36)
                }
                .padding(.trailing, 4)
                .padding(.bottom, 2) // Stick to bottom with small padding
            }
        }
        .frame(height: textHeight) // Container matches text height
    }
    
   
    
    private var sendButton: some View {
        Button(action: {
            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "Empty message - cannot send")
            } else {
                handleSendMessage()
            }
        }) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(45)) // Rotate to point right
                .offset(x: -2) // Move slightly to the left for better centering
                .frame(width: 37, height: 37)
                .background(
                    Circle()
                        .fill(canSendMessage ? 
                            // Blue gradient matching online status pattern
                            LinearGradient(
                                colors: [Color("ColorAccent").opacity(0.7), Color("ColorAccent")],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ) : 
                            // Disabled state - solid gray
                            LinearGradient(
                                colors: [Color("shade4"), Color("shade4")],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                )
        }
        .disabled(!canSendMessage)
        .opacity(canSendMessage ? 1.0 : 0.7)
    }

    // MARK: - Popup Overlays
    
    @ViewBuilder
    private var popupOverlays: some View {
        // Voice Call popup overlay (Android Parity)
        if showVoiceCallPopup {
            VoiceCallPopupView(
                isPresented: $showVoiceCallPopup,
                onSubscribe: { navigateToSubscription() }
            )
        }
        
        // Video Call popup overlay (Android Parity)
        if showVideoCallPopup {
            VideoCallPopupView(
                isPresented: $showVideoCallPopup,
                onSubscribe: { navigateToSubscription() }
            )
        }
        
        // Live Call popup overlay (Android Parity)
        if showLiveCallPopup {
            LiveCallPopupView(
                isPresented: $showLiveCallPopup,
                onSubscribe: { navigateToSubscription() }
            )
        }
    }
    
    @ViewBuilder
    private var toastOverlays: some View {
        // Toast overlay
        if showToast {
            VStack {
                Spacer()
                Text(toastMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
        
        // Busy toast overlay
        if showBusyToast {
            VStack {
                Spacer()
                Text("User is busy in another call")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showBusyToast = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            ongoingCallView
            liveOverlayView
            messagesScrollView
            messageInputView
        }
        .animation(.easeInOut(duration: 0.3), value: isLiveOn)
    }

    @ViewBuilder
    private var overlayViews: some View {
        Group {
            // Rating popup removed from MessagesView - now shown in MainView when returning
            
            // MARK: - Notification Permission Popup Overlay (Contextual Request)
            if showNotificationPermissionPopup {
                AppNotificationPermissionPopupView(
                    isPresented: $showNotificationPermissionPopup,
                    onAllow: {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup onAllow() User agreed to allow notifications")
                        
                        // Handle both first-time and retry scenarios
                        if AppNotificationPermissionService.shared.shouldShowRetryPopup() {
                            // This is a retry scenario
                            AppNotificationPermissionService.shared.requestRetryPermission(
                                context: "after_message_engagement"
                            ) { granted in
                                AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup retry iOS permission result: \(granted)")
                                showNotificationPermissionPopup = false
                                
                                if granted {
                                    // Reset retry mechanism on success
                                    AppNotificationPermissionService.shared.resetRetryMechanism()
                                }
                            }
                        } else {
                            // First-time request - Use FCMTokenUpdateService for contextual token update
                            FCMTokenUpdateService.shared.requestPermissionAndUpdateToken(
                                context: "after_first_message"
                            ) { success in
                                AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup FCM token update result: \(success)")
                                showNotificationPermissionPopup = false
                                
                                if success {
                                    // Reset retry mechanism on success
                                    AppNotificationPermissionService.shared.resetRetryMechanism()
                                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup FCM token updated successfully")
                                } else {
                                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup FCM token update failed, but user can continue chatting")
                                }
                            }
                        }
                    },
                    onMaybeLater: {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notificationPermissionPopup onMaybeLater() User chose maybe later")
                        
                        // Handle "maybe later" with retry mechanism
                        AppNotificationPermissionService.shared.handleMaybeLaterResponse(context: "after_first_message")
                        
                        showNotificationPermissionPopup = false
                        hasShownNotificationPopup = true // Mark as shown to prevent showing again in this session
                    }
                )
                .zIndex(1000) // Ensure it appears above all other content
            }
            
            // MARK: - Interests Popup Overlay (Android Parity)
            // Removed full-screen InterestsPopupView
            
            // MARK: - Message Limit Popup Overlay
            if showMessageLimitPopup, let result = messageLimitResult {
                MessageLimitPopupView(
                    isPresented: $showMessageLimitPopup,
                    remainingCooldown: result.remainingCooldown,
                    isLimitReached: result.currentUsage >= result.limit,
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    onUpgradeToPremium: { 
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "MessageLimitPopup navigating to subscription")
                        navigateToSubscription() 
                    }
                )
                .zIndex(998) // Below notification popup but above other content
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        // Back button + badge + username with controlled spacing and centered alignment
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 0) {
                // Back chevron
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color("ColorAccent"))
                }
                .buttonStyle(PlainButtonStyle())

                // Chats badge immediately next to chevron (no gap)
                if badgeManager.chatsBadgeCount > 0 {
                    BadgeView(count: badgeManager.chatsBadgeCount)
                        .padding(.leading, 0)
                }

                // Username with larger gap from badge
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "username tapped - navigating to profile for user: \(otherUser.name)")
                    showUserProfile = true
                }) {
                    Text(isAIChat ? "\(otherUser.name)." : otherUser.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("dark"))
                        .padding(.leading, 12) // larger spacing between badge and username
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        
        // Voice call button (Android Parity Implementation)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { handleVoiceCallButtonTap() }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color("ColorAccent"))
            }
        }
        
        // Video call button (Android Parity Implementation)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { handleVideoCallButtonTap() }) {
                Image(systemName: "video.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color("ColorAccent"))
            }
        }
        
        // Info/options button
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "info button tapped - navigating to profile options")
                showProfileOptions = true
            }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color("ColorAccent"))
            }
        }
    }

    @ViewBuilder
    private var navigationLinks: some View {
        VStack {
            NavigationLink(
                destination: ProfileView(otherUserId: otherUser.id),
                isActive: $showUserProfile
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: ProfileOptionsView(
                    otherUserId: otherUser.id,
                    otherUserName: otherUser.name,
                    otherUserDevId: otherUser.deviceId,
                    otherUserGender: otherUser.gender,
                    chatId: chatId,
                    onConversationCleared: {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "ProfileOptionsView onConversationCleared() - conversation cleared, dismissing MessagesView")
                        // Dismiss MessagesView and go back to previous view (ChatsTabView or ProfileView)
                        DispatchQueue.main.async {
                            self.onDismiss?()
                        }
                    }
                ),
                isActive: $showProfileOptions
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: InfiniteXOGameView(
                    chatId: chatId,
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    otherUserId: otherUser.id,
                    otherUserName: otherUser.name
                ),
                isActive: $navigateToInfiniteXOGame
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: MakeVideoCallView(
                    otherUserId: otherUser.id,
                    otherUserName: otherUser.name,
                    otherUserProfileImage: otherUser.profileImage,
                    chatId: chatId
                ),
                isActive: $showVideoCall
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: MakeAudioCallView(
                    otherUserId: otherUser.id,
                    otherUserName: otherUser.name,
                    otherUserProfileImage: otherUser.profileImage,
                    otherUserGender: otherUser.gender,
                    chatId: chatId
                ),
                isActive: $showAudioCall
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: SubscriptionView(),
                isActive: $showSubscriptionView
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: PhotoViewerView(
                    imageUrl: fullScreenImageURL,
                    imageUserId: otherUser.id,
                    imageType: "chat_image"
                ),
                isActive: $showFullScreenImage
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: FeedbackView(),
                isActive: Binding<Bool>(
                    get: { RatingService.shared.navigateToFeedback },
                    set: { _ in RatingService.shared.navigateToFeedback = false }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    var body: some View {
        ZStack {
            mainContent
            popupOverlays
            toastOverlays
        }
        .overlay(overlayViews)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent() }
        .alert("Permission Required", isPresented: $showPermissionDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Give Permission") {
                requestPermission()
            }
        } message: {
            Text(getPermissionDialogText())
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoLibraryPicker { image in
                self.handleImageSelected(image)
                self.showImagePicker = false
            }
        }
        .background(navigationLinks)
        .task {
            await setupView()
        }
        .onAppear(perform: handleViewAppear)
        .onDisappear(perform: handleViewDisappear)
    }
    
    // MARK: - Lifecycle Methods
    
    private func handleViewAppear() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "MessagesView onAppear() - ensuring scroll to bottom for latest messages")
        
        // Reset dismissal flags
        isViewBeingDismissed = false
        hasFullyAppeared = false
        
        // Initialize text input height to calculated single line height (Progressive Growth Pattern)
        textHeight = calculateTextHeight(for: "")
        
        // ANDROID PARITY: Ensure status is visible immediately like live button
        if currentUserStatus.isEmpty || currentUserStatus == "Connecting..." || currentUserStatus == "    " {
            setInitialStatus()
        }
        
        // ANDROID PARITY: Load move to inbox flag from user profile
        loadMoveToInboxFlag()
        
        // Set flag to indicate view has fully appeared after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            hasFullyAppeared = true
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "MessagesView onAppear() - hasFullyAppeared set to true")
        }
        
        // Ensure scroll to bottom after a short delay to allow UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !messages.isEmpty {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "MessagesView onAppear() - triggering scroll to bottom with \(messages.count) messages")
            }
        }

        // Prepare entry pill content (alternates between Category A and B)
        loadAboutYouCacheAndPrepareEntryPill()

        // Update "here" status so other devices can detect we're in this chat (Android parity)
        updateHereStatus(isActive: true)
    }

    private func loadAboutYouCacheAndPrepareEntryPill() {
        let uid = UserSessionManager.shared.userId ?? ""
        guard !uid.isEmpty else { prepareEntryPill(); return }
        Firestore.firestore().collection("Users").document(uid).getDocument { doc, _ in
            var values: [String: String] = [:]
            if let data = doc?.data() {
                let keys = [
                    "married", "children", "smokes", "drinks",
                    "voice_allowed", "video_allowed", "pics_allowed"
                ]
                for k in keys {
                    if let v = data[k] as? String { values[k] = v }
                }
            }
            self.aboutYouValues = values
            self.prepareEntryPill()
            // If we showed something previously and the user ignored it, rotate to next on re-entry
            if self.entryPill == nil { self.prepareEntryPill() }
        }
    }
    
    private func handleViewDisappear() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() called - hasFullyAppeared: \(hasFullyAppeared), isViewBeingDismissed: \(isViewBeingDismissed)")
        
        // Prevent immediate cleanup if view hasn't fully appeared yet
        guard hasFullyAppeared else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() View hasn't fully appeared yet, skipping cleanup")
            return
        }
        
        // A sheet or navigation link is being presented, don't clean up.
        // This is a workaround for an issue where presenting a sheet/link causes the view to be popped.
        if showImagePicker || showUserProfile || showProfileOptions || navigateToInfiniteXOGame ||
           showVideoCall || showAudioCall || showSubscriptionView || showFullScreenImage {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Sheet/popup is active, skipping cleanup")
            return
        }
        
        // Prevent multiple cleanup calls
        guard !isViewBeingDismissed else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Already being dismissed, skipping cleanup")
            return
        }
        
        isViewBeingDismissed = true

        // Clear "here" status when leaving this chat
        updateHereStatus(isActive: false)
    
        // Otherwise, the view is likely being popped.
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Performing cleanup and dismissal")
        cleanupView()
        
        // Only call onDismiss if we have a dismiss callback AND the view has fully appeared
        // This prevents premature dismissal callbacks that cause navigation issues
        if onDismiss != nil && hasFullyAppeared {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Calling onDismiss callback")
            DispatchQueue.main.async {
                onDismiss?()
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Skipping onDismiss - hasFullyAppeared: \(hasFullyAppeared), onDismiss: \(onDismiss != nil)")
        }
        
        // ANDROID PARITY: Check and show rating dialog when returning from message activity
        // This matches Android MainActivity.onActivityResult() for MESSAGE_TEXT_ACTIVITY_REQUEST_CODE
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "onDisappear() Checking rating conditions after message activity")
        RatingService.shared.checkAndShowRatingDialogIfNeeded()
    }
    
    // MARK: - Call Button Handlers (Android Parity)
    
    private func handleVoiceCallButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleVoiceCallButtonTap() Voice call button tapped")
        
        // Check microphone permission first (matching Android)
        if !hasPermission(for: .microphone) {
            permissionDialogType = .microphone
            showPermissionDialog = true
            return
        }
        
        // Check subscription status - calls require Plus or Pro (matching Android)
        let subscriptionManager = SubscriptionSessionManager.shared
        let isPlusSubscriber = subscriptionManager.isUserSubscribedToPlus()
        let isProSubscriber = subscriptionManager.isUserSubscribedToPro()
        
        if isPlusSubscriber || isProSubscriber {
            // Directly initiate voice call after checking if user is busy
            checkCallBusy { isBusy in
                DispatchQueue.main.async {
                    if isBusy {
                        self.showBusyToast = true
                    } else {
                        self.initiateActualCall(isVideo: false)
                    }
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "User needs Plus/Pro subscription for voice calls. Showing voice call popup.")
            showVoiceCallPopup = true
        }
    }
    
    private func handleVideoCallButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleVideoCallButtonTap() Video call button tapped")
        
        // Check microphone and camera permissions (matching Android)
        if !hasPermission(for: .microphone) || !hasPermission(for: .camera) {
            permissionDialogType = .microphoneAndCamera
            showPermissionDialog = true
            return
        }
        
        // Check subscription status - video calls require Plus or Pro (matching Android)
        let subscriptionManager = SubscriptionSessionManager.shared
        let isPlusSubscriber = subscriptionManager.isUserSubscribedToPlus()
        let isProSubscriber = subscriptionManager.isUserSubscribedToPro()
        
        if isPlusSubscriber || isProSubscriber {
            // Directly initiate video call after checking if user is busy
            checkCallBusy { isBusy in
                DispatchQueue.main.async {
                    if isBusy {
                        self.showBusyToast = true
                    } else {
                        self.initiateActualCall(isVideo: true)
                    }
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "User needs Plus/Pro subscription for video calls. Showing video call popup.")
            showVideoCallPopup = true
        }
    }
    
    private func checkCallBusy(completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkCallBusy() Checking if other user is busy")
        
        // Check VideoCall collection for other user
        Firestore.firestore()
            .collection("VideoCall")
            .document(otherUser.id)
            .getDocument { document, error in
                if let document = document, document.exists {
                    let data = document.data()
                    let callEnded = data?["call_ended"] as? Bool ?? true
                    completion(!callEnded) // User is busy if call hasn't ended
                } else {
                    completion(false) // No ongoing call, user is free
                }
            }
    }
    
    private func initiateActualCall(isVideo: Bool) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "initiateActualCall() Initiating \(isVideo ? "video" : "audio") call")
        
        if isVideo {
            showVideoCall = true
        } else {
            showAudioCall = true
        }
        
        isInCall = true
        isVideoCall = isVideo
    }
    
    // MARK: - Permission Management (Android Parity)
    
    private func hasPermission(for type: PermissionType) -> Bool {
        switch type {
        case .microphone:
            return AVAudioSession.sharedInstance().recordPermission == .granted
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphoneAndCamera:
            return hasPermission(for: .microphone) && hasPermission(for: .camera)
        }
    }
    
    private func requestPermission() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "requestPermission() type: \(permissionDialogType)")
        
        switch permissionDialogType {
        case .microphone:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.handleVoiceCallButtonTap()
                    }
                }
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.handleVideoCallButtonTap()
                    }
                }
            }
        case .microphoneAndCamera:
            AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                if audioGranted {
                    AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                        if videoGranted {
                            DispatchQueue.main.async {
                                self.handleVideoCallButtonTap()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getPermissionDialogText() -> String {
        switch permissionDialogType {
        case .microphone:
            return "Microphone permission is required to start a voice call"
        case .camera:
            return "Camera permission is required to start a video call"
        case .microphoneAndCamera:
            return "Camera and microphone permissions are required to start a video call"
        }
    }
    
    // MARK: - Navigation Helper
    
    private func navigateToSubscription() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "navigateToSubscription() Navigating to subscription view")
        showSubscriptionView = true
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Setup and Cleanup
    
    @MainActor
    private func setupView() async {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupView() Setting up message view for chat: \(chatId)")
        
        // CRITICAL FIX: Ensure database is ready before proceeding
        if !DatabaseManager.shared.isDatabaseReady() {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupView() Database not ready - initializing and waiting")
            
            // Initialize database
            DatabaseManager.shared.initializeDatabase()
            
            // Wait for database to be ready with timeout
            var attempts = 0
            while !DatabaseManager.shared.isDatabaseReady() && attempts < 10 {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupView() Waiting for database initialization - attempt \(attempts + 1)")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                attempts += 1
            }
            
            if !DatabaseManager.shared.isDatabaseReady() {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupView() CRITICAL ERROR: Database failed to initialize after 5 seconds")
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupView() Database ready after \(attempts + 1) attempts")
            }
        }
        
        setupAIChat()
        setupSession()
        
        // ANDROID PARITY: Set initial status immediately like live button - no delay
        setInitialStatus()
        
        await loadMessages()
        setupFirebaseListeners()
        fetchOtherUserDetails()
        
        if isAIChat {
            startAIStatusSimulation()
        }
        
        // Show interest status after 1 hour (Android parity)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) {
            showInterestStatus = true
        }
    }
    
    private func cleanupView() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "cleanupView() Cleaning up message view")
        
        removeFirebaseListeners()
        
        aiTypingTimer?.invalidate()
        aiStatusTimer?.invalidate()
        
        // Cleanup direct call timers (Android Parity)
        liveTimer?.invalidate()
        
        // Stop live calls if active (Android Parity)
        if isLiveOn {
            stopLive()
        }
        
        // Cleanup LiveManager
        liveManager.cleanup()
        
        // Image picker cleanup is handled by SwiftUI sheet presentation
        
        // Cleanup Agora if in call
        if isInCall {
            agoraEngine?.leaveChannel(nil)
            AgoraRtcEngineKit.destroy()
        }
    }
    
    // MARK: - AI Chat Setup
    
    private func setupAIChat() {
        let aiChatIds = sessionManager.aiChatIds
        isAIChat = aiChatIds.contains(chatId)
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAIChat() isAIChat set to: \(isAIChat)")
    }
    
    // ANDROID PARITY: Set initial status immediately when view loads (like live button)
    private func setInitialStatus() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInitialStatus() Setting initial status for immediate display")
        
        if isAIChat {
            // AI chats start with "Online" status
            currentUserStatus = "Online"
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInitialStatus() AI chat - set to Online")
        } else {
            // Regular chats start with placeholder spaces until Firebase updates
            currentUserStatus = "    "
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInitialStatus() Regular chat - set to placeholder spaces")
        }
    }
    
    private func setupSession() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupSession() Session setup complete")
        
        // CRITICAL: Mark messages as read when opening chat (Android Parity)
        // This is the iOS equivalent of Android's new_message_false() function
        markChatAsRead()
    }

    // MARK: - Here Status Updates (Android Parity)
    private func updateHereStatus(isActive: Bool) {
        let myUserId = UserSessionManager.shared.userId ?? ""
        guard !myUserId.isEmpty else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(myUserId)
        let data: [String: Any] = [
            "current_chat_uid_for_here": isActive ? otherUser.id : "null"
        ]
        userRef.setData(data, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateHereStatus() Failed to set here status: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateHereStatus() Here status set to \(isActive ? "ACTIVE" : "INACTIVE") for chat with: \(otherUser.id)")
            }
        }
    }
    
    // MARK: - Message Read Status (Android Parity)
    
    /// iOS equivalent of Android's new_message_false() function
    /// Called when user opens a chat to mark messages as read
    private func markChatAsRead() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "markChatAsRead() Marking chat as read - iOS equivalent of Android new_message_false()")
        
        // ANDROID PARITY FIX: Only update new_message field, NOT timestamp
        // The Android new_message_false() function should NOT update last_message_timestamp
        // Timestamp should only be updated when actual messages are sent (in setTimeForChatList)
        let chatData: [String: Any] = [
            "new_message": false
            // REMOVED: "last_message_timestamp": FieldValue.serverTimestamp()
            // This was causing chats to move up in the list when just opening/closing them
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .collection("Chats")
            .document(otherUser.id)
            .setData(chatData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "markChatAsRead() Failed to update Firebase: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "markChatAsRead() Successfully marked chat as read in Firebase (without updating timestamp)")
                    
                    // Update local database to reflect read status (Android Parity)
                    DispatchQueue.main.async {
                        self.updateLocalChatReadStatus()
                    }
                    
                    // Mark individual messages as seen (Android Parity - MarkAsSeenAsyncTask equivalent)
                    self.markMessagesAsSeen()
                }
            }
    }
    
    /// Local-only seen handling based on presence windows
    private func markMessagesAsSeen() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "markMessagesAsSeen() Local-only seen marking (no Firebase writes)")
        
        if otherUserChattingInCurrentChat {
            // Other user is currently in this chat → all of our outgoing messages are effectively seen
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "markMessagesAsSeen() Other user HERE → mark all sent messages seen")
            markSentMessagesAsSeenLocally(upTo: nil)
            return
        }
        
        // Otherwise, mark up to their last_time_seen
        if let lastSeen = otherUserLastSeen {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "markMessagesAsSeen() Using last_time_seen=\(lastSeen) to mark sent messages seen locally")
            markSentMessagesAsSeenLocally(upTo: lastSeen)
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "markMessagesAsSeen() No presence info available; skipping")
        }
    }
    
    /// Helper: Mark our sent messages as seen locally, optionally only up to a cutoff time
    private func markSentMessagesAsSeenLocally(upTo cutoff: Date?) {
        var updatedCount = 0
        for i in 0..<messages.count {
            guard messages[i].isFromCurrentUser else { continue }
            if let cutoff = cutoff, messages[i].timestamp > cutoff { continue }
            if messages[i].isMessageSeen { continue }
            messages[i].isMessageSeen = true
            messageSeenMap[messages[i].id] = true
            updatedCount += 1
        }
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "markSentMessagesAsSeenLocally() Marked \(updatedCount) sent messages as seen locally")
    }
    
    /// Update local message objects to reflect seen status for SENT messages only
    private func updateLocalMessageSeenStatus() {
        var updated = 0
        for i in 0..<messages.count {
            if messages[i].isFromCurrentUser && !messages[i].isMessageSeen {
                messages[i].isMessageSeen = true
                messageSeenMap[messages[i].id] = true
                updated += 1
            }
        }
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalMessageSeenStatus() Updated local seen status for \(updated) sent messages")
    }
    
    /// Update local database to mark chat as read (Android Parity)
    private func updateLocalChatReadStatus() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalChatReadStatus() Updating local database")
        
        // CRITICAL FIX: Check database readiness before updating
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalChatReadStatus() Database not ready - skipping update")
            return
        }
        
        // ANDROID PARITY FIX: Only update NewMessage field, NOT timestamp
        // Get current chat data first to preserve existing timestamp
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalChatReadStatus() Database connection is nil")
                return
            }
            
            // Get existing chat data to preserve timestamp using the correct method name
            let existingChats = ChatsDB.shared.singlequary(ChatId: self.chatId)
            
            if let chat = existingChats.first {
                // Update only NewMessage field, preserve existing timestamp
                let chatsDB = ChatsDB.shared
                chatsDB.update(
                    LastTimeStamp: chat.LastTimeStamp, // PRESERVE existing timestamp
                    NewMessage: 0, // Mark as read (0 = false, 1 = true)
                    ChatId: self.chatId,
                    Lastsentby: chat.Lastsentby, // PRESERVE existing last sender
                    Inbox: chat.inbox // PRESERVE existing inbox status (note: lowercase 'i')
                )
                
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalChatReadStatus() Local database updated successfully (preserved timestamp: \(chat.LastTimeStamp))")
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateLocalChatReadStatus() Chat not found in local database")
            }
        }
    }
    
    // MARK: - Message Loading
    
    @MainActor
    private func loadMessagesFromLocalDatabase() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() STARTING - Loading messages from local database for chat: \(chatId)")
        
        isLoading = true
        
        // CRITICAL FIX: Check database readiness before querying
        let isDatabaseReady = DatabaseManager.shared.isDatabaseReady()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() Database readiness check: \(isDatabaseReady)")
        
        guard isDatabaseReady else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() Database not ready - will retry after initialization")
            
            // Initialize database if not ready
            DatabaseManager.shared.initializeDatabase()
            
            // Retry after a short delay with exponential backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadMessagesFromLocalDatabaseWithRetry(attempt: 1)
            }
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() Database is ready - calling MessagesDB.selectMessagesByChatId(\(chatId))")
        
        // DEBUG: Check database contents first
        let totalMessages = MessagesDB.shared.getTotalMessageCount()
        let allChatIds = MessagesDB.shared.getAllChatIds()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() DEBUG - Total messages in DB: \(totalMessages), All chat IDs: \(allChatIds)")
        
        // Get messages from local database using the new concurrent read method
        // No need to wrap in executeOnDatabaseQueueAsync since selectMessagesByChatId handles concurrency internally
        let messageDataArray = MessagesDB.shared.selectMessagesByChatId(self.chatId)
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() MessagesDB returned \(messageDataArray.count) MessageData objects")
        
        // Convert MessageData to ChatMessage
        let chatMessages = messageDataArray.map { messageData in
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() Converting MessageData: id=\(messageData.docId), text=\(messageData.message.prefix(20))..., senderId=\(messageData.senderId)")
            
            return ChatMessage(
                id: messageData.docId,
                text: messageData.message,
                isFromCurrentUser: messageData.senderId == self.currentUserId,
                timestamp: Date(timeIntervalSince1970: TimeInterval(messageData.sendDate)),
                isMessageSeen: false, // Will be updated by Firebase listener
                hasAd: messageData.adAvailable == 1,
                actualMessage: messageData.message,
                isPremium: messageData.premium == 1,
                isAIMessage: false,
                imageUrl: messageData.image.isEmpty ? nil : messageData.image,
                containsProfanity: false,
                isProfanityMasked: false
            )
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() Converted to \(chatMessages.count) ChatMessage objects")
        
        // Update UI on main thread
        DispatchQueue.main.async {
            // Preserve any known seen states already present in the in-memory messages array
            // Merge seen states from current in-memory array and the persistent seen map
            var existingSeenById: [String: Bool] = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0.isMessageSeen) })
            for (key, value) in self.messageSeenMap { existingSeenById[key] = value }
            var mergedMessages: [ChatMessage] = chatMessages.map { incoming in
                var updated = incoming
                if let knownSeen = existingSeenById[incoming.id] {
                    updated.isMessageSeen = knownSeen
                }
                return updated
            }
            
            // ANDROID PARITY: Keep messages in DESC order (newest first) to match Android RecyclerView pattern
            // Database returns DESC order, use inverted scroll pattern for display
            mergedMessages.sort { $0.timestamp > $1.timestamp }
            self.messages = mergedMessages
            self.isLoading = false
            self.isFirstLoad = false
            
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabase() COMPLETED - UI updated with \(self.messages.count) messages, isLoading=\(self.isLoading)")
        }
    }
    
    /// Retry loading messages with exponential backoff
    private func loadMessagesFromLocalDatabaseWithRetry(attempt: Int) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabaseWithRetry() attempt \(attempt)")
        
        // Max 5 attempts
        guard attempt <= 5 else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabaseWithRetry() Max retry attempts reached - giving up")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        // Check if database is ready now
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabaseWithRetry() Database still not ready - attempt \(attempt)")
            
            // Initialize database again if needed
            DatabaseManager.shared.initializeDatabase()
            
            // Retry with exponential backoff (cap at 5 seconds)
            let delay = min(pow(2.0, Double(attempt - 1)), 5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.loadMessagesFromLocalDatabaseWithRetry(attempt: attempt + 1)
            }
            return
        }
        
        // Database is ready, try loading again
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessagesFromLocalDatabaseWithRetry() Database ready on attempt \(attempt) - loading messages")
        loadMessagesFromLocalDatabase()
    }
    
    @MainActor
    private func loadMessages() async {
        // This method is now just for initial Firebase data sync
        // The actual UI display comes from local database
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessages() Starting initial Firebase sync for chat: \(chatId)")
        
        // Load from local database first for immediate display
        loadMessagesFromLocalDatabase()
        
        // Then sync with Firebase (listener will handle updates)
        // This is just for initial pagination setup
        do {
            let query = Firestore.firestore()
                .collection("Chats")
                .document(chatId)
                .collection("Messages")
                .order(by: "message_time_stamp", descending: true)
                .limit(to: 20) // Initial load
            
            let snapshot = try await query.getDocuments()
            
            // Process documents to ensure they're in local database
            for document in snapshot.documents {
                let data = document.data()
                saveMessageToLocalDatabase(documentSnapshot: document, data: data)
            }
            
            // Reload from local database after sync
            loadMessagesFromLocalDatabase()
            
        } catch {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMessages() Firebase sync failed: \(error.localizedDescription)")
        }
    }
    
    private func saveMessageToLocalDatabase(documentSnapshot: DocumentSnapshot, data: [String: Any]) {
        let messageId = documentSnapshot.documentID
        let message = data["message_text_content"] as? String ?? ""
        let senderId = data["message_userId"] as? String ?? ""
        let image = data["message_image"] as? String ?? ""
        let sendDate = Int((data["message_time_stamp"] as? Timestamp)?.seconds ?? Int64(Date().timeIntervalSince1970))
        let adAvailable = data["message_ad_available"] as? Bool ?? false ? 1 : 0
        let premium = data["message_premium"] as? Bool ?? false ? 1 : 0
        
        // CRITICAL FIX: Check database readiness before saving
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveMessageToLocalDatabase() Database not ready - initializing and retrying")
            
            // Initialize database if not ready
            DatabaseManager.shared.initializeDatabase()
            
            // Retry after initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.saveMessageToLocalDatabase(documentSnapshot: documentSnapshot, data: data)
            }
            return
        }
        
        // Save to local database using the new concurrent approach
        // Use DatabaseManager's executeOnDatabaseQueueAsync for writes (inserts/updates must be serialized)
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveMessageToLocalDatabase() Database connection is nil - database may not be fully initialized")
                
                // Retry once more after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.saveMessageToLocalDatabase(documentSnapshot: documentSnapshot, data: data)
                }
                return
            }
            
            // Android Pattern: Insert message into local database
            MessagesDB.shared.insertMessage(
                messageId: messageId,
                chatId: self.chatId,
                message: message,
                senderId: senderId,
                image: image,
                sendDate: sendDate,
                docId: messageId,
                adAvailable: adAvailable,
                premium: premium,
                db: db
            )
            
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveMessageToLocalDatabase() Saved message to local database: \(messageId)")
        }
    }
    

    
    private func loadMoreMessages() {
        // Android Pattern: Load more messages from local database
        // In Android, this would trigger more Firebase queries that get saved to local DB
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMoreMessages() Loading more messages from local database")
        
        // For now, just reload from local database
        // In a full implementation, this would fetch older messages from Firebase
        loadMessagesFromLocalDatabase()
    }
    
    // MARK: - Message Sending
    
    private func handleSendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() Attempting to send message")
        
        // MARK: - Message Limit Check
        // Set the current user ID for per-user message tracking
        MessageLimitManager.shared.setCurrentUserId(otherUser.id)
        
        // Log subscription status for debugging message limit issues
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() DEBUG - Subscription Status:")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Has Pro Access: \(SubscriptionSessionManager.shared.hasProAccess())")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Subscription Tier: \(SubscriptionSessionManager.shared.getSubscriptionTier())")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Is Subscription Active: \(SubscriptionSessionManager.shared.isSubscriptionActive())")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Message Limit: \(SessionManager.shared.freeMessagesLimit)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Message Cooldown: \(SessionManager.shared.freeMessagesCooldownSeconds)s")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - First Account Time: \(UserSessionManager.shared.firstAccountCreatedTime)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - New User Period: \(SessionManager.shared.newUserFreePeriodSeconds)s")
        
        // Check message limits before sending
        let result = MessageLimitManager.shared.checkMessageLimit()
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() MessageLimit Result:")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Can Proceed: \(result.canProceed)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Show Popup: \(result.showPopup)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Current Usage: \(result.currentUsage)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Limit: \(result.limit)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "  - Remaining Cooldown: \(result.remainingCooldown)s")
        
        if result.showPopup {
            // Show popup if limits reached
            messageLimitResult = result
            showMessageLimitPopup = true
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() Message limit reached, showing popup")
            return
        }
        
        if result.canProceed {
            // Proceed with message sending
            MessageLimitManager.shared.performMessageSend { success in
                if success {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() Message limit check passed, proceeding with send")
                    // Precompute interest suggestion before messageText cleared
                    computeInterestSuggestionIfAny(sentText: text)
                    sendMessage()
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() Message send blocked by limit manager")
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() Cannot proceed with message - user over limit")
            // If user can't proceed but popup wasn't shown, there might be an issue
            if !result.showPopup {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleSendMessage() WARNING: User can't proceed but popup not shown - this shouldn't happen")
            }
        }
    }

    // MARK: - Interest Suggestion Integration
    @State private var pendingInterestSuggestion: String? = nil
    private func computeInterestSuggestionIfAny(sentText: String) {
        let suggestion = InterestSuggestionManager.shared.processOutgoingMessage(chatId: chatId, message: sentText)
        DispatchQueue.main.async {
            withAnimation { self.pendingInterestSuggestion = suggestion }
            if suggestion != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation { if self.pendingInterestSuggestion == suggestion { self.pendingInterestSuggestion = nil } }
                }
            }
        }
    }

    private func acceptInterestSuggestion(_ phrase: String) {
        // Optimistically hide immediately (ask one at a time UX)
        withAnimation {
            if case .interest(let p)? = self.entryPill, p.caseInsensitiveCompare(phrase) == .orderedSame {
                self.entryPill = nil
            }
            self.pendingInterestSuggestion = nil
        }
        InterestSuggestionManager.shared.acceptInterest(phrase, chatId: chatId) { _ in }
    }

    private func rejectInterestSuggestion(_ phrase: String) {
        // Optimistically hide immediately
        withAnimation {
            self.pendingInterestSuggestion = nil
            if case .interest(let p)? = self.entryPill, p.caseInsensitiveCompare(phrase) == .orderedSame {
                self.entryPill = nil
            }
        }
        InterestSuggestionManager.shared.rejectInterest(phrase, chatId: chatId)
    }

    // MARK: - Entry Pill Logic (Alternating A/B)

    private func prepareEntryPill() {
        // Decide alternation based on a simple toggle persisted in UserDefaults
        let defaults = UserDefaults.standard
        let lastCategoryA = defaults.bool(forKey: "entry_pill_last_was_A")

        // Attempt preferred category first, then fallback to the other
        if !lastCategoryA {
            if let a = nextInterestSuggestionForEntry() {
                entryPill = .interest(phrase: a)
                defaults.set(true, forKey: "entry_pill_last_was_A")
                return
            } else if let b = nextAboutYouQuestionForEntry() {
                entryPill = .aboutYou(key: b.key, question: b.question)
                defaults.set(false, forKey: "entry_pill_last_was_A")
                return
            }
        } else {
            if let b = nextAboutYouQuestionForEntry() {
                entryPill = .aboutYou(key: b.key, question: b.question)
                defaults.set(false, forKey: "entry_pill_last_was_A")
                return
            } else if let a = nextInterestSuggestionForEntry() {
                entryPill = .interest(phrase: a)
                defaults.set(true, forKey: "entry_pill_last_was_A")
                return
            }
        }

        // If nothing to ask, hide
        entryPill = nil
    }

    private func nextInterestSuggestionForEntry() -> String? {
        // Persisted rotation across visits using an index in UserDefaults
        let suggestions = InterestSuggestionManager.shared.getSuggestedInterests()
        guard !suggestions.isEmpty else { return nil }

        let defaults = UserDefaults.standard
        let indexKey = "entry_pill_interest_index"
        var startIndex = defaults.integer(forKey: indexKey)
        if startIndex < 0 || startIndex >= suggestions.count { startIndex = 0 }

        let accepted = Set(SessionManager.shared.interestTags.map { $0.lowercased() })

        var foundIndex: Int? = nil
        for offset in 0..<suggestions.count {
            let idx = (startIndex + offset) % suggestions.count
            let phrase = suggestions[idx]
            if !accepted.contains(phrase.lowercased()) {
                foundIndex = idx
                break
            }
        }

        if let idx = foundIndex {
            // Advance pointer to the next item for future entries
            defaults.set((idx + 1) % suggestions.count, forKey: indexKey)
            return suggestions[idx]
        } else {
            // Nothing usable (all accepted). Still advance pointer to keep rotation moving.
            defaults.set((startIndex + 1) % suggestions.count, forKey: indexKey)
            return nil
        }
    }

    private func nextAboutYouQuestionForEntry() -> (key: String, question: String)? {
        // Consider a subset of yes/no style profile fields from EditProfile
        // Map Firestore key -> human-readable question
        let candidates: [(String, String)] = [
            ("married", "Are you married?"),
            ("children", "Do you have children?"),
            ("smokes", "Do you smoke?"),
            ("drinks", "Do you drink?"),
            ("voice_allowed", "Do you allow voice calls?"),
            ("video_allowed", "Do you allow video calls?"),
            ("pics_allowed", "Do you send pictures?")
        ]

        let defaults = UserDefaults.standard
        let indexKey = "entry_pill_about_index"
        var startIndex = defaults.integer(forKey: indexKey)
        if startIndex < 0 || startIndex >= candidates.count { startIndex = 0 }

        // Treat empty/null as unanswered
        for offset in 0..<candidates.count {
            let idx = (startIndex + offset) % candidates.count
            let (key, question) = candidates[idx]
            let current = aboutYouValues[key] ?? ""
            if current.isEmpty || current == "null" {
                // Advance pointer to the next item for future entries
                defaults.set((idx + 1) % candidates.count, forKey: indexKey)
                return (key, question)
            }
        }

        // All answered — still advance pointer to keep rotation moving
        defaults.set((startIndex + 1) % max(candidates.count, 1), forKey: indexKey)
        return nil
    }

    // MARK: - Entry Pill View
    private var entryPillView: AnyView? {
        guard let entryPill else { return nil }
        switch entryPill {
        case .interest(let phrase):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    Text("Are you interested in")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                    Text(phrase.interestDisplayFormatted)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        pillChoiceButton(title: "Yes", system: "heart.fill", bg: Color.white.opacity(0.2)) {
                            acceptInterestSuggestion(phrase)
                        }
                        pillChoiceButton(title: "No", system: "xmark", bg: Color.white.opacity(0.15)) {
                            rejectInterestSuggestion(phrase)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
        case .aboutYou(let key, let question):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tell us more about you")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                    Text(question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        pillChoiceButton(title: "Yes", system: "heart.fill", bg: Color.white.opacity(0.2)) {
                            saveAboutYouAnswer(key: key, yes: true)
                            withAnimation { self.entryPill = nil }
                        }
                        pillChoiceButton(title: "No", system: "xmark", bg: Color.white.opacity(0.15)) {
                            saveAboutYouAnswer(key: key, yes: false)
                            withAnimation { self.entryPill = nil }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
        }
    }

    private func pillCircleButton(system: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(8)
                .background(bg)
                .clipShape(Circle())
        }
    }

    private func pillChoiceButton(title: String, system: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(bg)
            .clipShape(Capsule())
        }
    }

    private func saveAboutYouAnswer(key: String, yes: Bool) {
        let userId = UserSessionManager.shared.userId ?? ""
        let value = yes ? "yes" : "no"
        // Optimistic close (ask one at a time UX)
        withAnimation { self.entryPill = nil }
        let db = Firestore.firestore()
        db.collection("Users").document(userId).setData([key: value], merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAboutYouAnswer() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAboutYouAnswer() saved \(key)=\(value)")
            }
        }
    }
    
    // MARK: - Debug Helper for Message Limit Testing
    private func testMessageLimitPopup() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "testMessageLimitPopup() Testing message limit popup")
        
        // Create a test result that forces the popup to show
        let testResult = FeatureLimitResult(
            canProceed: false,
            showPopup: true,
            remainingCooldown: 60, // 1 minute cooldown
            currentUsage: 5,
            limit: 5
        )
        
        messageLimitResult = testResult
        showMessageLimitPopup = true
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "testMessageLimitPopup() Forced message limit popup to show")
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() sending message: \(text)")
        
        // ANDROID PARITY: Check for app name profanity and increment moderation score
        if Profanity.share.doesContainProfanityAppName(text) {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() Profanity AppName detected")
            let currentScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
            ModerationSettingsSessionManager.shared.hiveTextModerationScore = currentScore + 101
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() Updated moderation score to: \(ModerationSettingsSessionManager.shared.hiveTextModerationScore)")
        }
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        let bad = Profanity.share.doesContainProfanity(text)
        
        // ANDROID PARITY: Check conversation started status and handle profanity
        checkConversationStarted()
        
        if !conversationStarted {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() First message detected")
            
            if moveToInbox && bad {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() Moving to inbox due to profanity in first message")
                setMoveToInbox(true)
            }
            
            if bad {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() Incrementing moderation score for profanity in first message")
                let currentScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
                ModerationSettingsSessionManager.shared.hiveTextModerationScore = currentScore + 10
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() Updated moderation score to: \(ModerationSettingsSessionManager.shared.hiveTextModerationScore)")
            }
        }
        
        // Android Pattern: Do NOT create local message object
        // Only write to Firebase, the listener will catch it and save to local database
        messageText = ""
        
        // Reset text height to single line after sending message (Progressive Growth Pattern)
        withAnimation(.easeInOut(duration: 0.2)) {
            textHeight = calculateTextHeight(for: "")
        }
        
        // Save user message for AI training if this is an AI chat
        if isAIChat {
            saveUserMessageForTraining(text)
        }
        
        // Send to Firebase
        let messageData: [String: Any] = [
            "message_text_content": text,
            "message_userId": currentUserId,
            "message_sender_name": currentUserName,
            "message_time_stamp": FieldValue.serverTimestamp(),
            "message_seen": false, // Android Parity: Use message_seen field
            "message_ad_available": false,
            "message_actual": text,
            "message_premium": false,
            "is_ai_message": false,
            "message_is_bad": bad
        ]
        
        Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .collection("Messages")
            .document(messageId)
            .setData(messageData) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() failed: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendMessage() success")
                    
                    // Android Parity: Mark that a message was sent this session
                    self.messageSentThisSession = true
                    
                    updateLastMessage(text: text, timestamp: timestamp)
                    
                    // Increment message sent counter for rating system (Android Parity)
                    MessagingSettingsSessionManager.shared.incrementMessageCount()
                    
                    // Increment per-user message count for message limit popup
                    MessagingSettingsSessionManager.shared.incrementMessageCount(otherUserId: self.otherUser.id)
                    
                    // MARK: - Android Parity: Convert Inbox Chat to Regular Chat
                    // When user sends message from inbox chat, convert it to regular chat (matching Android's setInBox(false))
                    // Note: Only updates Firebase - local database will be updated by ChatsSyncService listener
                    if self.isFromInbox {
                        self.setInBox(false)
                    }
                    
                    // MARK: - Contextual Notification Permission Request
                    // Show notification permission popup after first message is successfully sent
                    // This provides the perfect context for users to understand the value of notifications
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.checkAndShowNotificationPermissionPopup()
                    }
                    
                    // Removed Interests Popup Trigger
                }
            }
        
        if isAIChat {
            // Trigger AI response after user sends message
            startAITypingTimer()
        }
    }
    
    // MARK: - Android Parity: Inbox Chat Conversion
    
    /// Convert inbox chat to regular chat by setting inbox field to false in Firebase
    /// This matches Android's setInBox() method in MessageTextActivity.java
    /// Note: Only updates Firebase - ChatsSyncService listener will handle local database updates
    private func setInBox(_ inbox: Bool) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInBox() setting inbox - \(inbox) userid - \(currentUserId) ouser - \(otherUser.id)")
        
        let peopleData: [String: Any] = ["inbox": inbox]
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .collection("Chats")
            .document(otherUser.id)
            .setData(peopleData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInBox() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setInBox() Success: inbox set to \(inbox) - ChatsSyncService will update local database")
                }
            }
    }
    
    // REMOVED: updateLocalChatInboxStatus() - ChatsSyncService handles all database updates
    
    // MARK: - Android Parity: Conversation Tracking
    
    private func checkConversationStarted() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkConversationStarted() Checking if conversation has started")
        
        // Count messages from current user to other user (excluding AI messages)
        let userMessages = messages.filter { message in
            message.isFromCurrentUser && !message.isAIMessage
        }
        
        let messageCount = userMessages.count
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkConversationStarted() User message count: \(messageCount)")
        
        if messageCount > 0 {
            conversationStarted = true
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkConversationStarted() Conversation started: true")
        } else {
            conversationStarted = false
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkConversationStarted() Conversation started: false")
        }
    }
    
    private func setMoveToInbox(_ move: Bool) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setMoveToInbox() setting inbox - \(move) for other user - \(otherUser.id)")
        
        let peopleData: [String: Any] = ["inbox": move]
        
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .collection("Chats")
            .document(currentUserId)
            .setData(peopleData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setMoveToInbox() Error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setMoveToInbox() Success: inbox set to \(move) for other user")
                }
            }
    }
    
    private func loadMoveToInboxFlag() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMoveToInboxFlag() Loading move to inbox flag from user profile")
        
        // Get the move_to_inbox flag from current user's profile (equivalent to Android's MOVETOINBOX = profile_tables.get(0).isMove_to_inbox())
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .getDocument { document, error in
                if let document = document, document.exists {
                    let data = document.data()
                    let moveToInboxFlag = data?["move_to_inbox"] as? Bool ?? false
                    
                    DispatchQueue.main.async {
                        self.moveToInbox = moveToInboxFlag
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMoveToInboxFlag() Loaded moveToInbox flag: \(moveToInboxFlag)")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadMoveToInboxFlag() User document not found or error: \(error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.async {
                        self.moveToInbox = false
                    }
                }
            }
    }
    
    // MARK: - AI Message Logic
    
    private func startAITypingTimer() {
        aiTypingTimer?.invalidate()
        aiStatus = "typing"
        
        aiTypingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            triggerAIMessage()
        }
    }
    
    private func triggerAIMessage() {
        guard let myProfile = getMyProfile(), let otherProfile = getOtherUserProfile() else {
            return
        }
        
        let conversationHistory = getConversationHistory()
        _ = MessagingSettingsSessionManager.shared.getLastUserMessage(for: chatId) ?? messages.last?.text ?? ""
        
        let prompt = PromptCreator().createChatPrompt(
            myProfile: myProfile,
            otherProfile: otherProfile,
            conversationHistory: conversationHistory,
            myInterests: [],
            myStatus: "",
            mood: "friendly",
            similarReply: false
        )
        
        guard let otherProfile = getOtherUserProfile() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerAIMessage() Failed to get other user profile")
            aiStatus = "online"
            return
        }
        
        // Android Parity: Load credentials like Android getCredentials()
        CredentialsService.shared.loadCredentials()
        let apiUrl = CredentialsService.shared.getAiApiUrl()
        let apiKey = CredentialsService.shared.getAiApiKey()
        
        // Android Parity: Use real AI API with credentials
        AIMessageService.shared.getAiMessage(
            prompt: prompt,
            apiUrl: apiUrl,
            apiKey: apiKey,
            chatId: chatId,
            otherProfile: otherProfile,
            lastAiMessage: lastAIMessage,
            isProfanity: false
        ) { success in
            DispatchQueue.main.async {
                if success {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerAIMessage() AI message sent successfully")
                    // Note: The actual message will be received through Firebase listener
                    // This is just confirmation that the request was processed
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerAIMessage() AI message failed")
                }
                aiStatus = "online"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if we should show notification permission popup after first message or retry
    /// This provides contextual permission request when user understands the value
    private func checkAndShowNotificationPermissionPopup() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Checking if notification permission popup should be shown")
        
        // Don't show if already shown in this session
        guard !hasShownNotificationPopup else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Already shown in this session")
            return
        }
        
        // Don't show for AI chats (they don't reply with real notifications)
        guard !isAIChat else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Skipping for AI chat")
            return
        }
        
        // Check if this is a retry scenario (user previously said "maybe later")
        // Retry Logic: Shows popup again after user sends/receives 15 more messages since "maybe later"
        // This ensures user is actively engaged before asking again (max 3 retry attempts)
        if AppNotificationPermissionService.shared.shouldShowRetryPopup() {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Showing retry popup after user engagement (15+ messages since maybe later)")
            showRetryNotificationPermissionPopup()
            return
        }
        
        // Don't show if permission already requested/granted
        guard AppNotificationPermissionService.shared.shouldRequestPermission() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Permission already requested or granted")
            return
        }
        
        // Check if this is user's first message in this chat (contextual trigger)
        let userMessageCount = messages.filter { $0.isFromCurrentUser }.count
        guard userMessageCount == 1 else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Not first message (count: \(userMessageCount))")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkAndShowNotificationPermissionPopup() Showing first-time notification permission popup")
        
        // Show the custom popup with explanation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showNotificationPermissionPopup = true
        }
        
        // Mark as shown to prevent showing again in this session
        hasShownNotificationPopup = true
    }
    
    /// Show retry notification permission popup with updated messaging
    private func showRetryNotificationPermissionPopup() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "showRetryNotificationPermissionPopup() Showing retry popup")
        
        // Show the same popup but with retry context
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showNotificationPermissionPopup = true
        }
        
        // Mark as shown to prevent showing again in this session
        hasShownNotificationPopup = true
    }
    
    // Removed: checkAndShowInterestsPopup (no longer showing full-screen interests popup)
    
    // Removed: checkTimeBasedInterestsPopup (no longer showing full-screen interests popup)
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard !messages.isEmpty else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "scrollToBottom() No messages to scroll to")
            return
        }
        
        // ANDROID PARITY: With inverted scroll pattern, newest message (messages.first) appears at visual bottom
        // The ScrollView is flipped, so scrolling to the first message shows it at the bottom of screen
        if let newestMessage = messages.first {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "scrollToBottom() Scrolling to newest message: \(newestMessage.id) (inverted scroll pattern)")
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(newestMessage.id, anchor: .top) // Use .top anchor because ScrollView is flipped
            }
        }
    }
    
    private func updateLastMessage(text: String, timestamp: Date) {
        // Android parity: Update chat list with last message (setTimeForChatList equivalent)
        
        // Update current user's chat list (my side)
        let myChatData: [String: Any] = [
            "last_message": text,
            "last_message_timestamp": FieldValue.serverTimestamp(), // Android Parity: Use server timestamp
            "last_message_sent_by_user_id": currentUserId // Android parity: track who sent the last message
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .collection("Chats")
            .document(otherUser.id)
            .setData(myChatData, merge: true)
        
        // Update other user's chat list (other side) - Android parity: setTimeForChatList(true)
        let otherChatData: [String: Any] = [
            "last_message": text,
            "last_message_timestamp": FieldValue.serverTimestamp(), // Android Parity: Use server timestamp
            "new_message": true, // Android parity: new message for other user
            "last_message_sent_by_user_id": currentUserId // Android parity: track who sent the last message
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .collection("Chats")
            .document(currentUserId)
            .setData(otherChatData, merge: true)
        
        // Save user message for AI training
        MessagingSettingsSessionManager.shared.setLastUserMessage(text, for: chatId)
    }
    
    private func handleTyping() {
        // Send typing indicator to other user
        if !isAIChat {
            let typingData: [String: Any] = [
                "typing": true,
                "timestamp": Date()
            ]
            
            Firestore.firestore()
                .collection("Chats")
                .document(chatId)
                .collection("Typing")
                .document(currentUserId)
                .setData(typingData)
            
            // Stop typing indicator after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let stopTypingData: [String: Any] = [
                    "typing": false,
                    "timestamp": Date()
                ]
                
                Firestore.firestore()
                    .collection("Chats")
                    .document(chatId)
                    .collection("Typing")
                    .document(currentUserId)
                    .setData(stopTypingData)
            }
        }
    }
    
    // MARK: - Firebase Listeners
    
    private func setupFirebaseListeners() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupFirebaseListeners() Setting up Firebase listeners")
        
        setupMessageListener()
        setupTypingListener()
        setupStatusListener()
        setupBlockListener()
        setupLiveListeners() // Add live listeners
    }
    
    private func removeFirebaseListeners() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "removeFirebaseListeners() Removing Firebase listeners")
        
        messageListener?.remove()
        typingListener?.remove()
        statusListener?.remove()
        blockListener?.remove()
        liveListener?.remove()
        
        messageListener = nil
        typingListener = nil
        statusListener = nil
        blockListener = nil
        liveListener = nil
    }
    
    private func setupLiveListeners() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupLiveListeners() Setting up live status listeners")
        
        // Listen to other user's live status
        liveListener = Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .collection("Live")
            .document(otherUser.id)
            .addSnapshotListener { documentSnapshot, error in
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupLiveListeners() Live listener error: \(error)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    let data = document.data()
                    let isLiveOn = data?["live"] as? Bool ?? false
                    
                    DispatchQueue.main.async {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupLiveListeners() Other user live status: \(isLiveOn)")
                        
                        if isLiveOn && self.isLiveOn {
                            // Both users have live on - show toast
                            self.showToastMessage("Live connected")
                        }
                    }
                }
            }
    }
    
    private func setupMessageListener() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupMessageListener() Setting up real-time message listener")
        
        // Message listener for real-time updates - ANDROID PARITY: Query in DESC order
        messageListener = Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .collection("Messages")
            .order(by: "message_time_stamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "Message listener error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                // Handle real-time message updates
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        let data = change.document.data()
                        let senderId = data["message_userId"] as? String ?? ""
                        let messageId = change.document.documentID
                        let isMessageSeen = data["message_seen"] as? Bool ?? false
                        
                        // Only promote to seen if Firestore explicitly has true; never override local seen to false
                        if senderId == currentUserId && isMessageSeen {
                            DispatchQueue.main.async {
                                self.messageSeenMap[messageId] = true
                                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                                    messages[index].isMessageSeen = true
                                }
                            }
                        }
                        
                        // Android Pattern: Save all messages to local database (both current user and other users)
                        // The listener catches ALL messages, including our own sent messages
                        
                        // Save message to local database
                        self.saveMessageToLocalDatabase(documentSnapshot: change.document, data: data)
                        
                        // Only increment counters for messages from other users
                        if senderId != currentUserId {
                            DispatchQueue.main.async {
                                                                  // Increment message received counter for rating system (Android Parity)
                                 MessagingSettingsSessionManager.shared.totalNoOfMessageReceived += 1
                                
                                // Android Parity: Mark messages as seen when receiving new messages while user is "here"
                                // This matches Android's logic in FetchMessageListener where markAsSeenAsyncTask is called
                                if self.otherUserChattingInCurrentChat {
                                    self.markMessagesAsSeen()
                                }
                            }
                        }
                        
                        // Android Pattern: After saving to local database, reload UI from database
                        DispatchQueue.main.async {
                            self.loadMessagesFromLocalDatabase()
                        }
                    } else if change.type == .modified {
                        // Android Parity: Handle message seen status updates for sent messages
                        let data = change.document.data()
                        let messageId = change.document.documentID
                        let senderId = data["message_userId"] as? String ?? ""  // FIXED: Use correct field name matching Android
                        let isMessageSeen = data["message_seen"] as? Bool ?? false // Android Parity: Use message_seen field
                        
                        // Update seen status for our sent messages when recipient reads them
                        if senderId == currentUserId && isMessageSeen {
                            DispatchQueue.main.async {
                                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                                    messages[index].isMessageSeen = true
                                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupMessageListener() Updated seen status for message \(messageId): true")
                                }
                                // Persist seen state in map to survive local DB reloads
                                self.messageSeenMap[messageId] = true
                            }
                        }
                    }
                }
            }
    }
    
    private func setupTypingListener() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupTypingListener() Setting up typing indicator listener")
        
        // Typing indicator listener
        if !isAIChat {
            typingListener = Firestore.firestore()
                .collection("Chats")
                .document(chatId)
                .collection("Typing")
                .document(otherUser.id)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot, snapshot.exists else { return }
                    
                    let data = snapshot.data() ?? [:]
                    let typing = data["typing"] as? Bool ?? false
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Show typing indicator only if recent (within 5 seconds)
                    let isRecent = Date().timeIntervalSince(timestamp) < 5
                    
                    DispatchQueue.main.async {
                        isOtherUserTyping = typing && isRecent
                        
                        // Update status display when typing state changes (Android Parity)
                        updateUserStatus()
                    }
                }
        }
    }
    
    private func setupStatusListener() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupStatusListener() Setting up user status listener")
        
        // User status listener (Android Parity - exact field names and logic)
        statusListener = Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                let data = snapshot.data() ?? [:]
                
                // Android Parity: Extract all status fields exactly as Android does
                let timeString: String? = {
                    if let timestamp = data["last_time_seen"] as? Timestamp {
                        return self.formatLastSeenTime(timestamp.dateValue())
                    }
                    return nil
                }()
                
                let isUserOnline = data["is_user_online"] as? Bool ?? false
                let otherUserTyping = data["other_user_typing"] as? Bool ?? false
                let playingGames = data["playing_games"] as? Bool ?? false
                let onCall = data["on_call"] as? Bool ?? false
                let onLive = data["on_live"] as? Bool ?? false
                let currentChatUidForHere = data["current_chat_uid_for_here"] as? String ?? "null"
                let hereTimestamp = (data["here_timestamp"] as? Timestamp)?.dateValue()
                let interestTags = data["interest_tags"] as? [String] ?? []
                let interestSentence = data["interest_sentence"] as? String ?? ""
                
                DispatchQueue.main.async {
                    // Update interests display (Android Parity)
                    self.otherUserInterests = interestTags
                    self.displayInterests(tags: interestTags, sentence: interestSentence)
                    
                    // Check if other user is "here" in current chat (Android Parity)
                    let isHere = currentChatUidForHere.lowercased() == self.currentUserId.lowercased()
                    
                    // Update status based on Android logic exactly
                    if isUserOnline {
                        if self.isAIChat {
                            // AI chat handling
                            self.handleAIStatus()
                        } else if playingGames && !self.isPremiumUser {
                            self.updateStatus("Playing games", color: "color_card_playing")
                        } else if onLive && !self.isPremiumUser {
                            self.updateStatus("Live session", color: "color_card_call")
                        } else if onCall && !self.isPremiumUser {
                            self.updateStatus("On a call", color: "color_card_call")
                        } else if isHere {
                            if otherUserTyping {
                                self.updateStatus("Typing…", color: "color_card_typing")
                                self.isOtherUserTyping = true
                            } else {
                                self.updateStatus("In chat", color: "color_card_here")
                                self.isOtherUserTyping = false
                            }
                            // Android Parity: Mark messages as seen when user is "here" (equivalent to Android's markAsSeenAsyncTask)
                            self.markMessagesAsSeen()
                        } else {
                            if otherUserTyping && !self.isPremiumUser {
                                self.updateStatus("Chatting with someone else", color: "color_card_typing")
                                self.isOtherUserTyping = true
                            } else {
                                self.updateStatus("Online", color: "color_card_online")
                                self.isOtherUserTyping = false
                            }
                        }
                    } else {
                        // User is offline
                        if self.isAIChat {
                            // AI offline handling -> always show unified Last seen format
                            if let timeString = timeString {
                                self.updateStatus("Last seen: \(timeString) ago", color: "color_card_offline")
                            } else {
                                self.updateStatus("Last seen: 1s ago", color: "color_card_offline")
                            }
                        } else {
                            if let timeString = timeString {
                                self.updateStatus("Last seen: \(timeString) ago", color: "color_card_offline")
                            } else {
                                self.updateStatus("Last seen: 1s ago", color: "color_card_offline")
                            }
                        }
                        self.isOtherUserTyping = false
                    }
                    
                    // Update other properties
                    self.otherUserIsOnline = isUserOnline
                    if let timestamp = data["last_time_seen"] as? Timestamp {
                        self.otherUserLastSeen = timestamp.dateValue()
                    }
                    self.otherUserChattingInCurrentChat = isHere
                    
                    // Track enter/leave moments using here_timestamp if provided
                    if isHere {
                        self.otherUserHereEnterTime = hereTimestamp ?? Date()
                        // While here, mark our sent messages as seen in real time
                        self.markSentMessagesAsSeenLocally(upTo: nil)
                    } else {
                        if let leaveTime = hereTimestamp ?? self.otherUserLastSeen {
                            self.otherUserHereLeaveTime = leaveTime
                            // On leaving, mark our sent messages up to leave time
                            self.markSentMessagesAsSeenLocally(upTo: leaveTime)
                        }
                    }
                }
            }
    }
    
    private func setupBlockListener() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupBlockListener() Setting up block status listener")
        
        // Block status listener implementation would go here
        // This is a placeholder for consistency with Android implementation
    }
    
    // MARK: - Additional Features
    
    private func fetchOtherUserDetails() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserDetails() Fetching details for: \(otherUser.name)")
        
        // Fetch user interests from Firebase (Android Parity - correct field names)
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .getDocument { document, error in
                if let document = document, document.exists {
                    let data = document.data()
                    let interestTags = data?["interest_tags"] as? [String] ?? [] // Android Parity: correct field name
                    let interestSentence = data?["interest_sentence"] as? String ?? "" // Android Parity: support sentence
                    
                    DispatchQueue.main.async {
                        // Use displayInterests method for consistent formatting (Android Parity)
                        self.displayInterests(tags: interestTags, sentence: interestSentence)
                        
                        // Update status display (Android Parity)
                        self.updateUserStatus()
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserDetails() Failed to fetch user details: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
    }
    
    private func startAIStatusSimulation() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "startAIStatusSimulation() Starting AI status simulation")
        
        aiStatus = "online"
        updateUserStatus() // Update status display (Android Parity)
        
        aiStatusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            let statuses = ["online", "typing", "offline"]
            aiStatus = statuses.randomElement() ?? "online"
            
            DispatchQueue.main.async {
                updateUserStatus() // Update status display when AI status changes (Android Parity)
            }
        }
    }
    
    // MARK: - Image and Voice Handling
    
    private func handleImageSelected(_ image: UIImage) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageSelected() processing selected image")
        
        // Show uploading toast (matching Android pattern)
        showToastMessage("Uploading photo please wait...")
        
        // Start image moderation and upload task (matching Android pattern)
        startImageModerationAndUploadTask(image: image)
    }
    
    private func startImageModerationAndUploadTask(image: UIImage) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "startImageModerationAndUploadTask() Starting image processing workflow")
        
        // Step 1: Save image temporarily for moderation (Android parity)
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let tempImagePath = saveImageTemporarily(imageData: imageData) else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "startImageModerationAndUploadTask() Failed to save image temporarily")
            showToastMessage("Failed to process image")
            return
        }
        
        // Step 2: Image Moderation using new HiveImageModerationService (Android parity)
        class ModerationCallback: HiveImageModerationService.HiveImageModerationCallback {
            let messagesView: MessagesView
            let image: UIImage
            
            init(messagesView: MessagesView, image: UIImage) {
                self.messagesView = messagesView
                self.image = image
            }
            
            func onHiveImageModerationComplete(_ isNSFW: Bool) {
                DispatchQueue.main.async {
                    self.messagesView.handleModerationResult(isNSFW: isNSFW, image: self.image)
                }
            }
        }
        
        let callback = ModerationCallback(messagesView: self, image: image)
        HiveImageModerationService.shared.moderateImage(imagePath: tempImagePath, callback: callback)
    }
    
    // Android Parity: Save image temporarily for moderation
    private func saveImageTemporarily(imageData: Data) -> String? {
        let tempDir = NSTemporaryDirectory()
        let tempFileName = "temp_image_\(Int64(Date().timeIntervalSince1970)).jpg"
        let tempFilePath = tempDir + tempFileName
        
        do {
            try imageData.write(to: URL(fileURLWithPath: tempFilePath))
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveImageTemporarily() Saved to: \(tempFilePath)")
            return tempFilePath
        } catch {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveImageTemporarily() Failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Android Parity: Handle moderation result
    private func handleModerationResult(isNSFW: Bool, image: UIImage) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleModerationResult() isNSFW: \(isNSFW)")
        
        if isNSFW {
            // Image not allowed (matching Android toast message exactly)
            showToastMessage("Image selected is not allowed, choose another")
        } else {
            // Step 3: Compression is handled by AWSClass (0.5 compression quality)
            // Step 4: AWS Upload (matching Android UploadImageToAwsClass pattern)
            uploadImageToAWS(image: image)
        }
    }
    
    private func uploadImageToAWS(image: UIImage) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "uploadImageToAWS() Starting AWS upload")
        
        let userId = currentUserId
        let imageName = "\(userId)_\(Int64(Date().timeIntervalSince1970)).jpg"
        
        // Use AWSClass to upload image (matching Android UploadImageToAwsClass pattern)
                 AWSService.sharedInstance.uploadImageToS3(
             image: image,
             imageName: imageName
         ) { imageUrl, error in
             DispatchQueue.main.async {
                 if let error = error {
                     AppLogger.log(tag: "LOG-APP: MessagesView", message: "uploadImageToAWS() Upload failed: \(error.localizedDescription)")
                     self.showToastMessage("Failed to upload image")
                 } else if let imageUrl = imageUrl {
                     AppLogger.log(tag: "LOG-APP: MessagesView", message: "uploadImageToAWS() Upload complete: \(imageUrl)")
                     // Step 4: Send message with AWS URL (matching Android sendImageMessage pattern)
                     self.sendImageMessage(imageURL: imageUrl)
                 } else {
                     AppLogger.log(tag: "LOG-APP: MessagesView", message: "uploadImageToAWS() Upload failed: No URL returned")
                     self.showToastMessage("Failed to upload image")
                 }
             }
         }
    }
    
    private func sendImageMessage(imageURL: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendImageMessage() sending image message with URL: \(imageURL)")
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        
        // Android Pattern: Do NOT create local message object
        // Only write to Firebase, the listener will catch it and save to local database
        
        // Send to Firebase (matching Android Firebase structure)
        let messageData: [String: Any] = [
            "message_text_content": "",
            "message_userId": currentUserId,
            "message_sender_name": currentUserName,
            "message_time_stamp": FieldValue.serverTimestamp(),
            "message_seen": false, // Android Parity: Use message_seen field
            "message_ad_available": false,
            "message_actual": "",
            "message_premium": false,
            "is_ai_message": false,
            "message_image": imageURL,
            "message_is_bad": false
        ]
        
        Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .collection("Messages")
            .document(messageId)
                         .setData(messageData) { error in
                 if let error = error {
                     AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendImageMessage() failed: \(error.localizedDescription)")
                 } else {
                     AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendImageMessage() success")
                     
                     // Android Parity: Mark that a message was sent this session
                     self.messageSentThisSession = true
                     
                     self.updateLastMessage(text: "📷 Image", timestamp: timestamp)
                     
                     // Increment message sent counter for rating system (Android Parity)
                     MessagingSettingsSessionManager.shared.incrementMessageCount()
                     
                     // Increment per-user message count for message limit popup
                     MessagingSettingsSessionManager.shared.incrementMessageCount(otherUserId: self.otherUser.id)
                 }
             }
    }
    
    // MARK: - AI Training Methods
    
    private func saveAITrainingMessage(userMessage: String, aiReply: String) {
        let currentTime = Int64(Date().timeIntervalSince1970)
        let userName = currentUserName
        let aiName = otherUser.name
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAITrainingMessage() Saving training data for chat: \(chatId)")
        
        AITrainingMessageStore.shared.insert(
            messageId: UUID().uuidString,
            chatId: chatId,
            userName: userName,
            userMessage: userMessage,
            replyName: aiName,
            replyMessage: aiReply,
            messageTime: TimeInterval(currentTime)
        )
        
        // Manage storage - keep only latest 25 messages per chat for performance (Android parity)
        let currentMessages = AITrainingMessageStore.shared.getMessagesForChat(chatId: chatId)
        if currentMessages.count > 25 {
            AITrainingMessageStore.shared.deleteOldestMessage(forChatId: chatId)
        }
    }
    
    private func saveUserMessageForTraining(_ messageText: String) {
        guard isAIChat else { return }
        
        SessionManager.shared.setLastUserMessage(messageText, for: chatId)
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveUserMessageForTraining() Stored user message for AI training")
    }
    
    private func getMyProfile() -> UserCoreDataReplacement? {
        let profile = UserCoreDataReplacement.current()
        if profile.isValid && profile.userId == currentUserId {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "getMyProfile() Retrieved profile from SessionManager for user: \(currentUserId)")
            return profile
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "getMyProfile() No valid profile found in SessionManager for user: \(currentUserId)")
            return nil
        }
    }
    
    private func getOtherUserProfile() -> UserCoreDataReplacement? {
        // For other user profile, we'll create a minimal profile with the chat user data
        // In a real scenario, this would come from the chat context or API
        let otherProfile = UserCoreDataReplacement(
            userId: otherUser.id,
            username: otherUser.name,
            age: nil, // We don't have this data from the chat
            gender: otherUser.gender,
            country: nil, // We don't have this data from the chat
            language: nil, // We don't have this data from the chat
            image: otherUser.profileImage,
            deviceId: nil, // We don't have this data from the chat
            deviceToken: nil // We don't have this data from the chat
        )
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "getOtherUserProfile() Created profile for other user: \(otherUser.id)")
        return otherProfile
    }
    
    private func getConversationHistory() -> String {
        return messages.suffix(15).map { msg in
            let sender = msg.isFromCurrentUser ? "Me" : otherUser.name
            return "\(sender): \(msg.text)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Direct Call Button Handlers (Android Parity)
    

    
    private func handleLiveButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() Live button tapped")
        
        // DEBUG: Log current liveSeconds
        let currentSeconds = MessagingSettingsSessionManager.shared.liveSeconds
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() Current liveSeconds: \(currentSeconds)")
        
        // Android Pattern: Check permissions first (camera and microphone)
        if !hasPermission(for: .microphone) || !hasPermission(for: .camera) {
            permissionDialogType = .microphoneAndCamera
            showPermissionDialog = true
            return
        }
        
        // Android Pattern: If already turned on, turn it off
        if isLiveOn {
            stopLive()
            return
        }
        
        // Android Pattern: Check subscription status - live calls require Plus or Pro
        let subscriptionManager = SubscriptionSessionManager.shared
        let hasPlusAccess = subscriptionManager.hasPlusTierOrHigher()
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() Subscription status - PlusOrHigher: \(hasPlusAccess)")
        
        if hasPlusAccess {
            // Check if user has time remaining before starting live
            if currentSeconds <= 0 {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() No liveSeconds available - showing time exceeded toast")
                showToastMessage("Live time has expired. Please wait for time to replenish or upgrade your subscription.")
                return
            }
            
            // Start live
            startLive()
        } else {
            // Non-premium user - check if they have any live seconds remaining
            if currentSeconds <= 0 {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() Free user with no liveSeconds - showing monetization dialog")
                showLiveCallMonetizationDialog()
            } else {
                // Free user with some time remaining - start live
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLiveButtonTap() Free user with \(currentSeconds) seconds remaining - starting live")
                startLive()
            }
        }
    }
    
    private func handleCameraSwitchButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleCameraSwitchButtonTap() Camera switch button tapped")
        liveManager.switchCamera()
    }
    
    private func handleVideoToggleButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleVideoToggleButtonTap() Video toggle button tapped")
        // Toggle video on/off while keeping audio
        liveManager.toggleVideo()
    }
    
    private func handleMuteButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleMuteButtonTap() Mute button tapped")
        // Toggle audio mute
        liveManager.toggleMute()
    }
    
    private func handleGamesButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleGamesButtonTap() Games button tapped - launching Infinite X/O game")
        navigateToInfiniteXOGame = true
    }
    
    // MARK: - Direct Call Implementation (Android Parity)
    

    
    private func startLive() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "startLive() Starting live connection")
        
        // Android Pattern: Set status first
        setLive(true)
        isLiveOn = true
        
        // Android Pattern: Initialize Agora engine for live video
        liveManager.initializeAgoraEngineForLive(chatId: chatId)
        liveManager.setupLocalVideo()
        
        // Android Pattern: Start timer
        startLiveTimer()
        
        // Android Pattern: Update UI (matching directVideoAnimation(true) and show camera_switch)
        // The UI will automatically update due to the state change in liveOverlayView
        
        // Android Pattern: Show toast
        showToastMessage("Live connected")
    }
    
    // MARK: - Android Parity: LiveSeconds Replenishment Logic
    
    /// Replenish liveSeconds based on subscription status (Android Parity)
    /// This matches Android's subscription replenishment logic and prevents immediate timer expiration
    private func replenishLiveSecondsIfNeeded() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Checking replenishment needs using TimeAllocationManager")
        
        // Use TimeAllocationManager for subscription-based time allocation
        TimeAllocationManager.shared.replenishLiveSecondsIfNeeded()
        
        let currentSeconds = SessionManager.shared.liveSeconds
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Current liveSeconds after replenishment: \(currentSeconds)")
        
        // Android Parity: Check subscription status
        let subscriptionManager = SubscriptionSessionManager.shared
        let hasPlusAccess = subscriptionManager.hasPlusTierOrHigher()
        
        // ANDROID PARITY: Check legacy premium status as fallback (for backward compatibility)
        let isLegacyPremium = MessagingSettingsSessionManager.shared.premiumActive
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Subscription status - PlusOrHigher: \(hasPlusAccess), Legacy Premium: \(isLegacyPremium)")
        
        if hasPlusAccess || isLegacyPremium {
            // Time allocation managed by TimeAllocationManager
            if currentSeconds > 0 {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Premium user - has \(currentSeconds) seconds remaining in current period")
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Premium user - no time remaining in current subscription period")
                showToastMessage("Live time allocation exhausted for this subscription period")
            }
        } else {
            // ANDROID PARITY: Free users always get 60 seconds per session (matching Android onRewarded() method)
            // This ensures free users can always use the live feature at least once per session
            SessionManager.shared.liveSeconds = 60
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "replenishLiveSecondsIfNeeded() Free user - replenished to 60 seconds (Android parity)")
            
            if currentSeconds <= 0 {
                showToastMessage("1 minute Live added")
            }
        }
    }
    
    private func stopLive() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "stopLive() Stopping live connection")
        
        // Android Pattern: Leave channel first
        liveManager.leaveChannel()
        
        // Android Pattern: Cancel timer
        liveTimer?.invalidate()
        
        // Android Pattern: Set status
        setLive(false)
        isLiveOn = false
        
        // Android Pattern: Update UI (matching directVideoAnimation(false) and hide camera_switch/local_video)
        // The UI will automatically update due to the state change in liveOverlayView
    }
    

    
    private func startLiveTimer() {
        // Android Pattern: Use session manager to get live seconds (using direct video seconds)
        let liveSeconds = SessionManager.shared.liveSeconds
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "startLiveTimer() Starting timer with \(liveSeconds) seconds available")
        
        // No need for additional check here since we already checked in startLive()
        
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            
            let remainingSeconds = SessionManager.shared.liveSeconds
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "startLiveTimer tick = \(remainingSeconds)")
            
            // Android Pattern: Decrement seconds in session manager
            SessionManager.shared.liveSeconds = max(0, remainingSeconds - 1)
            
            // Track time consumption in TimeAllocationManager for subscription users
            let subscriptionManager = SubscriptionSessionManager.shared
            if subscriptionManager.hasPlusTierOrHigher() {
                TimeAllocationManager.shared.consumeLiveTime(seconds: 1)
            }
            
            // Android Pattern: Auto-stop when timer finishes
            if SessionManager.shared.liveSeconds <= 0 {
                timer.invalidate()
                self.liveManager.leaveChannel()
                self.setLive(false)
                self.isLiveOn = false
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "Live timer finished - auto-stopping")
            }
        }
    }
    

    
    // MARK: - Android Pattern: setLive (Firebase Updates)
    
    private func setLive(_ isOn: Bool) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setLive() isOn: \(isOn)")
        
        // Update Live collection (matching the listener structure)
        let liveData: [String: Any] = [
            "live": isOn,
            "timestamp": Date()
        ]
        
        Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .collection("Live")
            .document(currentUserId)
            .setData(liveData)
        
        // Also call the setOnLive method (matching Android pattern)
        setOnLive(isOn)
    }
    
    private func setOnLive(_ isOn: Bool) {
        // Android Pattern: Additional status update method
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setOnLive() isOn: \(isOn)")
        // This method can be used for additional status tracking if needed
    }
    
    private func showLiveCallMonetizationDialog() {
        // Android Pattern: Show live call popup for monetization
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "showLiveCallMonetizationDialog() showing live call popup")
        
        showLiveCallPopup = true
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
    
    // MARK: - Dynamic Text Height Calculation (Progressive Growth Like WhatsApp/Telegram)
    
    private func updateTextHeight(for text: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateTextHeight() Calculating height for text length: \(text.count)")
        
        // Calculate the height needed for the text
        let calculatedHeight = calculateTextHeight(for: text)
        
        // Animate the height change smoothly
        withAnimation(.easeInOut(duration: 0.2)) {
            textHeight = calculatedHeight
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateTextHeight() Updated text height to: \(calculatedHeight)")
    }
    
    private func calculateTextHeight(for text: String) -> CGFloat {
        // Calculate text bounds for proper sizing
        let font = UIFont.systemFont(ofSize: 16, weight: .regular)
        let maxWidth = UIScreen.main.bounds.width - 120 // Account for padding, photo button, send button
        
        // Calculate minimum height for single line (using placeholder for empty text)
        let singleLineText = "A" // Always use placeholder to get consistent single line height
        let singleLineRect = singleLineText.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let minimumHeight = singleLineRect.height + 16 // Single line height with padding
        
        // Calculate actual content height if text is not empty
        let contentHeight: CGFloat
        if text.isEmpty {
            contentHeight = minimumHeight
        } else {
            let textRect = text.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            contentHeight = textRect.height + 16
        }
        
        // Progressive growth: Start at minimum height, max at 120pt (4 lines like Android)
        let maxHeight: CGFloat = 120 // Maximum height constraint
        let finalHeight = max(minimumHeight, min(maxHeight, contentHeight))
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "calculateTextHeight() text: '\(text.isEmpty ? "empty" : String(text.prefix(20)))...', calculated: \(contentHeight), final: \(finalHeight)")
        
        return finalHeight
    }
    
    // MARK: - Status and Interests Helper Methods (Android Parity)
    
    private func capitalizeWords(_ text: String) -> String {
        return text.components(separatedBy: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private func getInterestTags() -> [String] {
        guard !otherUserInterests.isEmpty else { return [] }
        
        let interestText = otherUserInterests.first ?? ""
        
        // Remove "Interested in • " prefix if present
        let cleanText = interestText.replacingOccurrences(of: "Interested in • ", with: "")
        
        // Split by " • " separator to get individual interests
        let tags = cleanText.components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return tags
    }
    
    private func getStatusGradient() -> LinearGradient {
        switch currentUserStatus.lowercased() {
        case "online":
            // Green gradient - light from top trailing
            return LinearGradient(
                colors: [Color("Online").opacity(0.7), Color("Online")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case "connecting", "connecting...", "    ":
            // Reload/default state uses pill gray (shade2) - consistent with adjacent pills
            return LinearGradient(
                colors: [Color("shade2"), Color("shade2")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("typing"):
            // Typing uses shade_500 family
            return LinearGradient(
                colors: [Color("shade_500").opacity(0.85), Color("shade_500")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case "here":
            // Red gradient - light from top trailing
            return LinearGradient(
                colors: [Color("Here").opacity(0.8), Color("Here")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("in chat"):
            // Explicit mapping for "In chat" label
            return LinearGradient(
                colors: [Color("Here").opacity(0.8), Color("Here")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case "offline":
            // Offline uses the same gray as interest pills
            return LinearGradient(
                colors: [Color("shade2"), Color("shade2")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case "now":
            // Treat as offline pill gray (we no longer use "now" string)
            return LinearGradient(
                colors: [Color("shade2"), Color("shade2")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("seen"):
            // Last seen is considered an offline-like state → pill gray
            return LinearGradient(
                colors: [Color("shade2"), Color("shade2")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("playing games"):
            // Purple gradient - light from top trailing
            return LinearGradient(
                colors: [Color("playingGames").opacity(0.7), Color("playingGames")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("live"):
            // On-live uses Plus subscription gradient
            return LinearGradient(
                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("call"):
            // On-call uses Pro subscription gradient
            return LinearGradient(
                colors: [Color("proGradientStart"), Color("proGradientEnd")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case let status where status.contains("chatting"):
            // Make "chatting with someone else" visually attractive
            return LinearGradient(
                colors: [Color("instaPink").opacity(0.9), Color("instaPink")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        default:
            // Default to pill gray to match adjacent interest tags
            return LinearGradient(
                colors: [Color("shade2"), Color("shade2")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    private func getStatusTextColor() -> Color {
        let status = currentUserStatus.lowercased()
        switch status {
        case "online", "here":
            // Bright colored backgrounds → white text
            return .white
        case let s where s.contains("typing"):
            return .white
        case let s where s.contains("live"):
            return .white
        case let s where s.contains("call"):
            return .white
        case let s where s.contains("chatting"):
            return .white
        case "connecting", "connecting...", "    ":
            // Gray pill
            return Color("shade6")
        case let s where s.contains("seen"):
            // Last seen → gray pill background; use dark text for readability in light mode
            return Color("shade6")
        case "offline", "now":
            return Color("shade6")
        default:
            // Default to dark-on-light for neutral/gray pills
            return Color("shade6")
        }
    }
    
    private func getInterestsGradient() -> LinearGradient {
        // Same background as text editor - consistent design language
        return LinearGradient(
            colors: [Color("shade2"), Color("shade2")],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
    
    // Android Parity: New status update method with color mapping
    private func updateStatus(_ statusText: String, color colorName: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateStatus() Updating status to: \(statusText)")
        
        currentUserStatus = statusText
        
        // Status and interests container is always visible now (Android parity)
    }
    
    // Android Parity: Smooth animation for status changes (like hereAndTypingAnimation)
    private func performStatusChangeAnimation(newStatus: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "performStatusChangeAnimation() Animating status change from '\(previousStatusText)' to '\(newStatus)'")
        
        // Only animate if status actually changed
        guard newStatus != previousStatusText else { return }
        
        // Android Parity: Scale animation like here_pop_in.xml (scale from 0.8 to 1.0)
        withAnimation(.easeOut(duration: 0.15)) {
            statusAnimationScale = 0.8
            statusAnimationOpacity = 0.8
        }
        
        // Return to normal scale with slight bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.1)) {
                statusAnimationScale = 1.0
                statusAnimationOpacity = 1.0
            }
        }
        
        // Update previous status for next comparison
        previousStatusText = newStatus
        
        // Trigger animation state change for color transitions
        animationTrigger.toggle()
    }
    
    // Android Parity: Display interests method matching Android exactly
    private func displayInterests(tags: [String], sentence: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "displayInterests() Processing interests")
        
        // Return early if no interests (Android Parity)
        if tags.isEmpty && sentence.isEmpty {
            return
        }
        
        var interestsBuilder = ""
        
        // Add tags with separator (Android Parity)
        if !tags.isEmpty {
            for tag in tags {
                interestsBuilder += tag + " • "
            }
        }
        
        // Add sentence (Android Parity)
        if !sentence.isEmpty {
            interestsBuilder += sentence
        }
        
        // Remove trailing separator (Android Parity)
        if interestsBuilder.hasSuffix(" • ") {
            interestsBuilder = String(interestsBuilder.dropLast(3))
        }
        
        // Set final text with prefix (Android Parity)
        let finalInterestsText = "Interested in • " + interestsBuilder
        
        // Update interests display
        DispatchQueue.main.async {
            // Convert to array for MarqueeText (keeping the formatted string)
            self.otherUserInterests = [finalInterestsText]
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "displayInterests() Set interests text: '\(finalInterestsText)'")
            
            // Status and interests container is always visible now (Android parity)
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "displayInterests() Set interests text: '\(finalInterestsText)'")
        }
    }
    
    // Android Parity: Handle AI status updates
    private func handleAIStatus() {
        // This method handles AI-specific status logic
        // Implementation would match Android's handleFirstStatus, handleDoYourTasksStatus methods
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleAIStatus() AI status handling")
    }
    
    private func updateUserStatus() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateUserStatus() Updating user status display")
        
        if isAIChat {
            switch aiStatus.lowercased() {
            case "typing":
                currentUserStatus = "Typing…"
            case "online":
                currentUserStatus = "Online"
            case "offline":
                if let lastSeen = otherUserLastSeen {
                    let timeAgo = formatLastSeenTime(lastSeen)
                    currentUserStatus = "Last seen: \(timeAgo) ago"
                } else {
                    currentUserStatus = "Last seen: 1s ago"
                }
            default:
                currentUserStatus = aiStatus.capitalized
            }
        } else if isOtherUserTyping {
            currentUserStatus = "Typing…"
        } else if otherUserIsOnline {
            currentUserStatus = "Online"
        } else {
            if let lastSeen = otherUserLastSeen {
                let timeAgo = formatLastSeenTime(lastSeen)
                currentUserStatus = "Last seen: \(timeAgo) ago"
            } else {
                // Only update to "now" if we have actual data, otherwise keep initial status
                // This prevents overriding "Connecting..." with empty data during initial load
                if !otherUserLastSeen.debugDescription.isEmpty || otherUserIsOnline {
                    currentUserStatus = "Online"
                }
            }
        }
        
        // Status and interests container is always visible now (Android parity)
    }
    
    private func formatLastSeenTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        // Android Parity: Match TimeFormatter.getTimeAgo() format exactly
        if interval < 60 {
            let seconds = Int(interval)
            return seconds < 1 ? "1s" : "\(seconds)s"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1m" : "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1h" : "\(hours)h"
        } else if interval < 604800 { // 7 days
            let days = Int(interval / 86400)
            return days == 1 ? "1d" : "\(days)d"
        } else if interval < 2592000 { // 30 days
            let weeks = Int(interval / 604800)
            return weeks == 1 ? "1w" : "\(weeks)w"
        } else if interval < 31536000 { // 365 days
            let months = Int(interval / 2592000)
            return months == 1 ? "1mo" : "\(months)mo"
        } else {
            let years = Int(interval / 31536000)
            return years == 1 ? "1y" : "\(years)y"
        }
    }
    
    // MARK: - Image Selection

    private func handleImageButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Image button tapped")

        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .authorized, .limited:
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Permission already granted. Opening image picker.")
            DispatchQueue.main.async {
                self.showImagePicker = true
            }
        case .notDetermined:
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Permission not determined. Requesting permission.")
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Permission granted. Opening image picker.")
                        self.showImagePicker = true
                    } else {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Permission denied.")
                        self.showToastMessage("Photo library access was denied.")
                    }
                }
            }
        case .denied, .restricted:
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Permission denied or restricted. Showing settings alert.")
            showPermissionDeniedAlert()
        @unknown default:
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleImageButtonTap() Unknown authorization status.")
            break
        }
    }

    private func showPermissionDeniedAlert() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "showPermissionDeniedAlert() Photo library access denied.")

        let alert = UIAlertController(
            title: "Permission Denied",
            message: "To send photos, please allow ChatHub to access your photo library in Settings.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })

        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {

            var topViewController = rootViewController
            while let presentedViewController = topViewController.presentedViewController {
                topViewController = presentedViewController
            }

            topViewController.present(alert, animated: true)
        }
    }
}

struct OngoingCallBarView: View {
    let isVideoCall: Bool
    let otherUserName: String
    let onTapToView: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isVideoCall ? "video.fill" : "phone.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ongoing call")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Click to view")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(otherUserName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .onTapGesture {
            onTapToView()
        }
    }
}



// Removed ChatTypingIndicatorView - Android Parity: typing status only shown in status blob at bottom

struct LiveOverlayView: View {
    let isLocalActive: Bool
    let isRemoteActive: Bool
    let isLocalSpeaking: Bool
    let isRemoteSpeaking: Bool
    let localVideoView: UIView?
    let remoteVideoView: UIView?
    let isVideoEnabled: Bool
    let isMuted: Bool
    let otherUserName: String
    let onCameraSwitch: () -> Void
    let onVideoToggle: () -> Void
    let onMute: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            LiveVideoContainerView(
                localVideoView: localVideoView,
                remoteVideoView: remoteVideoView,
                isLocalActive: isLocalActive,
                isRemoteActive: isRemoteActive,
                isVideoEnabled: isVideoEnabled,
                isMuted: isMuted,
                otherUserName: otherUserName,
                onCameraSwitch: onCameraSwitch,
                onVideoToggle: onVideoToggle,
                onMute: onMute
            )
            .frame(height: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color("Background Color"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color("shade3"))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}



// MARK: - Live Video Container View
struct LiveVideoContainerView: View {
    let localVideoView: UIView?
    let remoteVideoView: UIView?
    let isLocalActive: Bool
    let isRemoteActive: Bool
    let isVideoEnabled: Bool
    let isMuted: Bool
    let otherUserName: String
    let onCameraSwitch: () -> Void
    let onVideoToggle: () -> Void
    let onMute: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Local video (You)
            LiveVideoUserView(
                videoView: localVideoView,
                isCurrentUser: true,
                userName: "You",
                isActive: isLocalActive,
                isVideoEnabled: isVideoEnabled
            )
            
            // Right side - Remote video (Other user)
            LiveVideoUserView(
                videoView: remoteVideoView,
                isCurrentUser: false,
                userName: otherUserName,
                isActive: isRemoteActive,
                isVideoEnabled: true // Other user's video state
            )
            
            // Control buttons overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // Control buttons
                    VStack(spacing: 8) {
                        // Camera flip button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onCameraSwitch()
                        }) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        // Video toggle button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onVideoToggle()
                        }) {
                            Image(systemName: isVideoEnabled ? "video.fill" : "video.slash.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background((isVideoEnabled ? Color.black : Color("ErrorRed")).opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        // Mute button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onMute()
                        }) {
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background((isMuted ? Color("ErrorRed") : Color.black).opacity(0.7))
                                .clipShape(Circle())
                        }
                        

                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Live Video User View
struct LiveVideoUserView: View {
    let videoView: UIView?
    let isCurrentUser: Bool
    let userName: String
    let isActive: Bool
    let isVideoEnabled: Bool
    
    var body: some View {
        ZStack {
            // Video container
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .overlay(
                    Group {
                        if let videoView = videoView, isActive && isVideoEnabled {
                            AgoraVideoViewRepresentable(videoView: videoView)
                                .cornerRadius(12)
                        } else {
                            // Placeholder when video is off
                            VStack(spacing: 8) {
                                Image(systemName: isVideoEnabled ? "video.slash.fill" : "video.slash.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(isActive ? (isVideoEnabled ? "Connecting..." : "Video Off") : "Video Off")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                )
                .overlay(
                    // User name label
                    VStack {
                        Spacer()
                        HStack {
                            Text(userName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(.leading, 8)
                                .padding(.bottom, 8)
                            Spacer()
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.75, contentMode: .fit) // 4:3 aspect ratio for video
    }
}

// MARK: - Agora Video View Representable
struct AgoraVideoViewRepresentable: UIViewRepresentable {
    let videoView: UIView
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Clear existing subviews
        uiView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add the Agora video view
        videoView.frame = uiView.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        uiView.addSubview(videoView)
    }
}



// MARK: - Improved Photo Library Picker
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .fullScreen
        
        // Additional configuration to prevent dismissal issues
        picker.navigationBar.isTranslucent = false
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Ensure the picker stays presented
        if uiViewController.presentingViewController == nil {
            AppLogger.log(tag: "LOG-APP: PhotoLibraryPicker", message: "updateUIViewController() picker not properly presented")
        }
    }

    @objc(PhotoLibraryPickerCoordinator)
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            AppLogger.log(tag: "LOG-APP: PhotoLibraryPicker", message: "didFinishPickingMediaWithInfo() Image selected successfully")
            
            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async {
                    self.parent.onImagePicked(image)
                }
            } else {
                AppLogger.log(tag: "LOG-APP: PhotoLibraryPicker", message: "didFinishPickingMediaWithInfo() Failed to get image from info")
            }
            
            // Don't dismiss here - let the parent handle dismissal
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            AppLogger.log(tag: "LOG-APP: PhotoLibraryPicker", message: "imagePickerControllerDidCancel() User cancelled image selection")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - MarqueeText Component (Android Parity)

struct MarqueeText: View {
    let text: String
    let font: Font
    let leftFade: CGFloat
    let rightFade: CGFloat
    let startDelay: Double
    
    @State private var animateText = false
    @State private var textWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible text to measure width
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .opacity(0)
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeometry.size.width
                                    viewWidth = geometry.size.width
                                    AppLogger.log(tag: "LOG-APP: MarqueeText", message: "Measured textWidth: \(textWidth), viewWidth: \(viewWidth) for text: '\(text)'")
                                    startAnimation()
                                }
                                .onChange(of: geometry.size.width) { newWidth in
                                    viewWidth = newWidth
                                    startAnimation()
                                }
                        }
                    )
                
                // Visible scrolling text
                if textWidth > viewWidth && textWidth > 0 && viewWidth > 0 {
                    // Text overflows - show scrolling animation
                    HStack(spacing: 50) {
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                        Text(text) // Duplicate for seamless loop
                            .font(font)
                            .lineLimit(1)
                    }
                    .offset(x: animateText ? -(textWidth + 50) : 0)
                    .animation(
                        Animation.linear(duration: Double(textWidth / 30))
                            .repeatForever(autoreverses: false),
                        value: animateText
                    )
                    .clipped()
                } else {
                    // Text fits - show static text
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                
                // Fade effects only when scrolling
                if textWidth > viewWidth && textWidth > 0 && viewWidth > 0 {
                    HStack {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black, location: 0),
                                .init(color: Color.clear, location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: leftFade)
                        .blendMode(.destinationOut)
                        
                        Spacer()
                        
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0),
                                .init(color: Color.black, location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: rightFade)
                        .blendMode(.destinationOut)
                    }
                }
            }
        }
        .compositingGroup()
        .clipped()
        .onAppear {
            // Restart animation when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimation()
            }
        }
        .onChange(of: text) { _ in
            // Reset and restart when text changes
            animateText = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard !text.isEmpty && textWidth > viewWidth && textWidth > 0 && viewWidth > 0 else {
            AppLogger.log(tag: "LOG-APP: MarqueeText", message: "No animation needed - text fits or invalid dimensions")
            return
        }
        
        // Reset animation
        animateText = false
        
        // Start animation after delay (Android parity)
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            AppLogger.log(tag: "LOG-APP: MarqueeText", message: "Starting marquee animation for: '\(text)'")
            animateText = true
        }
    }
}



// MARK: - Adaptive Entry Pill (single-row when fits, two-row otherwise)
// Removed adaptive layout for simplicity and to reduce height
private struct EntryPillAdaptiveView: View {
    let question: String
    let yesTitle: String
    let yesSystem: String
    let noTitle: String
    let noSystem: String
    let gradientColors: [Color]
    var onYes: () -> Void
    var onNo: () -> Void

    @State private var questionWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Measure available width
            GeometryReader { proxy in
                Color.clear
                    .onAppear { availableWidth = proxy.size.width - 28 }
                    .onChange(of: proxy.size.width) { newWidth in
                        availableWidth = newWidth - 28
                    }
            }
            .frame(height: 0)

            // Invisible measurement for question text (single-line width)
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.clear)
                .lineLimit(1)
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { questionWidth = g.size.width }
                            .onChange(of: g.size.width) { newWidth in questionWidth = newWidth }
                    }
                )
                .hidden()

            if fitsSingleRow(availableWidth: availableWidth) {
                HStack(spacing: 10) {
                    Text(question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    pillButton(title: yesTitle, system: yesSystem, bg: Color.white.opacity(0.2), action: onYes)
                    pillButton(title: noTitle, system: noSystem, bg: Color.white.opacity(0.15), action: onNo)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        pillButton(title: yesTitle, system: yesSystem, bg: Color.white.opacity(0.2), action: onYes)
                        pillButton(title: noTitle, system: noSystem, bg: Color.white.opacity(0.15), action: onNo)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pillButton(title: String, system: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(bg)
            .clipShape(Capsule())
        }
    }

    private func fitsSingleRow(availableWidth: CGFloat) -> Bool {
        // Approximate: question + two buttons widths should fit available width
        // Buttons are relatively constant width (~80 each including padding). Use 170 as heuristic.
        let buttonsWidth: CGFloat = 170
        guard availableWidth > 0, questionWidth > 0 else { return false }
        return (questionWidth + buttonsWidth) <= availableWidth
    }
}

#Preview {
    MessagesView(
        chatId: "sample_chat_id",
        otherUser: ChatUser(
            id: "other_user_id",
            name: "John Doe",
            profileImage: "",
            gender: "Male",
            deviceId: "device_123",
            isOnline: true
        ),
        isFromInbox: false
    )
}

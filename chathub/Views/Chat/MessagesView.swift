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
    
    // Android-style typing + here status (Unique Feature Implementation)
    @State private var typingDebounceWork: DispatchWorkItem?
    @State private var typingActive: Bool = false
    @State private var isHere: Bool = false // Tracks if other user is "here" in this chat
    private let typingDelay: TimeInterval = 1.5
    
    // Text editor focus state
    @FocusState private var isTextEditorFocused: Bool

    @State private var showSubscriptionPopup: Bool = false
    @State private var showInterestStatus: Bool = false
    @State private var fullScreenImageURL: String = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    // MARK: - Screenshot Protection
    @StateObject private var captureProtection = CaptureProtection()
    // Unified Info Gathering System (Periodic pill display)
    private enum InfoGatherContent {
        case interest(phrase: String)
        case aboutYou(key: String, question: String)
        
        var title: String {
            switch self {
            case .interest: return "Are you interested in"
            case .aboutYou: return "Tell us more about you"
            }
        }
        
        var text: String {
            switch self {
            case .interest(let phrase): return phrase.interestDisplayFormatted
            case .aboutYou(_, let question): return question
            }
        }
    }
    @State private var currentInfoGatherContent: InfoGatherContent? = nil
    @State private var infoGatherTimer: Timer? = nil
    @State private var aboutYouValues: [String: String] = [:]
    @State private var infoGatherDelay: TimeInterval = 5.0 // Adaptive delay
    @State private var pillsShownThisSession: Int = 0
    private let maxPillsPerSession: Int = 15
    @State private var interestRejectionCounts: [String: Int] = [:]
    private let maxInterestRejections: Int = 2

    
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
    @State private var otherUserIsPremium: Bool = false // Track if OTHER USER is premium (Android parity)
    
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
    // Notification permission popup removed - now handled in ProfileView
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
    @State private var statusListener: ListenerRegistration? = nil
    @State private var blockListener: ListenerRegistration? = nil
    @State private var liveListener: ListenerRegistration? = nil
    @State private var androidDirectVideoListener: ListenerRegistration? = nil
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
    
    // MARK: - Android Parity: Notification State Variables
    @State private var isThisChatPaid: Bool = false // Android: ISTHISCHATPAID
    @State private var otherUserHasNotificationsDisabled: Bool = false // Android: MUTED - other user disabled notifications globally
    @State private var otherUserHasMutedMe: Bool = false // Android: MINEMUTED - other user specifically muted me
    @State private var aiChatEnabled: Bool = false // Android: AICHATENABLED
    
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
                isRemoteAudioMuted: liveManager.isRemoteAudioMuted,
                otherUserName: otherUser.name,
                onCameraSwitch: { handleCameraSwitchButtonTap() },
                onVideoToggle: { handleVideoToggleButtonTap() },
                onLocalMute: { handleLocalMuteButtonTap() },
                onRemoteMute: { handleRemoteMuteButtonTap() }
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
            .transition(.move(edge: .top).combined(with: .opacity))
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
            .onChange(of: messages.count) { oldCount, newCount in
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "messagesScrollView onChange() messages count changed from \(oldCount) to \(newCount), isFirstLoad: \(isFirstLoad)")
                
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
            // Unified periodic info gathering pill
            if let content = currentInfoGatherContent {
                InfoGatherPill(
                    title: content.title,
                    text: content.text,
                    onYes: { handleInfoGatherResponse(content: content, accepted: true) },
                    onNo: { handleInfoGatherResponse(content: content, accepted: false) }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)))
            }

            statusAndInterestsView
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
        HStack(spacing: 4) {
            let iconName = getStatusIcon(for: currentUserStatus)
            if !iconName.isEmpty {
                if iconName.hasPrefix("emoji:") || iconName.unicodeScalars.first?.properties.isEmoji == true {
                    // Display emoji as text
                    Text(iconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(getStatusTextColor())
                } else {
                    // Display SF Symbol
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(getStatusTextColor())
                }
            }
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
        .onChange(of: currentUserStatus) { _, newStatus in
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
                                .padding(.leading, 16) // Increased padding to account for TextEditor's internal padding
                                .padding(.vertical, 2) // Match TextEditor vertical padding
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
                                .textContentType(.none) // Prevent password suggestions, enable word suggestions
                                .keyboardType(.default) // Ensure default keyboard with word suggestions
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
                                .textContentType(.none) // Prevent password suggestions, enable word suggestions
                                .keyboardType(.default) // Ensure default keyboard with word suggestions
                                .frame(height: textHeight) // Dynamic height - starts at calculated height
                                .padding(.leading, 10)
                                .padding(.trailing, 4) // Minimal padding to photo button
                                .padding(.vertical, 2)
                                .background(Color.clear)
                                .focused($isTextEditorFocused)
                                // iOS 14-15 use UITextView.appearance() from AppDelegate
                        }
                    }
                        .onChange(of: messageText) { _, newText in
                            updateTextHeight(for: newText)
                            handleTypingDebounced()
                        }
                        .onChange(of: isTextEditorFocused) { _, focused in
                            // Stop typing when losing focus
                            if !focused {
                                stopTypingOnAction()
                            }
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
            
            // MARK: - Notification Permission Popup Overlay (Moved to ProfileView)
            // Notification permission popup has been moved to ProfileView to show when user clicks "start chat"
            
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
        // Back button (system-provided) + badge + username with controlled spacing and centered alignment
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 0) {
                // Chats badge immediately next to system back chevron (reduced gap)
                if badgeManager.chatsBadgeCount > 0 {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        BadgeView(count: badgeManager.chatsBadgeCount)
                            .padding(.leading, -25) // Negative padding to pull closer to back button
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Username with larger gap from badge
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "username tapped - navigating to profile for user: \(otherUser.name)")
                    showUserProfile = true
                }) {
                    HStack(spacing: 4) {
                        Text(isAIChat ? "\(otherUser.name)." : otherUser.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("dark"))
                        
                        // DEBUG ONLY: AI indicator dot
                        #if DEBUG
                        if isAIChat {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                        #endif
                    }
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
        .effectiveScreenshotBlock() // Apply effective screenshot prevention
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScreenshotAttemptDetected"))) { notification in
            handleScreenshotAttempt(notification)
        }
    }
    
    // MARK: - Lifecycle Methods
    
    private func handleViewAppear() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "MessagesView onAppear() - ensuring scroll to bottom for latest messages")
        
        // MARK: - Screenshot Protection Setup
        captureProtection.start()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "Effective screenshot prevention enabled - content embedded in secure field")
        
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

        // Start unified info gathering system with integrated interest suggestions
        startInfoGatheringSystem()

        // Update "here" status so other devices can detect we're in this chat (Android parity)
        updateHereStatus(isActive: true)
    }

    // MARK: - Unified Info Gathering System
    
    private func startInfoGatheringSystem() {
        // Load rejection counts from UserDefaults
        loadInterestRejectionCounts()
        
        // Load AboutYou answers from local storage only (no Firestore read)
        loadAboutYouValuesFromLocal()
        
        // Cleanup old presented questions tracking data (housekeeping)
        cleanupOldPresentedQuestions()
        
        // DEBUG: Test if system can handle interest suggestions - add a test suggestion
        // Remove this after confirming the system works
        let debugState = SimplifiedInterestManager.shared.debugCurrentState()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "startInfoGatheringSystem() Initial state: \(debugState)")
        
        // Show first pill immediately - no network dependency
        showNextInfoGatherPill()
        
        // Optional: Sync Firestore data to local storage in background (for migration)
        syncFirestoreToLocalInBackground()
    }
    
    private func showNextInfoGatherPill() {
        // Check session limits
        guard pillsShownThisSession < maxPillsPerSession else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "showNextInfoGatherPill() Session limit reached (\(maxPillsPerSession))")
            return
        }
        
        // Get next content using the same alternating logic
        guard let content = getNextInfoGatherContent() else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "showNextInfoGatherPill() No content available - scheduling retry")
            // CRITICAL FIX: Always schedule next check even when no content available
            // This ensures the system keeps checking for new suggestions as they become available
            scheduleNextInfoGatherPill(delay: infoGatherDelay)
            return
        }
        
        // Show the pill with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentInfoGatherContent = content
        }
        
        pillsShownThisSession += 1
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "showNextInfoGatherPill() Showed pill \(pillsShownThisSession)/\(maxPillsPerSession)")
    }
    
    private func handleInfoGatherResponse(content: InfoGatherContent, accepted: Bool) {
        // Process the response based on content type
        switch content {
        case .interest(let phrase):
            if accepted {
                acceptInterestSuggestion(phrase)
            } else {
                rejectInterestSuggestion(phrase)
            }
            
        case .aboutYou(let key, _):
            saveAboutYouAnswer(key: key, yes: accepted)
        }
        
        // Hide current pill with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentInfoGatherContent = nil
        }
        
        // Increase delay slightly after each interaction to be less aggressive
        infoGatherDelay = min(infoGatherDelay * 1.2, 20.0) // Cap at 20 seconds
        
        // Schedule next pill after delay
        scheduleNextInfoGatherPill(delay: infoGatherDelay)
    }
    
    private func scheduleNextInfoGatherPill(delay: TimeInterval) {
        // Invalidate existing timer
        infoGatherTimer?.invalidate()
        
        // Schedule new timer
        infoGatherTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                self.showNextInfoGatherPill()
            }
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "scheduleNextInfoGatherPill() Next pill in \(delay) seconds")
    }
    
    /// CRITICAL FIX: Trigger immediate pill check when new content becomes available
    /// This prevents the dead state where system waits indefinitely when both lists were initially empty
    private func triggerImmediatePillCheckIfNeeded() {
        // Only trigger if no pill is currently showing and we're within session limits
        guard currentInfoGatherContent == nil && pillsShownThisSession < maxPillsPerSession else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerImmediatePillCheckIfNeeded() Skipping - pill showing or session limit reached")
            return
        }
        
        // Check if we now have content available (when we previously didn't)
        let availableInterest = nextInterestSuggestionForEntry()
        let availableAboutYou = nextAboutYouQuestionForEntry()
        
        if availableInterest != nil || availableAboutYou != nil {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerImmediatePillCheckIfNeeded() New content available - triggering immediate check")
            // Cancel existing timer and show immediately
            infoGatherTimer?.invalidate()
            // Small delay to let the UI settle after message send
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showNextInfoGatherPill()
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "triggerImmediatePillCheckIfNeeded() No new content available yet")
        }
    }
    
    private func getNextInfoGatherContent() -> InfoGatherContent? {
        // Use resilient alternating logic that prioritizes showing any available content
        let defaults = UserDefaults.standard
        let lastCategoryA = defaults.bool(forKey: "entry_pill_last_was_A")
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() lastCategoryA: \(lastCategoryA)")
        
        // Check what's available before attempting
        let availableInterest = nextInterestSuggestionForEntry()
        let availableAboutYou = nextAboutYouQuestionForEntry()
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() Available - Interest: \(availableInterest ?? "none"), AboutYou: \(availableAboutYou?.question ?? "none")")
        
        // RESILIENT LOGIC: Always show something if available, prefer alternating when both exist
        if availableInterest != nil && availableAboutYou != nil {
            // Both available - use alternating logic
            if !lastCategoryA {
                // Prefer interest suggestions first
                defaults.set(true, forKey: "entry_pill_last_was_A")
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() Alternating - Showing INTEREST: \(availableInterest!)")
                return .interest(phrase: availableInterest!)
            } else {
                // Prefer AboutYou questions first
                defaults.set(false, forKey: "entry_pill_last_was_A")
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() Alternating - Showing ABOUTYOU: \(availableAboutYou!.question)")
                return .aboutYou(key: availableAboutYou!.key, question: availableAboutYou!.question)
            }
        } else if let phrase = availableInterest {
            // Only interests available - keep showing them
            defaults.set(true, forKey: "entry_pill_last_was_A")
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() Interest-only mode - Showing INTEREST: \(phrase)")
            return .interest(phrase: phrase)
        } else if let aboutYou = availableAboutYou {
            // Only AboutYou available - keep showing them
            defaults.set(false, forKey: "entry_pill_last_was_A")
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() AboutYou-only mode - Showing ABOUTYOU: \(aboutYou.question)")
            return .aboutYou(key: aboutYou.key, question: aboutYou.question)
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "getNextInfoGatherContent() No content available")
        return nil
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
        
        // Stop typing indicator when view disappears
        stopTypingOnAction()
    
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
        case .liveFeature:
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
        case .liveFeature:
            AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                if audioGranted {
                    AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                        if videoGranted {
                            DispatchQueue.main.async {
                                self.handleLiveButtonTap()
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
        case .liveFeature:
            return "Camera and microphone permissions are required to use the live feature"
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
        fetchOtherUserPremiumStatus() // One-time fetch of other user's premium status
        
        // MARK: - Android Parity: Load notification state variables
        loadNotificationStateVariables()
        
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
        
        // Clean up info gathering timer
        infoGatherTimer?.invalidate()
        infoGatherTimer = nil
        
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
        // Delegate to Android-style setHere function
        setHere(isActive)
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



    // MARK: - Simplified Interest System
    
    // NOTE: showInterestSuggestionPill() removed - interests now use InfoGatherPill timing system
    
    /// Handle user accepting an interest suggestion (simplified)
    private func acceptInterestSuggestion(_ phrase: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "acceptInterestSuggestion() '\(phrase)' accepted")
        
        // Add to interests list
        SimplifiedInterestManager.shared.addInterest(phrase)
        
        // Remove from pending queue
        SimplifiedInterestManager.shared.removePendingSuggestion(phrase)
        
        // Show success feedback
        // TODO: Add toast notification "Added to interests"
    }

    /// Handle user rejecting an interest suggestion (simplified)
    private func rejectInterestSuggestion(_ phrase: String) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "rejectInterestSuggestion() '\(phrase)' rejected")
        
        // Remove from pending queue (discarded)
        SimplifiedInterestManager.shared.removePendingSuggestion(phrase)
        
        // Use simplified manager (no-op - just discard)
        SimplifiedInterestManager.shared.rejectInterest(phrase)
    }



    private func nextInterestSuggestionForEntry() -> String? {
        // Get next pending suggestion from SimplifiedInterestManager queue
        let suggestion = SimplifiedInterestManager.shared.getNextPendingSuggestion()
        
        // Debug current state
        let debugState = SimplifiedInterestManager.shared.debugCurrentState()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "nextInterestSuggestionForEntry() \(debugState)")
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "nextInterestSuggestionForEntry() Returning: \(suggestion ?? "nil")")
        
        return suggestion
    }

    private func nextAboutYouQuestionForEntry() -> (key: String, question: String)? {
        // Complete set of yes/no style profile fields from EditProfile
        // Map Firestore key -> human-readable question
        let candidates: [(String, String)] = [
            // Relationship & Personal Status
            ("like_men", "Do you like men?"),
            ("like_woman", "Do you like women?"),
            ("single", "Are you single?"),
            ("married", "Are you married?"),
            ("children", "Do you have children?"),
            
            // Lifestyle & Activities
            ("gym", "Do you go to the gym?"),
            ("smokes", "Do you smoke?"),
            ("drinks", "Do you drink?"),
            ("games", "Do you play video games?"),
            ("decent_chat", "Do you prefer decent conversation?"),
            
            // Interests & Hobbies
            ("pets", "Do you love pets?"),
            ("travel", "Do you love to travel?"),
            ("music", "Do you love music?"),
            ("movies", "Do you love movies?"),
            ("naughty", "Are you naughty?"),
            ("foodie", "Are you a foodie?"),
            ("dates", "Do you go on dates?"),
            ("fashion", "Do you love fashion?"),
            
            // Emotional State
            ("broken", "Are you feeling broken or hurt?"),
            ("depressed", "Are you feeling depressed?"),
            ("lonely", "Are you feeling lonely?"),
            ("cheated", "Have you been cheated on?"),
            ("insomnia", "Do you have trouble sleeping?"),
            
            // Communication Preferences
            ("voice_allowed", "Do you allow voice calls?"),
            ("video_allowed", "Do you allow video calls?"),
            ("pics_allowed", "Do you send pictures?")
        ]

        let defaults = UserDefaults.standard
        let indexKey = "entry_pill_about_index"
        var startIndex = defaults.integer(forKey: indexKey)
        if startIndex < 0 || startIndex >= candidates.count { startIndex = 0 }

        // Load presented questions tracking
        let presentedQuestions = loadPresentedAboutYouQuestions()
        
        // Find questions that haven't been answered AND haven't been presented recently
        for offset in 0..<candidates.count {
            let idx = (startIndex + offset) % candidates.count
            let (key, question) = candidates[idx]
            let current = aboutYouValues[key] ?? ""
            
            // Skip if already answered
            if !current.isEmpty && current != "null" {
                continue
            }
            
            // Skip if already presented recently (within last 30 days)
            if let lastPresented = presentedQuestions[key] {
                let daysSincePresented = Date().timeIntervalSince(lastPresented) / (24 * 60 * 60)
                if daysSincePresented < 30 {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "nextAboutYouQuestionForEntry() Skipping '\(key)' - presented \(Int(daysSincePresented)) days ago")
                    continue
                }
            }
            
            // This question is eligible - mark as presented and return it
            markAboutYouQuestionAsPresented(key: key)
            
            // Advance pointer to the next item for future entries
            defaults.set((idx + 1) % candidates.count, forKey: indexKey)
            
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "nextAboutYouQuestionForEntry() Selected question: '\(key)' - '\(question)'")
            return (key, question)
        }

        // All questions either answered or recently presented — still advance pointer
        defaults.set((startIndex + 1) % max(candidates.count, 1), forKey: indexKey)
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "nextAboutYouQuestionForEntry() No eligible questions found")
        return nil
    }





    // MARK: - Interest Rejection Tracking Persistence
    
    private func loadInterestRejectionCounts() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "interest_rejection_counts"),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            interestRejectionCounts = counts
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadInterestRejectionCounts() Loaded \(counts.count) rejection counts")
        } else {
            interestRejectionCounts = [:]
        }
    }
    
    private func saveInterestRejectionCounts() {
        let defaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(interestRejectionCounts)
            defaults.set(data, forKey: "interest_rejection_counts")
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveInterestRejectionCounts() Saved \(interestRejectionCounts.count) rejection counts")
        } catch {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveInterestRejectionCounts() Error saving: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Local AboutYou Storage (No initial Firestore read)
    
    private func loadAboutYouValuesFromLocal() {
        let defaults = UserDefaults.standard
        let aboutYouKey = "about_you_answers"
        
        if let data = defaults.data(forKey: aboutYouKey),
           let values = try? JSONDecoder().decode([String: String].self, from: data) {
            aboutYouValues = values
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadAboutYouValuesFromLocal() Loaded \(values.count) answers from local storage")
        } else {
            aboutYouValues = [:]
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadAboutYouValuesFromLocal() No local answers found - starting fresh")
        }
    }
    
    private func saveAboutYouAnswerToLocal(key: String, value: String) {
        let defaults = UserDefaults.standard
        let aboutYouKey = "about_you_answers"
        
        // Update in-memory cache
        aboutYouValues[key] = value
        
        // Save to local storage
        if let data = try? JSONEncoder().encode(aboutYouValues) {
            defaults.set(data, forKey: aboutYouKey)
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAboutYouAnswerToLocal() Saved \(key)=\(value) locally")
        }
    }

    private func saveAboutYouAnswer(key: String, yes: Bool) {
        let userId = UserSessionManager.shared.userId ?? ""
        let value = yes ? "true" : "null"
        
        // 1. Save to local storage first (immediate, no network dependency)
        saveAboutYouAnswerToLocal(key: key, value: value)
        
        // 2. Sync to Firestore in background (for cross-device sync)
        let db = Firestore.firestore()
        db.collection("Users").document(userId).setData([key: value], merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAboutYouAnswer() Firestore sync failed: \(error.localizedDescription)")
                // Local storage still works, just no cross-device sync
            } else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "saveAboutYouAnswer() Synced \(key)=\(value) to Firestore")
            }
        }
    }
    
    // MARK: - Presented Questions Tracking
    
    /// Load the tracking data for which AboutYou questions have been presented to the user
    private func loadPresentedAboutYouQuestions() -> [String: Date] {
        let defaults = UserDefaults.standard
        let presentedKey = "about_you_questions_presented"
        
        if let data = defaults.data(forKey: presentedKey),
           let timestamps = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            let presentedQuestions = timestamps.mapValues { Date(timeIntervalSince1970: $0) }
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadPresentedAboutYouQuestions() Loaded \(presentedQuestions.count) presented questions")
            return presentedQuestions
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadPresentedAboutYouQuestions() No presentation tracking found, starting fresh")
            return [:]
        }
    }
    
    /// Mark an AboutYou question as having been presented to the user
    private func markAboutYouQuestionAsPresented(key: String) {
        let defaults = UserDefaults.standard
        let presentedKey = "about_you_questions_presented"
        
        // Load existing data
        var presentedQuestions = loadPresentedAboutYouQuestions()
        
        // Add/update the timestamp for this question
        presentedQuestions[key] = Date()
        
        // Save back to UserDefaults
        let timestamps = presentedQuestions.mapValues { $0.timeIntervalSince1970 }
        do {
            let data = try JSONEncoder().encode(timestamps)
            defaults.set(data, forKey: presentedKey)
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "markAboutYouQuestionAsPresented() Marked '\(key)' as presented at \(Date())")
        } catch {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "markAboutYouQuestionAsPresented() Error saving: \(error.localizedDescription)")
        }
    }
    
    /// Clean up old presentation tracking data (optional, for housekeeping)
    private func cleanupOldPresentedQuestions() {
        let defaults = UserDefaults.standard
        let presentedKey = "about_you_questions_presented"
        let cutoffDate = Date().addingTimeInterval(-90 * 24 * 60 * 60) // 90 days ago
        
        var presentedQuestions = loadPresentedAboutYouQuestions()
        let originalCount = presentedQuestions.count
        
        // Remove entries older than 90 days
        presentedQuestions = presentedQuestions.filter { $0.value > cutoffDate }
        
        if presentedQuestions.count != originalCount {
            let timestamps = presentedQuestions.mapValues { $0.timeIntervalSince1970 }
            do {
                let data = try JSONEncoder().encode(timestamps)
                defaults.set(data, forKey: presentedKey)
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "cleanupOldPresentedQuestions() Cleaned up \(originalCount - presentedQuestions.count) old entries")
            } catch {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "cleanupOldPresentedQuestions() Error saving: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Optional Background Migration (Non-blocking)
    
    private func syncFirestoreToLocalInBackground() {
        let userId = UserSessionManager.shared.userId ?? ""
        guard !userId.isEmpty else { return }
        
        // Only sync if local storage is empty (migration case)
        if aboutYouValues.isEmpty {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "syncFirestoreToLocalInBackground() Starting background migration")
            
            DispatchQueue.global(qos: .utility).async {
                Firestore.firestore().collection("Users").document(userId).getDocument { doc, _ in
                    var values: [String: String] = [:]
                    if let data = doc?.data() {
                        let keys = [
                            // Relationship & Personal Status
                            "like_men", "like_woman", "single", "married", "children",
                            // Lifestyle & Activities
                            "gym", "smokes", "drinks", "games", "decent_chat",
                            // Interests & Hobbies
                            "pets", "travel", "music", "movies", "naughty", "foodie", "dates", "fashion",
                            // Emotional State
                            "broken", "depressed", "lonely", "cheated", "insomnia",
                            // Communication Preferences
                            "voice_allowed", "video_allowed", "pics_allowed"
                        ]
                        for k in keys {
                            if let v = data[k] as? String, !v.isEmpty && v != "null" {
                                // Migrate old "yes"/"no" format to "true"/"null" format
                                if v == "yes" {
                                    values[k] = "true"
                                } else if v == "no" {
                                    values[k] = "null"
                                } else {
                                    values[k] = v
                                }
                            }
                        }
                    }
                    
                    // Update local storage with migrated data
                    if !values.isEmpty {
                        DispatchQueue.main.async {
                            let defaults = UserDefaults.standard
                            let aboutYouKey = "about_you_answers"
                            
                            if let data = try? JSONEncoder().encode(values) {
                                defaults.set(data, forKey: aboutYouKey)
                                self.aboutYouValues = values
                                AppLogger.log(tag: "LOG-APP: MessagesView", message: "syncFirestoreToLocalInBackground() Migrated \(values.count) answers from Firestore")
                            }
                        }
                    }
                }
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
        
        // ⚡ LAYER 1: Fast Detection + Immediate Action (PRESERVED - NO CHANGES)
        let appNameViolation = Profanity.share.doesContainProfanityAppName(text)
        if appNameViolation {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "Layer 1: App name violation detected - applying penalties and restrictions")
            let currentScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
            ModerationSettingsSessionManager.shared.hiveTextModerationScore = currentScore + 101
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "Layer 1: Updated moderation score to: \(ModerationSettingsSessionManager.shared.hiveTextModerationScore)")
            
            // Apply conversation restriction for app name violations
            ConversationRestrictionManager.shared.applyRestrictionForAppNameViolation()
            
            // Move conversation to inbox immediately for app name violations
            setMoveToInbox(true)
        }
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        let bad = Profanity.share.doesContainProfanity(text)
        
        // ANDROID PARITY: Check conversation started status and handle profanity
        checkConversationStarted()
        
        // IMMEDIATE ACTIONS - First Message Profanity Handling
        if !conversationStarted && bad {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "Layer 1: First message profanity detected - moving to inbox")
            let currentScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
            ModerationSettingsSessionManager.shared.hiveTextModerationScore = currentScore + 10
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "Layer 1: Updated moderation score to: \(ModerationSettingsSessionManager.shared.hiveTextModerationScore)")
            // Move conversation to inbox instead of blocking
            setMoveToInbox(true)
        }
        
        // 🤖 LAYER 2: Advanced Analysis + Silent Data Collection (NEW - NO USER IMPACT)
        // This runs in background after message passes Layer 1 checks
        // Silent intelligence collection for compliance and safety analytics
        DispatchQueue.global(qos: .utility).async {
            SafetySignalManager.shared.analyzeMessageForSafetySignals(text, userId: self.otherUser.id)
        }
        
        // Android Pattern: Do NOT create local message object
        // Only write to Firebase, the listener will catch it and save to local database
        
        // Stop typing indicator when sending message
        stopTypingOnAction()
        
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
                    
                    // Track activity for comprehensive user analytics
                    ActivityTracker.shared.trackMessageSent(to: self.otherUser.id, otherUserGender: self.otherUser.gender)
                    
                    // MARK: - Android Parity: Convert Inbox Chat to Regular Chat
                    // When user sends message from inbox chat, convert it to regular chat (matching Android's setInBox(false))
                    // Note: Only updates Firebase - local database will be updated by ChatsSyncService listener
                    if self.isFromInbox {
                        self.setInBox(false)
                    }
                    
                    // MARK: - Simplified Interest Processing
                    // Process last 4 messages + current for better context-aware interest extraction
                    let contextTexts = self.messages
                        .suffix(4)
                        .filter { !$0.containsProfanity }
                        .map { $0.text }
                    
                    SimplifiedInterestManager.shared.processNewMessageWithContext(
                        latestText: text,
                        contextMessages: contextTexts,
                        maxContext: 5
                    )
                    
                    // CRITICAL FIX: Check if we should show a pill immediately after new suggestions are added
                    // This ensures pills appear promptly when new interests are detected during chat
                    triggerImmediatePillCheckIfNeeded()
                    
                    // MARK: - Android Parity: Send Notification
                    // Send notification to other user following same conditions as Android
                    self.sendNotificationIfNeeded()
                    
                    // MARK: - Contextual Notification Permission Request
                    // Notification permission popup is now handled in ProfileView when user starts chat
                    // This provides better UX as user gives permission before entering the conversation
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
    
    // MARK: - Android Parity: Notification Logic
    
    /// Send notification following same conditions as Android MessageTextActivity
    private func sendNotificationIfNeeded() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "sendNotificationIfNeeded() Checking notification conditions")
        
        // Android Condition 1: AI Chat check (!AICHATENABLED)
        if aiChatEnabled {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - AI chat enabled")
            return
        }
        
        // Android Condition 2: Muting checks (!MUTED && !MINEMUTED)
        if otherUserHasNotificationsDisabled {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - other user has disabled notifications globally")
            return
        }
        
        if otherUserHasMutedMe {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - other user has specifically muted me")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification mute check passed")
        
        // Android Condition 3: Chat paid or conversation started (ISTHISCHATPAID || CONVERSATIONSTARTED)
        if !isThisChatPaid && !conversationStarted {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - chat not paid and conversation not started")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification chat status check passed - paid: \(isThisChatPaid), conversation started: \(conversationStarted)")
        
        // Android Condition 4: Other user not currently active (!ISHERE)
        if isHere {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - other user is currently active in chat")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification presence check passed - other user not here")
        
        // Android Condition 5: Message not already sent (!MSGSENT)
        if !messageSentThisSession {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - message not confirmed sent")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification send status check passed")
        
        // Android Condition 6: Timing conditions (30-minute rule)
        if otherUserIsOnline {
            // If user is online, check if last seen was more than 30 minutes ago
            if let lastSeen = otherUserLastSeen {
                let thirtyMinutesAgo = Date().addingTimeInterval(-1800) // 1800 seconds = 30 minutes
                if lastSeen > thirtyMinutesAgo {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification blocked - other user online and last seen within 30 minutes")
                    return
                }
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification timing check passed - other user online but last seen > 30 minutes ago")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification timing check passed - other user offline")
        }
        
        // All conditions passed - send notification
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "notification all conditions passed - sending notification")
        setUpNotification()
    }
    
    /// Set up notification document in Firebase (matching Android setUpNotification)
    private func setUpNotification() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setUpNotification() preparing notification for user: \(otherUser.id)")
        
        // Fetch FCM token from Firestore using the same field name as Android
        fetchOtherUserFCMToken { fcmToken in
            guard let otherUserToken = fcmToken, !otherUserToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setUpNotification() no FCM token available for other user")
                return
            }
            
            sendNotificationToFirestore(with: otherUserToken)
        }
    }
    
    /// Fetch FCM token for other user from Firestore (Android parity)
    private func fetchOtherUserFCMToken(completion: @escaping (String?) -> Void) {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserFCMToken() fetching token for user: \(otherUser.id)")
        
        Firestore.firestore().collection("Users").document(otherUser.id).getDocument { document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserFCMToken() error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = document?.data() else {
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserFCMToken() no document data found")
                completion(nil)
                return
            }
            
            // Use same field name as Android
            let fcmToken = data["User_device_token"] as? String
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserFCMToken() retrieved token: \(fcmToken?.prefix(20) ?? "nil")...")
            completion(fcmToken)
        }
    }
    
    /// Send notification to Firestore (separated for clarity)
    private func sendNotificationToFirestore(with otherUserToken: String) {
        
        let currentUserName = UserSessionManager.shared.userName ?? "Unknown"
        let currentUserGender = UserSessionManager.shared.userGender ?? "Unknown"
        let currentUserProfilePic = UserSessionManager.shared.userProfilePhoto ?? ""
        
        // Get current message text (assuming it's still in messageText when this is called)
        let notificationContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let notificationData: [String: Any] = [
            "notification_type": "chat",
            "notif_sender_name": currentUserName,
            "notif_sender_id": currentUserId,
            "notif_sender_gender": currentUserGender,
            "notif_sender_image": currentUserProfilePic,
            "notif_token": otherUserToken,
            "notif_id": chatId,
            "notif_content": notificationContent
        ]
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setUpNotification() sending to token: \(otherUserToken.prefix(20))...")
        
        // Send to Firebase (matches Android path structure)
        Firestore.firestore()
            .collection("Notifications")
            .document(otherUser.id)
            .collection("Notifications_chat")
            .document(currentUserId)
            .setData(notificationData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setUpNotification() failed: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setUpNotification() success - notification document created")
                }
            }
    }
    
    /// Load notification-related state variables (Android parity)
    private func loadNotificationStateVariables() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadNotificationStateVariables() Loading notification state variables")
        
        // Check if this chat is paid (Android: ISTHISCHATPAID)
        checkIfChatIsPaid()
        
        // Check muting status (Android: MUTED and MINEMUTED)
        checkMutingStatus()
        
        // Set AI chat status (Android: AICHATENABLED)
        aiChatEnabled = isAIChat
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "loadNotificationStateVariables() AI chat enabled: \(aiChatEnabled)")
    }
    
    /// Check if this chat is paid (matching Android's isThisChatPaid check)
    private func checkIfChatIsPaid() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkIfChatIsPaid() Checking if chat is paid for chatId: \(chatId)")
        
        // In iOS, we can check if this came from a paid source or subscription status
        // For now, we'll assume non-AI chats with premium users are "paid"
        if !isAIChat && otherUserIsPremium {
            isThisChatPaid = true
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkIfChatIsPaid() Chat marked as paid - premium user conversation")
        } else {
            isThisChatPaid = false
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkIfChatIsPaid() Chat marked as not paid")
        }
    }
    
    /// Check muting status (matching Android's MUTED and MINEMUTED checks)
    private func checkMutingStatus() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Checking muting status between users")
        
        // Check if other user has disabled notifications globally (Android: MUTED)
        // This checks if other user's own ID exists in their own BlockedNotificationList
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .collection("BlockedNotificationList")
            .document(otherUser.id) // FIXED: Check for their own ID in their own list
            .getDocument { snapshot, error in
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Error checking if other user disabled notifications: \(error.localizedDescription)")
                    return
                }
                
                if let document = snapshot, document.exists {
                    otherUserHasNotificationsDisabled = document.data()?.keys.contains("blocked_notification_id") ?? false
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Other user has notifications disabled: \(otherUserHasNotificationsDisabled)")
                } else {
                    otherUserHasNotificationsDisabled = false
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Other user has notifications enabled")
                }
            }
        
        // Check if other user has specifically muted me (Android: MINEMUTED)  
        // This checks if my ID exists in other user's BlockedNotificationList
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .collection("BlockedNotificationList")
            .document(currentUserId)
            .getDocument { snapshot, error in
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Error checking if other user muted me: \(error.localizedDescription)")
                    return
                }
                
                if let document = snapshot, document.exists {
                    otherUserHasMutedMe = document.data()?.keys.contains("blocked_notification_id") ?? false
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Other user has specifically muted me: \(otherUserHasMutedMe)")
                } else {
                    self.otherUserHasMutedMe = false
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "checkMutingStatus() Other user has not specifically muted me")
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
    
    // MARK: - Screenshot Protection Methods
    
    private func handleScreenshotAttempt(_ notification: Notification) {
        guard let attemptCount = notification.userInfo?["attemptCount"] as? Int else { return }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleScreenshotAttempt() - Screenshot attempt #\(attemptCount) blocked in anonymous chat")
        
        // No toast needed - screenshot is prevented, so user doesn't need notification
        // Just log the attempt for analytics/monitoring purposes
        handleScreenshotResponse()
    }
    
    private func handleScreenshotResponse() {
        // Additional response to screenshot attempt
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleScreenshotResponse() - Applying additional security measures")
        
        // You can add additional security measures here if needed
        // For example: temporary content blur, logging, etc.
    }
    
    // MARK: - Notification Permission Logic (Moved to ProfileView)
    // Notification permission popup logic has been moved to ProfileView
    // This provides better UX as permission is requested when user initiates chat
    
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
    
    // MARK: - Android-Style Typing + Here Status (Unique Feature)
    
    private func handleTypingDebounced() {
        // Only process if not AI chat
        guard !isAIChat else { return }
        
        // Android-style debounced typing: Leading edge triggers, trailing edge stops
        if !typingActive {
            typingActive = true
            setIsTyping(true)
        }
        
        // Reset the stop timer with each keystroke
        typingDebounceWork?.cancel()
        let work = DispatchWorkItem {
            self.typingActive = false
            self.setIsTyping(false)
        }
        typingDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay, execute: work)
    }
    
    private func setIsTyping(_ isTyping: Bool) {
        let currentUserId = UserSessionManager.shared.userId ?? ""
        
        // Android-style: Update Users/{currentUserId} with other_user_typing field
        let data: [String: Any] = ["other_user_typing": isTyping]
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .setData(data, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setIsTyping() Error: \(error.localizedDescription)")
                }
            }
    }
    
    private func setHere(_ isAmHere: Bool) {
        let currentUserId = UserSessionManager.shared.userId ?? ""
        
        // Android-style: Update current_chat_uid_for_here field
        let chatUid = isAmHere ? otherUser.id : "null"
        let data: [String: Any] = ["current_chat_uid_for_here": chatUid]
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .setData(data, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setHere() Error: \(error.localizedDescription)")
                }
            }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setHere() called with isAmHere: \(isAmHere), chatUid: \(chatUid)")
    }
    
    private func stopTypingOnAction() {
        // Force stop typing on send/blur/dismiss
        typingDebounceWork?.cancel()
        if typingActive {
            typingActive = false
            setIsTyping(false)
        }
    }
    
    // MARK: - Firebase Listeners
    
    private func setupFirebaseListeners() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupFirebaseListeners() Setting up Firebase listeners")
        
        setupMessageListener()
        setupStatusListener()
        setupBlockListener()
        setupLiveListeners() // Add live listeners
    }
    
    private func removeFirebaseListeners() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "removeFirebaseListeners() Removing Firebase listeners")
        
        messageListener?.remove()
        statusListener?.remove()
        blockListener?.remove()
        liveListener?.remove()
        androidDirectVideoListener?.remove()
        
        messageListener = nil
        statusListener = nil
        blockListener = nil
        liveListener = nil
        androidDirectVideoListener = nil
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
                            // Both users have live on
                            // Toast notification removed per user request
                        }
                    }
                }
            }
        
        // CROSS-PLATFORM SYNC: Listen to Android direct video triggers
        // This allows iOS to respond when Android users start direct video
        setupAndroidDirectVideoListener()
    }
    
    // MARK: - CROSS-PLATFORM SYNC: Android Direct Video Listener
    
    private func setupAndroidDirectVideoListener() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() Setting up Android direct video compatibility listener")
        
        // Listen to Android direct video format in the main Chats document
        // Android sets "direct_video_{userId}" in the Chats document
        androidDirectVideoListener = Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .addSnapshotListener { documentSnapshot, error in
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() Error: \(error.localizedDescription)")
                    return
                }
                
                guard let document = documentSnapshot, document.exists, let data = document.data() else {
                    return
                }
                
                // Check if Android user started direct video
                let androidDirectVideoKey = "direct_video_\(self.otherUser.id)"
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() 🔍 Checking for key: \(androidDirectVideoKey) in document data")
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() 📋 All document keys: \(Array(data.keys))")
                
                if let androidDirectVideoActive = data[androidDirectVideoKey] as? Bool {
                    DispatchQueue.main.async {
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() ✅ Found Android direct video status: \(androidDirectVideoActive)")
                        
                        if androidDirectVideoActive && !self.isLiveOn {
                            // Android user started direct video, automatically start iOS live to join
                            AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() 🚀 Android user started direct video, auto-starting iOS live")
                            self.autoStartLiveForAndroidDirectVideo()
                        } else if !androidDirectVideoActive && self.isLiveOn {
                            // Android user stopped direct video, check if we should stop iOS live
                            AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() 🛑 Android user stopped direct video")
                            // Don't auto-stop iOS live as user might want to continue
                            // Toast notification removed per user request
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setupAndroidDirectVideoListener() ❌ Key \(androidDirectVideoKey) not found or not a boolean")
                }
            }
    }
    
    private func autoStartLiveForAndroidDirectVideo() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "autoStartLiveForAndroidDirectVideo() Auto-starting live for Android direct video compatibility")
        
        // Check permissions first
        if !hasPermission(for: .microphone) || !hasPermission(for: .camera) {
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "autoStartLiveForAndroidDirectVideo() Missing permissions, showing permission dialog")
            permissionDialogType = .liveFeature
            showPermissionDialog = true
            return
        }
        
        // Check subscription and time allocation
        let subscriptionManager = SubscriptionSessionManager.shared
        let hasPlusAccess = subscriptionManager.hasPlusTierOrHigher()
        let currentSeconds = MessagingSettingsSessionManager.shared.liveSeconds
        
        if hasPlusAccess || currentSeconds > 0 {
            // Start live to join Android direct video
            startLive()
            // Toast notification removed per user request
        } else {
            // Show monetization dialog
            AppLogger.log(tag: "LOG-APP: MessagesView", message: "autoStartLiveForAndroidDirectVideo() No subscription or time remaining, showing monetization")
            showLiveCallMonetizationDialog()
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
                let onDirectVoice = data["on_direct_voice"] as? Bool ?? false
                let onDirectVideo = data["on_direct_video"] as? Bool ?? false
                let onLive = data["on_live"] as? Bool ?? false
                let currentChatUidForHere = data["current_chat_uid_for_here"] as? String ?? "null"
                
                // Debug logging for Firebase data
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - Firebase Status Data: online=\(isUserOnline), typing=\(otherUserTyping), chatUid=\(currentChatUidForHere), currentUserId=\(self.currentUserId)")
                let hereTimestamp = (data["here_timestamp"] as? Timestamp)?.dateValue()
                let interestTags = data["interest_tags"] as? [String] ?? []
                let interestSentence = data["interest_sentence"] as? String ?? ""
                
                DispatchQueue.main.async {
                    // Update interests display (Android Parity)
                    self.otherUserInterests = interestTags
                    self.displayInterests(tags: interestTags, sentence: interestSentence)
                    
                    // Android-style: Update all state variables first
                    self.otherUserIsOnline = isUserOnline
                    self.isOtherUserTyping = otherUserTyping
                    self.isHere = currentChatUidForHere.lowercased() == self.currentUserId.lowercased()
                    
                    // Update last seen timestamp
                    if let timestamp = data["last_time_seen"] as? Timestamp {
                        self.otherUserLastSeen = timestamp.dateValue()
                    }
                    
                    // Android Parity: Mark messages as seen when user is "here" (equivalent to Android's markAsSeenAsyncTask)
                    if self.isHere {
                        self.markMessagesAsSeen()
                    }
                    
                    // Handle special statuses first (they override the 4-state matrix)
                    if isUserOnline {
                        if self.isAIChat {
                            // AI chat handling
                            self.handleAIStatus()
                            return // Exit early to avoid overriding AI status
                        } else if playingGames && !self.otherUserIsPremium {
                            self.currentUserStatus = "Playing games"
                            return
                        } else if onDirectVoice && !self.otherUserIsPremium {
                            self.currentUserStatus = "On direct voice"
                            return
                        } else if onDirectVideo && !self.otherUserIsPremium {
                            self.currentUserStatus = "On direct video"
                            return
                        } else if onCall && !self.otherUserIsPremium {
                            self.currentUserStatus = "On a call"
                            return
                        } else if onLive && !self.otherUserIsPremium {
                            self.currentUserStatus = "On chathub live" 
                            return
                        }
                    }
                    
                    // Use the Android-style 4-state decision matrix for normal cases
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - About to call updateUserStatus() - online: \(isUserOnline), typing: \(otherUserTyping), here: \(self.isHere)")
                    self.updateUserStatus()
                    
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "Status listener updated - online: \(isUserOnline), typing: \(otherUserTyping), here: \(self.isHere), final status: \(self.currentUserStatus)")
                    
                    // Track additional state for Android parity  
                    self.otherUserChattingInCurrentChat = self.isHere
                    
                    // Track enter/leave moments using here_timestamp if provided
                    if self.isHere {
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
    
    private func fetchOtherUserPremiumStatus() {
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserPremiumStatus() Fetching other user's premium status (one-time)")
        
        // One-time fetch of OTHER USER's premium status (more efficient than listener)
        Firestore.firestore()
            .collection("Users")
            .document(otherUser.id)
            .collection("Premium")
            .document("Premium")
            .getDocument { snapshot, error in
                guard let snapshot = snapshot, snapshot.exists else {
                    DispatchQueue.main.async {
                        self.otherUserIsPremium = false
                        AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserPremiumStatus() Other user premium document not found - defaulting to false")
                    }
                    return
                }
                
                let data = snapshot.data() ?? [:]
                let premiumActive = data["premium_active"] as? Bool ?? false
                
                DispatchQueue.main.async {
                    self.otherUserIsPremium = premiumActive
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "fetchOtherUserPremiumStatus() Other user premium status: \(premiumActive)")
                    
                    // Trigger status update since premium status affects display
                    self.updateUserStatus()
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
                     
                     // MARK: - Android Parity: Send Notification for Image Message
                     // Send notification to other user following same conditions as Android
                     self.sendNotificationIfNeeded()
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
            permissionDialogType = .liveFeature
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
    
    private func handleLocalMuteButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleLocalMuteButtonTap() Local mic mute button tapped")
        // Toggle local audio mute (our microphone)
        liveManager.toggleMute()
    }
    
    private func handleRemoteMuteButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "handleRemoteMuteButtonTap() Remote audio mute button tapped")
        // Toggle remote audio mute (other person's audio)
        liveManager.toggleRemoteAudioMute()
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
        
        // Android Pattern: Toast notification removed per user request
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
        
        // CROSS-PLATFORM SYNC: Also set Android direct video format
        // This ensures Android users see the iOS live functionality as direct video
        let androidCompatData: [String: Any] = [
            "direct_video_\(currentUserId)": isOn,
            "timestamp": Date()
        ]
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setLive() CROSS-PLATFORM DEBUG - Setting Android compatibility data: direct_video_\(currentUserId) = \(isOn) in chatId: \(chatId)")
        
        Firestore.firestore()
            .collection("Chats")
            .document(chatId)
            .setData(androidCompatData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setLive() Error setting Android compatibility data: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setLive() ✅ CROSS-PLATFORM SUCCESS - Android compatibility data written: direct_video_\(self.currentUserId) = \(isOn)")
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setLive() 🔍 Android should now see this field in Chats/\(self.chatId) and auto-trigger direct video")
                }
            }
        
        // Also call the setOnLive method (matching Android pattern)
        setOnLive(isOn)
    }
    
    private func setOnLive(_ isOn: Bool) {
        // Android Pattern: Update user's on_live status in Users collection
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "setOnLive() isOn: \(isOn)")
        
        // Update the user's status in Users collection with comprehensive live data
        var userData: [String: Any] = [
            "on_live": isOn,
            "on_direct_video": isOn, // CROSS-PLATFORM SYNC: Android compatibility
            "timestamp": Date()
        ]
        
        // When starting live, also set the current chat context
        if isOn {
            userData["current_chat_uid_for_live"] = otherUser.id
            userData["live_timestamp"] = Date()
        } else {
            // When ending live, clear the context
            userData["current_chat_uid_for_live"] = "null"
        }
        
        Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .setData(userData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setOnLive() Error updating Users collection: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "setOnLive() Successfully updated Users collection with on_live: \(isOn), on_direct_video: \(isOn), chat_uid: \(isOn ? self.otherUser.id : "null")")
                }
            }
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
        case "online", "here", "in chat":
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
    
    private func getStatusIcon(for status: String) -> String {
        let normalizedStatus = status.lowercased()
        switch normalizedStatus {
        case "in chat":
            return "👀"
        case let s where s.contains("typing"):
            return "text.bubble"
        case "online":
            return "circle.fill"
        case let s where s.contains("chatting"):
            return "bubble.left.and.bubble.right.fill"
        case let s where s.contains("playing"):
            return "gamecontroller.fill"
        case let s where s.contains("direct voice"):
            return "phone.fill"
        case let s where s.contains("direct video"):
            return "video.fill"
        case let s where s.contains("call"):
            return "phone.fill"
        case let s where s.contains("chathub live"), let s where s.contains("live"):
            return "tv.fill"
        case let s where s.contains("last seen"):
            return "clock.fill"
        case "offline":
            return "zzz"
        default:
            return ""
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
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "updateUserStatus() Updating user status display with Android-style decision matrix")
        
        // Debug logging for "Chatting with someone else" detection
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - Status Variables: isHere=\(isHere), isOtherUserTyping=\(isOtherUserTyping), otherUserIsOnline=\(otherUserIsOnline), otherUserIsPremium=\(otherUserIsPremium)")
        
        if isAIChat {
            // AI chat logic (unchanged)
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
        } else {
            // Android-style 4-state decision matrix
            // Note: We check OTHER USER's premium status, not current user's (Android parity)
            
            if isHere {
                // Other user is "here" in this specific chat
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - User is HERE in this chat")
                if isOtherUserTyping {
                    currentUserStatus = "Typing…"
                } else {
                    currentUserStatus = "In chat"
                }
            } else {
                // Other user is not in this chat (somewhere else or offline)
                AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - User is NOT HERE - checking typing status")
                if isOtherUserTyping && !otherUserIsPremium {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - Setting status to 'Chatting with someone else…' - typing=\(isOtherUserTyping), otherUserIsPremium=\(otherUserIsPremium)")
                    currentUserStatus = "Chatting with someone else…"
                } else if otherUserIsOnline {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - Setting status to 'Online' - online=\(otherUserIsOnline)")
                    currentUserStatus = "Online"
                } else {
                    AppLogger.log(tag: "LOG-APP: MessagesView", message: "DEBUG - Setting status to 'Last seen' - user offline")
                    // Show last seen time for offline users
                    if let lastSeen = otherUserLastSeen {
                        let timeAgo = formatLastSeenTime(lastSeen)
                        currentUserStatus = "Last seen: \(timeAgo) ago"
                    } else {
                        currentUserStatus = "Online"
                    }
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesView", message: "Status updated to: \(currentUserStatus) (isHere: \(isHere), isTyping: \(isOtherUserTyping), isOnline: \(otherUserIsOnline))")
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
    let isRemoteAudioMuted: Bool
    let otherUserName: String
    let onCameraSwitch: () -> Void
    let onVideoToggle: () -> Void
    let onLocalMute: () -> Void
    let onRemoteMute: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            LiveVideoContainerView(
                localVideoView: localVideoView,
                remoteVideoView: remoteVideoView,
                isLocalActive: isLocalActive,
                isRemoteActive: isRemoteActive,
                isVideoEnabled: isVideoEnabled,
                isMuted: isMuted,
                isRemoteAudioMuted: isRemoteAudioMuted,
                otherUserName: otherUserName,
                onCameraSwitch: onCameraSwitch,
                onVideoToggle: onVideoToggle,
                onLocalMute: onLocalMute,
                onRemoteMute: onRemoteMute
            )
            .frame(height: 200)
        }
        .background(Color.clear)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
    let isRemoteAudioMuted: Bool
    let otherUserName: String
    let onCameraSwitch: () -> Void
    let onVideoToggle: () -> Void
    let onLocalMute: () -> Void
    let onRemoteMute: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left half - Other person's video
                ZStack {
                    LiveVideoUserView(
                        videoView: remoteVideoView,
                        isCurrentUser: false,
                        userName: otherUserName,
                        isActive: isRemoteActive,
                        isVideoEnabled: true // Other user's video state
                    )
                    
                    // Mute remote button - bottom left
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                // Mute remote user's audio (so we don't hear them)
                                onRemoteMute()
                            }) {
                                Image(systemName: isRemoteAudioMuted ? "speaker.slash.fill" : "speaker.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background((isRemoteAudioMuted ? Color("ErrorRed") : Color.black).opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 6)
                            .padding(.bottom, 12)
                            
                            Spacer()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(width: (geometry.size.width - 12) / 2)

                // Explicit middle gap to avoid any overlay bleed collapsing spacing
                Spacer()
                    .frame(width: 12)

                // Right half - Your video
                ZStack {
                    LiveVideoUserView(
                        videoView: localVideoView,
                        isCurrentUser: true,
                        userName: "You",
                        isActive: isLocalActive,
                        isVideoEnabled: isVideoEnabled
                    )
                    
                    // Your controls - bottom right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 10) {
                                // Mic button (top)
                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    // Mute our microphone (so other person doesn't hear us)
                                    onLocalMute()
                                }) {
                                    Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background((isMuted ? Color("ErrorRed") : Color.black).opacity(0.7))
                                        .clipShape(Circle())
                                }
                                
                                // Video toggle button (middle)
                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onVideoToggle()
                                }) {
                                    Image(systemName: isVideoEnabled ? "video.fill" : "video.slash.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background((isVideoEnabled ? Color.black : Color("ErrorRed")).opacity(0.7))
                                        .clipShape(Circle())
                                }
                                
                                // Camera flip button (bottom)
                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onCameraSwitch()
                                }) {
                                    Image(systemName: "camera.rotate.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.trailing, 6)
                            .padding(.bottom, 12)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(width: (geometry.size.width - 12) / 2)
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
            // Full-bleed video container with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .overlay(
                    Group {
                        if let videoView = videoView, isActive && isVideoEnabled {
                            AgoraVideoViewRepresentable(videoView: videoView)
                                .aspectRatio(contentMode: .fill)
                                .clipped()
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
                    // User name label - positioned based on user
                    VStack {
                        HStack {
                            if !isCurrentUser {
                                // Other person - left aligned
                                Text(userName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                                    .padding(.leading, 6)
                                    .padding(.top, 12)
                                Spacer()
                            } else {
                                // Current user - right aligned
                                Spacer()
                                Text(userName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                                    .padding(.trailing, 6)
                                    .padding(.top, 12)
                            }
                        }
                        Spacer()
                    }
                )
                .frame(maxHeight: .infinity)
        }
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
                                .onChange(of: geometry.size.width) { _, newWidth in
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
        .onChange(of: text) { _, _ in
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

import SwiftUI
import UIKit
import FirebaseFirestore
import AVFoundation
import FirebaseAnalytics
import SDWebImageSwiftUI

// MARK: - RewardType Enum (Previously from VAdEnhancer)
enum RewardType {
    case message
    case messageAgain
}

// MARK: - ChatPayData Struct (Defined in Models/Chat/ChatModels.swift)

// UserProfile struct moved to ChatHub/Models/UserProfile.swift

struct ProfileView: View {
    let otherUserId: String
    
    // MODERN UX: Accept basic user data from online users list for immediate display
    let initialUserName: String?
    let initialGender: String?
    let initialCountry: String?
    let initialProfileImage: String?
    
    @State private var userProfile: UserProfile?
    @State private var userDetails: [String] = []
    @State private var isLoading: Bool = false  // Start with false, only set to true if no local data exists
    @State private var errorMessage: String? = nil
    @State private var showPhotoViewer: Bool = false
    @State private var showUserReport: Bool = false
    @State private var navigateToMessages: Bool = false
    @State private var showMakeCall: Bool = false
    @State private var showVideoCall: Bool = false
    @State private var navigateToProfileOptions: Bool = false
    @State private var bannedUser: Bool = false
    @State private var chatExists: Bool = false
    @State private var chatId: String = ""
    @State private var isBlocked: Bool = false
    @State private var otherUserBlocked: Bool = false
    @State private var otherUserDevId: String = ""
    @State private var showPermissionDialog: Bool = false
    @State private var permissionDialogType: PermissionType = .microphone
    @State private var showConversationLimitPopup = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSubscriptionView = false
    
    // Conversation Limit Popup Data (New System)
    @State private var conversationLimitResult: FeatureLimitResult?
    
    // Chat Pay Data (Legacy - for compatibility)
    @State private var chatPayData: ChatPayData?
    @State private var showChatPayPopup = false

    
    // Session data
    @State private var currentUserId: String = ""
    @State private var currentUserName: String = ""
    @State private var currentDeviceId: String = ""
    @State private var currentGender: String = ""
    @State private var currentProfilePhoto: String = ""
    @State private var currentCountry: String = ""
    
    // MARK: - Initializers
    
    // Convenience initializer for backward compatibility
    init(otherUserId: String) {
        self.otherUserId = otherUserId
        self.initialUserName = nil
        self.initialGender = nil
        self.initialCountry = nil
        self.initialProfileImage = nil
    }
    
    // Full initializer with basic user data from online users list
    init(otherUserId: String, userName: String?, gender: String?, country: String?, profileImage: String?) {
        self.otherUserId = otherUserId
        self.initialUserName = userName
        self.initialGender = gender
        self.initialCountry = country
        self.initialProfileImage = profileImage
    }
    
    // Convenience initializer from OnlineUser
    init(onlineUser: OnlineUser) {
        self.otherUserId = onlineUser.id
        self.initialUserName = onlineUser.name
        self.initialGender = onlineUser.gender
        self.initialCountry = onlineUser.country
        self.initialProfileImage = onlineUser.profileImage.isEmpty ? nil : onlineUser.profileImage
    }
    
    // AI Training Messages
    @State private var aiTrainingMessages: [AITrainingMessage] = []
    
    // Subscription Status
    @State private var isProSubscriber: Bool = false
    
    // Local Database - Use centralized DatabaseManager
    private var profileDB: ProfileDB? { DatabaseManager.shared.getProfileDB() }



    // New Popup States (Android Parity - Using specific popups)
    @State private var showVoiceCallPopup = false
    @State private var showVideoCallPopup = false
    @State private var showNotificationPermissionPopup = false
    
    // MARK: - Conversation Flow Tracking
    @State private var conversationFlowSessionId: String?
    @State private var conversationFlowStartTime: Date?
    
    // MARK: - AI Detection (Debug Support)
    @State private var otherUserIpAddress: String?
    @State private var otherUserLastSeenTime: Double = 0
    
    private var shouldShowAIIndicator: Bool {
        // Show AI indicator if AI takeover is likely to happen based on current conditions
        return shouldAiTakeOver()
    }

    var body: some View {
        ZStack {
            mainContent
            // Conversation Limit popup overlay (Always-Show Strategy)
            if showConversationLimitPopup, let result = conversationLimitResult {
                ConversationLimitPopupView(
                    isPresented: $showConversationLimitPopup,
                    remainingCooldown: result.remainingCooldown,
                    isLimitReached: result.isLimitReached,
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    onStartConversation: {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "ConversationLimitPopup onStartConversation callback - resetting popup state")
                        showConversationLimitPopup = false
                        conversationLimitResult = nil
                        handleStartConversationFromPopup()
                    },
                    onUpgradeToPremium: {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "ConversationLimitPopup onUpgradeToPremium callback - resetting popup state")
                        showConversationLimitPopup = false
                        conversationLimitResult = nil
                        navigateToSubscription()
                    },
                    isShadowBan: ModerationSettingsSessionManager.shared.textModerationIssueSB && result.remainingCooldown > 0
                )
            }
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
            
            // Notification Permission popup overlay
            if showNotificationPermissionPopup {
                AppNotificationPermissionPopupView(
                    isPresented: $showNotificationPermissionPopup,
                    onAllow: {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "notificationPermissionPopup onAllow() User agreed to allow notifications")
                        
                        // Close custom popup immediately
                        showNotificationPermissionPopup = false
                        
                        // Wait for custom popup to fully close before showing system popup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Clean approach: Request iOS permission and update FCM token in one step
                            FCMTokenUpdateService.shared.requestPermissionAndUpdateToken(
                                context: "profile_notification_popup"
                            ) { success in
                                AppLogger.log(tag: "LOG-APP: ProfileView", message: "notificationPermissionPopup Permission request and FCM token update completed: \(success)")
                                
                                if success {
                                    // Reset retry mechanism on success
                                    AppNotificationPermissionService.shared.resetRetryMechanism()
                                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "notificationPermissionPopup Notification setup completed successfully")
                                }
                            }
                        }
                    },
                    onMaybeLater: {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "notificationPermissionPopup onMaybeLater() User chose maybe later")
                        
                        // Handle "maybe later" with retry mechanism
                        AppNotificationPermissionService.shared.handleMaybeLaterResponse(context: "start_chat_button")
                        
                        showNotificationPermissionPopup = false
                        
                        // Proceed with chat creation anyway
                        proceedAfterNotificationPermission()
                    }
                )
                .zIndex(1000) // Ensure it appears above all other content
            }

            // Enhanced toast overlay
            if showToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(toastMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            // Shadow layer
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.black.opacity(0.3))
                                .offset(y: 2)
                                .blur(radius: 4)
                            
                            // Main background
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.black.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.showToast = false
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // CRITICAL DEBUG: Log the exact state when view appears
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "🚀 onAppear() TRIGGERED - otherUserId: \(otherUserId), isLoading: \(isLoading), userProfile: \(userProfile?.username ?? "nil")")
            
            // CRITICAL FIX: Load profile data immediately following the same pattern as other views
            loadProfileDataImmediately()
            
            // Fetch other user metadata for AI takeover logic (Android parity)
            fetchOtherUserMetadata()
        }
        .onDisappear {
            // CRITICAL FIX: Reset popup states when view disappears to prevent stale values
            cleanupPopupStates()
        }
        .task {
            // Background tasks for session data and other operations
            await loadSessionData()
            // NOTE: Removed loadUserProfileFromDB() call to prevent duplicate loading and loading animation flicker
            // The loadProfileDataImmediately() method already handles database loading and background refresh
            await checkBlockStatus()
            await checkExistingChat()
            sendProfileViewNotification()
            fetchAIMessages()
            
            // Enhanced Firebase Analytics logging
            var analyticsParameters: [String: Any] = [
                "other_user_id": otherUserId,
                "current_user_id": currentUserId,
                "view_timestamp": Int64(Date().timeIntervalSince1970)
            ]
            
            if let profile = userProfile {
                analyticsParameters["other_user_gender"] = profile.gender
                analyticsParameters["other_user_age"] = profile.age
                analyticsParameters["other_user_country"] = profile.country
                analyticsParameters["other_user_platform"] = profile.platform
                analyticsParameters["other_user_subscription_tier"] = profile.subscriptionTier ?? "none"
                analyticsParameters["details_count"] = userDetails.count
                
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "task() Firebase Analytics: profile_view_opened with parameters: \(analyticsParameters)")
            }
            
            Analytics.logEvent("profile_view_opened", parameters: analyticsParameters)
        }
        .background(
            Group {
                NavigationLink(
                    destination: Group {
                        if let profile = userProfile {
                            PhotoViewerView(
                                imageUrl: profile.profileImage,
                                imageUserId: profile.id,
                                imageType: profile.gender.lowercased() == "male" ? "profilemale" : "profilefemale"
                            )
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $showPhotoViewer
                ) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(
                    destination: Group {
                        if let profile = userProfile {
                            let other = ChatUser(
                                id: otherUserId,
                                name: profile.name,
                                profileImage: profile.profileImage,
                                gender: profile.gender,
                                deviceId: otherUserDevId,
                                isOnline: profile.isOnline
                            )
                            MessagesView(chatId: chatId, otherUser: other, isFromInbox: false)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToMessages
                ) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(
                    destination: Group {
                        if let profile = userProfile {
                            ProfileOptionsView(
                                otherUserId: otherUserId,
                                otherUserName: profile.name,
                                otherUserDevId: otherUserDevId,
                                otherUserGender: profile.gender,
                                chatId: chatId,
                                onConversationCleared: {
                                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "ProfileOptionsView onConversationCleared() - conversation cleared, staying on ProfileView")
                                    // Stay on ProfileView since user came from ProfileView, not MessagesView
                                    // No need to dismiss as we're already on the correct view
                                }
                            )
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToProfileOptions
                ) {
                    EmptyView()
                }
                .hidden()
                
                // NavigationLink for subscription view - opens as full screen intent
                NavigationLink(
                    destination: SubscriptionView(),
                    isActive: $showSubscriptionView
                ) {
                    EmptyView()
                }
                .hidden()
            }
        )
        .sheet(isPresented: $showUserReport) {
            Text("User Report View")
                .font(.title)
        }
        .sheet(isPresented: $showMakeCall) {
            Text("Make Call - \(userProfile?.name ?? "")")
                .font(.title)
        }
        .sheet(isPresented: $showVideoCall) {
            Text("Video Call - \(userProfile?.name ?? "")")
                .font(.title)
        }


        // Permission dialogs matching Android
        .alert("Permission Required", isPresented: $showPermissionDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Give Permission") {
                requestPermission()
            }
        } message: {
            Text(getPermissionDialogText())
        }
    }
    
    // MARK: - View Lifecycle Management
    
    private func cleanupPopupStates() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "cleanupPopupStates() Resetting popup states when view disappears")
        
        // Reset conversation limit popup state
        if showConversationLimitPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "cleanupPopupStates() Resetting conversation limit popup state")
            showConversationLimitPopup = false
            conversationLimitResult = nil
        }
        
        // Reset other popup states to prevent stale values
        if showVoiceCallPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "cleanupPopupStates() Resetting voice call popup state")
            showVoiceCallPopup = false
        }
        
        if showVideoCallPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "cleanupPopupStates() Resetting video call popup state")
            showVideoCallPopup = false
        }
        
        if showNotificationPermissionPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "cleanupPopupStates() Resetting notification permission popup state")
            showNotificationPermissionPopup = false
        }
        
        // Reset any other modal states
        if showPhotoViewer {
            showPhotoViewer = false
        }
        
        if showUserReport {
            showUserReport = false
        }
        
        if showPermissionDialog {
            showPermissionDialog = false
        }
    }
    
    // MARK: - Immediate Profile Loading (Following OnlineUsersViewModel Pattern Exactly)
    private func loadProfileDataImmediately() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() STARTING - Loading profile for user: \(otherUserId)")
        
        // CRITICAL FIX: Follow OnlineUsersViewModel pattern exactly - never show loading for local database queries
        // Always set isLoading = false first (like OnlineUsersViewModel line 315)
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() 🔧 Setting isLoading = false (OnlineUsersViewModel pattern)")
        self.isLoading = false
        
        // Get ProfileDB instance (assume it's always available like OnlineUsersViewModel)
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() 📊 Checking ProfileDB availability - DatabaseManager.isDatabaseReady(): \(DatabaseManager.shared.isDatabaseReady())")
        
        guard let profileDB = profileDB else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ProfileDB not available - will fetch from Firebase with loading")
            
            // Only show loading when ProfileDB is truly not available (first time setup)
            self.isLoading = true
            
            Task {
                await fetchProfileFromFirebaseAndSave(shouldUpdateLoadingState: true)
            }
            return
        }
        
        // CRITICAL FIX: Local database queries should be INSTANT with no loading state (OnlineUsersViewModel pattern)
        if let localProfile = profileDB.query(UserId: otherUserId) {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ✅ Found cached profile for user: \(otherUserId)")
            
            // Convert to UserProfile and show immediately
            let userProfile = convertProfileModelToUserProfile(localProfile)
            
            // Update UI IMMEDIATELY on main thread (no DispatchQueue.main.async) - like OnlineUsersViewModel lines 102-106
            self.userProfile = userProfile
            self.userDetails = createUserDetailsArray(from: userProfile)
            self.isLoading = false // Always ensure loading is off after local database load (OnlineUsersViewModel line 124)
            self.errorMessage = nil
            
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ✅ Updated UI with cached profile immediately")
            
            // Check if cached data is stale and needs background refresh
            let currentTime = Int(Date().timeIntervalSince1970)
            let profileAge = currentTime - localProfile.Time
            let cacheValiditySeconds = 3600 // 1 hour
            
            if profileAge >= cacheValiditySeconds {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ⚠️ Cached profile is stale (age: \(profileAge)s >= \(cacheValiditySeconds)s), scheduling background refresh")
                
                // Refresh from Firebase in background without showing loading
                Task {
                    await fetchProfileFromFirebaseAndSave(shouldUpdateLoadingState: false)
                }
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ✅ Cached profile is fresh (age: \(profileAge)s < \(cacheValiditySeconds)s), no refresh needed")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadProfileDataImmediately() ❌ No cached profile found - will show loading and fetch from Firebase")
            
            // Only show loading when we need to fetch from Firebase
            self.isLoading = true
            
            // Fetch from Firebase since no cached data exists
            Task {
                await fetchProfileFromFirebaseAndSave(shouldUpdateLoadingState: true)
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color("ErrorRed"))
                    
                    Text("Unable to load profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("dark"))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                // MODERN UX: Always show skeleton UI structure immediately, then populate with data
                if let profile = userProfile {
                    // CRITICAL DEBUG: Log when profile UI is displayed
                    let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "👤 SHOWING PROFILE UI - user: \(profile.username), isLoading: \(isLoading)")
                    
                    profileScrollView(for: profile)
                } else {
                    // SKELETON UI: Show structure immediately while loading data
                    let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "🎨 SHOWING SKELETON UI - isLoading: \(isLoading), userProfile: nil")
                    
                    skeletonProfileView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func skeletonProfileView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                skeletonProfileImageSection()
                
                // Enhanced spacing before MREC ad
                Spacer()
                    .frame(height: 40)
                
                // Bottom padding for better scroll experience
                Spacer()
                    .frame(height: 80)
            }
            .padding(.top, 24) // Better top spacing
        }
    }
    
    @ViewBuilder
    private func skeletonProfileImageSection() -> some View {
        VStack(spacing: 0) {
            // Profile Image - exact same size and styling as real profile image
            VStack(spacing: 12) {
                unifiedProfileImage(profile: nil, isInteractive: false)
                
                // Show username immediately if available from online users list (ONLY username, no other details)
                VStack(spacing: 8) {
                    if let userName = initialUserName {
                        HStack(spacing: 6) {
                            Text(Profanity.share.removeProfanityNumbersAllowed(userName))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color("dark"))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            // DEBUG ONLY: AI indicator dot (skeleton state)
                            #if DEBUG
                            if shouldShowAIIndicator {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            #endif
                        }
                    } else {
                        Spacer()
                            .frame(height: 26) // Reserve space for username
                    }
                    
                    // Don't reserve space for online status to match offline users (most common case)
                    // Online status will be added when profile data loads
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // Spacing before action buttons - matches the actual profile view spacing
            // Use consistent 32px spacing just like the real profile view when no subscription
            Spacer()
                .frame(height: 32)
            
            // Action Buttons - ALWAYS SHOW THESE (they're functional even during loading)
            VStack(spacing: 0) {
                enhancedActionButtonsSection
            }
            
            // Add spacing after buttons but don't reserve fixed height
            // Profile details will appear here when data loads
            Spacer()
                .frame(height: 24)
        }
    }
    
        @ViewBuilder
    private func unifiedProfileImage(profile: UserProfile? = nil, isInteractive: Bool = true) -> some View {
        let imageUrl = profile?.profileImage ?? initialProfileImage
        let gender = profile?.gender ?? initialGender
        let isOnline = profile?.isOnline ?? false
        
        ZStack {
            // Shadow layer - consistent for both states
            profileImageShadow
            
            // Profile image content
            if let imageUrl = imageUrl, !imageUrl.isEmpty && imageUrl != "null",
               let url = URL(string: imageUrl) {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    unifiedProfilePlaceholder(gender: gender)
                }
                .indicator(.activity)
                .transition(.opacity)
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(profileImageBorder)
                .overlay(profileImageInnerHighlight)
            } else {
                unifiedProfilePlaceholder(gender: gender)
                    .overlay(profileImageBorder)
                    .overlay(profileImageInnerHighlight)
            }
            
            // Online indicator (only for loaded profile)
            if let profile = profile, isOnline {
                onlineIndicator(for: profile)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            if isInteractive, let profile = profile, !profile.profileImage.isEmpty && profile.profileImage != "null" {
                showPhotoViewer = true
            }
        }
    }
    
    @ViewBuilder
    private func unifiedProfilePlaceholder(gender: String?) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color("shade3"),
                            Color("shade4")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .clipShape(Circle())
            
            // Gender-specific icon or default
            if let gender = gender {
                Image(gender.lowercased() == "male" ? "male" : "female")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.8)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color("shade5"))
                    .opacity(0.3)
            }
        }
    }
    
    @ViewBuilder
    private func profileScrollView(for profile: UserProfile) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                profileImageSection(for: profile)
                
                // Enhanced spacing before MREC ad
                Spacer()
                    .frame(height: 40)
                
                // Bottom padding for better scroll experience
                Spacer()
                    .frame(height: 80)
            }
            .padding(.top, 24) // Better top spacing
        }
    }
    
    @ViewBuilder
    private func profileImageSection(for profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            // Profile Image with enhanced shadow and styling (standardized spacing)
            VStack(spacing: 12) {
                unifiedProfileImage(profile: profile, isInteractive: true)
                
                // User Name with standardized typography (matching EditProfileView)
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(Profanity.share.removeProfanityNumbersAllowed(profile.name))
                            .font(.system(size: 26, weight: .bold)) // Standardized font size matching EditProfileView
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        // DEBUG ONLY: AI indicator dot
                        #if DEBUG
                        if shouldShowAIIndicator {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                        #endif
                    }
                    
                    // Online status with enhanced styling
                    if profile.isOnline {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color("Online"))
                                .frame(width: 8, height: 8)
                            
                            Text("Online")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("Online"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("Online").opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12) // Standardized top padding - reduced further
            
            // Consistent spacing before action buttons - always 32px
            Spacer()
                .frame(height: 32)
            
            // Action Buttons with reduced spacing
            if !isBlocked && !otherUserBlocked {
                VStack(spacing: 0) {
                    enhancedActionButtonsSection
                }
            }
            
            // User Details with reduced spacing
            if !isBlocked && !otherUserBlocked {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 24)
                    
                    enhancedUserDetailsSection(for: profile)
                }
            }
        }
    }
    
    @ViewBuilder
    private func userDetailsFlowLayout(for profile: UserProfile) -> some View {
        // Debug: Log the userDetails array being displayed
        let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "userDetailsFlowLayout() ===== UI DISPLAY LOGGING =====")
        let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "userDetailsFlowLayout() userDetails count: \(userDetails.count)")
        let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "userDetailsFlowLayout() userDetails array: \(userDetails)")
        
        // Log each detail that will be displayed
        let _ = {
            for (index, detail) in userDetails.enumerated() {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "userDetailsFlowLayout() 🎨 Will Display[\(index)]: '\(detail)'")
            }
        }()
        
        let pillSpacing: CGFloat = 12
        
        // Check if user has subscription to show as a badge
        let subscriptionExpiry = profile.subscriptionExpiry ?? 0
        let subscriptionTier = profile.subscriptionTier ?? ""
        let currentTime = Int64(Date().timeIntervalSince1970)
        let hasSubscription = !subscriptionTier.isEmpty &&
                              subscriptionTier != "none" &&
                              subscriptionExpiry > currentTime
        
        if userDetails.isEmpty && !hasSubscription {
            let _ = AppLogger.log(tag: "LOG-APP: ProfileView", message: "userDetailsFlowLayout() ⚠️ No details to display - showing empty state")
            // Show a message when no details are available
            Text("No additional profile details available")
                .font(.system(size: 14))
                .foregroundColor(Color("shade6"))
                .padding()
                .padding(.horizontal)
        } else {
            if #available(iOS 16.0, *) {
                FlowLayout(spacing: pillSpacing) {
                    // Show subscription badge first if available
                    if hasSubscription {
                        subscriptionBadge(for: profile)
                    }
                    // Then show other user details
                    ForEach(userDetails, id: \.self) { chip in
                        UserDetailChip(detail: chip)
                    }
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: pillSpacing) {
                    // Show subscription badge first if available
                    if hasSubscription {
                        subscriptionBadge(for: profile)
                    }
                    // Then show other details in rows
                    HStack(spacing: pillSpacing) {
                        ForEach(userDetails, id: \.self) { chip in
                            UserDetailChip(detail: chip)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func platformBadge(for profile: UserProfile) -> some View {
        HStack(spacing: 6) {
            if profile.platform == "ios" {
                Image("ic_apple")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                Text("iPhone")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Image("ic_android")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                Text("Android")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(profile.platform == "ios" ? Color("shade5") : Color("AndroidGreen"))
        .cornerRadius(20)
    }
    
    @ViewBuilder
    private func subscriptionBadge(for profile: UserProfile) -> some View {
        // Check subscription status from profile data
        let subscriptionExpiry = profile.subscriptionExpiry ?? 0
        let subscriptionTier = profile.subscriptionTier ?? ""
        let currentTime = Int64(Date().timeIntervalSince1970)
        
        let isSubscribed = !subscriptionTier.isEmpty &&
                          subscriptionTier != "none" &&
                          subscriptionExpiry > currentTime
        
        if isSubscribed {
            HStack(spacing: 6) {
                Image("ic_subscription")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.white)
                
                Text(getSubscriptionDisplayText(tier: subscriptionTier))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(getSubscriptionGradient(tier: subscriptionTier))
            .cornerRadius(20)
        }
    }
    
    private func getSubscriptionDisplayText(tier: String) -> String {
        switch tier.lowercased() {
        case "lite": return "Lite Subscriber"
        case "plus": return "Plus Subscriber"
        case "pro": return "Pro Subscriber"
        default: return "Premium"
        }
    }
    
    private func getSubscriptionGradient(tier: String) -> some View {
        switch tier.lowercased() {
        case "lite":
            return LinearGradient(
                colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case "plus":
            return LinearGradient(
                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case "pro":
            return LinearGradient(
                colors: [Color("Red1"), Color("redA7")],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [Color("Red1"), Color("redA7")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var profileImageShadow: some View {
        Circle()
            .fill(Color.black.opacity(0.08))
            .frame(width: 160, height: 160)
            .offset(y: 2)
            .blur(radius: 4)
    }
    
    private var profileImageBorder: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.8),
                        Color("shade3").opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
    }
    
    private var profileImageInnerHighlight: some View {
        Circle()
            .strokeBorder(
                Color.white.opacity(0.3),
                lineWidth: 1
            )
            .padding(1)
    }
    
    private func onlineIndicator(for profile: UserProfile) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .offset(y: 1)
                        .blur(radius: 2)
                    
                    Circle()
                        .fill(Color("Online"))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }
                .offset(x: -10, y: -10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: profile.isOnline)
    }
    
    @ViewBuilder
    private var enhancedActionButtonsSection: some View {
        VStack(spacing: 16) {
            // Enhanced action buttons with better design
            HStack(spacing: 15) {
                // Chat Button - Primary action
                EnhancedActionButton(
                    icon: "message.fill",
                    title: "Chat",
                    backgroundColor: Color("ColorAccent"),
                    iconColor: .white,
                    textColor: .white, // This parameter is ignored, adaptiveTextColor is used
                    isPrimary: true
                ) {
                    handleChatButtonTap()
                }
                
                // Call Button - Secondary action
                EnhancedActionButton(
                    icon: "phone.fill",
                    title: "Call",
                    backgroundColor: Color("shade2"),
                    iconColor: .green,
                    textColor: Color("dark"), // Theme-aware text color
                    isPrimary: false
                ) {
                    handleCallButtonTap()
                }
                
                // Video Button - Secondary action
                EnhancedActionButton(
                    icon: "video.fill",
                    title: "Video",
                    backgroundColor: Color("shade2"),
                    iconColor: .green,
                    textColor: Color("dark"), // Theme-aware text color
                    isPrimary: false
                ) {
                    handleVideoCallButtonTap()
                }
                
                // Info Button - Tertiary action
                EnhancedActionButton(
                    icon: "info.circle.fill",
                    title: "More",
                    backgroundColor: Color("shade2"),
                    iconColor: Color("shade6"),
                    textColor: Color("dark"), // Theme-aware text color
                    isPrimary: false
                ) {
                    handleInfoButtonTap()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private func enhancedUserDetailsSection(for profile: UserProfile) -> some View {
        VStack(spacing: 24) {
            // Enhanced user details with better organization
            if userDetails.isEmpty {
                // Empty state with better design
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color("shade4"))
                    
                    VStack(spacing: 8) {
                        Text("No details available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("dark"))
                        
                        Text("This user hasn't shared additional profile information yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade6"))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
            } else {
                // Organized details with better spacing
                LazyVStack(spacing: 16) {
                    if #available(iOS 16.0, *) {
                        FlowLayout(spacing: 12) {
                            ForEach(userDetails, id: \.self) { detail in
                                EnhancedUserDetailChip(detail: detail)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Fallback for older iOS versions
                        VStack(spacing: 12) {
                            ForEach(Array(stride(from: 0, to: userDetails.count, by: 2)), id: \.self) { index in
                                HStack(spacing: 12) {
                                    EnhancedUserDetailChip(detail: userDetails[index])
                                    
                                    if index + 1 < userDetails.count {
                                        EnhancedUserDetailChip(detail: userDetails[index + 1])
                                    } else {
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management
    private func loadSessionData() async {
        let sessionManager = SessionManager.shared
        currentUserId = sessionManager.userId ?? ""
        currentUserName = sessionManager.userName ?? ""
        currentDeviceId = sessionManager.deviceId ?? ""
        currentGender = sessionManager.userGender ?? ""
        currentProfilePhoto = sessionManager.userProfilePhoto ?? ""
        currentCountry = sessionManager.userCountry ?? ""
        isProSubscriber = sessionManager.premiumActive
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "loadSessionData() loaded session for user: \(currentUserId)")
    }

    // MARK: - Local Database Profile Loading (Android Parity)

    
    private func fetchProfileFromFirebaseAndSave(shouldUpdateLoadingState: Bool = true) async {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() fetching profile from Firebase for: \(otherUserId), shouldUpdateLoadingState: \(shouldUpdateLoadingState)")
        
        do {
            let db = Firestore.firestore()
            
            // Step 1: Fetch basic profile data from Users collection (like Android)
            let userDocument = try await db.collection("Users").document(otherUserId).getDocument()
            
            guard userDocument.exists, let userData = userDocument.data() else {
                            await MainActor.run {
                self.errorMessage = "User not found"
                if shouldUpdateLoadingState {
                    self.isLoading = false
                }
            }
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() successfully fetched Users collection data")
            
            // Step 2: Get device ID for UserDevData collection (like Android)
            let userDeviceId = userData["User_device_id"] as? String ?? ""
            var combinedData = userData
            
            // Step 3: Fetch statistics data from UserDevData collection (matching Android exactly)
            if !userDeviceId.isEmpty && userDeviceId != "null" {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() fetching UserDevData for device: \(userDeviceId)")
                
                do {
                    let devDocument = try await db.collection("UserDevData").document(userDeviceId).getDocument()
                    
                    if devDocument.exists, let devData = devDocument.data() {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() successfully fetched UserDevData collection")
                        
                        // Merge UserDevData into combined data (Android gets these fields from UserDevData)
                        combinedData["voice_calls"] = devData["voice_calls"]
                        combinedData["video_calls"] = devData["video_calls"]
                        combinedData["live"] = devData["live"]
                        combinedData["good_experience"] = devData["good_experience"]
                        combinedData["bad_experience"] = devData["bad_experience"]
                        combinedData["male_accounts"] = devData["male_accounts"]
                        combinedData["female_accounts"] = devData["female_accounts"]
                        combinedData["reports"] = devData["reports"]
                        combinedData["blocks"] = devData["blocks"]
                        combinedData["female_chats"] = devData["female_chats"]
                        combinedData["male_chats"] = devData["male_chats"]
                        
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() merged UserDevData statistics into profile")
                    } else {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() UserDevData document not found for device: \(userDeviceId)")
                    }
                } catch {
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() UserDevData fetch error: \(error.localizedDescription)")
                }
            }
            
            // Step 4: Create UserProfile from combined data (Users + UserDevData)
            let profile = createUserProfileFromFirebaseData(combinedData)
            
            // Step 5: Save to local database
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() saving profile to local database")
            await saveProfileToLocalDatabase(profile, data: combinedData)
            
            // Step 6: Update UI and populate user details
            await MainActor.run {
                self.userProfile = profile
                let newDetails = self.createUserDetailsArray(from: profile)
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() updating userDetails from \(self.userDetails.count) to \(newDetails.count) items")
                self.userDetails = newDetails
                
                // Only update loading state if this is not a background refresh
                if shouldUpdateLoadingState {
                    self.isLoading = false
                }
                
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() UI updated successfully, isLoading: \(self.isLoading)")
            }
            
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchProfileFromFirebaseAndSave() error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                if shouldUpdateLoadingState {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func saveProfileToLocalDatabase(_ profile: UserProfile, data: [String: Any]) async {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() saving profile to local database for user: \(profile.id)")
        
        // Wait for database to be ready
        var attempts = 0
        let maxAttempts = 10
        while profileDB == nil && attempts < maxAttempts {
            if !DatabaseManager.shared.isDatabaseReady() {
                DatabaseManager.shared.initializeDatabase()
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() waiting for ProfileDB... attempt \(attempts)")
        }
        
        guard let profileDB = profileDB else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() ❌ ProfileDB not initialized after waiting, cannot save")
            return
        }
        
        // Extract all fields from Firebase data with defaults using exact Android field names
        let userId = NSString(string: profile.id)
        let age = NSString(string: profile.age)
        let country = NSString(string: profile.country)
        let language = NSString(string: profile.language)
        let gender = NSString(string: profile.gender)
        let city = NSString(string: profile.city ?? "")
        let height = NSString(string: data["height"] as? String ?? "")
        let occupation = NSString(string: data["occupation"] as? String ?? "")
        let hobbies = NSString(string: data["hobbies"] as? String ?? "")
        let zodiac = NSString(string: data["zodiac"] as? String ?? "")
        let snap = NSString(string: data["snap"] as? String ?? "")
        let instagram = NSString(string: data["insta"] as? String ?? "")
        let emailVerified = NSString(string: profile.emailVerified ?? "")
        let createdTime = NSString(string: profile.userRegisteredTime ?? "")
        let platform = NSString(string: data["platform"] as? String ?? "")
        let subscriptionTier = NSString(string: data["subscriptionTier"] as? String ?? "none")
        
        // Preference fields - using exact Android field names
        let likeMen = NSString(string: data["like_men"] as? String ?? "")
        let likeWomen = NSString(string: data["like_woman"] as? String ?? "")
        let single = NSString(string: data["single"] as? String ?? "")
        let married = NSString(string: data["married"] as? String ?? "")
        let children = NSString(string: data["children"] as? String ?? "")
        let gym = NSString(string: data["gym"] as? String ?? "")
        let smokes = NSString(string: data["smokes"] as? String ?? "")
        let drinks = NSString(string: data["drinks"] as? String ?? "")
        let games = NSString(string: data["games"] as? String ?? "")
        let decentChat = NSString(string: data["decent_chat"] as? String ?? "")
        let pets = NSString(string: data["pets"] as? String ?? "")
        let travel = NSString(string: data["travel"] as? String ?? "")
        let music = NSString(string: data["music"] as? String ?? "")
        let movies = NSString(string: data["movies"] as? String ?? "")
        let naughty = NSString(string: data["naughty"] as? String ?? "")

        let foodie = NSString(string: data["foodie"] as? String ?? "")
        let dates = NSString(string: data["dates"] as? String ?? "")
        let fashion = NSString(string: data["fashion"] as? String ?? "")
        let broken = NSString(string: data["broken"] as? String ?? "")
        let depressed = NSString(string: data["depressed"] as? String ?? "")
        let lonely = NSString(string: data["lonely"] as? String ?? "")
        let cheated = NSString(string: data["cheated"] as? String ?? "")
        let insomnia = NSString(string: data["insomnia"] as? String ?? "")
        let voiceAllowed = NSString(string: data["voice_allowed"] as? String ?? "")
        let videoAllowed = NSString(string: data["video_allowed"] as? String ?? "")
        let picsAllowed = NSString(string: data["pics_allowed"] as? String ?? "")
        
        // Statistics - using data from UserProfile object (already processed from Firebase)
        let voiceCalls = NSString(string: profile.voiceCalls ?? "")
        let videoCalls = NSString(string: profile.videoCalls ?? "")
        let goodExperience = NSString(string: profile.goodExperience ?? "")
        let badExperience = NSString(string: profile.badExperience ?? "")
        let maleAccounts = NSString(string: profile.maleAccounts ?? "")
        let femaleAccounts = NSString(string: profile.femaleAccounts ?? "")
        let maleChats = NSString(string: profile.maleChats ?? "")
        let femaleChats = NSString(string: profile.femaleChats ?? "")
        let reports = NSString(string: profile.reports ?? "")
        let blocks = NSString(string: profile.blocks ?? "")
        
        let image = NSString(string: profile.profileImage)
        let name = NSString(string: profile.name)
        let currentTime = Date()
        
        // Use continuation to wait for database operations to complete
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() 💾 Upserting profile for user: \(profile.id) (INSERT OR REPLACE)")
                
                // Insert or replace profile data (synchronous) - no need to delete first
                profileDB.insert(
                    UserId: userId,
                    Age: age,
                    Country: country,
                    Language: language,
                    Gender: gender,
                    men: likeMen,
                    women: likeWomen,
                    single: single,
                    married: married,
                    children: children,
                    gym: gym,
                    smoke: smokes,
                    drink: drinks,
                    games: games,
                    decenttalk: decentChat,
                    pets: pets,
                    travel: travel,
                    music: music,
                    movies: movies,
                    naughty: naughty,

                    Foodie: foodie,
                    dates: dates,
                    fashion: fashion,
                    broken: broken,
                    depressed: depressed,
                    lonely: lonely,
                    cheated: cheated,
                    insomnia: insomnia,
                    voice: voiceAllowed,
                    video: videoAllowed,
                    pics: picsAllowed,
                    goodexperience: goodExperience,
                    badexperience: badExperience,
                    male_accounts: maleAccounts,
                    female_accounts: femaleAccounts,
                    male_chats: maleChats,
                    female_chats: femaleChats,
                    reports: reports,
                    blocks: blocks,
                    voicecalls: voiceCalls,
                    videocalls: videoCalls,
                    Time: currentTime,
                    Image: image,
                    Named: name,
                    Height: height,
                    Occupation: occupation,
                    Instagram: instagram,
                    Snapchat: snap,
                    Zodic: zodiac,
                    Hobbies: hobbies,
                    EmailVerified: emailVerified,
                    CreatedTime: createdTime,
                    Platform: platform,
                    Premium: subscriptionTier,
                    city: city
                )
                
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() ✅ Profile upsert completed for user: \(profile.id)")
                
                // Verify the profile was saved correctly
                if let savedProfile = profileDB.query(UserId: profile.id) {
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() ✅ Verification successful - profile saved and retrieved: \(savedProfile.Name)")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "saveProfileToLocalDatabase() ❌ Verification failed - profile not found after saving")
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - User Details Array Creation (Android Parity)
    private func createUserDetailsArray(from profile: UserProfile) -> [String] {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ===== STARTING USER DETAILS CREATION =====")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() Processing profile for user: \(profile.id)")
        
        var details: [String] = []

        // 1. Email Verified (Android: always at the top if verified)
        if let emailVerified = profile.emailVerified, emailVerified.lowercased() == "true" {
            details.append("Email Verified")
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Added: Email Verified")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ❌ Skipped: Email Verified (value: '\(profile.emailVerified ?? "nil")')")
        }

        // 2. Account creation date (separated into two pills)
        if let createdTime = profile.userRegisteredTime, !createdTime.isEmpty && createdTime != "null" {
            var createdDate: Date?
            if let timeInterval = Double(createdTime) {
                if timeInterval > 1000000000000 {
                    createdDate = Date(timeIntervalSince1970: timeInterval / 1000)
                } else if timeInterval > 1000000000 {
                    createdDate = Date(timeIntervalSince1970: timeInterval)
                } else {
                    createdDate = Date(timeIntervalSince1970: timeInterval * 86400)
                }
            }
            if createdDate == nil {
                let formatter = ISO8601DateFormatter()
                createdDate = formatter.date(from: createdTime)
            }
            if createdDate == nil {
                let dateFormats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd"]
                for format in dateFormats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    if let date = formatter.date(from: createdTime) {
                        createdDate = date
                        break
                    }
                }
            }
            if let date = createdDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM yyyy"
                let dateString = formatter.string(from: date)
                let daysSinceCreation = Int(Date().timeIntervalSince(date) / 86400)
                
                // Add two separate pills
                details.append("Created: \(dateString)")
                details.append("\(daysSinceCreation) days old")
            }
        }
        // 3. Platform (as string, not badge)
        if !profile.platform.isEmpty && profile.platform.lowercased() != "null" {
            let platformString = profile.platform.lowercased() == "ios" ? "iPhone" : "Android"
            details.append(platformString)
        }
        // 4. Age (capitalize 'Years old')
        if !profile.age.isEmpty && profile.age != "null" {
            let ageDetail = "\(profile.age) Years old"
            details.append(ageDetail)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Added: \(ageDetail)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ❌ Skipped: Age (value: '\(profile.age)')")
        }
        // 5. Gender
        if !profile.gender.isEmpty && profile.gender != "null" {
            details.append(profile.gender)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Added: \(profile.gender)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ❌ Skipped: Gender (value: '\(profile.gender)')")
        }
        // 6. Language
        if !profile.language.isEmpty && profile.language != "null" {
            details.append(profile.language)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Added: \(profile.language)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ❌ Skipped: Language (value: '\(profile.language)')")
        }
        // 7. City (Android: 'Around <city>')
        if let city = profile.city, !city.isEmpty && city != "null" {
            details.append("Around \(city)")
        }
        // 8. Country
        if !profile.country.isEmpty && profile.country != "null" {
            details.append(profile.country)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Added: \(profile.country)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ❌ Skipped: Country (value: '\(profile.country)')")
        }
        // 9. Height
        if let height = profile.height, !height.isEmpty && height != "null" {
            let filteredHeight = Profanity.share.removeProfanityNumbersAllowed(height)
            details.append(filteredHeight)
        }
        // 10. Occupation
        if let occupation = profile.occupation, !occupation.isEmpty && occupation != "null" {
            let filteredOccupation = Profanity.share.removeProfanity(occupation)
            details.append(filteredOccupation)
        }
        // 11. Hobbies
        if let hobbies = profile.hobbies, !hobbies.isEmpty && hobbies != "null" {
            let filteredHobbies = Profanity.share.removeProfanity(hobbies)
            details.append(filteredHobbies)
        }
        // 12. Zodiac
        if let zodiac = profile.zodiac, !zodiac.isEmpty && zodiac != "null" {
            let filteredZodiac = Profanity.share.removeProfanity(zodiac)
            details.append(filteredZodiac)
        }
        // Insert line break before Relationship Preferences
        // details.append("__NEWLINE__") // REMOVE
        // 13. Relationship preferences (Android exact text)
        if let likeMen = profile.likeMen, !likeMen.isEmpty && likeMen != "null" && likeMen.lowercased() == "yes" {
            details.append("I like men")
        }
        if let likeWoman = profile.likeWoman, !likeWoman.isEmpty && likeWoman != "null" && likeWoman.lowercased() == "yes" {
            details.append("I like woman")
        }
        if let single = profile.single, !single.isEmpty && single != "null" && single.lowercased() == "yes" {
            details.append("Single")
        }
        if let married = profile.married, !married.isEmpty && married != "null" && married.lowercased() == "yes" {
            details.append("Married")
        }
        if let children = profile.children, !children.isEmpty && children != "null" && children.lowercased() == "yes" {
            details.append("Have Kids")
        }
        // Insert line break before Lifestyle Preferences
        // details.append("__NEWLINE__") // REMOVE
        // 14. Lifestyle preferences (Android exact text)
        if let gym = profile.gym, !gym.isEmpty && gym != "null" && gym.lowercased() == "yes" {
            details.append("Gym")
        }
        if let smokes = profile.smokes, !smokes.isEmpty && smokes != "null" && smokes.lowercased() == "yes" {
            details.append("Smokes")
        }
        if let drinks = profile.drinks, !drinks.isEmpty && drinks != "null" && drinks.lowercased() == "yes" {
            details.append("Drinks")
        }
        if let games = profile.games, !games.isEmpty && games != "null" && games.lowercased() == "yes" {
            details.append("I play games")
        }
        if let decentChat = profile.decentChat, !decentChat.isEmpty && decentChat != "null" && decentChat.lowercased() == "yes" {
            details.append("Strictly decent chats please")
        }
        // Insert line break before Interests
        // details.append("__NEWLINE__") // REMOVE
        // 15. Interests (Android exact text)
        if let pets = profile.pets, !pets.isEmpty && pets != "null" && pets.lowercased() == "yes" {
            details.append("I love pets")
        }
        if let travel = profile.travel, !travel.isEmpty && travel != "null" && travel.lowercased() == "yes" {
            details.append("I travel")
        }
        if let music = profile.music, !music.isEmpty && music != "null" && music.lowercased() == "yes" {
            details.append("I love music")
        }
        if let movies = profile.movies, !movies.isEmpty && movies != "null" && movies.lowercased() == "yes" {
            details.append("I love movies")
        }
        if let naughty = profile.naughty, !naughty.isEmpty && naughty != "null" && naughty.lowercased() == "yes" {
            details.append("I am naughty")
        }

        if let foodie = profile.foodie, !foodie.isEmpty && foodie != "null" && foodie.lowercased() == "yes" {
            details.append("Foodie")
        }
        if let dates = profile.dates, !dates.isEmpty && dates != "null" && dates.lowercased() == "yes" {
            details.append("I go on dates")
        }
        if let fashion = profile.fashion, !fashion.isEmpty && fashion != "null" && fashion.lowercased() == "yes" {
            details.append("I love fashion")
        }
        // Insert line break before Emotional States
        // details.append("__NEWLINE__") // REMOVE
        // 16. Emotional states (Android exact text)
        if let broken = profile.broken, !broken.isEmpty && broken != "null" && broken.lowercased() == "yes" {
            details.append("Broken")
        }
        if let depressed = profile.depressed, !depressed.isEmpty && depressed != "null" && depressed.lowercased() == "yes" {
            details.append("Depressed")
        }
        if let lonely = profile.lonely, !lonely.isEmpty && lonely != "null" && lonely.lowercased() == "yes" {
            details.append("Lonely")
        }
        if let cheated = profile.cheated, !cheated.isEmpty && cheated != "null" && cheated.lowercased() == "yes" {
            details.append("I got cheated")
        }
        if let insomnia = profile.insomnia, !insomnia.isEmpty && insomnia != "null" && insomnia.lowercased() == "yes" {
            details.append("I can't sleep")
        }
        // Insert line break before Permissions
        // details.append("__NEWLINE__") // REMOVE
        // 17. Permissions (Android exact text)
        if let voiceAllowed = profile.voiceAllowed, !voiceAllowed.isEmpty && voiceAllowed != "null" && voiceAllowed.lowercased() == "yes" {
            details.append("Voice calls allowed")
        }
        if let videoAllowed = profile.videoAllowed, !videoAllowed.isEmpty && videoAllowed != "null" && videoAllowed.lowercased() == "yes" {
            details.append("Video calls allowed")
        }
        if let picsAllowed = profile.picsAllowed, !picsAllowed.isEmpty && picsAllowed != "null" && picsAllowed.lowercased() == "yes" {
            details.append("Pictures allowed")
        }
        // Insert line break before Call statistics
        // details.append("__NEWLINE__") // REMOVE
        // 18. Call statistics
        if let voiceCalls = profile.voiceCalls, !voiceCalls.isEmpty && voiceCalls != "null" && voiceCalls != "0" {
            details.append("\(voiceCalls) voice calls")
        }
        if let videoCalls = profile.videoCalls, !videoCalls.isEmpty && videoCalls != "null" && videoCalls != "0" {
            details.append("\(videoCalls) video calls")
        }
        if let live = profile.live, !live.isEmpty && live != "null" && live != "0" {
            details.append("\(live) live")
        }
        // Insert line break before Experience statistics
        // details.append("__NEWLINE__") // REMOVE
        // 19. Experience statistics
        if let goodExperience = profile.goodExperience, !goodExperience.isEmpty && goodExperience != "null" && goodExperience != "0" {
            details.append("\(goodExperience) thumbs up")
        }
        if let badExperience = profile.badExperience, !badExperience.isEmpty && badExperience != "null" && badExperience != "0" {
            details.append("\(badExperience) thumbs down")
        }
        // Insert line break before Account statistics
        // details.append("__NEWLINE__") // REMOVE
        // 20. Account statistics
        if let maleAccounts = profile.maleAccounts, !maleAccounts.isEmpty && maleAccounts != "null" && maleAccounts != "0" {
            details.append("\(maleAccounts) male accounts")
        }
        if let femaleAccounts = profile.femaleAccounts, !femaleAccounts.isEmpty && femaleAccounts != "null" && femaleAccounts != "0" {
            details.append("\(femaleAccounts) female accounts")
        }
        // Insert line break before Chat statistics
        // details.append("__NEWLINE__") // REMOVE
        // 21. Chat statistics
        if let maleChats = profile.maleChats, !maleChats.isEmpty && maleChats != "null" && maleChats != "0" {
            details.append("\(maleChats) male chats")
        }
        if let femaleChats = profile.femaleChats, !femaleChats.isEmpty && femaleChats != "null" && femaleChats != "0" {
            details.append("\(femaleChats) female chats")
        }
        // Insert line break before Reports and blocks
        // details.append("__NEWLINE__") // REMOVE
        // 22. Reports and blocks
        if let reports = profile.reports, !reports.isEmpty && reports != "null" && reports != "0" {
            details.append("\(reports) reports")
        }
        if let blocks = profile.blocks, !blocks.isEmpty && blocks != "null" && blocks != "0" {
            details.append("\(blocks) blocks")
        }
        // Insert line break before Snap and Insta
        // details.append("__NEWLINE__") // REMOVE
        // 23. Snap
        if let snap = profile.snap, !snap.isEmpty && snap != "null" {
            let filteredSnap = Profanity.share.removeProfanityNumbersAllowed(snap)
            details.append("Snap: \(filteredSnap)")
        }
        // 24. Insta
        if let insta = profile.insta, !insta.isEmpty && insta != "null" {
            let filteredInsta = Profanity.share.removeProfanityNumbersAllowed(insta)
            details.append("Insta: \(filteredInsta)")
        }
        // Fallback if no details
        if details.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ⚠️ No details found, using fallback")
            if !profile.age.isEmpty && profile.age != "null" && profile.age != "0" {
                let fallbackAge = "\(profile.age) Years old"
                details.append(fallbackAge)
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Fallback Added: \(fallbackAge)")
            }
            if !profile.country.isEmpty && profile.country != "null" {
                details.append(profile.country)
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Fallback Added: \(profile.country)")
            }
            if !profile.language.isEmpty && profile.language != "null" {
                details.append(profile.language)
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Fallback Added: \(profile.language)")
            }
            if details.isEmpty {
                details.append("Profile information loading...")
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ✅ Fallback Added: Profile information loading...")
            }
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ===== FINAL USER DETAILS ARRAY =====")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() Total details count: \(details.count)")
        for (index, detail) in details.enumerated() {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() Detail[\(index)]: '\(detail)'")
        }
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserDetailsArray() ===== END USER DETAILS CREATION =====")
        
        return details.filter { $0 != "__NEWLINE__" }
    }
    
    private func convertProfileModelToUserProfile(_ profileModel: ProfileModel) -> UserProfile {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "convertProfileModelToUserProfile() Converting cached profile - EmailVerified: '\(profileModel.EmailVerified)', CreatedTime: '\(profileModel.CreatedTime)'")
        
        let subscriptionTier = profileModel.Premium.isEmpty ? "none" : profileModel.Premium
        let subscriptionExpiry = Int64(profileModel.Time) + 86400 // Default 1 day from last update
        
        return UserProfile(
            id: profileModel.UserId,
            username: profileModel.Name,
            gender: profileModel.Gender,
            age: profileModel.Age,
            country: profileModel.Country,
            language: profileModel.Language,
            platform: profileModel.Platform,
            profilePhoto: profileModel.Image,
            subscriptionTier: subscriptionTier,
            subscriptionExpiry: subscriptionExpiry,
            city: profileModel.city,
            height: profileModel.Height,
            occupation: profileModel.Occupation,
            hobbies: profileModel.Hobbies,
            zodiac: profileModel.Zodic,
            snap: profileModel.Snapchat,
            insta: profileModel.Instagram,
            emailVerified: profileModel.EmailVerified,
            userRegisteredTime: profileModel.CreatedTime,
            likeMen: profileModel.men,
            likeWoman: profileModel.women,
            single: profileModel.single,
            married: profileModel.married,
            children: profileModel.children,
            gym: profileModel.gym,
            smokes: profileModel.smoke,
            drinks: profileModel.drink,
            games: profileModel.games,
            decentChat: profileModel.decenttalk,
            pets: profileModel.pets,
            travel: profileModel.travel,
            music: profileModel.music,
            movies: profileModel.movies,
            naughty: profileModel.naughty,

            foodie: profileModel.Foodie,
            dates: profileModel.dates,
            fashion: profileModel.fashion,
            broken: profileModel.broken,
            depressed: profileModel.depressed,
            lonely: profileModel.lonely,
            cheated: profileModel.cheated,
            insomnia: profileModel.insomnia,
            voiceAllowed: profileModel.voice,
            videoAllowed: profileModel.video,
            picsAllowed: profileModel.pics,
            voiceCalls: profileModel.voicecalls,
            videoCalls: profileModel.videocalls,
            live: "",
            goodExperience: profileModel.goodexperience,
            badExperience: profileModel.badexperience,
            maleAccounts: profileModel.male_accounts,
            femaleAccounts: profileModel.female_accounts,
            reports: profileModel.reports,
            blocks: profileModel.blocks,
            femaleChats: profileModel.female_chats,
            maleChats: profileModel.male_chats
        )
    }
    
    private func createUserProfileFromFirebaseData(_ data: [String: Any]) -> UserProfile {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() ===== COMPLETE FIREBASE DATA RECEIVED =====")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() Firebase data keys count: \(data.keys.count)")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() All Firebase keys: \(data.keys.sorted())")
        
        // Log ALL Firebase data fields
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() Firebase[\(key)]: '\(value)'")
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() ===== PROCESSING SPECIFIC FIELDS =====")
        
        // Handle User_registered_time (Android uses this field name and it's a Long in seconds)
        var userRegisteredTimeString = ""
        if let registeredTime = data["User_registered_time"] as? Int64 {
            userRegisteredTimeString = String(registeredTime)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_registered_time as Int64: \(registeredTime)")
        } else if let registeredTime = data["User_registered_time"] as? Double {
            userRegisteredTimeString = String(Int64(registeredTime))
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_registered_time as Double: \(registeredTime)")
        } else if let registeredTime = data["User_registered_time"] as? String {
            userRegisteredTimeString = registeredTime
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_registered_time as String: \(registeredTime)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_registered_time not found or null")
        }
        
        // Handle email verification (Android uses User_verified boolean field)
        var emailVerifiedString = ""
        if let verified = data["User_verified"] as? Bool {
            emailVerifiedString = String(verified)
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_verified as Bool: \(verified)")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_verified not found or null")
        }
        
        // Log key field mappings for debugging
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() KEY FIELD MAPPINGS:")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_name -> username: '\(data["User_name"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_gender -> gender: '\(data["User_gender"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_age -> age: '\(data["User_age"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_country -> country: '\(data["User_country"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() user_language -> language: '\(data["user_language"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() platform -> platform: '\(data["platform"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() User_image -> profilePhoto: '\(data["User_image"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() subscriptionTier -> subscriptionTier: '\(data["subscriptionTier"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() subscriptionExpiry -> subscriptionExpiry: '\(data["subscriptionExpiry"] as? Int64 ?? 0)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() city -> city: '\(data["city"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() height -> height: '\(data["height"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() occupation -> occupation: '\(data["occupation"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() hobbies -> hobbies: '\(data["hobbies"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() zodiac -> zodiac: '\(data["zodiac"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() snap -> snap: '\(data["snap"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() insta -> insta: '\(data["insta"] as? String ?? "nil")'")
        
        // Log preference fields that are missing from Firebase but expected by Android
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() PREFERENCE FIELDS (missing from Firebase):")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() like_men: '\(data["like_men"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() like_woman: '\(data["like_woman"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() single: '\(data["single"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() married: '\(data["married"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() children: '\(data["children"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() gym: '\(data["gym"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() smokes: '\(data["smokes"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() drinks: '\(data["drinks"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() games: '\(data["games"] as? String ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() decent_chat: '\(data["decent_chat"] as? String ?? "nil")'")
        
        // Log statistics fields from UserDevData collection (Android fetches these from UserDevData)
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() STATISTICS FIELDS (from UserDevData):")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() voice_calls: '\(data["voice_calls"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() video_calls: '\(data["video_calls"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() live: '\(data["live"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() good_experience: '\(data["good_experience"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() bad_experience: '\(data["bad_experience"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() male_accounts: '\(data["male_accounts"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() female_accounts: '\(data["female_accounts"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() reports: '\(data["reports"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() blocks: '\(data["blocks"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() female_chats: '\(data["female_chats"] ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() male_chats: '\(data["male_chats"] ?? "nil")'")
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() ===== ANALYSIS COMPLETE - CREATING USERPROFILE OBJECT =====")
        
        let userProfile = UserProfile(
            id: otherUserId,
            username: data["User_name"] as? String ?? "",
            gender: data["User_gender"] as? String ?? "",
            age: data["User_age"] as? String ?? "",
            country: data["User_country"] as? String ?? "",
            language: data["user_language"] as? String ?? "",
            platform: data["platform"] as? String ?? "",
            profilePhoto: data["User_image"] as? String ?? "",
            subscriptionTier: data["subscriptionTier"] as? String ?? "none",
            subscriptionExpiry: data["subscriptionExpiry"] as? Int64 ?? 0,
            city: data["userRetrievedCity"] as? String ?? "", // Android uses "userRetrievedCity" field name
            height: data["height"] as? String ?? "",
            occupation: data["occupation"] as? String ?? "",
            hobbies: data["hobbies"] as? String ?? "",
            zodiac: data["zodiac"] as? String ?? "",
            snap: data["snap"] as? String ?? "",
            insta: data["insta"] as? String ?? "",
            emailVerified: emailVerifiedString,
            userRegisteredTime: userRegisteredTimeString,
            likeMen: data["like_men"] as? String ?? "",
            likeWoman: data["like_woman"] as? String ?? "",
            single: data["single"] as? String ?? "",
            married: data["married"] as? String ?? "",
            children: data["children"] as? String ?? "",
            gym: data["gym"] as? String ?? "",
            smokes: data["smokes"] as? String ?? "",
            drinks: data["drinks"] as? String ?? "",
            games: data["games"] as? String ?? "",
            decentChat: data["decent_chat"] as? String ?? "",
            pets: data["pets"] as? String ?? "",
            travel: data["travel"] as? String ?? "",
            music: data["music"] as? String ?? "",
            movies: data["movies"] as? String ?? "",
            naughty: data["naughty"] as? String ?? "",

            foodie: data["foodie"] as? String ?? "",
            dates: data["dates"] as? String ?? "",
            fashion: data["fashion"] as? String ?? "",
            broken: data["broken"] as? String ?? "",
            depressed: data["depressed"] as? String ?? "",
            lonely: data["lonely"] as? String ?? "",
            cheated: data["cheated"] as? String ?? "",
            insomnia: data["insomnia"] as? String ?? "",
            voiceAllowed: data["voice_allowed"] as? String ?? "",
            videoAllowed: data["video_allowed"] as? String ?? "",
            picsAllowed: data["pics_allowed"] as? String ?? "",
            voiceCalls: convertToString(data["voice_calls"]),
            videoCalls: convertToString(data["video_calls"]),
            live: convertToString(data["live"]),
            goodExperience: convertToString(data["good_experience"]),
            badExperience: convertToString(data["bad_experience"]),
            maleAccounts: convertToString(data["male_accounts"]),
            femaleAccounts: convertToString(data["female_accounts"]),
            reports: convertToString(data["reports"]),
            blocks: convertToString(data["blocks"]),
            femaleChats: convertToString(data["female_chats"]),
            maleChats: convertToString(data["male_chats"])
        )
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() ===== CREATED USER PROFILE OBJECT =====")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.id: '\(userProfile.id)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.name: '\(userProfile.name)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.gender: '\(userProfile.gender)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.age: '\(userProfile.age)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.country: '\(userProfile.country)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.language: '\(userProfile.language)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.platform: '\(userProfile.platform)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.profileImage: '\(userProfile.profileImage)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.subscriptionTier: '\(userProfile.subscriptionTier ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.subscriptionExpiry: '\(userProfile.subscriptionExpiry ?? 0)'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.city: '\(userProfile.city ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.height: '\(userProfile.height ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.occupation: '\(userProfile.occupation ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.hobbies: '\(userProfile.hobbies ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.zodiac: '\(userProfile.zodiac ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.snap: '\(userProfile.snap ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.insta: '\(userProfile.insta ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.emailVerified: '\(userProfile.emailVerified ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.userRegisteredTime: '\(userProfile.userRegisteredTime ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.likeMen: '\(userProfile.likeMen ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.likeWoman: '\(userProfile.likeWoman ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.single: '\(userProfile.single ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.married: '\(userProfile.married ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.children: '\(userProfile.children ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.gym: '\(userProfile.gym ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.smokes: '\(userProfile.smokes ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.drinks: '\(userProfile.drinks ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.games: '\(userProfile.games ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.decentChat: '\(userProfile.decentChat ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.pets: '\(userProfile.pets ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.travel: '\(userProfile.travel ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.music: '\(userProfile.music ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.movies: '\(userProfile.movies ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.naughty: '\(userProfile.naughty ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.foodie: '\(userProfile.foodie ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.dates: '\(userProfile.dates ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.fashion: '\(userProfile.fashion ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.broken: '\(userProfile.broken ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.depressed: '\(userProfile.depressed ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.lonely: '\(userProfile.lonely ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.cheated: '\(userProfile.cheated ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.insomnia: '\(userProfile.insomnia ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.voiceAllowed: '\(userProfile.voiceAllowed ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.videoAllowed: '\(userProfile.videoAllowed ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.picsAllowed: '\(userProfile.picsAllowed ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.voiceCalls: '\(userProfile.voiceCalls ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.videoCalls: '\(userProfile.videoCalls ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.live: '\(userProfile.live ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.goodExperience: '\(userProfile.goodExperience ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.badExperience: '\(userProfile.badExperience ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.maleAccounts: '\(userProfile.maleAccounts ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.femaleAccounts: '\(userProfile.femaleAccounts ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.reports: '\(userProfile.reports ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.blocks: '\(userProfile.blocks ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.femaleChats: '\(userProfile.femaleChats ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createUserProfileFromFirebaseData() UserProfile.maleChats: '\(userProfile.maleChats ?? "nil")'")
        
        return userProfile
    }
    
    // Helper function to convert Firebase values to strings (matching Android behavior)
    private func convertToString(_ value: Any?) -> String {
        guard let value = value else { return "" }
        
        if let stringValue = value as? String {
            return stringValue == "null" ? "" : stringValue
        } else if let longValue = value as? Int64 {
            return longValue == 0 ? "" : String(longValue)
        } else if let intValue = value as? Int {
            return intValue == 0 ? "" : String(intValue)
        } else if let doubleValue = value as? Double {
            return doubleValue == 0 ? "" : String(Int(doubleValue))
        } else {
            return ""
        }
    }

    // MARK: - Block/Unblock Functionality
    private func checkBlockStatus() async {
        do {
            // Check if current user blocked the other user
            let blockedSnapshot = try await Firestore.firestore()
                .collection("Users").document(currentUserId)
                .collection("BlockedUserList")
                .getDocuments()
            
            isBlocked = blockedSnapshot.documents.contains { $0.documentID == otherUserId }
            
            // Check if other user blocked current user
            let otherBlockedSnapshot = try await Firestore.firestore()
                .collection("Users").document(otherUserId)
                .collection("BlockedUserList")
                .getDocuments()
            
            otherUserBlocked = otherBlockedSnapshot.documents.contains { $0.documentID == currentUserId }
            

            
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkBlockStatus() isBlocked: \(isBlocked), otherUserBlocked: \(otherUserBlocked)")
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkBlockStatus() failed: \(error.localizedDescription)")
        }
    }
    

    


    // MARK: - Chat Management
    private func checkExistingChat() async {
        do {
            let chatQuery = try await Firestore.firestore()
                .collection("Users").document(currentUserId)
                .collection("Chats")
                .getDocuments()
            
            let snapshot = chatQuery
            
            for document in snapshot.documents {
                if document.documentID == otherUserId {
                    chatExists = true
                    chatId = document.data()["Chat_id"] as? String ?? ""
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkExistingChat() found existing chat: \(chatId)")
                    return
                }
            }
            
            chatExists = false
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkExistingChat() no existing chat found")
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkExistingChat() failed: \(error.localizedDescription)")
        }
    }
    


    // MARK: - Action Handlers with Enhanced Monetization (Android Parity)
    private func handleChatButtonTap() {
        // Haptic feedback on chat tap
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleChatButtonTap()")
        handleConversationStart()
    }
    
    // Add haptic feedback helper for ProfileView
    private func triggerHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - User Type Determination
    private func determineUserType() -> ConversationUserType {
        let subscriptionManager = SubscriptionSessionManager.shared
        
        if subscriptionManager.hasProTier() {
            return .pro
        } else if subscriptionManager.hasPlusTierOrHigher() {
            return .plus
        } else if subscriptionManager.hasLiteTierOrHigher() {
            return .lite
        }
        
        // Check if new user
        if ConversationLimitManagerNew.shared.isNewUser() {
            return .newUser
        }
        
        return .free
    }
    
    // MARK: - Conversation Start Logic (Always-Show Popup Strategy)
    private func handleConversationStart() {
        // Generate unique flow session ID for tracking
        let flowId = "FLOW_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 1000...9999))"
        conversationFlowSessionId = flowId
        conversationFlowStartTime = Date()
        
        // Determine user type for logging
        let userType = determineUserType()
        
        // Log flow start with structured logging
        ConversationFlowLogger.shared.logFlowStart(
            initiatorUserId: SessionManager.shared.userId ?? "unknown",
            targetUserId: otherUserId,
            userType: userType,
            sessionId: flowId
        )
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() Starting conversation initiation")
        
        guard userProfile != nil else {
            ConversationFlowLogger.shared.logFlowError(
                flowId: flowId,
                error: NSError(domain: "ProfileView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user profile available"]),
                step: .start
            )
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() No user profile available")
            return
        }
        
        // Check if this is an existing conversation
        if !chatId.isEmpty && chatId != "null" {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() Existing conversation detected - navigating directly")
            // For existing conversations, navigate directly without any limit checks
            navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
            return
        }
        
        // For new conversations - First check if we should show notification permission popup
        if shouldShowNotificationPermissionPopup() {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() Showing notification permission popup before chat")
            showNotificationPermissionPopup = true
            return
        }
        
        // For new conversations - Check conversation limits using always-show popup strategy
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() New conversation - checking limits")
        
        let limitCheckStartTime = Date()
        let result = ConversationLimitManagerNew.shared.checkConversationLimit()
        
        // Log limit check result with structured logging
        ConversationFlowLogger.shared.logLimitCheck(
            flowId: flowId,
            result: result,
            userType: userType
        )
        
        // Track conversation button tap
        ConversationAnalytics.shared.trackConversationButtonTapped(
            userType: ConversationAnalytics.shared.getUserType(),
            currentUsage: result.currentUsage,
            limit: result.limit,
            isLimitReached: result.isLimitReached
        )
        
        if result.showPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() Showing conversation limit popup")
            conversationLimitResult = result
            showConversationLimitPopup = true
        } else {
            // ONLY Plus+ subscribers and new users proceed directly without popup AND without algorithm
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleConversationStart() Plus+/New user - bypassing popup AND algorithm")
            
            // Log routing decision for privileged users
            ConversationFlowLogger.shared.logRoutingDecision(
                flowId: flowId,
                decision: RoutingDecision(toInbox: false, isPaid: SubscriptionSessionManager.shared.hasPlusTierOrHigher()),
                userType: userType,
                bypassReason: "Privileged user bypass (Plus+/New user)"
            )
            
            // Track bypass analytics
            if SubscriptionSessionManager.shared.hasPlusTierOrHigher() {
                ConversationAnalytics.shared.trackPlusSubscriberBypass()
            } else if ConversationLimitManagerNew.shared.isNewUser() {
                // Calculate remaining new user time
                let userSessionManager = UserSessionManager.shared
                let firstAccountTime = userSessionManager.firstAccountCreatedTime
                let newUserPeriod = TimeInterval(SessionManager.shared.newUserFreePeriodSeconds)
                let remainingTime = max(0, newUserPeriod - (Date().timeIntervalSince1970 - firstAccountTime))
                ConversationAnalytics.shared.trackNewUserBypass(newUserTimeRemaining: remainingTime)
            }
            
            // Create direct chat without running inbox routing algorithm
            createDirectChatBypassingAllChecks()
        }
    }
    
    // MARK: - Popup Flow Management (Free & Lite Users)
    private func handleStartConversationFromPopup() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleStartConversationFromPopup() User clicked 'Start Conversation' in popup")
        
        // Re-check limits (cooldown might have changed)
        let result = ConversationLimitManagerNew.shared.checkConversationLimit()
        
        if result.canProceed {
            incrementUsageAndProceedWithRouting()
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleStartConversationFromPopup() Still at limit, showing toast")
            toastMessage = "Please wait for the cooldown to finish"
            withAnimation {
                showToast = true
            }
        }
    }
    
    private func incrementUsageAndProceedWithRouting() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "incrementUsageAndProceedWithRouting() Incrementing usage count and proceeding")
        
        guard let profile = userProfile else { return }
        
        // Track conversation performed analytics
        let result = ConversationLimitManagerNew.shared.checkConversationLimit()
        let isFirstConversationOfSession = result.currentUsage == 0
        
        ConversationAnalytics.shared.trackConversationPerformed(
            userType: ConversationAnalytics.shared.getUserType(),
            currentUsage: result.currentUsage + 1, // +1 because we're about to increment
            limit: result.limit,
            isFirstConversationOfSession: isFirstConversationOfSession
        )
        
        // Increment conversation count and proceed to routing decision
        ConversationLimitManagerNew.shared.performConversationStart { success in
            if success {
                DispatchQueue.main.async {
                    // Proceed to routing decision (Lite check + Algorithm)
                    self.executeRoutingDecisionFlow()
                }
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "incrementUsageAndProceedWithRouting() Failed to increment usage count")
            }
        }
    }
    
    private func proceedToChat(profile: UserProfile) {
        // Use the new simplified chat creation logic
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedToChat() Chat created successfully: \(chatId)")
                DispatchQueue.main.async {

                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedToChat() Error: \(error.localizedDescription)")
            }
        )
        
        ChatFlowManager.shared.createChat(
            otherUserId: otherUserId,
            otherUserName: profile.name,
            otherUserGender: profile.gender,
            otherUserImage: profile.profileImage,
            otherUserDevId: profile.devid,
            callback: chatFlowCallback
        )
    }
    
    // MARK: - Routing Decision Flow (Lite Check + Algorithm)
    private func executeRoutingDecisionFlow() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "executeRoutingDecisionFlow() Determining routing for Free/Lite user from popup")
        
        guard let profile = userProfile else { return }
        
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "executeRoutingDecisionFlow() Chat created successfully: \(chatId)")
                DispatchQueue.main.async {

                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "executeRoutingDecisionFlow() Error: \(error.localizedDescription)")
            }
        )
        
        // Execute the routing decision flow (Lite check first, then algorithm for Free users)
        ChatFlowManager.shared.executeInboxRoutingDecision(
            otherUserId: otherUserId,
            otherUserName: profile.name,
            otherUserGender: profile.gender,
            otherUserCountry: profile.country,
            otherUserImage: profile.profileImage,
            otherUserDevId: profile.devid,
            otherUserAge: profile.age,
            otherUserLanguage: profile.language ?? "",
            callback: chatFlowCallback
        )
    }
    
    // MARK: - Direct Chat Creation (Bypass All Limits & Algorithm)
    private func createDirectChatBypassingAllChecks() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "createDirectChatBypassingAllChecks() Creating direct chat for privileged users (Plus+/New users)")
        
        guard let profile = userProfile else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "createDirectChatBypassingAllChecks() No user profile available")
            return
        }
        
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createDirectChatBypassingAllChecks() Direct chat created successfully: \(chatId)")
                
                // Log successful chat creation with structured logging
                if let flowId = self.conversationFlowSessionId,
                   let startTime = self.conversationFlowStartTime {
                    let totalTime = Date().timeIntervalSince(startTime)
                    
                    ConversationFlowLogger.shared.logChatCreation(
                        flowId: flowId,
                        chatId: chatId,
                        routing: RoutingDecision(toInbox: false, isPaid: SubscriptionSessionManager.shared.hasPlusTierOrHigher()),
                        timeTaken: totalTime
                    )
                    
                    // Log performance metrics
                    let metrics = ConversationFlowMetrics(
                        limitCheckTime: 0.1, // Estimated for bypass case
                        algorithmTime: 0.0,  // Skipped for privileged users
                        chatCreationTime: 0.5, // Estimated
                        totalTime: totalTime
                    )
                    
                    ConversationFlowLogger.shared.logPerformanceMetrics(
                        flowId: flowId,
                        metrics: metrics
                    )
                }
                
                DispatchQueue.main.async {

                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createDirectChatBypassingAllChecks() Error: \(error.localizedDescription)")
                
                // Log error with structured logging
                if let flowId = self.conversationFlowSessionId {
                    ConversationFlowLogger.shared.logFlowError(
                        flowId: flowId,
                        error: error,
                        step: .chatCreation,
                        context: [
                            "method": "createDirectChatBypassingAllChecks",
                            "userType": self.determineUserType().description,
                            "targetUserId": otherUserId
                        ]
                    )
                }
            }
        )
        
        let hasPlusOrHigher = SubscriptionSessionManager.shared.hasPlusTierOrHigher()
        
        // Direct chat creation - bypasses all limits, popups, and algorithm
        ChatFlowManager.shared.createDirectChat(
            otherUserId: otherUserId,
            otherUserName: profile.name,
            otherUserGender: profile.gender,
            otherUserImage: profile.profileImage,
            otherUserDevId: profile.devid,
            isPremiumUser: hasPlusOrHigher,
            callback: chatFlowCallback
        )
    }
    
    // MARK: - Reward Handling (Android Parity - onRewarded equivalent)
    private func onRewarded(rewardType: RewardType) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "onRewarded() rewardType: \(rewardType)")
        
        guard let profile = userProfile else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "onRewarded() No user profile available")
            return
        }
        
        // Rewarded action replaced with direct chat creation (limit-based system)
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "onRewarded() Chat created successfully: \(chatId)")
                DispatchQueue.main.async {

                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "onRewarded() Error: \(error.localizedDescription)")
            }
        )
        
        // Use standard chat creation instead of handleRewardedAction (removed with ad system)
        ChatFlowManager.shared.executeInboxRoutingDecision(
            otherUserId: otherUserId,
            otherUserName: profile.name,
            otherUserGender: profile.gender,
            otherUserCountry: profile.country,
            otherUserImage: profile.profileImage,
            otherUserDevId: profile.devid,
            otherUserAge: profile.age,
            otherUserLanguage: profile.language ?? "",
            callback: chatFlowCallback
        )
    }
    
    private func handleCallButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleCallButtonTap()")
        
        // Check microphone permission first (matching Android)
        if !hasPermission(for: .microphone) {
            permissionDialogType = .microphone
            showPermissionDialog = true
            return
        }
        
        // Check subscription status - calls require Plus or Pro (matching Android)
        let subscriptionManager = SubscriptionSessionManager.shared
        let isPlusSubscriber = subscriptionManager.hasPlusTierOrHigher()
        let isProSubscriber = subscriptionManager.hasProTier()
        
        if isPlusSubscriber || isProSubscriber {
            // Directly initiate voice call after checking if user is busy
            checkCallBusy(isVideo: false)
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "User needs Plus/Pro subscription for calls. Showing voice call popup.")
            showVoiceCallPopup = true
        }
    }
    
    private func handleVideoCallButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleVideoCallButtonTap()")
        
        // Check microphone and camera permissions (matching Android)
        if !hasPermission(for: .microphone) || !hasPermission(for: .camera) {
            permissionDialogType = .microphoneAndCamera
            showPermissionDialog = true
            return
        }
        
        // Check subscription status - video calls require Plus or Pro (matching Android)
        let subscriptionManager = SubscriptionSessionManager.shared
        let isPlusSubscriber = subscriptionManager.hasPlusTierOrHigher()
        let isProSubscriber = subscriptionManager.hasProTier()
        
        if isPlusSubscriber || isProSubscriber {
            // Directly initiate video call after checking if user is busy
            checkCallBusy(isVideo: true)
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "User needs Plus/Pro subscription for video calls. Showing video call popup.")
            showVideoCallPopup = true
        }
    }
    
    private func checkCallBusy(isVideo: Bool) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "checkCallBusy() Checking if other user is busy")
        
        // Check VideoCall collection for other user
        Firestore.firestore()
            .collection("VideoCall").document(otherUserId)
            .getDocument { document, error in
                DispatchQueue.main.async {
                    if let document = document, document.exists {
                        let data = document.data()
                        let callEnded = data?["call_ended"] as? Bool ?? true
                        
                        if callEnded {
                            // User is free - initiate call
                            if isVideo {
                                self.showVideoCall = true
                            } else {
                                self.showMakeCall = true
                            }
                        } else {
                            // User is busy
                            self.showBusyToast()
                        }
                    } else {
                        // No ongoing call document - user is free
                        if isVideo {
                            self.showVideoCall = true
                        } else {
                            self.showMakeCall = true
                        }
                    }
                }
            }
    }
    
    private func handleInfoButtonTap() {
        triggerHapticFeedback()
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleInfoButtonTap() opening profile options")
        navigateToProfileOptions = true
    }
    
    // MARK: - Permission Management (Android Parity)
    private func hasPermission(for type: PermissionType) -> Bool {
        switch type {
        case .microphone:
            if #available(iOS 17.0, *) {
                return AVAudioApplication.shared.recordPermission == .granted
            } else {
                return AVAudioSession.sharedInstance().recordPermission == .granted
            }
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphoneAndCamera:
            return hasPermission(for: .microphone) && hasPermission(for: .camera)
        case .liveFeature:
            return hasPermission(for: .microphoneAndCamera)
        }
    }
    
    private func requestPermission() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "requestPermission() type: \(permissionDialogType)")
        
        switch permissionDialogType {
        case .microphone:
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.handleCallButtonTap()
                        }
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.handleCallButtonTap()
                        }
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
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { audioGranted in
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
            } else {
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
        case .liveFeature:
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { audioGranted in
                    if audioGranted {
                        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                            if videoGranted {
                                DispatchQueue.main.async {
                                    // Handle live feature permission granted
                                    // This can be customized based on what live feature should do
                                    self.handleVideoCallButtonTap()
                                }
                            }
                        }
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                    if audioGranted {
                        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                            if videoGranted {
                                DispatchQueue.main.async {
                                    // Handle live feature permission granted
                                    // This can be customized based on what live feature should do
                                    self.handleVideoCallButtonTap()
                                }
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
            return "Microphone and camera permissions are required to start a video call"
        case .liveFeature:
            return "Microphone and camera permissions are required for live features"
        }
    }
    
    // MARK: - Enhanced Monetization Handlers (Android Parity)
    private func handleAdWatchedForCalls() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleAdWatchedForCalls() ad completed")
        // In Android, watching ads doesn't give permanent access to calls
        // Calls require Plus/Pro subscription, so redirect to subscription
        navigateToSubscription()
    }
    
    private func handleAdWatchedForVideo() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleAdWatchedForVideo() ad completed")
        // In Android, watching ads doesn't give permanent access to video calls
        // Video calls require Plus/Pro subscription, so redirect to subscription
        navigateToSubscription()
    }
    
    private func navigateToSubscription() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "navigateToSubscription() Navigating to subscription")
        showSubscriptionView = true
    }
    
    private func startDirectChat() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "startDirectChat()")
        
        // Create ChatUser object for SwiftUI MessagesView
        guard let profile = userProfile else { return }
        
        let _ = ChatUser(
            id: otherUserId,
            name: profile.name,
            profileImage: profile.profileImage,
            gender: profile.gender,
            deviceId: profile.devid,
            isOnline: profile.isOnline
        )
        
        // Generate chatId from both user IDs
        let chatId = [currentUserId, otherUserId].sorted().joined(separator: "_")
        
        if chatExists {
            self.chatId = chatId
            self.navigateToMessages = true
        } else {
            // Create new chat
            createNewChat(chatId: chatId)
        }
    }
    
    private func createNewChat(chatId: String) {
        let chatData: [String: Any] = [
            "participants": [currentUserId, otherUserId],
            "created_at": Timestamp(date: Date()),
            "last_message": "",
            "last_message_time": Timestamp(date: Date())
        ]
        
        Firestore.firestore().collection("Chats").document(chatId).setData(chatData) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createNewChat() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "createNewChat() success - chat created: \(chatId)")
                self.chatId = chatId
                self.chatExists = true
                self.navigateToMessages = true
            }
        }
    }

    // MARK: - Notification Permission Logic
    private func shouldShowNotificationPermissionPopup() -> Bool {
        // Don't show if permission already requested/granted
        guard AppNotificationPermissionService.shared.shouldRequestPermission() else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldShowNotificationPermissionPopup() Permission already requested or granted")
            return false
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldShowNotificationPermissionPopup() Should show notification permission popup")
        return true
    }
    
    private func proceedAfterNotificationPermission() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedAfterNotificationPermission() Continuing with conversation flow after notification permission")
        
        // Continue with the conversation flow
        let limitCheckStartTime = Date()
        let result = ConversationLimitManagerNew.shared.checkConversationLimit()
        
        // Log limit check result with structured logging
        if let flowId = conversationFlowSessionId {
            ConversationFlowLogger.shared.logLimitCheck(
                flowId: flowId,
                result: result,
                userType: determineUserType()
            )
        }
        
        // Track conversation button tap
        ConversationAnalytics.shared.trackConversationButtonTapped(
            userType: ConversationAnalytics.shared.getUserType(),
            currentUsage: result.currentUsage,
            limit: result.limit,
            isLimitReached: result.isLimitReached
        )
        
        if result.showPopup {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedAfterNotificationPermission() Showing conversation limit popup")
            conversationLimitResult = result
            showConversationLimitPopup = true
        } else {
            // ONLY Plus+ subscribers and new users proceed directly without popup AND without algorithm
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedAfterNotificationPermission() Plus+/New user - bypassing popup AND algorithm")
            incrementUsageAndProceedWithRouting()
        }
    }

    // MARK: - Profile View Notification
    private func sendProfileViewNotification() {
        let time = Int64(Date().timeIntervalSince1970)
        let notificationData: [String: Any] = [
            "notif_sender_name": currentUserName,
            "notif_sender_id": currentUserId,
            "notif_sender_gender": currentGender,
            "notif_sender_image": currentProfilePhoto,
            "notif_token": currentDeviceId,
            "notif_other_id": otherUserId,
            "notif_time": time,
            "notif_type": "profileview"
        ]
        
        Firestore.firestore()
            .collection("Notifications").document(otherUserId)
            .collection("Notifications").document(time.description)
            .setData(notificationData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "sendProfileViewNotification() failed: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileView", message: "sendProfileViewNotification() success")
                }
            }
    }

    // MARK: - AI Functionality
    private func fetchAIMessages() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessages() Starting AI messages fetch from Firebase")
        
        // ANDROID PARITY: First fetch from Firebase like UserProfileActivity, then save to local DB
        fetchAIMessagesFromFirebaseAndSaveToLocal {
            // After Firebase fetch completes, load from local database
            DispatchQueue.main.async {
                self.aiTrainingMessages = AITrainingMessageStore.shared.getMessagesForChat(chatId: self.otherUserId)
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessages() fetched \(self.aiTrainingMessages.count) AI messages")
            }
        }
    }
    
    // ANDROID PARITY: Fetch AI messages from Firebase and save to local database like UserProfileActivity
    private func fetchAIMessagesFromFirebaseAndSaveToLocal(completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessagesFromFirebaseAndSaveToLocal() Fetching AI messages from Firebase")
        
        Firestore.firestore().collection("AIMessages").document("messages").getDocument { document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessagesFromFirebaseAndSaveToLocal() Error fetching AI messages: \(error.localizedDescription)")
                completion()
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let formattedMessages = data["formatted_messages"] as? String else {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessagesFromFirebaseAndSaveToLocal() No AI messages found or document doesn't exist")
                completion()
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchAIMessagesFromFirebaseAndSaveToLocal() Successfully fetched AI messages from Firebase")
            
            // ANDROID PARITY: Parse and save to local database like UserProfileActivity
            self.parseAndSaveAIMessages(formattedMessages: formattedMessages, chatId: self.otherUserId) {
                completion()
            }
        }
    }
    
    // ANDROID PARITY: Parse formatted messages and save to local database like UserProfileActivity
    private func parseAndSaveAIMessages(formattedMessages: String, chatId: String, completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "parseAndSaveAIMessages() Parsing and saving AI messages to local database")
        
        DispatchQueue.global(qos: .background).async {
            // ANDROID PARITY: First delete existing messages for this chat like UserProfileActivity
            AITrainingMessageStore.shared.deleteMessagesForChat(chatId: chatId)
            
            let lines = formattedMessages.components(separatedBy: "\n")
            
            // ANDROID PARITY: Process messages in pairs like UserProfileActivity
            var i = 0
            while i < lines.count - 1 {
                let userLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                let replyLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse user message
                let userParts = userLine.components(separatedBy: "'s message: ")
                if userParts.count == 2 {
                    let userName = userParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let userMessage = userParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Parse reply message
                    let replyParts = replyLine.components(separatedBy: "'s reply: ")
                    if replyParts.count == 2 {
                        let replyName = replyParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let replyMessage = replyParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Create and save the AI training message like UserProfileActivity
                        AITrainingMessageStore.shared.insert(
                            messageId: UUID().uuidString,
                            chatId: chatId,
                            userName: userName,
                            userMessage: userMessage,
                            replyName: replyName,
                            replyMessage: replyMessage,
                            messageTime: Date().timeIntervalSince1970
                        )
                        
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "parseAndSaveAIMessages() Saved AI training message: \(userName) -> \(replyName)")
                    }
                }
                
                i += 2
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "parseAndSaveAIMessages() Completed parsing and saving AI messages")
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // MARK: - AI Takeover Logic (Android Parity)
    private func shouldAiTakeOver() -> Bool {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldAiTakeOver() checking AI takeover conditions")
        
        // Null check for otherUserId (Android OTHERUSERID validation)
        guard !otherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "Error: otherUserId is empty in shouldAiTakeOver")
            return false
        }
        
        let sessionManager = SessionManager.shared
        let timeElapsedSinceLastMessageReceived = Date().timeIntervalSince1970 - Double(sessionManager.lastMessageReceivedTime)
        
        // Check if users are from same city (Android parity)
        let myCity = sessionManager.getUserRetrievedCity()
        let otherUserCity = userProfile?.city?.replacingOccurrences(of: "Around ", with: "") ?? ""
        let sameCity = myCity != nil && !myCity!.isEmpty && !otherUserCity.isEmpty && 
                      myCity!.caseInsensitiveCompare(otherUserCity) == .orderedSame
        
        // Check if users have same IP address (compare first 3 octets for privacy - Android parity)
        let myIpAddress = sessionManager.getUserRetrievedIp()
        var sameIpAddress = false
        
        if let myIp = myIpAddress, let otherIp = otherUserIpAddress,
           !myIp.isEmpty && !otherIp.isEmpty {
            let myIpParts = myIp.components(separatedBy: ".")
            let otherIpParts = otherIp.components(separatedBy: ".")
            
            if myIpParts.count >= 3 && otherIpParts.count >= 3 {
                sameIpAddress = myIpParts[0] == otherIpParts[0] && 
                               myIpParts[1] == otherIpParts[1] && 
                               myIpParts[2] == otherIpParts[2]
            }
        }
        
        // Get other user online status and last seen time
        let otherUserOnline = userProfile?.isOnline ?? false
        let currentTime = Date().timeIntervalSince1970
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: """
            shouldAiTakeOver() conditions:
            aiChatEnabled: \(sessionManager.aiChatEnabled)
            timeElapsed: \(timeElapsedSinceLastMessageReceived)
            maxIdleTime: \(sessionManager.maxIdleSecondsForAiChatEnabling)
            otherUserOnline: \(otherUserOnline)
            aiCoolOffTime: \(sessionManager.getAiCoolOffTime())
            currentTime: \(currentTime)
            lastSeenTime: \(otherUserLastSeenTime)
            minOfflineSeconds: \(sessionManager.minOfflineSecondsForAiChatEnabling)
            sameCity: \(sameCity) (my: '\(myCity ?? "nil")', other: '\(otherUserCity)')
            sameIpAddress: \(sameIpAddress) (my: '\(myIpAddress ?? "nil")', other: '\(otherUserIpAddress ?? "nil")')
            """)
        
        var shouldAiTakeOver = false
        
        // Only proceed with AI chat check if users are not from same city and don't have same IP (Android parity)
        if !sameCity && !sameIpAddress {
            if sessionManager.aiChatEnabled {
                if timeElapsedSinceLastMessageReceived > Double(sessionManager.maxIdleSecondsForAiChatEnabling) {
                    let coolOffExpired = (sessionManager.getAiCoolOffTime() + 60) < Int64(currentTime)
                    
                    if otherUserOnline {
                        // User is online - check cooloff time (Android parity)
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldAiTakeOver() Online user - coolOffExpired: \(coolOffExpired)")
                        if coolOffExpired {
                            shouldAiTakeOver = true
                        }
                    } else {
                        // User is offline - only enable AI if they were recently offline (within minOfflineSeconds) AND cooloff expired (Android parity)
                        let recentlyOffline = (otherUserLastSeenTime + Double(sessionManager.minOfflineSecondsForAiChatEnabling)) > currentTime
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldAiTakeOver() Offline user - recentlyOffline: \(recentlyOffline), coolOffExpired: \(coolOffExpired)")
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldAiTakeOver() Calculation: (\(otherUserLastSeenTime) + \(sessionManager.minOfflineSecondsForAiChatEnabling)) > \(currentTime) = \(otherUserLastSeenTime + Double(sessionManager.minOfflineSecondsForAiChatEnabling)) > \(currentTime)")
                        if recentlyOffline && coolOffExpired {
                            shouldAiTakeOver = true
                        }
                    }
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "shouldAiTakeOver() result: \(shouldAiTakeOver)")
        return shouldAiTakeOver
    }
    
    // MARK: - Fetch Other User IP and Last Seen (Android Parity)
    private func fetchOtherUserMetadata() {
        guard !otherUserId.isEmpty else { return }
        
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() fetching IP and last seen for user: \(otherUserId)")
        
        Firestore.firestore().collection("Users").document(otherUserId).getDocument { documentSnapshot, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() error: \(error.localizedDescription)")
                return
            }
            
            if let document = documentSnapshot, document.exists {
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() document exists, processing...")
                DispatchQueue.main.async {
                    // Get other user's IP address (Android parity)
                    if let userRetrievedIp = document.get("userRetrievedIp") as? String {
                        self.otherUserIpAddress = userRetrievedIp
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() other user IP: \(userRetrievedIp)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() userRetrievedIp not found in document")
                    }
                    
                    // Get other user's last seen time (Android parity: "last_time_seen")
                    if let lastSeenTimestamp = document.get("last_time_seen") as? Timestamp {
                        self.otherUserLastSeenTime = lastSeenTimestamp.dateValue().timeIntervalSince1970
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() other user last seen: \(self.otherUserLastSeenTime)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: ProfileView", message: "fetchOtherUserMetadata() last_time_seen not found in document")
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Action Button Component
    struct EnhancedActionButton: View {
        let icon: String
        let title: String
        let backgroundColor: Color
        let iconColor: Color
        let textColor: Color
        let isPrimary: Bool
        let action: () -> Void
        
        @State private var isPressed = false
        @Environment(\.colorScheme) private var colorScheme
        
        // Adaptive text color for better contrast
        private var adaptiveTextColor: Color {
            if isPrimary {
                // For primary buttons, use theme-aware colors that adapt to light/dark mode
                // Dark text in light mode, white text in dark mode for better contrast
                return colorScheme == .dark ? .white : Color("dark")
            } else {
                // For secondary buttons, use theme-aware colors that adapt to light/dark mode
                return colorScheme == .dark ? .white : Color("dark")
            }
        }
        
        var body: some View {
            Button(action: {
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                action()
            }) {
                VStack(spacing: 12) {
                    // Icon container with enhanced design
                    ZStack {
                        // Shadow layer (Rule 1: Light comes from the sky)
                        if isPrimary {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 61, height: 61)
                                .offset(y: 1)
                                .blur(radius: 2)
                        }
                        
                        // Main icon background
                        Circle()
                            .fill(backgroundColor)
                            .frame(width: 60, height: 60)
                            .overlay(
                                // Subtle inner shadow for depth
                                Circle()
                                    .strokeBorder(
                                        isPrimary ?
                                        Color.white.opacity(0.3) :
                                        Color.black.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                        
                        // Icon
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                    
                    // Text label with better typography
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(adaptiveTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .frame(minWidth: 70) // Ensure minimum touch target
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
        }
    }
    
    // MARK: - Navigation Methods (Android Parity)
    
    private func navigateToMessageView(chatId: String, otherUserId: String) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "navigateToMessageView() Navigating to chat: \(chatId)")
        
        // Store the chat info for navigation
        self.chatId = chatId
        
        // Trigger navigation to message view
        self.navigateToMessages = true
    }
    
    // MARK: - Dialog Methods (Android Parity)
    
    private func showWatchAdDialog(coins: Int, freeMessage: Bool) {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "showWatchAdDialog() Showing watch ad dialog: coins=\(coins), freeMessage=\(freeMessage)")
        
        guard let profile = userProfile else { return }
        
        // Create chat pay data and show popup (matching Android dialog_pay_to_chat.xml)
        chatPayData = ChatPayData(
            otherUserId: otherUserId,
            otherUserName: profile.name,
            otherUserGender: profile.gender,
            otherUserImage: profile.profileImage,
            otherUserDevId: profile.devid,
            coins: coins,
            freeMessage: freeMessage
        )
        showChatPayPopup = true
    }
    

    
    // MARK: - Chat Pay Action Handlers (Android Parity)
    
    private func handleFreeChat() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleFreeChat() Free chat selected")
        
        guard let data = chatPayData else { return }
        
        // Proceed with creating free chat (inbox message)
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleFreeChat() Free chat created successfully: \(chatId)")
                DispatchQueue.main.async {
                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleFreeChat() Error: \(error.localizedDescription)")
            }
        )
        
        ChatFlowManager.shared.checkOldOrNewChat(
            otherUserId: data.otherUserId,
            otherUserName: data.otherUserName,
            otherUserGender: data.otherUserGender,
            otherUserImage: data.otherUserImage,
            otherUserDevId: data.otherUserDevId,
            inBox: true, // Free message goes to inbox
            paid: false,
            callback: chatFlowCallback
        )
        
        // Update free message time (matching Android)
        SessionManager.shared.freeMessageTime = Int64(Date().timeIntervalSince1970)
    }
    
    private func handleMessageAction() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleMessageAction() Free message button tapped")
        
        // Check message limits and proceed if allowed
        let result = MessageLimitManager.shared.checkMessageLimit()
        
        if result.canProceed {
            MessageLimitManager.shared.performMessageSend { success in
                if success {
                    DispatchQueue.main.async {
                        // Navigate to existing chat if available
                        if !self.chatId.isEmpty && self.chatId != "null" {
                            self.navigateToMessageView(chatId: self.chatId, otherUserId: self.otherUserId)
                        } else {
                            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleMessageAction() No existing chat to navigate to")
                        }
                    }
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleMessageAction() Still at message limit")
        }
    }
    
    private func handleWatchAdForChat() {
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleWatchAdForChat() Watch ad for chat selected")
        
        guard let data = chatPayData else { return }
        
        // Check if ad is available and show it (matching Android)
        // Advertising functionality removed - proceed directly to chat
        AppLogger.log(tag: "LOG-APP: ProfileView", message: "handleWatchAdForChat() Advertising removed, proceeding to chat")
        
        // Determine reward type based on current state (matching original Android onRewarded logic)
        let rewardType: RewardType = self.chatId.isEmpty || self.chatId == "null" ? .message : .messageAgain
        self.onRewarded(rewardType: rewardType)
        
        // Update free message time and reset activity count (matching Android)
        SessionManager.shared.freeMessageTime = Int64(Date().timeIntervalSince1970)
        SessionManager.shared.activityResumedCount = 0
    }
    
    private func proceedToDirectChat(data: ChatPayData) {
        // Proceed with creating direct chat (chat box with notification)
        let chatFlowCallback = ProfileViewChatFlowCallback(
            onChatCreated: { (chatId: String, otherUserId: String) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedToDirectChat() Direct chat created successfully: \(chatId)")
                DispatchQueue.main.async {
                    self.navigateToMessageView(chatId: chatId, otherUserId: otherUserId)
                }
            },
            onError: { (error: Error) in
                AppLogger.log(tag: "LOG-APP: ProfileView", message: "proceedToDirectChat() Error: \(error.localizedDescription)")
            }
        )
        
        ChatFlowManager.shared.checkOldOrNewChat(
            otherUserId: data.otherUserId,
            otherUserName: data.otherUserName,
            otherUserGender: data.otherUserGender,
            otherUserImage: data.otherUserImage,
            otherUserDevId: data.otherUserDevId,
            inBox: false, // Direct message goes to chat box
            paid: true,
            callback: chatFlowCallback
        )
    }

    private func showBusyToast() {
        toastMessage = "User is Busy"
        withAnimation {
            showToast = true
        }
    }

}

// MARK: - User Detail Chip Component
struct UserDetailChip: View {
    let detail: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if detail == "__NEWLINE__" {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                // Icon based on detail type
                if let iconName = getIconName(for: detail), let iconType = getIconType(for: detail) {
                    if iconType == .asset, let flagAsset = CountryLanguageHelper.getFlagAssetName(for: detail), isCountry(detail) {
                        Image(flagAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 16, height: 16)
                            .clipShape(Circle())
                    } else if iconType == .asset {
                        Image(iconName)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(textColor)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                    }
                }
                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(grayBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("shade4"), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private var grayBackgroundColor: Color {
        Color("shade2")
    }
    
    private var textColor: Color {
        Color("dark")
    }
    
    private func getMeaningfulColor(for detail: String) -> Color {
        let d = detail.lowercased()
        return getMeaningfulColorForChip(d)
    }
    
    // MARK: - Meaningful Colors for Icons Only (Text uses theme colors)
    
    private func getMeaningfulColorForChip(_ d: String) -> Color {
        // Table mapping - using meaningful colors only (NO GRAY COLORS)
        // FIXED: Better color distribution and content-based assignments
        
        // ✅ Verification & Account Info
        if d.contains("email verified") { return Color(.systemGreen) } // Green = verified/success
        if d.contains("created:") { return Color(.systemIndigo) } // Indigo = account creation date
        if d.contains("days old") { return Color(.systemCyan) } // Cyan = account age/duration
        
        // ✅ Platform & Demographics
        if d == "iphone" { return .black } // Black = Apple branding
        if d == "android" { return Color(.systemGreen) } // Green = Android branding
        if d.contains("years old") { return Color(.systemOrange) } // Orange = age/demographics
        if d == "male" { return Color(.systemBlue) } // Blue = male
        if d == "female" { return Color(.systemPink) } // Pink = female
        if d == "english" { return Color(.systemTeal) } // Teal = language/communication
        
        // ✅ Location
        if d.contains("around ") { return Color(.systemOrange) } // Orange = local area
        if isCountryFromLowercase(d) { return Color(.systemIndigo) } // Indigo = country/nationality
        
        // ✅ Physical Attributes
        if d.contains("'") || d.contains("\"") { return Color(.systemCyan) } // Cyan = measurements
        if d.contains("engineer") { return Color(.systemYellow) } // Yellow = profession
        if d.contains("cricket") || d.contains("hobbies") { return Color(.systemPurple) } // Purple = hobbies
        if d.contains("leo") { return Color(.systemOrange) } // Orange = zodiac/fire sign
        
        // ✅ Relationship Preferences (Gender-based colors)
        if d == "i like men" { return Color(.systemBlue) } // Blue = male preference
        if d == "i like woman" { return Color(.systemPink) } // Pink = female preference
        if d == "single" { return Color(.systemTeal) } // Teal = available status
        if d == "married" { return Color(.systemRed) } // Red = committed relationship
        if d == "have kids" { return Color(.systemYellow) } // Yellow = family/children
        
        // ✅ Lifestyle & Health
        if d == "gym" { return Color(.systemGreen) } // Green = health/fitness
        if d == "smokes" { return Color(.systemRed) } // Red = health risk
        if d == "drinks" { return Color(.systemOrange) } // Orange = social drinking
        if d == "i play games" { return Color(.systemPurple) } // Purple = gaming/entertainment
        if d == "strictly decent chats please" { return Color(.systemGreen) } // Green = safe/appropriate
        
        // ✅ Interests & Hobbies (More varied colors)
        if d == "i love pets" { return Color(.systemBrown) } // Brown = animals/nature
        if d == "i travel" { return Color(.systemTeal) } // Teal = adventure/freedom
        if d == "i love music" { return Color(.systemPurple) } // Purple = arts/creativity
        if d == "i love movies" { return Color(.systemIndigo) } // Indigo = entertainment
        if d == "i am naughty" { return Color(.systemRed) } // Red = playful/bold
        if d == "foodie" { return Color(.systemOrange) } // Orange = food/appetite
        if d == "i go on dates" { return Color(.systemRed) } // Red = romance/dating
        if d == "i love fashion" { return Color(.systemPink) } // Pink = style/beauty
        
        // ✅ Emotional States (Appropriate color psychology)
        if d == "broken" { return Color(.systemRed) } // Red = pain/heartbreak
        if d == "depressed" { return Color(.systemIndigo) } // Indigo = deep sadness
        if d == "lonely" { return Color(.systemCyan) } // Cyan = isolation/distance
        if d == "i got cheated" { return Color(.systemRed) } // Red = betrayal/anger
        if d == "i can't sleep" { return Color(.systemIndigo) } // Indigo = night/insomnia
        
        // ✅ Permissions (All green for consistency)
        if d == "voice calls allowed" { return Color(.systemGreen) }
        if d == "video calls allowed" { return Color(.systemGreen) }
        if d == "pictures allowed" { return Color(.systemGreen) }
        
        // ✅ Activity Statistics (Gender-aware + activity type)
        if d.contains("voice calls") { return Color(.systemTeal) } // Teal = voice communication
        if d.contains("video calls") { return Color(.systemCyan) } // Cyan = video communication
        if d.contains("live") { return Color(.systemCyan) } // Cyan = live
        
        // ✅ Feedback & Experience
        if d.contains("thumbs up") { return Color(.systemGreen) } // Green = positive
        if d.contains("thumbs down") { return Color(.systemRed) } // Red = negative
        
        // ✅ Account & Chat Statistics (Gender-aware)
        if d.contains("male accounts") { return Color(.systemBlue) } // Blue = male
        if d.contains("female accounts") { return Color(.systemPink) } // Pink = female
        if d.contains("male chats") { return Color(.systemBlue) } // Blue = male chats
        if d.contains("female chats") { return Color(.systemPink) } // Pink = female chats
        
        // ✅ Safety & Moderation
        if d.contains("reports") { return Color(.systemRed) } // Red = warnings/reports
        if d.contains("blocks") { return Color(.systemOrange) } // Orange = caution/blocked
        
        // ✅ Social Media (Brand colors)
        if d.contains("snap:") { return Color(.systemYellow) } // Yellow = Snapchat
        if d.contains("insta:") { return Color(.systemPink) } // Pink = Instagram
        
        // ✅ Music as special case (was getting caught by hobbies)
        if d.contains("music") { return Color(.systemPurple) } // Purple = music/arts
        
        // Fallback - Reduced blue usage
        return Color(.systemTeal) // Teal instead of blue for better variety
    }
    
    private func isCountryFromLowercase(_ lowercaseDetail: String) -> Bool {
        guard !lowercaseDetail.isEmpty else { return false }
        // Convert back to proper case for country checking
        let properCase = lowercaseDetail.capitalized
        return CountryLanguageHelper.shared.isValidCountry(properCase)
    }

    
    private enum IconType { case sfSymbol, asset }
    private func getIconType(for detail: String) -> IconType? {
        let d = detail.lowercased()
        if d == "iphone" || d == "android" || d.contains("snap:") || d.contains("insta:") || (isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil) {
            return .asset
        }
        return .sfSymbol
    }
    private func getIconName(for detail: String) -> String? {
        let d = detail.lowercased()
        // Table mapping - SF Symbols using FILLED versions only for consistent appearance
        if d.contains("email verified") { return "checkmark.seal.fill" }
        if d.contains("created:") { return "calendar.circle.fill" }
        if d.contains("days old") { return "clock.fill" }
        if d == "iphone" { return "ic_apple" }
        if d == "android" { return "ic_android" }
        if d.contains("years old") { return "person.circle.fill" }
        if d == "male" { return "person.fill" }
        if d == "female" { return "person.fill" }
        if d == "english" { return "bubble.left.and.bubble.right.fill" }
        if d.contains("around ") { return "location.circle.fill" }
        if isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil { return CountryLanguageHelper.getFlagAssetName(for: detail) }
        if isCountry(detail) { return "flag.fill" }
        if d.contains("'") || d.contains("\"") { return "ruler.fill" }
        if d.contains("engineer") { return "wrench.and.screwdriver.fill" }
        if d.contains("cricket") { return "sportscourt.fill" }
        if d.contains("music") && !d.contains("i love music") { return "music.note.circle.fill" }
        if d.contains("leo") { return "sun.max.fill" }
        if d == "i like men" { return "person.2.fill" }
        if d == "i like woman" { return "person.2.fill" }
        if d == "single" { return "heart.fill" }
        if d == "married" { return "heart.fill" }
        if d == "have kids" { return "person.2.fill" }
        if d == "gym" { return "dumbbell.fill" }
        if d == "smokes" { return "smoke.fill" }
        if d == "drinks" { return "wineglass.fill" }
        if d == "i play games" { return "gamecontroller.fill" }
        if d == "strictly decent chats please" { return "hand.raised.fill" }
        if d == "i love pets" { return "pawprint.fill" }
        if d == "i travel" { return "airplane.circle.fill" }
        if d == "i love music" { return "music.note.circle.fill" }
        if d == "i love movies" { return "film.fill" }
        if d == "i am naughty" { return "face.smiling.fill" }
        if d == "foodie" { return "fork.knife.circle.fill" }
        if d == "i go on dates" { return "heart.circle.fill" }
        if d == "i love fashion" { return "tshirt.fill" }
        if d == "broken" { return "heart.slash.fill" }
        if d == "depressed" { return "cloud.fill" }
        if d == "lonely" { return "person.fill" }
        if d == "i got cheated" { return "exclamationmark.triangle.fill" }
        if d == "i can't sleep" { return "moon.fill" }
        if d == "voice calls allowed" { return "phone.fill" }
        if d == "video calls allowed" { return "video.fill" }
        if d == "pictures allowed" { return "camera.fill" }
        if d.contains("voice calls") { return "phone.circle.fill" }
        if d.contains("video calls") { return "video.circle.fill" }
        if d.contains("live") { return "video.fill" }
        if d.contains("thumbs up") { return "hand.thumbsup.fill" }
        if d.contains("thumbs down") { return "hand.thumbsdown.fill" }
        if d.contains("male accounts") { return "person.3.fill" }
        if d.contains("female accounts") { return "person.3.fill" }
        if d.contains("male chats") { return "message.fill" }
        if d.contains("female chats") { return "message.fill" }
        if d.contains("reports") { return "flag.fill" }
        if d.contains("blocks") { return "hand.raised.fill" }
        if d.contains("snap:") { return "ic_snapchat" }
        if d.contains("insta:") { return "ic_instagram" }
        // Fallback
        return "info.circle.fill"
    }
    private func isCountry(_ detail: String) -> Bool {
        guard !detail.isEmpty else { return false }
        return CountryLanguageHelper.shared.isValidCountry(detail)
    }
} // <-- This closes UserDetailChip

// MARK: - Enhanced User Detail Chip Component
struct EnhancedUserDetailChip: View {
    let detail: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if detail == "__NEWLINE__" {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                // Icon with meaningful colors
                if let iconName = getIconName(for: detail), let iconType = getIconType(for: detail) {
                    Group {
                        if iconType == .asset, let flagAsset = CountryLanguageHelper.getFlagAssetName(for: detail), isCountry(detail) {
                            Image(flagAsset)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        } else if iconType == .asset {
                            Image(iconName)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(getMeaningfulColor(for: detail))
                        } else {
                            Image(systemName: iconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(getMeaningfulColor(for: detail))
                        }
                    }
                }
                
                // Text with better typography
                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(chipBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("shade4"), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private var chipBackgroundColor: Color {
        Color("shade2")
    }
    
    private var textColor: Color {
        Color("dark")
    }
    
    private func getMeaningfulColor(for detail: String) -> Color {
        let d = detail.lowercased()
        
        // Enhanced color mapping with better contrast ratios
        if d.contains("email verified") { return Color(.systemGreen) }
        if d.contains("created:") { return Color(.systemIndigo) }
        if d.contains("days old") { return Color(.systemCyan) }
        if d == "iphone" { return .primary }
        if d == "android" { return Color(.systemGreen) }
        if d.contains("years old") { return Color(.systemOrange) }
        if d == "male" { return Color(.systemBlue) }
        if d == "female" { return Color(.systemPink) }
        if d == "english" { return Color(.systemTeal) }
        if d.contains("around ") { return Color(.systemOrange) }
        if d.contains("'") || d.contains("\"") { return Color(.systemCyan) }
        if d.contains("engineer") { return Color(.systemYellow) }
        if d == "gym" { return Color(.systemGreen) }
        if d == "smokes" { return Color(.systemRed) }
        if d == "drinks" { return Color(.systemOrange) }
        if d == "i play games" { return Color(.systemPurple) }
        if d == "i love pets" { return Color(.systemBrown) }
        if d == "i travel" { return Color(.systemTeal) }
        if d == "i love music" { return Color(.systemPurple) }
        if d == "i love movies" { return Color(.systemIndigo) }
        if d == "foodie" { return Color(.systemOrange) }
        if d.contains("voice calls") { return Color(.systemTeal) }
        if d.contains("video calls") { return Color(.systemCyan) }
        if d.contains("thumbs up") { return Color(.systemGreen) }
        if d.contains("thumbs down") { return Color(.systemRed) }
        if d.contains("snap:") { return Color(.systemYellow) }
        if d.contains("insta:") { return Color(.systemPink) }
        
        return Color(.systemTeal)
    }
    
    private enum IconType { case sfSymbol, asset }
    
    private func getIconType(for detail: String) -> IconType? {
        let d = detail.lowercased()
        if d == "iphone" || d == "android" || d.contains("snap:") || d.contains("insta:") || (isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil) {
            return .asset
        }
        return .sfSymbol
    }
    
    private func getIconName(for detail: String) -> String? {
        let d = detail.lowercased()
        if d.contains("email verified") { return "checkmark.seal.fill" }
        if d.contains("created:") { return "calendar.circle.fill" }
        if d.contains("days old") { return "clock.fill" }
        if d == "iphone" { return "ic_apple" }
        if d == "android" { return "ic_android" }
        if d.contains("years old") { return "person.circle.fill" }
        if d == "male" { return "person.fill" }
        if d == "female" { return "person.fill" }
        if d == "english" { return "bubble.left.and.bubble.right.fill" }
        if d.contains("around ") { return "location.circle.fill" }
        if isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil {
            return CountryLanguageHelper.getFlagAssetName(for: detail)
        }
        if isCountry(detail) { return "flag.fill" }
        if d.contains("'") || d.contains("\"") { return "ruler.fill" }
        if d.contains("engineer") { return "wrench.and.screwdriver.fill" }
        if d == "gym" { return "dumbbell.fill" }
        if d == "smokes" { return "smoke.fill" }
        if d == "drinks" { return "wineglass.fill" }
        if d == "i play games" { return "gamecontroller.fill" }
        if d == "i love pets" { return "pawprint.fill" }
        if d == "i travel" { return "airplane.circle.fill" }
        if d == "i love music" { return "music.note.circle.fill" }
        if d == "i love movies" { return "film.fill" }
        if d == "foodie" { return "fork.knife.circle.fill" }
        if d.contains("voice calls") { return "phone.circle.fill" }
        if d.contains("video calls") { return "video.circle.fill" }
        if d.contains("thumbs up") { return "hand.thumbsup.fill" }
        if d.contains("thumbs down") { return "hand.thumbsdown.fill" }
        if d.contains("snap:") { return "ic_snapchat" }
        if d.contains("insta:") { return "ic_instagram" }
        
        return "info.circle.fill"
    }
    
    private func isCountry(_ detail: String) -> Bool {
        guard !detail.isEmpty else { return false }
        return CountryLanguageHelper.shared.isValidCountry(detail)
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(otherUserId: "test123")
    }
}



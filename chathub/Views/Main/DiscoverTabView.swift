import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import SDWebImageSwiftUI



// MARK: - DiscoverTabView
struct DiscoverTabView: View {
    @ObservedObject var viewModel: DiscoverTabViewModel
    @State private var showSubscriptionPopup: Bool = false
    @State private var showSearchLimitPopup: Bool = false
    @State private var searchLimitResult: FeatureLimitResult?
    
    // Use AppStorage for persistent state that survives tab switching
    @AppStorage("discoverTabView_hasInitiallyLoaded") private var hasInitiallyLoaded = false
    
    // Callback to notify parent when search field is focused
    var onSearchFocusChanged: ((Bool) -> Void)?
    
    // Custom initializer to support viewModel and onSearchFocusChanged parameters
    init(viewModel: DiscoverTabViewModel? = nil, onSearchFocusChanged: ((Bool) -> Void)? = nil) {
        self.viewModel = viewModel ?? DiscoverTabViewModel()
        self.onSearchFocusChanged = onSearchFocusChanged
    }
    
    // Session management - Use specialized managers instead of monolithic SessionManager
    private var userSessionManager = UserSessionManager.shared
    private var appSettingsSessionManager = AppSettingsSessionManager.shared
    private var subscriptionManager = SubscriptionSessionManager.shared
    private var isLiteSubscriber: Bool {
        return subscriptionManager.isUserSubscribedToLite() ||
               subscriptionManager.isUserSubscribedToPlus() ||
               subscriptionManager.isUserSubscribedToPro() ||
               ConversationLimitManagerNew.shared.isNewUser()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarSection
            contentSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - Discover tab view appeared")
            AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - Current notifications count: \(viewModel.notifications.count)")
            AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - isLoading: \(viewModel.isLoading)")
            AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - hasInitiallyLoaded: \(hasInitiallyLoaded)")
            
            // EFFICIENCY FIX: Only load if we haven't loaded before or have no data
            if !hasInitiallyLoaded || viewModel.notifications.isEmpty {
                AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - First time loading or no data present, checking if data load needed")
                
                // Use proper initial load method that respects data state
                AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - Calling initialLoadIfNeeded")
                viewModel.initialLoadIfNeeded()
                
                // Only set the flag to true if we actually have data now
                if !viewModel.notifications.isEmpty {
                    hasInitiallyLoaded = true
                    AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - Data loaded successfully, setting hasInitiallyLoaded to true")
                } else {
                    AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - No data loaded yet, will retry on next view appearance")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DiscoverTabView", message: "viewDidAppear() - Already loaded before with data (\(viewModel.notifications.count) notifications), skipping reload")
                // Still mark notifications as seen for badge management
                InAppNotificationsSyncService.shared.markNotificationsAsSeenInLocalDB()
            }
        }
        .onDisappear {
            cleanupView()
        }
        .background(subscriptionPresentation)

        .overlay(searchLimitPopupOverlay)
    }
    
    // MARK: - View Components
    
    private var searchBarSection: some View {
        DiscoverSearchBar(
            text: $viewModel.searchText,
            onSearchButtonClicked: {
                handleSearch()
            },
            onTextChanged: { text in
                if text.isEmpty {
                    viewModel.clearSearchResults()
                }
            },
            onFocusChanged: { focused in
                onSearchFocusChanged?(focused)
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
    
    private var contentSection: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.showEmptyState {
                emptyStateView
            } else {
                mainContentView
            }
        }
    }
    
    private var mainContentView: some View {
        Group {
            if viewModel.showSearchResults {
                searchResultsList
            } else {
                notificationsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .onTapGesture {
                    dismissKeyboard()
                }
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        DiscoverEmptyStateView(message: viewModel.emptyStateMessage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
    }
    
    private var searchResultsList: some View {
        List {
            ForEach(viewModel.searchResults) { user in
                ZStack {
                    // Hidden NavigationLink to handle navigation without showing arrow
                    NavigationLink(destination: ProfileView(otherUserId: user.userId)) {
                        EmptyView()
                    }
                    .opacity(0.0)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Actual content that will be displayed
                    DiscoverSearchResultRow(user: user)
                        .contentShape(Rectangle()) // Makes entire row tappable
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(listBackgroundView)
    }
    
        private var notificationsList: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                ZStack {
                    // Hidden NavigationLink to handle navigation without showing arrow
                    NavigationLink(destination: ProfileView(otherUserId: notification.NotificationId)) {
                        EmptyView()
                    }
                    .opacity(0.0)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Actual content that will be displayed
                    DiscoverNotificationRow(notification: notification)
                        .contentShape(Rectangle()) // Makes entire row tappable
                        .onAppear {
                            // Load more notifications when approaching the end
                            if notification.id == viewModel.notifications.last?.id {
                                viewModel.loadMoreNotifications()
                            }
                        }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            
            // Loading indicator for infinite scroll
            if viewModel.isLoadingMore && viewModel.hasMoreNotifications {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .padding(.vertical, 10)
            }
        }
        .listStyle(.plain)
        .background(listBackgroundView)
    }
    
    private var listBackgroundView: some View {
        Color("Background Color")
            .onTapGesture {
                dismissKeyboard()
            }
    }
    
    private var backgroundView: some View {
        Color("Background Color")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
    }
    
    private var subscriptionPresentation: some View {
        EmptyView()
            .sheet(isPresented: $showSubscriptionPopup) {
                SubscriptionView()
            }
    }
    

    
    private var searchLimitPopupOverlay: some View {
        Group {
            if showSearchLimitPopup, let result = searchLimitResult {
                SearchLimitPopupView(
                    isPresented: $showSearchLimitPopup,
                    remainingCooldown: result.remainingCooldown,
                    isLimitReached: result.isLimitReached,
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    onSearch: {
                        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "User chose to search from popup.")
                        handleSearchAction()
                    },
                    onUpgradeToPremium: {
                        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "User chose to upgrade from search popup.")
                        showSubscriptionPopup = true
                    }
                )
            }
        }
    }
    

    
    // MARK: - Helper Methods
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func setupView() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupView() Setting up discover view - Android onResume() equivalent")
        
        // Load all notifications from local database (both seen and unseen)
        viewModel.loadNotificationsFromLocalDB()
        viewModel.markNotificationsLoaded()
        
        // Force refresh from Firebase to get latest notifications (Android parity)
        viewModel.refreshNotifications()
        
        // Mark notifications as seen when discover tab is viewed (Android parity)
        // This only affects the badge count, not the notification display
        InAppNotificationsSyncService.shared.markNotificationsAsSeenInLocalDB()
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupView() Marked notifications as seen in local database")
    }
    
    private func cleanupView() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "cleanupView() Cleaning up discover view")
        
        // Reset search limit popup state to prevent stale values
        if showSearchLimitPopup {
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "cleanupView() Resetting search limit popup state")
            showSearchLimitPopup = false
            searchLimitResult = nil
        }
    }
    
    private func handleSearch() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "handleSearch() Search button clicked")
        
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { 
            viewModel.clearSearchResults()
            return 
        }
        
        // Hide keyboard immediately
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        viewModel.isSearching = true
        
        // Check search limits using new system
        performSearchWithLimits(query: query)
    }
    
    private func performSearchWithLimits(query: String) {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearchWithLimits() Checking search limits")
        
        let result = SearchLimitManager.shared.checkSearchLimit()
        
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearchWithLimits() Result - canProceed: \(result.canProceed), showPopup: \(result.showPopup), currentUsage: \(result.currentUsage), limit: \(result.limit)")
        
        if result.showPopup {
            // Always show popup for non-Lite subscribers and non-new users
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearchWithLimits() Showing search limit popup")
            
            // Track popup shown
            SearchAnalytics.shared.trackSearchPopupShown(
                currentUsage: result.currentUsage,
                limit: result.limit,
                remainingCooldown: result.remainingCooldown,
                triggerReason: result.isLimitReached ? "limit_reached" : "always_show_strategy"
            )
            
            searchLimitResult = result
            showSearchLimitPopup = true
            
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearchWithLimits() Set showSearchLimitPopup = true")
        } else {
            // Direct search for Lite subscribers and new users
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performSearchWithLimits() Can proceed - performing search")
            performActualSearch(query: query)
        }
    }
    
    private func handleSearchAction() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "handleSearchAction() Free search button tapped")
        
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Check limits again and proceed if allowed
        let result = SearchLimitManager.shared.checkSearchLimit()
        
        if result.canProceed {
            performActualSearch(query: query)
        } else {
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "handleSearchAction() Still at limit")
        }
    }
    
    private func performActualSearch(query: String) {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performActualSearch() Performing search for: \(query)")
        
        SearchLimitManager.shared.performSearch { success in
            if success {
                DispatchQueue.main.async {
                    self.performSearch(query: query)
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performActualSearch() Search blocked")
                
                // Track blocked search
                let result = SearchLimitManager.shared.checkSearchLimit()
                if result.isLimitReached {
                    SearchAnalytics.shared.trackSearchBlockedLimitReached(
                        currentUsage: result.currentUsage,
                        limit: result.limit,
                        searchQuery: query
                    )
                } else if SearchLimitManager.shared.isInCooldown() {
                    SearchAnalytics.shared.trackSearchBlockedCooldown(
                        remainingCooldown: result.remainingCooldown,
                        searchQuery: query
                    )
                }
            }
        }
    }
    
        private func performSearch(query: String) {
        viewModel.performSearch(query: query)
        
        // Track successful search execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let resultsCount = self.viewModel.searchResults.count
            let userType = SearchAnalytics.shared.getUserType()
            SearchAnalytics.shared.trackSearchPerformed(
                searchQuery: query,
                resultsCount: resultsCount,
                success: true,
                userType: userType
            )
        }
    }
    
    // Removed: now using SearchAnalytics.shared.getUserType() for consistency
    



    

}

// MARK: - Supporting Views

struct DiscoverSearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    let onTextChanged: (String) -> Void
    var onFocusChanged: ((Bool) -> Void)?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("dark"))
                .frame(width: 24, height: 24)
            
            TextField("Search", text: $text)
                .font(.system(size: 14))
                .foregroundColor(Color("dark"))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isTextFieldFocused)
                .textInputAutocapitalization(.never)
                .keyboardType(.default)
                .onChange(of: text) { _, newValue in
                    onTextChanged(newValue)
                }
                .onSubmit {
                    onSearchButtonClicked()
                }
                .submitLabel(.search)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
        .contentShape(Rectangle()) // Makes entire area tappable
        .background(Color("shade2"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
            isTextFieldFocused = true
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            onFocusChanged?(focused)
        }
        .animation(.none, value: isTextFieldFocused) // Disable animations that might cause lag
    }
}

struct DiscoverSearchResultRow: View {
    let user: SearchUser
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile Image - matching OnlineUsersView 65dp size exactly
            ZStack {
                if let url = URL(string: user.userImage), !user.userImage.isEmpty {
                    WebImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(user.userGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                    }
                    .onSuccess { image, data, cacheType in
                        // Image loaded successfully
                    }
                    .onFailure { error in
                        // Image loading failed
                    }
                                    .indicator(.activity)
                    .transition(.opacity)
                        .frame(width: 65, height: 65)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppTheme.shade2, lineWidth: 2)
                        )
                        .background(
                            Image(user.userGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 65, height: 65)
                                .clipShape(Circle())
                        )
                } else {
                    // Default gradient placeholder based on gender - matching Android design
                    Image(user.userGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 65)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppTheme.shade2, lineWidth: 2)
                        )
                }
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - centered vertically
            VStack(alignment: .leading, spacing: 4) {
                Spacer() // Top spacer for vertical centering
                
                // Username
                Text(Profanity.share.removeProfanityNumbersAllowed(user.userName))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.darkText)
                    .lineLimit(1)
                
                // Gender section
                HStack(spacing: 5) {
                    // Gender icon
                    Image(user.userGender.lowercased() == "male" ? "male_symbol" : "female_symbol")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .padding(.top, 1)
                    
                    // Gender text
                    Text(user.userGender.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(user.userGender.lowercased() == "male" ? AppTheme.darkBlue : AppTheme.warningOrange)
                }
                
                Spacer() // Bottom spacer for vertical centering
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
            
            // Country flag - 34dp circular, positioned on far right - matching OnlineUsersView
            if !user.userCountry.isEmpty {
                if let flagImage = getFlagImage(for: user.userCountry) {
                    Image(flagImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(AppTheme.shade200)
                                .frame(width: 34, height: 34)
                        )
                } else {
                    // Default flag placeholder with theme colors
                    Circle()
                        .fill(AppTheme.shade200)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image("flag")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(AppTheme.shade6)
                        )
                }
            } else {
                // Invisible spacer to maintain layout
                Circle()
                    .fill(Color.clear)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.trailing, 20)
        .background(Color("Background Color"))
        .contentShape(Rectangle())
    }
    
    // Helper function to get flag image name - matching OnlineUsersView
    private func getFlagImage(for country: String) -> String? {
        let flagName = country.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        
        // Check some common mappings
        let countryMappings: [String: String] = [
            "united_states": "United states of america",
            "usa": "United states of america", 
            "united_kingdom": "United kingdom",
            "uk": "United kingdom",
            "south_korea": "South korea",
            "north_korea": "North korea"
        ]
        
        let finalName = countryMappings[flagName] ?? country
        
        // Return the flag name if it exists in assets
        return finalName
    }
}

struct DiscoverNotificationRow: View {
let notification: InAppNotificationDetails
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile Image section - clean without overlay like Games/Chats tabs
            ZStack {
                if let url = URL(string: notification.NotificationImage), !notification.NotificationImage.isEmpty {
                    WebImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(notification.NotificationGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                    }
                    .onSuccess { image, data, cacheType in
                        // Image loaded successfully
                    }
                    .onFailure { error in
                        // Image loading failed
                    }
                    .indicator(.activity)
                    .transition(.opacity)
                    .frame(width: 65, height: 65)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.shade2, lineWidth: 2)
                    )
                    .background(
                        Image(notification.NotificationGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                    )
                } else {
                    // Default gradient placeholder based on gender - matching Android design
                    Image(notification.NotificationGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 65)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppTheme.shade2, lineWidth: 2)
                        )
                }
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - centered vertically
            VStack(alignment: .leading, spacing: 4) {
                Spacer() // Top spacer for vertical centering
                
                // Name
                Text(Profanity.share.removeProfanityNumbersAllowed(notification.NotificationName))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                
                // Action and time
                Text(notificationMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                Spacer() // Bottom spacer for vertical centering
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
            
            // Notification type icon - positioned on far right like Games/Chats tabs
            ZStack {
                Circle()
                    .fill(AppTheme.shade200)
                    .frame(width: 34, height: 34)
                
                Image(notificationIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppTheme.shade6)
            }
        }
        .padding(.trailing, 20)
        .background(Color("Background Color"))
        .contentShape(Rectangle())
    }
    
    // Handle all notification types gracefully
    private var notificationMessage: String {
        let timeAgo = formatTimeAgo(notification.NotificationTime)
        
        // Handle all notification types dynamically based on the type string
        switch notification.NotificationType.lowercased() {
        case "profileview":
            return "Viewed your profile · \(timeAgo)"
        case "message":
            return "Sent you a message · \(timeAgo)"
        case "call":
            return "Called you · \(timeAgo)"
        case "videocall":
            return "Video called you · \(timeAgo)"
        case "like":
            return "Liked your profile · \(timeAgo)"
        case "friend":
            return "Sent a friend request · \(timeAgo)"
        case "gift":
            return "Sent you a gift · \(timeAgo)"
        default:
            // For any other notification type, show it dynamically
            return "\(notification.NotificationType.capitalized) · \(timeAgo)"
        }
    }
    
    // Handle all notification types gracefully with appropriate icons
    private var notificationIconName: String {
        switch notification.NotificationType.lowercased() {
        case "profileview":
            return "eye_icon" // Eye icon for profile views
        case "message":
            return "message_icon" // Message icon
        case "call":
            return "call_icon" // Call icon
        case "videocall":
            return "video_call_icon" // Video call icon
        case "like":
            return "heart_icon" // Heart icon for likes
        case "friend":
            return "person_add_icon" // Person add icon for friend requests
        case "gift":
            return "gift_icon" // Gift icon
        default:
            // Default notification icon for unknown types
            return "bell" // Default bell icon
        }
    }
    
    private func formatTimeAgo(_ timestamp: String) -> String {
        guard let timeInterval = Double(timestamp) else { 
            return "now" 
        }
        
        // Handle both seconds and milliseconds timestamps
        let finalTimeInterval = timeInterval > 1000000000000 ? timeInterval / 1000 : timeInterval
        let date = Date(timeIntervalSince1970: finalTimeInterval)
        let timeDifference = Date().timeIntervalSince(date)
        
        if timeDifference < 60 {
            return "now"
        } else if timeDifference < 3600 {
            let minutes = Int(timeDifference / 60)
            return "\(minutes)m"
        } else if timeDifference < 86400 {
            let hours = Int(timeDifference / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeDifference / 86400)
            return "\(days)d"
        }
    }
}

struct DiscoverEmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // SF Symbol - using bell for notifications or magnifyingglass for search
            Image(systemName: message.contains("notification") ? "bell" : "magnifyingglass")
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundColor(Color("ButtonColor"))
            
            // Text Content
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("ButtonColor"))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Functions
// Removed local profanity filter - now using ProfanityService.shared consistently

// Ad callback classes removed - no longer needed with new limit system



// MARK: - Preview

#Preview {
    NavigationView {
        DiscoverTabView(onSearchFocusChanged: nil)
    }
}

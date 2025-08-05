import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine



// MARK: - DiscoverTabView
struct DiscoverTabView: View {
    @StateObject private var viewModel = DiscoverTabViewModel()
    @State private var showSubscriptionPopup: Bool = false
    @State private var showSearchLimitPopup: Bool = false
    @State private var searchLimitResult: FeatureLimitResult?
    
    // Callback to notify parent when search field is focused
    var onSearchFocusChanged: ((Bool) -> Void)?
    
    // Custom initializer to support onSearchFocusChanged parameter
    init(onSearchFocusChanged: ((Bool) -> Void)? = nil) {
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
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .background(subscriptionNavigationLink)

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
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
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
    
    private var subscriptionNavigationLink: some View {
        NavigationLink(
            destination: SubscriptionView(),
            isActive: $showSubscriptionPopup
        ) {
            EmptyView()
        }
        .hidden()
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
        
        // CRITICAL FIX: Load notifications like Android SearchFragment.onResume() does
        // This ensures notifications are loaded every time the view appears
        viewModel.loadNotificationsFromLocalDB()
        viewModel.markNotificationsLoaded()
        
        // Force refresh from Firebase to get latest notifications (Android parity)
        viewModel.refreshNotifications()
        
        // Mark notifications as seen when discover tab is viewed (Android parity)
        // Delay to ensure UI is fully loaded before marking as seen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            InAppNotificationsSyncService.shared.markNotificationsAsSeenInLocalDB()
            AppLogger.log(tag: "LOG-APP: DiscoverView", message: "setupView() Marked notifications as seen in local database")
        }
    }
    
    private func cleanupView() {
        AppLogger.log(tag: "LOG-APP: DiscoverView", message: "cleanupView() Cleaning up discover view")
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
                .onChange(of: text) { newValue in
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
        .onChange(of: isTextFieldFocused) { focused in
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
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 65, height: 65)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                                .frame(width: 65, height: 65)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.shade2, lineWidth: 2)
                                )
                        case .failure(_):
                            // Gender-based gradient placeholder while image loads - matching Android design
                            Image(user.userGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 65, height: 65)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.shade2, lineWidth: 2)
                                )
                        @unknown default:
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
            
            // Content section - matching OnlineUsersView layout
            VStack(alignment: .leading, spacing: 5) {
                // Username - matching Android 16sp
                Text(Profanity.share.removeProfanityNumbersAllowed(user.userName))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.darkText)
                    .lineLimit(1)
                    .padding(.top, 18)
                
                // Gender section - matching OnlineUsersView LinearLayout with icon + text
                HStack(spacing: 5) {
                    // Gender icon - sized to match text height
                    Image(user.userGender.lowercased() == "male" ? "male_symbol" : "female_symbol")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .padding(.top, 1)
                    
                    // Gender text - matching OnlineUsersView with Android color matching
                    Text(user.userGender.capitalized)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(user.userGender.lowercased() == "male" ? AppTheme.darkBlue : AppTheme.warningOrange)
                }
                
                Spacer()
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
            // Profile Image with notification type overlay - matching Android design
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if let url = URL(string: notification.NotificationImage), !notification.NotificationImage.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 65, height: 65)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 65, height: 65)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.shade2, lineWidth: 2)
                                    )
                            case .failure(_):
                                // Gender-based gradient placeholder while image loads - matching Android design
                                Image(notification.NotificationGender.lowercased() == "male" ? "male_icon" : "Female_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 65, height: 65)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.shade2, lineWidth: 2)
                                    )
                            @unknown default:
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
                
                // Notification type icon overlay - matching Android 32dp size and position
                Image(notificationIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color("shade_800"))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color("shade_200"))
                            .frame(width: 32, height: 32)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color("Background Color"), lineWidth: 2)
                            .frame(width: 32, height: 32)
                    )
            }
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - matching OnlineUsersView layout
            VStack(alignment: .leading, spacing: 5) {
                // Name - matching Android 16sp
                Text(Profanity.share.removeProfanityNumbersAllowed(notification.NotificationName))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                    .padding(.top, 15)
                
                // Action and time - matching Android design
                Text(notificationMessage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
        }
        .padding(.trailing, 20)
        .background(Color("Background Color"))
        .contentShape(Rectangle())
    }
    
    // Update notificationMessage to only handle profileview
    private var notificationMessage: String {
        let timeAgo = formatTimeAgo(notification.NotificationTime)
        
        switch InAppNotificationDetails.NotificationType(rawValue: notification.NotificationType) {
        case .profileview:
            return "Viewed your profile · \(timeAgo)"
        default:
            return "New notification · \(timeAgo)"
        }
    }
    
    // Update notificationIconName to only handle profileview
    private var notificationIconName: String {
        switch InAppNotificationDetails.NotificationType(rawValue: notification.NotificationType) {
        case .profileview:
            return "eye_icon" // Eye icon for profile views
        default:
            return "eye_icon" // Default eye icon
        }
    }
    
    private func formatTimeAgo(_ timestamp: String) -> String {
        guard let timeInterval = Double(timestamp) else { return "now" }
        let date = Date(timeIntervalSince1970: timeInterval)
        let hours = Date().timeIntervalSince(date)
        
        if hours < 3600 {
            let minutes = Int(hours / 60)
            return "\(minutes)m"
        } else if hours < 86400 {
            let hoursInt = Int(hours / 3600)
            return "\(hoursInt)h"
        } else {
            let days = Int(hours / 86400)
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

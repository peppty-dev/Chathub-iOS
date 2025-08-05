import SwiftUI
import FirebaseFirestore





// Android-matching OnlineUserRow with 100% parity - AppTheme Compliant
struct OnlineUserRow: View {
    let user: OnlineUser
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile picture section - matching Android 65dp size
            ZStack(alignment: .bottomTrailing) {
                // Main profile image with border
                ZStack {
                    if let url = URL(string: user.profileImage), !user.profileImage.isEmpty {
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
                                Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 65, height: 65)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.shade2, lineWidth: 2)
                                    )
                            @unknown default:
                                Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
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
                        Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.shade2, lineWidth: 2)
                            )
                    }
                    
                    // Last seen time overlay (centered on bottom of profile)
                    if !isUserOnlineNow && !timeAgoText.isEmpty {
                        Text(timeAgoText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AppTheme.shade8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.shade200)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.shade2, lineWidth: 2)
                                    )
                            )
                            .offset(y: 25) // Position at bottom center
                    }
                }
                
                // Online status indicator (green dot) - positioned more inside the profile circle
                if isUserOnlineNow {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.shade2, lineWidth: 2)
                        )
                        .offset(x: -5, y: -2)
                }
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - username and gender info
            VStack(alignment: .leading, spacing: 5) {
                // Username - matching Android 16sp with theme colors
                Text(user.name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.darkText)
                    .lineLimit(1)
                    .padding(.top, 18)
                
                // Gender section - matching Android LinearLayout with icon + text
                HStack(spacing: 5) {
                    // Gender icon - sized to match text height
                    Image(user.gender.lowercased() == "male" ? "male_symbol" : "female_symbol")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .padding(.top, 1)
                    
                    // Gender text - increased size with title case and Android color matching
                    Text(user.gender.capitalized)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(user.gender.lowercased() == "male" ? AppTheme.darkBlue : AppTheme.warningOrange)
                }
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
            
            // Country flag - 34dp circular, positioned on far right
            if !user.country.isEmpty {
                if let flagAsset = CountryLanguageHelper.getFlagAssetName(for: user.country) {
                    Image(flagAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(AppTheme.shade200)
                                .frame(width: 34, height: 34)
                        )
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "Flag asset for \(user.country): \(flagAsset)")
                        }
                } else {
                    // Default flag placeholder with theme colors
                    Circle()
                        .fill(AppTheme.shade200)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image("ic_flag")
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
        .background(AppTheme.background)
        .contentShape(Rectangle())
    }
    
    // Helper computed properties
    private var isUserOnlineNow: Bool {
        return timeAgoText == "now" || timeAgoText.hasSuffix("s")
    }
    
    private var timeAgoText: String {
        if user.lastTimeSeen.timeIntervalSinceNow > -60 {
            return "now"
        }
        return getTimeAgo(from: user.lastTimeSeen)
    }
    
    // Helper function to get flag image name
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
    
    // Helper function to format time ago (matching Android TimeFormatter)
    private func getTimeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}



// Replace FilterView placeholder with a real SwiftUI filter modal
struct FilterView: View {
    @Binding var isPresented: Bool
    @State private var male: Bool = false
    @State private var female: Bool = false
    @State private var country: String = ""
    @State private var language: String = ""
    @State private var minAge: String = ""
    @State private var maxAge: String = ""
    @State private var nearby: Bool = false
    @State private var countries: [String] = []
    @State private var languages: [String] = []
    var onApply: ((Bool, Bool, String, String, String, String, String) -> Void)? = nil
    var onClear: (() -> Void)? = nil
    var initialFilter: OnlineUserFilter?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gender")) {
                    HStack {
                        Button(action: { male.toggle() }) {
                            HStack {
                                Image(systemName: male ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.blue)
                                Text("Male")
                            }
                        }
                        Spacer()
                        Button(action: { female.toggle() }) {
                            HStack {
                                Image(systemName: female ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.pink)
                                Text("Female")
                            }
                        }
                    }
                }
                Section(header: Text("Country")) {
                    Picker("Country", selection: $country) {
                        ForEach(countries, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                }
                Section(header: Text("Language")) {
                    Picker("Language", selection: $language) {
                        ForEach(languages, id: \.self) { l in
                            Text(l).tag(l)
                        }
                    }
                }
                Section(header: Text("Age Range")) {
                    HStack {
                        TextField("Min", text: $minAge)
                            .keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", text: $maxAge)
                            .keyboardType(.numberPad)
                    }
                }
                Section {
                    Toggle("Nearby", isOn: $nearby)
                }
                Section {
                    Button("Apply") {
                        onApply?(male, female, country, minAge, maxAge, language, nearby ? "yes" : "")
                        isPresented = false
                    }
                    Button("Clear") {
                        male = false
                        female = false
                        country = ""
                        language = ""
                        minAge = ""
                        maxAge = ""
                        nearby = false
                        onClear?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .onAppear {
                // Populate countries and languages
                countries = getAllCountries()
                languages = getAllLanguages()
                if let initialFilter = initialFilter {
                    male = initialFilter.male
                    female = initialFilter.female
                    country = initialFilter.country
                    language = initialFilter.language
                    minAge = initialFilter.minAge
                    maxAge = initialFilter.maxAge
                    nearby = !initialFilter.nearby.isEmpty
                }
            }
        }
    }
}

// Helper functions for country/language lists - using shared Android-matching implementation
func getAllCountries() -> [String] {
    return CountryLanguageHelper.shared.getAllCountries()
}

func getAllLanguages() -> [String] {
    return CountryLanguageHelper.shared.getAllLanguages()
}





// User detail view migrated to SwiftUI
struct OnlineUserDetailView: View, Hashable {
    let user: OnlineUser
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let url = URL(string: user.profileImage), !user.profileImage.isEmpty {
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
                                .onAppear {
                                    AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "detail profile image loaded")
                                }
                        case .failure(let error):
                            // Gender-based gradient placeholder while image loads - matching Android design
                            Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 65, height: 65)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.shade2, lineWidth: 2)
                                )
                                .onAppear {
                                    AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "detail profile image failed: \(error.localizedDescription)")
                                }
                        @unknown default:
                            Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
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
                    Image(user.gender.lowercased() == "male" ? "male_icon" : "Female_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
                Text(user.name)
                    .font(.system(size: 28, weight: .bold))
                HStack(spacing: 16) {
                    if !user.country.isEmpty {
                        Label(user.country, systemImage: "globe")
                    }
                    if !user.age.isEmpty {
                        Label("Age: \(user.age)", systemImage: "person")
                    }
                    if !user.gender.isEmpty {
                        Label(user.gender, systemImage: "figure.stand")
                    }
                }
                .font(.headline)
                .foregroundColor(.secondary)
                if !user.language.isEmpty {
                    Label(user.language, systemImage: "character.book.closed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                // Add more details/actions as needed
                Spacer()
            }
            .padding()
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    static func == (lhs: OnlineUserDetailView, rhs: OnlineUserDetailView) -> Bool {
        lhs.user.id == rhs.user.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(user.id)
    }
}

struct OnlineUsersView: View {
    @StateObject private var viewModel = OnlineUsersViewModel()
    @State private var showApps = false
    @State private var navigateToFilters = false
    @State private var showRefreshLimitPopup: Bool = false
    @State private var refreshLimitResult: FeatureLimitResult?
    @State private var showSubscriptionView: Bool = false
    
    // Android parity: Add subscription manager instance
    private let subscriptionManager = SubscriptionSessionManager.shared
    
    // Android parity: Check all subscription types like Android does
    private var isAnySubscriptionActive: Bool {
        subscriptionManager.isUserSubscribedToLite() ||
        subscriptionManager.isUserSubscribedToPlus() ||
        subscriptionManager.isUserSubscribedToPro()
    }
    
    // Keep legacy property for backward compatibility
    private var isLiteSubscriber: Bool {
        MessagingSettingsSessionManager.shared.premiumActive
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    // Only show loading when there's no existing data - prevents flicker
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        HStack(spacing: 10) {
                            // Filter users button - matching Android new_filters_layout
                            Button(action: {
                                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "filterButtonTapped() Filter button tapped")
                                navigateToFilters = true
                            }) {
                                HStack {
                                    Text("Filter users")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color("dark"))
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color("blue_900"))
                                        .font(.system(size: 31, weight: .medium))
                                        .padding(.top, 2)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("blue_50"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color("ColorAccent").opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Refresh users button - matching Android new_refresh_layout
                            Button(action: handleRefreshButtonTapped) {
                                HStack {
                                    Text("Refresh users")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color("dark"))
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color("Red1"))
                                        .font(.system(size: 32, weight: .medium))
                                        .rotationEffect(.degrees(45))
                                        .padding(.top, 2)
                                        .padding(.trailing, 2)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("red_50"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color("red_500").opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color("background"))
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        
                        ForEach(viewModel.users.indices, id: \.self) { index in
                            let user = viewModel.users[index]
                            ZStack {
                                OnlineUserRow(user: user)
                                NavigationLink(destination: ProfileView(onlineUser: user)) {
                                    EmptyView()
                                }
                                .opacity(0.0)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                if index == viewModel.users.count - 5 {
                                    viewModel.fetchMoreUsers()
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color("background"))
            // NavigationLink for filters - opens as separate page instead of sheet
            .background(
                NavigationLink(
                    destination: FiltersView(
                        isLiteSubscriber: isLiteSubscriber,
                        onFiltersApplied: { filters in
                            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "filterApplied() - New filter applied from FiltersView")
                            
                            // CRITICAL FIX: Use the new refreshFiltersFromSessionManager method
                            // This will load filters directly from UserSessionManager where FiltersView saved them
                            viewModel.refreshFiltersFromSessionManager()
                        },
                        onFiltersCleared: {
                            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "filterCleared() - Filters cleared from FiltersView")
                            viewModel.clearFilter()
                        }
                    ),
                    isActive: $navigateToFilters
                ) {
                    EmptyView()
                }
                .hidden()
            )
            // NavigationLink for subscription view - opens as full screen intent
            .background(
                NavigationLink(
                    destination: SubscriptionView(),
                    isActive: $showSubscriptionView
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .onAppear {
                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - Online users view appeared")
                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - Current users count: \(viewModel.users.count)")
                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - isLoading: \(viewModel.isLoading)")
                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - hasMore: \(viewModel.hasMore)")
                
                // Android parity: Always call fetchUsers which will handle refresh time logic internally
                // This matches Android OnlineUserListFragment behavior exactly
                AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - Calling fetchUsers with Android parity logic")
                viewModel.fetchUsers()
            }

            .sheet(isPresented: $showApps) {
                Text("Apps Placeholder")
                    .font(.title)
            }
            .overlay(refreshLimitPopupOverlay)
        }
    }
    
    private var refreshLimitPopupOverlay: some View {
        Group {
            if showRefreshLimitPopup, let result = refreshLimitResult {
                RefreshLimitPopupView(
                    isPresented: $showRefreshLimitPopup,
                    remainingCooldown: result.remainingCooldown,
                    isLimitReached: result.isLimitReached,
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    onRefresh: {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "User chose to refresh from popup.")
                        handleRefreshAction()
                    },
                    onUpgradeToPremium: {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "User chose to upgrade from refresh popup.")
                        showSubscriptionView = true
                    }
                )
            }
        }
    }
    
    private func handleRefreshButtonTapped() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Refresh button tapped - Android parity logic")
        
        // Check refresh limits using new system
        let result = RefreshLimitManager.shared.checkRefreshLimit()
        let userType = RefreshAnalytics.shared.getUserType()
        
        // Track button tap
        RefreshAnalytics.shared.trackRefreshButtonTapped(
            userType: userType,
            currentUsage: result.currentUsage,
            limit: result.limit,
            isLimitReached: result.isLimitReached
        )
        
        if result.showPopup {
            // Always show popup for non-Lite subscribers and non-new users
            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Showing refresh popup")
            
            // Track popup shown
            RefreshAnalytics.shared.trackRefreshPopupShown(
                userType: userType,
                currentUsage: result.currentUsage,
                limit: result.limit,
                remainingCooldown: result.remainingCooldown,
                triggerReason: result.isLimitReached ? "limit_reached" : "always_show_strategy"
            )
            
            refreshLimitResult = result
            showRefreshLimitPopup = true
        } else {
            // Lite subscribers and new users bypass popup entirely
            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Lite subscriber or new user - direct refresh")
            
            // Track bypass analytics
            if userType == RefreshAnalytics.USER_TYPE_LITE_SUBSCRIBER {
                RefreshAnalytics.shared.trackLiteSubscriberBypass(
                    subscriptionTier: subscriptionManager.getSubscriptionTier()
                )
            } else if userType == RefreshAnalytics.USER_TYPE_NEW_USER {
                let firstAccountTime = UserSessionManager.shared.firstAccountCreatedTime
                let newUserPeriod = SessionManager.shared.newUserFreePeriodSeconds
                let remainingTime = TimeInterval(newUserPeriod) - (Date().timeIntervalSince1970 - firstAccountTime)
                RefreshAnalytics.shared.trackNewUserBypass(timeRemainingInFreePeriod: max(0, remainingTime))
            }
            
            RefreshLimitManager.shared.performRefresh { success in
                if success {
                    DispatchQueue.main.async {
                        viewModel.manualRefreshUsers()
                    }
                }
            }
        }
    }
    
    private func handleRefreshAction() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "handleRefreshAction() Free refresh button tapped")
        
        // Check limits again and proceed if allowed
        let result = RefreshLimitManager.shared.checkRefreshLimit()
        
        if result.canProceed {
            RefreshLimitManager.shared.performRefresh { success in
                if success {
                    DispatchQueue.main.async {
                        self.viewModel.manualRefreshUsers()
                    }
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "handleRefreshAction() Still at limit")
        }
    }
}

#Preview {
    OnlineUsersView()
} 

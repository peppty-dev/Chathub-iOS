import SwiftUI
import StoreKit  // For in-app review prompt
import UIKit
import FirebaseFirestore
import FirebaseAnalytics
import SDWebImageSwiftUI

// MARK: - Settings Tab View (SwiftUI)
// Complete Android parity implementation matching SettingsFragment.java exactly
struct SettingsTabView: View {


    // Warning state management (matching Android exactly)
    @State private var warningCount: Int = 0
    @State private var showWarnings: Bool = false
    
    // Account creation state (matching Android logic)
    @State private var isAccountCreated: Bool = false
    @State private var createAccountTitle: String = "Create Account"
    
    // Use RatingService for all rating functionality (consolidating duplicate code)
    @ObservedObject private var ratingService = RatingService.shared
    
    // Interests dialog state (matching Android popup behavior)
    @State private var showInterestsDialog = false
    
    // Fix app popup state - removed since we now use NavigationManager
    
    // Debug subscription popup state (DEBUG ONLY)
    @State private var showDebugSubscriptionPopup = false
    
    // App credentials (matching Android getCredentials())
    @State private var appName: String = "ChatHub"
    
    // Firebase database (matching Android)
    private let database = Firestore.firestore()

    private let rows: [SettingsRow] = [
        // CATEGORY 1: Navigation items (open new views)
        SettingsRow(title: "Create Account",         iconName: "Create",           isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Edit profile",           iconName: "edit",             isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Notifications",          iconName: "speakers",         isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Themes",                 iconName: "Themes",           isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Haptics",                iconName: "hand.raised", isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Unblock",                iconName: "unblock",          isDestructive: false, showsChevron: true,  category: .navigation),
        SettingsRow(title: "Welcome Screen",         iconName: "welcome",          isDestructive: false, showsChevron: true,  category: .navigation),
        
        // CATEGORY 2: Action items (perform functions/show popups)
        SettingsRow(title: "Update interests",       iconName: "filters",          isDestructive: false, showsChevron: false, category: .actions),
        SettingsRow(title: "Fix the app",            iconName: "settings",         isDestructive: false, showsChevron: false, category: .actions),
        SettingsRow(title: "Share the app",          iconName: "shares",           isDestructive: false, showsChevron: false, category: .actions),
        SettingsRow(title: "Rate the app",           iconName: "star",             isDestructive: false, showsChevron: false, category: .actions),
        SettingsRow(title: "Send feedback",          iconName: "message.badge",    isDestructive: false, showsChevron: false, category: .actions),
        SettingsRow(title: "Contact us",             iconName: "mail",             isDestructive: false, showsChevron: false, category: .actions),
        
        // CATEGORY 3: Destructive action
        SettingsRow(title: "Remove Account",         iconName: "logout",           isDestructive: true,  showsChevron: false, category: .destructive)
    ]

    // MARK: - Computed Properties
    private var settingsRowsGrouped: some View {
        VStack(spacing: 0) {
            // CATEGORY 1: Navigation items (Account & Settings)
            VStack(spacing: 0) {
                ForEach(rows.filter { $0.category == .navigation }) { row in
                    NavigationLink(destination: destinationView(for: row)) {
                        SettingsRowView(row: getUpdatedRow(row), isInsideNavigationLink: true)
                    }
                    .padding(.horizontal)
                }
            }
            
            // Section separator
            Rectangle()
                .fill(Color("shade_200"))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            // CATEGORY 2: Action items (Functions & Popups)
            VStack(spacing: 0) {
                ForEach(rows.filter { $0.category == .actions }) { row in
                    Button(action: {
                        onRowTap(row)
                    }) {
                        SettingsRowView(row: getUpdatedRow(row), isInsideNavigationLink: false)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
            }
            
            // Section separator
            Rectangle()
                .fill(Color("shade_200"))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            // CATEGORY 3: Destructive action (Remove Account)
            VStack(spacing: 0) {
                ForEach(rows.filter { $0.category == .destructive }) { row in
                    NavigationLink(destination: destinationView(for: row)) {
                        SettingsRowView(row: getUpdatedRow(row), isInsideNavigationLink: true)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Profile Header (matching Android design exactly)
                    profileHeader

                    // Warnings Section (conditionally shown like Android)
                    if showWarnings {
                        warningsSection
                    }

                    // Settings Rows - Grouped by Category
                    settingsRowsGrouped
                    
                    // Version information at bottom (matching Android)
                    versionSection
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .background(Color("Background Color").ignoresSafeArea())


        .overlay(
            Group {
                // Rating popup (only when manually triggered from Settings "Rate the app" button)
                if ratingService.showRatingDialog {
                    RatingPopupView()
                }
                
                // Interests Popup Overlay (matching Android popup behavior)
                if showInterestsDialog {
                    InterestsPopupView(isPresented: $showInterestsDialog)
                }
            }
        )
        .overlay(
            // Debug Subscription Popup Overlay (DEBUG ONLY)
            debugSubscriptionPopupOverlay
        )
        .onAppear {
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "onAppear() Settings tab loaded")
            getCredentials()
            updateWarningsSection()
            updateAccountCreationStatus()
        }
        .sheet(isPresented: $ratingService.navigateToFeedback) {
            FeedbackView()
        }
    }

    // MARK: - Profile Header (matching Android layout exactly)
    private var profileHeader: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Profile Image with standardized styling (matching other views exactly)
                ZStack {
                    // Shadow layer for depth (matching ProfileView)
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .offset(y: 2)
                        .blur(radius: 4)
                    
                    if let url = URL(string: UserSessionManager.shared.userProfilePhoto ?? ""), !url.absoluteString.isEmpty {
                        WebImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
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
                                
                                Image(UserSessionManager.shared.userGender == "Male" ? "male_icon" : "Female_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .opacity(0.8)
                            }
                            .frame(width: 160, height: 160)
                        }
                        .indicator(.activity)
                        .transition(.opacity)
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            // Gradient background for placeholder (matching ProfileView)
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
                            
                            // Default gender-based placeholder when no profile photo URL - matching OnlineUsersView pattern
                            Image(UserSessionManager.shared.userGender == "Male" ? "male_icon" : "Female_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.8)
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                    }
                    
                    // Enhanced border with gradient effect (matching ProfileView exactly)
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
                        .frame(width: 160, height: 160)
                    
                    // Inner highlight for 3D effect (matching ProfileView)
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.3),
                            lineWidth: 1
                        )
                        .frame(width: 160, height: 160)
                        .padding(1)
                }

                // Username with arrow (exactly like Android) - Perfectly centered text
                ZStack {
                    // Centered username text
                    Text(Profanity.share.removeProfanityNumbersAllowed(UserSessionManager.shared.userName ?? "User"))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    
                    // Chevron positioned on the right
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color("shade_400"))
                            .font(.system(size: 18))
                    }
                }
                .padding(.bottom, 15)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12) // Standardized padding - reduced further
            .padding(.horizontal)
            .onTapGesture {
                // Navigate to profile view (MyProfileActivity equivalent)
                AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "profileHeaderTapped() navigating to profile")
            }
        }
    }

    // MARK: - Warnings Section (conditional display like Android)
    private var warningsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Warning count badge (matching Android orange design)
                ZStack {
                    Circle()
                        .fill(Color("orange_800"))
                        .frame(width: 32, height: 32)
                    
                    Text("\(warningCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color("background"))
                }
                
                Text("Warnings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("dark"))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("orange_800"))
                    .font(.system(size: 22))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onTapGesture {
                // Navigate to WarningActivity equivalent
                AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "warningsTapped() navigating to warnings")
            }
        }
    }

    // MARK: - Debug Subscription Popup Overlay (DEBUG ONLY)
    @ViewBuilder
    private var debugSubscriptionPopupOverlay: some View {
        #if DEBUG
        if showDebugSubscriptionPopup {
            DebugSubscriptionPopupView(isPresented: $showDebugSubscriptionPopup)
        }
        #endif
    }

    // MARK: - Version Section (matching Android exactly)
    private var versionSection: some View {
        HStack {
            #if DEBUG
            Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")\nBuild: \(getBuildType())\n\(Bundle.main.bundleIdentifier ?? "")")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color("shade_500"))
                .multilineTextAlignment(.leading)
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "debugBuildTapped() DEBUG build info tapped - showing subscription debug popup")
                    showDebugSubscriptionPopup = true
                }
            #else
            Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color("shade_500"))
                .multilineTextAlignment(.leading)
            #endif
            Spacer()
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 25) // Adding Android's 25dp margin
    }
    
    // MARK: - Build Type Helper Function
    private func getBuildType() -> String {
        #if DEBUG
        return "DEBUG"
        #else
        return "RELEASE"
        #endif
    }

    // MARK: - Credentials Management (matching Android getCredentials())
    private func getCredentials() {
        // In iOS, we'll hardcode the app name since we don't have assets/credentials.json
        // This matches the Android pattern where app_name is extracted from credentials.json
        appName = "ChatHub"
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "getCredentials() app_name: \(appName)")
    }

    // MARK: - Row Management Functions
    private func getUpdatedRow(_ row: SettingsRow) -> SettingsRow {
        if row.title == "Create Account" {
            return SettingsRow(
                title: createAccountTitle,
                iconName: row.iconName,
                isDestructive: row.isDestructive,
                showsChevron: row.showsChevron,
                category: row.category
            )
        }
        return row
    }

    // MARK: - Warning Section Update (matching Android logic exactly)
    private func updateWarningsSection() {
        var war = 0
        
        // Matching Android SessionManager warning method names exactly
        if SessionManager.shared.getTimeMismatchedShowWarning() { war += 1 }
        if SessionManager.shared.getAdPolicyViolatedShowWarning() { war += 1 }
        if SessionManager.shared.getCanReportShowWarning() { war += 1 }
        if SessionManager.shared.getMultipleReportsShowWarning() { war += 1 }
        if SessionManager.shared.getTextModerationIssueShowWarning() { war += 1 }
        if SessionManager.shared.getImageModerationIssueShowWarning() { war += 1 }
        
        warningCount = war
        showWarnings = war > 0
        
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "updateWarningsSection() warning count: \(war)")
    }

    private func updateAccountCreationStatus() {
        isAccountCreated = UserSessionManager.shared.isAccountCreated
        createAccountTitle = isAccountCreated ? "Account Settings" : "Create Account"
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "updateAccountCreationStatus() isAccountCreated: \(isAccountCreated)")
    }

    // MARK: - Row Tap Handler (matching Android functionality exactly)
    private func onRowTap(_ row: SettingsRow) {
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "onRowTap() tapped: \(row.title)")

        switch row.title {
        case "Update interests":
            showInterestsDialog = true
            UserSessionManager.shared.interestTime = Date().timeIntervalSince1970
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "updateInterestsTapped() showing interests dialog")
        case "Share the app":
            shareApp()
        case "Rate the app":
            ratingService.showRatingDialog = true
        case "Send feedback":
            ratingService.ratingMessage = "We'd love to hear from you! Please share your thoughts, suggestions, or report any issues."
            ratingService.navigateToFeedback = true
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "sendFeedbackTapped() navigating to feedback view")
        case "Fix the app":
            NavigationManager.shared.showFixAppPopup {
                // Optional: Add any post-fix actions here
                AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "fixAppCompleted() fix process completed")
            }
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "fixAppTapped() showing fix app popup")
        case "Contact us":
            showContactUsAlert()
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "contactUsTapped() showing support email alert")
        case "Remove Account":
            // This will be handled by NavigationLink in the body - no action needed here
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "removeAccountTapped() - navigating to RemoveAccountView")
        default:
            break
        }
    }

    // MARK: - Action Functions (matching Android implementation exactly)
    private func shareApp() {
        let appLink = "https://apps.apple.com/us/app/chathub-stranger-chat-app/id1539272301"
        guard let topController = topViewController() else { return }
        let ac = UIActivityViewController(activityItems: [appLink], applicationActivities: nil)
        topController.present(ac, animated: true)
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "shareApp() sharing app link")
    }

    // Rating functionality now handled by RatingService - removed duplicate code

    private func showContactUsAlert() {
        AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "showContactUsAlert() showing support email alert")
        
        let alert = UIAlertController(
            title: "Contact Us",
            message: "In case of any support or help please write us a detailed email regarding the subject.\n\nchatstrangersapps@gmail.com",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Copy Email", style: .default) { _ in
            UIPasteboard.general.string = "chatstrangersapps@gmail.com"
            AppLogger.log(tag: "LOG-APP: SettingsTabView", message: "showContactUsAlert() email copied to clipboard")
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        guard let topController = topViewController() else { return }
        topController.present(alert, animated: true)
    }

    // MARK: - Helper Functions
    private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        } else if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        } else if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    // MARK: - Destination View Builder
    @ViewBuilder
    private func destinationView(for row: SettingsRow) -> some View {
        switch row.title {
        case "Create Account":
            if isAccountCreated {
                AccountSettingsView()
            } else {
                CreateAccountView()
            }
        case "Edit profile":
            EditProfileView()
        case "Notifications":
            NotificationSettingsView()
        case "Themes":
            SetThemesView()
        case "Haptics":
            HapticsSettingsView()
        case "Unblock":
            BlockedUsersView()
        case "Welcome Screen":
            WelcomeView()
        case "Remove Account":
            RemoveAccountView()
        default:
            Text("Coming Soon")
                .navigationTitle(row.title)
        }
    }
}

// MARK: - Row View (matching Android styling)
struct SettingsRowView: View {
    let row: SettingsRow
    let isInsideNavigationLink: Bool
    
    var body: some View {
        HStack(spacing: 16) { // Reduced spacing from 20 to 16
            // Icon with circular background (matching Android exactly) - Made smaller
            ZStack {
                Circle()
                    .fill(row.isDestructive ? Color("Red1") : Color("shade_800"))
                    .frame(width: 36, height: 36) // Reduced from 40x40 to 36x36
                
                // Handle SF Symbols vs Asset icons
                if row.iconName.contains(".") || isKnownSFSymbol(row.iconName) {
                    // SF Symbol (contains dots like "hand.raised" or known SF symbols)
                    Image(systemName: row.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color("bright"))
                        .frame(width: 20, height: 20) // Reduced from 24x24 to 20x20
                } else {
                    // Asset icon
                    Image(row.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color("bright"))
                        .frame(width: 20, height: 20) // Reduced from 24x24 to 20x20
                }
            }
            
            Text(row.title)
                .font(.system(size: 16, weight: row.isDestructive ? .bold : .medium)) // Reduced from 17 to 16
                .foregroundColor(row.isDestructive ? Color("Red1") : Color("dark"))
            
            Spacer()
            
            // Show chevron for navigation items (items that open new views)
            if shouldShowChevron(for: row, isInsideNavigationLink: isInsideNavigationLink) {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("shade_400"))
                    .font(.system(size: 14, weight: .medium)) // Reduced from 16 to 14
            }
        }
        .padding(.vertical, 16) // Reduced vertical padding from 18 to 16
        .padding(.horizontal, 2) // Reduced horizontal padding from 4 to 2
        .contentShape(Rectangle())
    }
    
    // Helper function to determine if chevron should be shown
    private func shouldShowChevron(for row: SettingsRow, isInsideNavigationLink: Bool) -> Bool {
        // Show chevron for navigation items only (items that open new views)
        return row.category == SettingsCategory.navigation || row.category == SettingsCategory.destructive
    }
    
    // Helper function to identify known SF Symbols that don't contain dots
    private func isKnownSFSymbol(_ iconName: String) -> Bool {
        let knownSFSymbols = ["waveform", "hand", "heart", "star", "person", "house", "gear", "plus", "minus", "multiply", "divide", "equal"]
        return knownSFSymbols.contains(iconName)
    }
}

// Rating functionality now handled by RatingService and RatingPopupView
// Removed duplicate popup views - using centralized system
#Preview {
    SettingsTabView()
} 
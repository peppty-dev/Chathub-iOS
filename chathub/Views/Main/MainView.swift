import SwiftUI
import Foundation
import Combine

struct MainView: View {
    @State private var selectedTab = 0
    @State private var showSubscriptionView = false
    @StateObject private var badgeManager = InAppNotificationBadgeManager.shared
    @State private var isSearchFocused = false
    
    // Add state for refresh popup at MainView level

    
    let tabTitles = ["People", "Chats", "Discover", "Games", "Settings"]
    let tabIcons = ["ic_people", "ic_chat", "ic_search", "ic_games", "ic_settings"]
    
    private func tabIcon(named name: String, size: CGFloat = 28) -> Image {
        guard let uiImage = UIImage(named: name) else {
            return Image(systemName: "questionmark.circle")
        }

        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let resizedUIImage = renderer.image { _ in
            let aspectRatio = uiImage.size.width / uiImage.size.height
            var newSize: CGSize
            if aspectRatio > 1 {
                newSize = CGSize(width: size, height: size / aspectRatio)
            } else {
                newSize = CGSize(width: size * aspectRatio, height: size)
            }

            let origin = CGPoint(x: (size - newSize.width) / 2, y: (size - newSize.height) / 2)
            uiImage.draw(in: CGRect(origin: origin, size: newSize))
        }
        
        return Image(uiImage: resizedUIImage.withRenderingMode(.alwaysTemplate))
    }
    
    // MARK: - Setup Methods
    
    private func setupMainView() {
        AppLogger.log(tag: "LOG-APP: MainView", message: "setupMainView() Setting up main view")
        // Advertising functionality removed
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Main content with custom tab implementation
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    // Content area
                    ZStack {
                        Group {
                            if selectedTab == 0 {
                                OnlineUsersView()
                            } else if selectedTab == 1 {
                                ChatsTabView()
                            } else if selectedTab == 2 {
                                DiscoverTabView(onSearchFocusChanged: { focused in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSearchFocused = focused
                                    }
                                })
                            } else if selectedTab == 3 {
                                GamesTabView()
                            } else if selectedTab == 4 {
                                SettingsTabView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60) // Height of header
                    
                    // Custom Tab Bar - hide when search is focused
                    if !isSearchFocused {
                        CustomTabBar(
                            selectedTab: $selectedTab,
                            tabTitles: tabTitles,
                            tabIcons: tabIcons,
                            chatsBadgeCount: badgeManager.chatsBadgeCount,
                            discoverBadgeCount: badgeManager.discoverBadgeCount
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onReceive(badgeManager.$chatsBadgeCount) { count in
                            AppLogger.log(tag: "LOG-APP: MainView", message: "chatsBadgeCount updated: \(count)")
                        }
                        .onReceive(badgeManager.$discoverBadgeCount) { count in
                            AppLogger.log(tag: "LOG-APP: MainView", message: "discoverBadgeCount updated: \(count)")
                        }
                    }
                }
                
                // Fixed header and banner
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // App name - clean and prominent like major messaging apps
                        Text("ChatHub")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .kerning(0) // Increased letter spacing for elegant look
                            .fixedSize(horizontal: false, vertical: true) // Prevent text truncation
                        
                        Spacer()
                        
                        SubscriptionStatusButton(showSubscriptionView: $showSubscriptionView)
                    }
                    .padding(.horizontal, 16) // Match OnlineUsersView spacing exactly
                    .frame(height: 60)
                    .frame(maxWidth: .infinity) // Ensure full width alignment
                    .multilineTextAlignment(.leading) // Ensure consistent text alignment
                    .background(
                        // Subtle gradient background like premium messaging apps
                        LinearGradient(
                            colors: [Color("background"), Color("background").opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                

            }
            .onChange(of: selectedTab) { newValue in
                AppLogger.log(tag: "LOG-APP: MainView", message: "tabChanged(to: \(tabTitles[newValue]))")
                
                // Handle tab selection - Android parity for badge clearing
                if newValue == 2 { // Discover tab
                    // Clear discover badge when discover tab is selected
                    badgeManager.clearDiscoverBadge()
                }
            }
            .onAppear {
                setupMainView()
                
                // Start badge monitoring when MainView appears
                badgeManager.startBadgeMonitoring()
                
                // Start notifications sync service (Firebase → Local Database)
                InAppNotificationsSyncService.shared.startNotificationsListener()
            }
            .onDisappear {
                // Stop badge monitoring when MainView disappears
                badgeManager.stopBadgeMonitoring()
                
                // Stop notifications sync service
                InAppNotificationsSyncService.shared.stopNotificationsListener()
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: SubscriptionView(),
                    isActive: $showSubscriptionView
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Custom Tab Bar Implementation
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let tabTitles: [String]
    let tabIcons: [String]
    let chatsBadgeCount: Int
    let discoverBadgeCount: Int
    @State private var isTabBarHidden = false
    
    private func tabIcon(named name: String, size: CGFloat = 28) -> Image {
        guard let uiImage = UIImage(named: name) else {
            return Image(systemName: "questionmark.circle")
        }

        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let resizedUIImage = renderer.image { _ in
            let aspectRatio = uiImage.size.width / uiImage.size.height
            var newSize: CGSize
            if aspectRatio > 1 {
                newSize = CGSize(width: size, height: size / aspectRatio)
            } else {
                newSize = CGSize(width: size * aspectRatio, height: size)
            }

            let origin = CGPoint(x: (size - newSize.width) / 2, y: (size - newSize.height) / 2)
            uiImage.draw(in: CGRect(origin: origin, size: newSize))
        }
        
        return Image(uiImage: resizedUIImage.withRenderingMode(.alwaysTemplate))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top separator line (matching native iOS tab bar)
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.33)
            
            HStack(spacing: 0) {
                ForEach(0..<tabTitles.count, id: \.self) { index in
                    Button(action: {
                        // Haptic feedback like native tab bar
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        selectedTab = index
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                // Tab icon
                                tabIcon(named: tabIcons[index], size: 28)
                                    .foregroundColor(selectedTab == index ? 
                                        Color.primary : Color.secondary)
                                    .font(.system(size: 28))
                                
                                // Badge overlay
                                if index == 1 && chatsBadgeCount > 0 {
                                    // Chats badge
                                    BadgeView(count: chatsBadgeCount)
                                        .offset(x: 12, y: -12)
                                } else if index == 2 && discoverBadgeCount > 0 {
                                    // Discover badge
                                    BadgeView(count: discoverBadgeCount)
                                        .offset(x: 12, y: -12)
                                }
                            }
                            
                            // Tab title
                            Text(tabTitles[index])
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedTab == index ? 
                                    Color.primary : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 83) // Standard iOS tab bar height
            .background(
                // iOS tab bar background with blur effect
                .ultraThinMaterial,
                ignoresSafeAreaEdges: .bottom
            )
            .offset(y: isTabBarHidden ? 83 : 0) // Hide tab bar by moving it down
            .animation(.easeInOut(duration: 0.3), value: isTabBarHidden)
            .onReceive(NotificationCenter.default.publisher(for: .hideTabBar)) { _ in
                isTabBarHidden = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showTabBar)) { _ in
                isTabBarHidden = false
            }
        }
    }
}

// Placeholder views for each tab
// REMOVED: Duplicate placeholder views - using actual implementations from separate files

#Preview {
    MainView()
        .preferredColorScheme(.dark)
}

// MARK: - Notification Extension for Communication
extension Notification.Name {
    static let hideTabBar = Notification.Name("hideTabBar")
    static let showTabBar = Notification.Name("showTabBar")
}

// Ad callback classes removed - advertising functionality removed



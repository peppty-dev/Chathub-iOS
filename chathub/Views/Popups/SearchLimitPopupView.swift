import SwiftUI

struct SearchLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onSearch: () -> Void
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var backgroundTimer: Timer?
    @State private var remainingTime: TimeInterval
    @State private var popupStartTime: Date = Date()
    private let totalCooldownDuration: TimeInterval
    
    // Pricing information for Lite subscription
    private func getLiteSubscriptionPrice() -> String? {
        let subscriptionsManager = SubscriptionsManagerStoreKit2.shared
        let productId = "com.peppty.ChatApp.lite.weekly" // Use weekly for pricing display
        
        if let cachedPrice = subscriptionsManager.getCachedFormattedPrice(productId: productId, period: "weekly") {
            return cachedPrice
        }
        
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "getLiteSubscriptionPrice() No cached price available for Lite subscription")
        return nil
    }
    
    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onSearch: @escaping () -> Void,
         onUpgradeToPremium: @escaping () -> Void) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onSearch = onSearch
        self.onUpgradeToPremium = onUpgradeToPremium
        self._remainingTime = State(initialValue: remainingCooldown)
        
        // Set total cooldown duration from SessionManager
        self.totalCooldownDuration = TimeInterval(SessionManager.shared.freeSearchCooldownSeconds)
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    
                    // Track popup dismissal via background tap
                    let timeSpent = Date().timeIntervalSince(popupStartTime)
                    SearchAnalytics.shared.trackSearchPopupDismissed(
                        dismissMethod: "background_tap",
                        timeSpentInPopup: timeSpent,
                        userAction: "dismiss"
                    )
                    
                    dismissPopup()
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Static title and description - refined hierarchy
                    VStack(spacing: 12) {
                        Text("Search Users")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        Text(getDescriptionText())
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade_800"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Progress bar and time remaining when in cooldown
                    if isLimitReached && remainingTime > 0 {
                        VStack(spacing: 12) {
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background bar
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    
                                    // Progress bar - shrinks from right to left as time runs out
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(remainingTime / totalCooldownDuration), height: 4)
                                        .cornerRadius(2)
                                        .animation(.linear(duration: 0.1), value: remainingTime)
                                }
                            }
                            .frame(height: 4)
                            
                            // Time remaining text
                            Text("Time remaining: \(formatTime(remainingTime))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("shade_800"))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)  // Consistent 24pt spacing with other sections
                    }
                    
                    // Buttons with consistent 24pt spacing
                    VStack(spacing: 12) {
                        // Search Button - only show when not in cooldown
                        if !(isLimitReached && remainingTime > 0) {
                            Button(action: searchAction) {
                            HStack(spacing: 0) {
                                // Left side - icon and text (always consistent)
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title3)
                                    Text("Search Users")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Right side - timer when in cooldown, search count when available
                                if isLimitReached && remainingTime > 0 {
                                    // Show timer during cooldown with pill background
                                    Text(formatTime(remainingTime))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.25))
                                        )
                                        .padding(.trailing, 8)
                                } else {
                                    // Show remaining searches when not in cooldown or when timer expired
                                    if SessionManager.shared.showRemainingChancesLabel {
                                        let remaining = max(0, limit - currentUsage)
                                        if remaining > 0 || remainingTime <= 0 {
                                            Text("\(remaining > 0 ? remaining : limit) left")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.white.opacity(0.25))
                                                )
                                                .padding(.trailing, 8)
                                        } else {
                                            // Invisible text to maintain button height consistency
                                            Text("00:00")
                                                .font(.system(size: 12, weight: .bold))
                                                .opacity(0)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .padding(.trailing, 8)
                                        }
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .padding(.horizontal, 12)
                            .background(
                                // Simple green gradient background (consistent with refresh/filter)
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.08, green: 0.55, blue: 0.22),  // Dark forest green
                                        Color("SuccessGreen")  // Slightly lighter green for contrast
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        }
                        
                        // Lite Subscription Button with matching gradient
                        Button(action: upgradeToPremiumAction) {
                            HStack(spacing: 0) {
                                // Left side - icon and text (always consistent)
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title3)
                                    Text("Subscribe to Lite")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Right side - pricing when available, invisible placeholder when not
                                if let price = getLiteSubscriptionPrice() {
                                    Text(price + "/week")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.25))
                                        )
                                        .padding(.trailing, 8)
                                } else {
                                    // Invisible text to maintain consistent button height
                                    Text("$0.00/week")
                                        .font(.system(size: 12, weight: .medium))
                                        .opacity(0)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .padding(.trailing, 8)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .padding(.horizontal, 12)
                            .background(
                                // Lite subscription gradient
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color("liteGradientStart"),
                                        Color("liteGradientEnd")
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .onAppear {
            popupStartTime = Date()
            
            // Start cooldown timestamp when popup opens (if limit reached and not already in cooldown)
            SearchLimitManager.shared.startCooldownOnPopupOpen()
            
            // Recalculate remaining time after potentially starting cooldown
            remainingTime = SearchLimitManager.shared.getRemainingCooldown()
            
            startCountdownTimer()
            
            // Listen for background cooldown expiration
            NotificationCenter.default.addObserver(
                forName: BackgroundTimerManager.searchCooldownExpiredNotification,
                object: nil,
                queue: .main
            ) { _ in
                AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Background cooldown expired - transitioning popup to available state")
                remainingTime = 0
                stopCountdownTimer()
                // Don't dismiss popup - let it transition to available state
            }
            
            // Track pricing display if available
            if let price = getLiteSubscriptionPrice() {
                SearchAnalytics.shared.trackPricingDisplayed(price: price, currency: "USD")
            }
            
            AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
            
            // Track analytics for popup dismissal
            let timeSpent = Date().timeIntervalSince(popupStartTime)
            SearchAnalytics.shared.trackSearchPopupDismissed(
                dismissMethod: "system_dismiss",
                timeSpentInPopup: timeSpent,
                userAction: "unknown"
            )
            
            AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "onDisappear() Popup dismissed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDescriptionText() -> String {
        let showRemaining = SessionManager.shared.showRemainingChancesLabel
        if isLimitReached && remainingTime > 0 {
            // During cooldown - show limit reached message
            if showRemaining {
                return "You've used your \(limit) free searches. Subscribe to ChatHub Lite for unlimited access or wait for the timer to reset."
            } else {
                return "You've reached your free search limit. Subscribe to ChatHub Lite for unlimited access or wait for the timer to reset."
            }
        } else {
            // Normal state - always show generic description (no counts)
            return "Find specific people! Upgrade to ChatHub Lite subscription to unlock unlimited searches."
        }
    }
    
    private func searchAction() {
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "searchAction() Search tapped")
        
        // Track analytics for search button tap
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        SearchAnalytics.shared.trackSearchPopupDismissed(
            dismissMethod: "search_button",
            timeSpentInPopup: timeSpent,
            userAction: "search"
        )
        
        dismissPopup()
        onSearch()
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "upgradeToPremiumAction() Lite subscription tapped")
        
        // Track subscription button tap with pricing
        let pricing = getLiteSubscriptionPrice() ?? "unknown"
        SearchAnalytics.shared.trackSearchSubscriptionButtonTapped(
            currentUsage: currentUsage,
            limit: limit,
            pricingDisplayed: pricing
        )
        
        // Track popup dismissal via subscription button
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        SearchAnalytics.shared.trackSearchPopupDismissed(
            dismissMethod: "subscription_button",
            timeSpentInPopup: timeSpent,
            userAction: "subscribe"
        )
        
        dismissPopup()
        onUpgradeToPremium()
    }
    
    private func dismissPopup() {
        stopCountdownTimer()
        isPresented = false
    }
    
    private func startCountdownTimer() {
        guard isLimitReached && remainingTime > 0 else { return }
        
        // Stop any existing timers
        stopCountdownTimer()
        
        // UI Timer: Update every 0.1 seconds for smooth animation
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if remainingTime > 0.1 {
                remainingTime -= 0.1
            } else {
                remainingTime = 0
                stopCountdownTimer()
                
                // Reset the usage count when cooldown expires
                SearchLimitManager.shared.resetCooldown()
                SearchAnalytics.shared.trackSearchCooldownCompleted(totalCooldownDuration: totalCooldownDuration)
                
                // Don't dismiss popup - let it transition to available state
                // The UI will automatically show the search button and hide progress bar
                // based on remainingTime = 0 condition
                AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Timer expired - transitioning popup to available state")
            }
        }
        
        // Background Timer: Safety net that ensures completion even if UI timer fails
        // Check every 1 second for maximum responsiveness and precision
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Recalculate remaining time from actual manager
            let actualRemaining = SearchLimitManager.shared.getRemainingCooldown()
            
            // Fix: Use tolerance of 1 second to handle timing precision issues (consistent with BackgroundTimerManager)
            if actualRemaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Background timer detected cooldown expiration - transitioning to available state (remaining: \(actualRemaining)s)")
                
                // Ensure cooldown is reset
                SearchLimitManager.shared.resetCooldown()
                SearchAnalytics.shared.trackSearchCooldownCompleted(totalCooldownDuration: totalCooldownDuration)
                
                DispatchQueue.main.async {
                    remainingTime = 0
                    stopCountdownTimer()
                    // Don't dismiss popup - let it transition to available state
                }
            } else {
                // Sync UI timer with actual remaining time if they diverge significantly
                let timeDifference = abs(remainingTime - actualRemaining)
                if timeDifference > 2.0 { // If UI and actual time differ by more than 2 seconds
                    AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Background timer syncing UI time - UI: \(remainingTime)s, Actual: \(actualRemaining)s")
                    DispatchQueue.main.async {
                        remainingTime = actualRemaining
                    }
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Started dual timers - UI: 0.1s interval, Background: 5s interval")
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "Stopped all timers")
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview
struct SearchLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        SearchLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 90,
            isLimitReached: true,
            currentUsage: 15,
            limit: 15,
            onSearch: { print("Search") },
            onUpgradeToPremium: { print("Upgrade to premium") }
        )
    }
}
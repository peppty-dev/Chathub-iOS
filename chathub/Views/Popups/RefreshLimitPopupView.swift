import SwiftUI

struct RefreshLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onRefresh: () -> Void
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
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
        
        AppLogger.log(tag: "LOG-APP: RefreshLimitPopupView", message: "getLiteSubscriptionPrice() No cached price available for Lite subscription")
        return nil
    }
    
    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onRefresh: @escaping () -> Void,
         onUpgradeToPremium: @escaping () -> Void) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onRefresh = onRefresh
        self.onUpgradeToPremium = onUpgradeToPremium
        self._remainingTime = State(initialValue: remainingCooldown)
        
        // Set total cooldown duration from SessionManager
        self.totalCooldownDuration = SessionManager.shared.freeRefreshCooldownSeconds
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: RefreshLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    
                    // Track popup dismissal via background tap
                    let timeSpent = Date().timeIntervalSince(popupStartTime)
                    RefreshAnalytics.shared.trackRefreshPopupDismissed(
                        userType: RefreshAnalytics.shared.getUserType(),
                        dismissMethod: "background_tap",
                        timeSpentInPopup: timeSpent
                    )
                    
                    dismissPopup()
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Static title and description - refined hierarchy
                    VStack(spacing: 12) {
                        Text("Refresh Users")
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
                                    
                                    // Progress bar - decreases from right to left as time runs out
                                    Rectangle()
                                        .fill(Color("blue"))
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
                        .padding(.top, 24)
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        // Refresh Button - only show when not in cooldown
                        if !(isLimitReached && remainingTime > 0) {
                            Button(action: refreshAction) {
                            HStack(spacing: 0) {
                                // Left side - icon and text (always consistent)
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Refresh Users")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Right side - timer when in cooldown, refresh count when available
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
                                    // Show remaining refreshes when not in cooldown or when timer expired
                                    // This handles both cases: !isLimitReached and (isLimitReached && remainingTime <= 0)
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
                                        // Invisible text to maintain button height consistency (rare edge case)
                                        Text("00:00")
                                            .font(.system(size: 12, weight: .bold))
                                            .opacity(0)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .padding(.horizontal, 12)
                            .background(
                                // Simple green gradient background
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
                                
                                // Right side - pricing when available with pill background, invisible text when not
                                if let price = getLiteSubscriptionPrice() {
                                    Text("\(price)/week")
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
                                LinearGradient(
                                    colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
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
            startCountdownTimer()
            
            // Track pricing display if available
            if let price = getLiteSubscriptionPrice() {
                RefreshAnalytics.shared.trackPricingDisplayed(price: price, currency: "USD")
            }
            
            AppLogger.log(tag: "LOG-APP: RefreshLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
        }
    }
    
    private func refreshAction() {
        AppLogger.log(tag: "LOG-APP: RefreshLimitPopupView", message: "refreshAction() Refresh tapped")
        
        // Track popup dismissal via refresh action
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        RefreshAnalytics.shared.trackRefreshPopupDismissed(
            userType: RefreshAnalytics.shared.getUserType(),
            dismissMethod: "refresh_action",
            timeSpentInPopup: timeSpent
        )
        
        dismissPopup()
        onRefresh()
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: RefreshLimitPopupView", message: "upgradeToPremiumAction() Premium upgrade tapped")
        
        // Track subscription button tap
        RefreshAnalytics.shared.trackSubscriptionButtonTapped(
            currentUsage: currentUsage,
            limit: limit,
            remainingCooldown: remainingTime,
            priceDisplayed: getLiteSubscriptionPrice()
        )
        
        // Track popup dismissal via subscription action
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        RefreshAnalytics.shared.trackRefreshPopupDismissed(
            userType: RefreshAnalytics.shared.getUserType(),
            dismissMethod: "subscription_action",
            timeSpentInPopup: timeSpent
        )
        
        dismissPopup()
        onUpgradeToPremium()
    }
    
    private func dismissPopup() {
        stopCountdownTimer()
        isPresented = false
    }
    
    private func startCountdownTimer() {
        guard isLimitReached && remainingCooldown > 0 else { return }
        
        // Update every 0.1 seconds for smooth, fluid animation like butterscotch
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if remainingTime > 0.1 {
                remainingTime -= 0.1
            } else {
                remainingTime = 0
                stopCountdownTimer()
                // Don't auto-dismiss popup - let user manually click refresh when ready
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func getDescriptionText() -> String {
        if isLimitReached && remainingTime > 0 {
            // During cooldown - show specific limit reached message
            return "You've used your \(limit) free refreshes. Subscribe to ChatHub Lite for unlimited access or wait for the timer to reset."
        } else {
            // Normal state - show general description
            return "Refresh the user list to see new online users. Upgrade to ChatHub Lite subscription to unlock unlimited refreshes."
        }
    }
}

// MARK: - Preview
struct RefreshLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        RefreshLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 120,
            isLimitReached: true,
            currentUsage: 10,
            limit: 10,
            onRefresh: { print("Refresh") },
            onUpgradeToPremium: { print("Upgrade to premium") }
        )
    }
}
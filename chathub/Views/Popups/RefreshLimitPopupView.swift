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
            Color.black.opacity(0.4)
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
                        
                        Text("Refresh the user list to see new online users and get fresh connection opportunities.")
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade_800"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        // Refresh Button - changes based on limit status
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
                                
                                // Right side - timer when in cooldown, invisible text when not
                                if isLimitReached && remainingTime > 0 {
                                    Text(formatTime(remainingTime))
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.trailing, 8)
                                } else {
                                    // Invisible text to maintain button height consistency
                                    Text("00:00")
                                        .font(.system(size: 14, weight: .bold))
                                        .opacity(0)
                                        .padding(.trailing, 8)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .padding(.horizontal, 12)
                            .background(
                                ZStack {
                                    // Base background - prominent green gradient revealed as countdown overlay shrinks
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green.opacity(0.9), Color.green.opacity(0.6)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    
                                    // Countdown overlay when in cooldown - shrinks from left to right revealing green gradient
                                    if isLimitReached && remainingTime > 0 {
                                        GeometryReader { geometry in
                                            // Gray overlay anchored to left side that shrinks leftward as time decreases
                                            HStack(spacing: 0) {
                                                // Gray overlay with wave edge effect
                                                WaveProgressView(
                                                    progress: CGFloat(remainingTime / totalCooldownDuration),
                                                    totalWidth: geometry.size.width,
                                                    height: geometry.size.height
                                                )
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isLimitReached && remainingTime > 0)
                        
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
                                
                                // Right side - pricing when available, invisible text when not
                                if let price = getLiteSubscriptionPrice() {
                                    Text("\(price)/week")
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.trailing, 8)
                                } else {
                                    // Invisible text to maintain button height consistency
                                    Text("$0.00/week")
                                        .font(.system(size: 14, weight: .medium))
                                        .opacity(0)
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
                                .stroke(Color(.separator).opacity(0.8), lineWidth: 1.5)
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
}

// MARK: - Wave Progress Effect
struct WaveProgressView: View {
    let progress: CGFloat
    let totalWidth: CGFloat
    let height: CGFloat
    
    @State private var waveOffset: CGFloat = 0
    @State private var waveTimer: Timer?
    @State private var waveDirection: CGFloat = 1  // 1 for forward, -1 for reverse
    
    var body: some View {
        let currentWidth = totalWidth * progress
        
        Path { path in
            if currentWidth <= 0 { return }
            
            let baseWaveHeight: CGFloat = 2  // Base wave height
            let waveLength: CGFloat = 20  // Distance between wave peaks
            
            // Start from top-left corner
            path.move(to: CGPoint(x: 0, y: 0))
            
            // Top edge - straight line
            path.addLine(to: CGPoint(x: currentWidth, y: 0))
            
            // Right edge with flowing waves - vertical wave motion with individual height variations
            for y in stride(from: 0, to: height, by: 0.5) {
                // Create multiple waves with time-based animation
                let wavePhase = (y / waveLength) * 2 * .pi + waveOffset
                
                // Individual height variation for each wave position - time-dependent
                let heightTimePhase = waveOffset * 0.5  // Slower time progression for height changes
                let positionPhase = (y / waveLength) * 3.0  // Different phase for each position
                let combinedHeightPhase = heightTimePhase + positionPhase
                let individualHeightMultiplier = 0.5 + 0.8 * sin(combinedHeightPhase)  // Range from 0.5 to 1.3
                let individualWaveHeight = baseWaveHeight * individualHeightMultiplier
                
                let wave = sin(wavePhase) * individualWaveHeight
                let x = currentWidth + wave
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Bottom edge - straight line back to left
            path.addLine(to: CGPoint(x: 0, y: height))
            
            // Close the path
            path.closeSubpath()
        }
        .fill(Color.gray.opacity(0.9))
        .animation(.easeInOut(duration: 0.2), value: progress)
        .onAppear {
            startWaveAnimation()
        }
        .onDisappear {
            stopWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        // Use Timer for directional flow with individual wave height variations
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Directional wave movement (up/down flow)
            waveOffset += (0.125 * waveDirection)
            
            // Reverse direction at the same points
            if waveOffset >= .pi {
                waveDirection = -1  // Reverse direction
            } else if waveOffset <= -.pi {
                waveDirection = 1   // Forward direction
            }
        }
    }
    
    private func stopWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
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
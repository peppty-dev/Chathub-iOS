import SwiftUI

struct MessageLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var backgroundTimer: Timer?
    @State private var remainingTime: TimeInterval
    @State private var popupStartTime: Date = Date()
    private let totalCooldownDuration: TimeInterval
    
    // Pricing information for Pro subscription
    private func getProSubscriptionPrice() -> String? {
        let subscriptionsManager = SubscriptionsManagerStoreKit2.shared
        let productId = "com.peppty.ChatApp.pro.weekly" // Use weekly for pricing display
        
        if let cachedPrice = subscriptionsManager.getCachedFormattedPrice(productId: productId, period: "weekly") {
            return cachedPrice
        }
        
        AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "getProSubscriptionPrice() No cached price available for Pro subscription")
        return nil
    }
    
    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onUpgradeToPremium: @escaping () -> Void) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onUpgradeToPremium = onUpgradeToPremium
        self._remainingTime = State(initialValue: remainingCooldown)
        
        // Set total cooldown duration from MessageLimitManager
        self.totalCooldownDuration = TimeInterval(SessionManager.shared.freeMessagesCooldownSeconds)
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    
                    // Track popup dismissal via background tap
                    let timeSpent = Date().timeIntervalSince(popupStartTime)
                    MessageAnalytics.shared.trackPopupDismissed(
                        method: "background_tap",
                        currentUsage: currentUsage,
                        limit: limit
                    )
                    
                    dismissPopup()
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Static title and description - refined hierarchy
                    VStack(spacing: 12) {
                        Text("Send Message")
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
                                        .fill(
                                            LinearGradient(
                                                colors: [Color("proGradientStart"), Color("proGradientEnd")],
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
                        .padding(.top, 24)
                    }
                    
                    // Single Lite Subscription Button (no send message button)
                    VStack(spacing: 12) {
                        // Lite Subscription Button with matching gradient
                        Button(action: upgradeToPremiumAction) {
                            HStack(spacing: 0) {
                                // Left side - icon and text (always consistent)
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title3)
                                    Text("Subscribe to Pro")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Right side - pricing when available with pill background, invisible text when not
                                if let price = getProSubscriptionPrice() {
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
                                    colors: [Color("proGradientStart"), Color("proGradientEnd")],
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
            
            // Start cooldown timestamp when popup opens (if limit reached and not already in cooldown)
            MessageLimitManager.shared.startCooldownOnPopupOpen()
            
            // Recalculate remaining time after potentially starting cooldown
            remainingTime = MessageLimitManager.shared.getRemainingCooldown()
            
            startCountdownTimer()
            
            // Listen for background cooldown expiration
            NotificationCenter.default.addObserver(
                forName: BackgroundTimerManager.messageCooldownExpiredNotification,
                object: nil,
                queue: .main
            ) { _ in
                AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Background cooldown expired - dismissing popup")
                remainingTime = 0
                stopCountdownTimer()
                dismissPopup()
            }
            
            // Track message limit popup shown
            MessageAnalytics.shared.trackMessageLimitPopupShown(
                currentUsage: currentUsage,
                limit: limit,
                remainingCooldown: remainingTime
            )
            
            AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
            // Clean up notification observer
            NotificationCenter.default.removeObserver(self, name: BackgroundTimerManager.messageCooldownExpiredNotification, object: nil)
        }
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "upgradeToPremiumAction() Premium upgrade tapped")
        
        // Track subscription button tap
        MessageAnalytics.shared.trackSubscriptionButtonTapped(
            priceDisplayed: getProSubscriptionPrice(),
            currentUsage: currentUsage,
            limit: limit
        )
        
        // Track popup dismissal via subscription action
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        MessageAnalytics.shared.trackPopupDismissed(
            method: "subscription_action",
            currentUsage: currentUsage,
            limit: limit
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
                MessageLimitManager.shared.resetCooldown()
                
                // Dismiss popup when cooldown expires for message limits (unlike filter/refresh)
                dismissPopup()
                AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Timer expired - dismissing popup")
            }
        }
        
        // Background Timer: Safety net that ensures completion even if UI timer fails
        // Check every 1 second for maximum responsiveness and precision
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Recalculate remaining time from actual manager
            let actualRemaining = MessageLimitManager.shared.getRemainingCooldown()
            
            // Fix: Use tolerance of 1 second to handle timing precision issues (consistent with BackgroundTimerManager)
            if actualRemaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Background timer detected cooldown expiration - dismissing popup (remaining: \(actualRemaining)s)")
                
                // Ensure cooldown is reset
                MessageLimitManager.shared.resetCooldown()
                
                DispatchQueue.main.async {
                    remainingTime = 0
                    stopCountdownTimer()
                    dismissPopup()
                }
            } else {
                // Sync UI timer with actual remaining time if they diverge significantly
                let timeDifference = abs(remainingTime - actualRemaining)
                if timeDifference > 1.0 { // If UI and actual time differ by more than 1 second
                    AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Background timer syncing UI time - UI: \(remainingTime)s, Actual: \(actualRemaining)s")
                    DispatchQueue.main.async {
                        remainingTime = actualRemaining
                    }
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Started dual timers - UI: 0.1s interval, Background: 1s interval")
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        AppLogger.log(tag: "LOG-APP: MessageLimitPopupView", message: "Stopped all timers")
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func getDescriptionText() -> String {
        if isLimitReached && remainingTime > 0 {
            // During cooldown - show specific limit reached message
            return "You've reached your limit of \(limit) free messages. Subscribe to ChatHub Pro for unlimited access or wait for the timer to reset."
        } else {
            // Normal state - show general description
            return "Send unlimited messages to connect with people. Upgrade to ChatHub Pro subscription to unlock unlimited messaging."
        }
    }
}

// MARK: - Preview
struct MessageLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        MessageLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 600,
            isLimitReached: true,
            currentUsage: 20,
            limit: 20,
            onUpgradeToPremium: { print("Upgrade to Pro subscription") }
        )
    }
}
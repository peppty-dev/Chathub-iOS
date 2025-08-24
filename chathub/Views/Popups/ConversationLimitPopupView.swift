import SwiftUI

struct ConversationLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onStartConversation: () -> Void
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var backgroundTimer: Timer?
    @State private var remainingTime: TimeInterval
    @State private var totalCooldownDuration: TimeInterval = 300 // Default 5 minutes
    @State private var popupStartTime = Date()
    
    @ObservedObject private var subscriptionsManager = SubscriptionsManagerStoreKit2.shared
    
    // When SB is active, reuse this view with the same title but with a different description
    // and hide the Start button while showing timer + Subscribe button.
    var isShadowBan: Bool = false

    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onStartConversation: @escaping () -> Void,
          onUpgradeToPremium: @escaping () -> Void,
          isShadowBan: Bool = false) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onStartConversation = onStartConversation
        self.onUpgradeToPremium = onUpgradeToPremium
        self.isShadowBan = isShadowBan
        self._remainingTime = State(initialValue: remainingCooldown)
        
        // Set total cooldown duration based on configuration
        let cooldownDuration = TimeInterval(SessionManager.shared.freeConversationsCooldownSeconds)
        self._totalCooldownDuration = State(initialValue: cooldownDuration > 0 ? cooldownDuration : 300)
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    
                    // Track popup dismissal via background tap
                    let timeSpent = Date().timeIntervalSince(popupStartTime)
                    ConversationAnalytics.shared.trackConversationPopupDismissed(
                        userType: ConversationAnalytics.shared.getUserType(),
                        dismissMethod: "background_tap",
                        timeSpentInPopup: timeSpent
                    )
                    
                    dismissPopup()
                }
            
            // Main popup container
            VStack(spacing: 0) {
                // Title
                Text("Start Conversation")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .padding(.top, 24)
                
                // Description
                Group {
                    if isShadowBan {
                        // SB description (title unchanged). Encourage Plus to chat instantly.
                        Text("You promoted other apps. You can start new conversations after the timer ends. Subscribe to Plus to chat instantly.")
                    } else if isLimitReached && remainingTime > 0 {
                        if SessionManager.shared.showRemainingChancesLabel {
                            Text("You've used your \(limit) free conversations. Subscribe to ChatHub Plus for unlimited conversations and discover more people!")
                        } else {
                            Text("You've reached your free conversation limit. Subscribe to ChatHub Plus for unlimited conversations and discover more people!")
                        }
                    } else {
                        if SessionManager.shared.showRemainingChancesLabel {
                            let remaining = max(0, limit - currentUsage)
                            if remaining > 0 {
                                Text("You have \(remaining) conversations remaining. Subscribe to ChatHub Plus for unlimited conversations.")
                            } else {
                                Text("Start new conversations to meet interesting people! Subscribe to ChatHub Plus for unlimited conversations.")
                            }
                        } else {
                            Text("Start new conversations to meet interesting people! Subscribe to ChatHub Plus for unlimited conversations.")
                        }
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(Color("shade_800"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                // Progress bar and timer (only show during cooldown)
                if (isLimitReached && remainingTime > 0) || isShadowBan {
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background bar
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                
                                // Progress bar - uses Plus gradient colors
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
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
                
                // Buttons
                VStack(spacing: 12) {
                    // Start Conversation Button - hidden for SB while timer active
                    if !(isShadowBan || (isLimitReached && remainingTime > 0)) {
                        Button(action: startConversationAction) {
                            HStack(spacing: 0) {
                                // Left side - icon and text (always consistent)
                                HStack(spacing: 8) {
                                    Image(systemName: "message.circle.fill")
                                        .font(.title3)
                                    Text("Start Conversation")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Right side - show remaining conversations
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
                    
                    // Plus Subscription Button
                    Button(action: upgradeToPremiumAction) {
                        HStack(spacing: 0) {
                            // Left side - icon and text (always consistent)
                            HStack(spacing: 8) {
                                Image(systemName: "star.circle.fill")
                                    .font(.title3)
                                Text("Subscribe to Plus")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                            
                            // Right side - pricing when available with pill background
                            if let price = getPlusSubscriptionPrice() {
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
                                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
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
            .background(Color("shade2"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
            )
            .padding(.horizontal, 20)
        }
        .onAppear {
            popupStartTime = Date()
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "onAppear() Starting - initial remainingTime: \(remainingTime)s, isLimitReached: \(isLimitReached)")
            
            startCooldownOnPopupOpen()
            
            // Recalculate remaining time after potentially starting cooldown
            remainingTime = ConversationLimitManagerNew.shared.getRemainingCooldown()
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "onAppear() After cooldown setup - remainingTime: \(remainingTime)s")
            
            startCountdownTimer()
            setupBackgroundTimer()
            
            // Register for background expiration notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("conversationCooldownExpiredNotification"),
                object: nil,
                queue: .main
            ) { _ in
                AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "Received cooldown expired notification - transitioning to available state")
                
                // Track cooldown completion analytics
                ConversationAnalytics.shared.trackCooldownCompleted(
                    totalCooldownDuration: totalCooldownDuration,
                    conversationLimit: limit
                )
                
                remainingTime = 0
                ConversationLimitManagerNew.shared.resetConversationUsage()
            }
            
            // Track analytics for popup shown
            ConversationAnalytics.shared.trackConversationPopupShown(
                userType: ConversationAnalytics.shared.getUserType(),
                currentUsage: currentUsage,
                limit: limit,
                remainingCooldown: remainingTime,
                triggerReason: isLimitReached ? "limit_reached" : "always_show_strategy"
            )
            
            // Track pricing display if available
            if let price = getPlusSubscriptionPrice() {
                ConversationAnalytics.shared.trackPricingDisplayed(price: price, currency: "USD")
            }
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
            stopBackgroundTimer()
            
            // Remove notification observer
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("conversationCooldownExpiredNotification"),
                object: nil
            )
        }
    }
    
    // MARK: - Actions
    
    private func startConversationAction() {
        AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "startConversationAction() Start conversation tapped")
        
        // Track popup dismissal via conversation action
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        ConversationAnalytics.shared.trackConversationPopupDismissed(
            userType: ConversationAnalytics.shared.getUserType(),
            dismissMethod: "conversation_action",
            timeSpentInPopup: timeSpent
        )
        
        dismissPopup()
        onStartConversation()
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "upgradeToPremiumAction() Plus subscription tapped")
        
        // Track subscription button tap
        ConversationAnalytics.shared.trackSubscriptionButtonTapped(
            currentUsage: currentUsage,
            limit: limit,
            remainingCooldown: remainingTime,
            priceDisplayed: getPlusSubscriptionPrice()
        )
        
        // Track popup dismissal via subscription action
        let timeSpent = Date().timeIntervalSince(popupStartTime)
        ConversationAnalytics.shared.trackConversationPopupDismissed(
            userType: ConversationAnalytics.shared.getUserType(),
            dismissMethod: "subscription_action",
            timeSpentInPopup: timeSpent
        )
        
        dismissPopup()
        onUpgradeToPremium()
    }
    
    private func dismissPopup() {
        stopCountdownTimer()
        stopBackgroundTimer()
        isPresented = false
    }
    
    // MARK: - Timer Management
    
    private func startCooldownOnPopupOpen() {
        // Check if we need to start cooldown (when limit reached but cooldown not started)
        if currentUsage >= limit && remainingTime <= 1.0 {
            AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "startCooldownOnPopupOpen() Starting cooldown on popup open")
            ConversationLimitManagerNew.shared.startCooldownOnPopupOpen()
            
            // Update remaining time after starting cooldown
            let newRemainingTime = ConversationLimitManagerNew.shared.getRemainingCooldown()
            remainingTime = newRemainingTime
            totalCooldownDuration = newRemainingTime
        }
    }
    
    private func startCountdownTimer() {
        guard isLimitReached && remainingTime > 0 else { 
            AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "startCountdownTimer() Skipped - isLimitReached: \(isLimitReached), remainingTime: \(remainingTime)s")
            return 
        }
        
        AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "startCountdownTimer() Starting timer - remainingTime: \(remainingTime)s")
        
        // Invalidate existing timer to prevent duplicates
        countdownTimer?.invalidate()
        
        // UI Timer: Update every 0.1 seconds for smooth animation (like other limit popups)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if remainingTime > 0.1 {
                remainingTime -= 0.1
            } else {
                remainingTime = 0
                stopCountdownTimer()
                
                // Reset the usage count when cooldown expires
                ConversationLimitManagerNew.shared.resetConversationUsage()
                
                // Don't dismiss popup - let it transition to available state
                // The UI will automatically show the conversation button and hide progress bar
                // based on remainingTime = 0 condition
                AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "Timer expired - transitioning popup to available state")
            }
        }
    }
    
    private func setupBackgroundTimer() {
        guard isLimitReached && remainingTime > 0 else { return }
        
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let actualRemaining = ConversationLimitManagerNew.shared.getRemainingCooldown()
            
            // Sync UI time with actual time if they diverge
            if abs(actualRemaining - remainingTime) > 1.0 {
                AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "setupBackgroundTimer() Syncing times - UI: \(remainingTime)s, Actual: \(actualRemaining)s")
                remainingTime = actualRemaining
            }
            
            // Check if cooldown has expired
            if actualRemaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: ConversationLimitPopupView", message: "setupBackgroundTimer() Cooldown expired - transitioning to available state")
                remainingTime = 0
                ConversationLimitManagerNew.shared.resetConversationUsage()
                stopBackgroundTimer()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - Helper Methods
    
    private func getPlusSubscriptionPrice() -> String? {
        // Get Plus subscription price from SubscriptionsManagerStoreKit2
        let productId = "com.peppty.ChatApp.plus.weekly"
        if let cachedPrice = subscriptionsManager.getCachedFormattedPrice(productId: productId, period: "weekly") {
            return cachedPrice
        }
        return nil
    }
}

// MARK: - Preview
struct ConversationLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 300,
            isLimitReached: true,
            currentUsage: 5,
            limit: 5,
            onStartConversation: { print("Start conversation") },
            onUpgradeToPremium: { print("Upgrade to Lite") }
        )
    }
}
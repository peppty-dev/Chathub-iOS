import SwiftUI

struct DebugSubscriptionPopupView: View {
    @Binding var isPresented: Bool
    @State private var selectedTier: String = "none"
    @State private var selectedPeriod: String = "weekly"
    
    private let tiers = ["none", "lite", "plus", "pro"]
    private let periods = ["weekly", "monthly", "yearly"]
    
    // Consistent background color following app patterns
    private var customBackgroundColor: Color {
        Color("shade2")
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.6)
                .ignoresSafeArea(.all, edges: .all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "background tapped - dismissing debug subscription popup")
                    isPresented = false
                }
            
            // Main popup container - following app's popup structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Icon - debug icon to represent debug feature
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color("ColorAccent"))
                        .padding(.top, 24)
                    
                    // Header
                    VStack(spacing: 16) {
                        // Title - following guidelines
                        Text("DEBUG: Change Subscription")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        // Subtitle - following guidelines
                        Text("This is a debug-only feature for testing different subscription states.\n\nChanging subscription will reset all live feature and call timers, giving you full time allocations to test with.")
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade_800"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                
                    // Current subscription status - following app layout patterns
                    VStack(spacing: 12) {
                        Text("Current Status")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("dark"))
                        
                        let currentState = SubscriptionSessionManager.shared.getCurrentSubscriptionState()
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("Tier:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("shade_800"))
                                Spacer()
                                Text(currentState.tier.capitalized)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("dark"))
                            }
                            
                            HStack {
                                Text("Period:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("shade_800"))
                                Spacer()
                                Text(currentState.period.capitalized)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("dark"))
                            }
                            
                            HStack {
                                Text("Active:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("shade_800"))
                                Spacer()
                                Text(currentState.isActive ? "Yes" : "No")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(currentState.isActive ? Color("green_500") : Color("red_500"))
                            }
                            
                            // Timer status section for debug purposes
                            VStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color("shade_300"))
                                    .frame(height: 1)
                                    .padding(.vertical, 8)
                                
                                HStack {
                                    Text("Live Time:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("shade_800"))
                                    Spacer()
                                    Text("\(MessagingSettingsSessionManager.shared.liveSeconds)s")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("dark"))
                                }
                                
                                HStack {
                                    Text("Call Time:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("shade_800"))
                                    Spacer()
                                    Text("\(MessagingSettingsSessionManager.shared.callSeconds)s")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("dark"))
                                }
                                
                                HStack {
                                    Text("Live Used:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("shade_800"))
                                    Spacer()
                                    Text("\(TimeAllocationManager.shared.getLiveTimeUsed())s")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("orange_600"))
                                }
                                
                                HStack {
                                    Text("Call Used:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("shade_800"))
                                    Spacer()
                                    Text("\(TimeAllocationManager.shared.getCallTimeUsed())s")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("orange_600"))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("shade_200"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color("shade_300"), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                    // Subscription tier selection - following app button patterns
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Tier")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("dark"))
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(tiers, id: \.self) { tier in
                                Button(action: {
                                    selectedTier = tier
                                }) {
                                    Text(tier.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedTier == tier ? .white : Color("dark"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedTier == tier ? Color("ColorAccent") : Color("shade_200"))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedTier == tier ? Color("ColorAccent") : Color("shade_300"), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                    // Period selection (only show if not "none") - following app patterns
                    if selectedTier != "none" {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Period")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("dark"))
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(periods, id: \.self) { period in
                                    Button(action: {
                                        selectedPeriod = period
                                    }) {
                                        Text(period.capitalized)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedPeriod == period ? .white : Color("dark"))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedPeriod == period ? Color("ColorAccent") : Color("shade_200"))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(selectedPeriod == period ? Color("ColorAccent") : Color("shade_300"), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                    }
                
                    // Action buttons - following app button patterns
                    HStack(spacing: 12) {
                        // Cancel button - following app secondary button style
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "cancel button tapped")
                            isPresented = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("shade_800"))
                                
                                Text("CANCEL")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("shade_800"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("shade_200"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("shade_300"), lineWidth: 1)
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Apply button - following app primary button style with gradient
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "apply debug subscription button tapped: tier=\(selectedTier), period=\(selectedPeriod)")
                            applySubscriptionChange()
                            isPresented = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                
                                Text("APPLY")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color("ColorAccent"), Color("ColorAccent").opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(customBackgroundColor)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTier)
                
                Spacer() // Center vertically
                
                // Bottom spacing to keep dialog above tab bar (following app patterns)
                Color.clear
                    .frame(height: 100)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: selectedTier)
        .onAppear {
            // Initialize with current subscription state
            let currentState = SubscriptionSessionManager.shared.getCurrentSubscriptionState()
            selectedTier = currentState.tier == SubscriptionConstants.TIER_NONE ? "none" : currentState.tier
            selectedPeriod = currentState.period == "none" ? "weekly" : currentState.period
        }
    }
    
    private func applySubscriptionChange() {
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "applySubscriptionChange() Applying debug subscription change: tier=\(selectedTier), period=\(selectedPeriod)")
        
        if selectedTier == "none" {
            // Set to inactive subscription
            SubscriptionSessionManager.shared.updateFromSubscriptionState(
                isActive: false,
                tier: SubscriptionConstants.TIER_NONE,
                period: "none",
                status: SubscriptionConstants.STATUS_INACTIVE,
                startTimeMillis: 0,
                expiryTimeMillis: 0,
                willAutoRenew: false,
                productId: "",
                purchaseToken: nil,
                basePlanId: nil
            )
            
            // Update main session manager for backwards compatibility
            SessionManager.shared.premiumActive = false
            SessionManager.shared.synchronize()
            
            // Reset all timers for testing purposes
            resetAllTimersForDebug()
            
        } else {
            // Set to active subscription with selected tier and period
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
            let expiryTime = calculateDebugExpiryTime(currentTime: currentTime, period: selectedPeriod)
            let productId = "com.peppty.ChatApp.\(selectedTier).\(selectedPeriod)"
            let basePlanId = "chathub-\(selectedTier)-\(selectedPeriod)"
            
            SubscriptionSessionManager.shared.updateFromSubscriptionState(
                isActive: true,
                tier: selectedTier,
                period: selectedPeriod,
                status: SubscriptionConstants.STATUS_ACTIVE,
                startTimeMillis: currentTime,
                expiryTimeMillis: expiryTime,
                willAutoRenew: true,
                productId: productId,
                purchaseToken: "debug_token_\(currentTime)",
                basePlanId: basePlanId
            )
            
            // Update main session manager for backwards compatibility
            SessionManager.shared.premiumActive = true
            SessionManager.shared.synchronize()
            
            // Reset all timers and replenish based on new subscription tier
            resetAllTimersForDebug()
            replenishTimersForDebugSubscription()
        }
        
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "applySubscriptionChange() Debug subscription change applied successfully with timer reset")
    }
    
    private func calculateDebugExpiryTime(currentTime: Int64, period: String) -> Int64 {
        let calendar = Calendar.current
        let currentDate = Date(timeIntervalSince1970: TimeInterval(currentTime / 1000))
        
        let expiryDate: Date
        switch period {
        case "weekly":
            expiryDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case "monthly":
            expiryDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        case "yearly":
            expiryDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
        default:
            expiryDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return Int64(expiryDate.timeIntervalSince1970 * 1000)
    }
    
    // MARK: - Debug Timer Reset Functions
    
    /// Reset all timers for debug testing (like subscription renewal)
    private func resetAllTimersForDebug() {
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "resetAllTimersForDebug() Resetting all live feature and call timers for debug testing")
        
        // Reset time allocations in TimeAllocationManager (this resets liveTimeUsed and callTimeUsed)
        TimeAllocationManager.shared.markSubscriptionRenewal()
        
        // Reset legacy live seconds in SessionManager
        SessionManager.shared.liveSeconds = 0
        
        // Reset live seconds in MessagingSettingsSessionManager
        MessagingSettingsSessionManager.shared.liveSeconds = 0
        
        // Reset call seconds in MessagingSettingsSessionManager
        MessagingSettingsSessionManager.shared.callSeconds = 0
        
        // Synchronize all changes
        SessionManager.shared.synchronize()
        
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "resetAllTimersForDebug() All timers reset successfully for debug testing")
    }
    
    /// Replenish timers based on new debug subscription tier
    private func replenishTimersForDebugSubscription() {
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "replenishTimersForDebugSubscription() Replenishing timers for tier: \(selectedTier)")
        
        // Use TimeAllocationManager to replenish live seconds based on new subscription
        TimeAllocationManager.shared.replenishLiveSecondsIfNeeded()
        
        // Replenish call seconds based on new subscription
        TimeAllocationManager.shared.replenishCallSecondsIfNeeded()
        
        // For debug purposes, let's also set some manual values to ensure testing works
        let subscriptionManager = SubscriptionSessionManager.shared
        
        if subscriptionManager.hasPlusTierOrHigher() {
            // Plus tier gets live feature time
            let remainingLiveTime = TimeAllocationManager.shared.getRemainingLiveTime()
            if remainingLiveTime > 0 {
                MessagingSettingsSessionManager.shared.liveSeconds = remainingLiveTime
                SessionManager.shared.liveSeconds = Int64(remainingLiveTime)
                AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "replenishTimersForDebugSubscription() Set live time to \(remainingLiveTime) seconds for Plus+ tier")
            }
        }
        
        if subscriptionManager.hasProTier() {
            // Pro tier gets call feature time
            let remainingCallTime = TimeAllocationManager.shared.getRemainingCallTime()
            if remainingCallTime > 0 {
                MessagingSettingsSessionManager.shared.callSeconds = remainingCallTime
                AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "replenishTimersForDebugSubscription() Set call time to \(remainingCallTime) seconds for Pro tier")
            }
        }
        
        // Synchronize changes
        SessionManager.shared.synchronize()
        
        AppLogger.log(tag: "LOG-APP: DebugSubscriptionPopup", message: "replenishTimersForDebugSubscription() Timer replenishment completed for debug subscription")
    }
}

#Preview {
    DebugSubscriptionPopupView(isPresented: .constant(true))
}

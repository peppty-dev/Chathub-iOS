import SwiftUI
import StoreKit
import Foundation

struct SubscriptionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTier: SubscriptionTier = .lite
    @State private var selectedPeriods: [SubscriptionTier: SubscriptionPeriod] = [
        .lite: .weekly,
        .plus: .weekly,
        .pro: .weekly
    ]
    @State private var isLoading = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showSubscriptionHistory = false
    @State private var pricesLoading = true
    @State private var purchaseError: String?
    @State private var showMoreRepliesInfo = false
    
    // Session managers
    private let sessionManager = SessionManager.shared
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    // Subscriptions manager
    @StateObject private var subscriptionsManager = SubscriptionsManagerStoreKit2.shared
    
    // Current subscription state
    private var isSubscribed: Bool {
        subscriptionSessionManager.isSubscriptionActive()
    }
    
    private var currentTier: String {
        subscriptionSessionManager.getSubscriptionTier()
    }
    
    private var currentPeriod: String {
        subscriptionSessionManager.getSubscriptionPeriod()
    }
    
    private var isAnonymous: Bool {
        // Android parity: Use SessionManager.isAnonymousUser() method
        return sessionManager.isAnonymousUser()
    }
    
    enum SubscriptionTier: CaseIterable {
        case lite, plus, pro
        
        var title: String {
            switch self {
            case .lite: return "Lite"
            case .plus: return "Plus"  
            case .pro: return "Pro"
            }
        }
        
        var features: [String] {
            switch self {
            case .lite:
                return [
                    "• Unlocks Refresh",
                    "• Unlocks Filters", 
                    "• Unlocks Search",
                    "",
                    "• Get More Replies ⓘ"
                ]
            case .plus:
                return [
                    "• Unlocks Refresh",
                    "• Unlocks Filters",
                    "• Unlocks Search", 
                    "",
                    "• Get More Replies ⓘ",
                    "",
                    "• Unlocks Live",
                    "",
                    "• No Conversation Limit"
                ]
            case .pro:
                return [
                    "• Unlocks Refresh",
                    "• Unlocks Filters",
                    "• Unlocks Search",
                    "",
                    "• Get More Replies ⓘ",
                    "",
                    "• Unlocks Live",
                    "• Unlocks Calls",
                    "",
                    "• No Conversation Limit", 
                    "• No Message Limit"
                ]
            }
        }
        
        var gradientColors: [Color] {
            switch self {
            case .lite: return [Color("liteGradientStart"), Color("liteGradientEnd")]
            case .plus: return [Color("plusGradientStart"), Color("plusGradientEnd")]
            case .pro: return [Color("proGradientStart"), Color("proGradientEnd")]
            }
        }
        
        var productIdPrefix: String {
            switch self {
            case .lite: return "chathub-lite"
            case .plus: return "chathub-plus"
            case .pro: return "chathub-pro"
            }
        }
    }
    
    enum SubscriptionPeriod: CaseIterable {
        case weekly, monthly, yearly
        
        var title: String {
            switch self {
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
        
        var suffix: String {
            switch self {
            case .weekly: return "weekly"
            case .monthly: return "monthly"
            case .yearly: return "yearly"
            }
        }
    }

    var body: some View {
        // Content ScrollView
        ScrollView {
            VStack(spacing: 0) {
                // Anonymous User Warning
                if isAnonymous && isSubscribed {
                    AnonymousWarningView()
                        .padding(.bottom, 8)
                }
                
                // Subscription Management (for existing subscribers)
                if isSubscribed {
                    SubscriptionManagementView()
                    
                    // Subtle divider between management and subscription tiers
                    Rectangle()
                        .fill(Color("shade3"))
                        .frame(height: 1)
                        .padding(.horizontal, 32)
                        .padding(.top, 5)
                        .padding(.bottom, 16)
                }
                
                // Subscription Tiers
                VStack(spacing: 16) {
                    ForEach(SubscriptionTier.allCases, id: \.title) { tier in
                        SubscriptionTierCard(
                            tier: tier,
                            selectedPeriod: selectedPeriods[tier] ?? .weekly,
                            onPeriodChanged: { period in
                                selectedPeriods[tier] = period
                            },
                            onSubscribe: {
                                subscribeToTier(tier, period: selectedPeriods[tier] ?? .weekly)
                            },
                            isLoading: isLoading,
                            pricesLoading: pricesLoading,
                            subscriptionsManager: subscriptionsManager,
                            showMoreRepliesInfo: $showMoreRepliesInfo
                        )
                    }
                }
                .padding(.horizontal, 16)
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions will automatically renew unless canceled at least 24 hours before the end of the current period.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
                .padding(.bottom, 32)
                
                // Error message display
                if let error = purchaseError {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("ErrorRed"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("ErrorRed").opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("ErrorRed").opacity(0.5), lineWidth: 2)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
            }
        }
        .background(Color("Background Color"))
        .navigationTitle("Subscription Plans")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "onAppear() setting up subscription view")
            Task {
                await subscriptionsManager.loadProducts()
                await MainActor.run {
                    pricesLoading = false
                }
            }
        }
        .background(
            NavigationLink(
                destination: SubscriptionHistoryView(),
                isActive: $showSubscriptionHistory
            ) {
                EmptyView()
            }
            .hidden()
        )
        .overlay(
            // Custom Get More Replies Popup
            Group {
                if showMoreRepliesInfo {
                    GetMoreRepliesPopupView(isPresented: $showMoreRepliesInfo)
                }
            }
        )
    }
    

    
    private func subscribeToTier(_ tier: SubscriptionTier, period: SubscriptionPeriod) {
        AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "subscribeToTier() subscribing to \(tier.title) \(period.title)")
        
        isLoading = true
        purchaseError = nil
        
        let productId = "com.peppty.ChatApp.\(tier.title.lowercased()).\(period.suffix)"
        
        Task {
            let success = await subscriptionsManager.purchaseProduct(productId: productId)
            
            await MainActor.run {
                self.isLoading = false
                
                if success {
                    AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "subscribeToTier() subscription successful")
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    // Handle purchase failure
                    switch subscriptionsManager.purchaseState {
                    case .cancelled:
                        AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "subscribeToTier() purchase cancelled by user")
                        // Don't show error for user cancellation
                    case .failed(let error):
                        AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "subscribeToTier() purchase failed: \(error.localizedDescription)")
                        self.purchaseError = error.localizedDescription
                    default:
                        AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "subscribeToTier() purchase failed with unknown state")
                        self.purchaseError = "Purchase failed. Please try again."
                    }
                }
            }
        }
    }
    
    /// Calculates subscription expiry time based on purchase time and period
    private func calculateExpiryTime(purchaseTime: Int64, period: String) -> Int64 {
        let purchaseTimeSeconds = purchaseTime / 1000
        let calendar = Calendar.current
        let purchaseDate = Date(timeIntervalSince1970: TimeInterval(purchaseTimeSeconds))
        
        var expiryDate: Date
        
        switch period.lowercased() {
        case "weekly":
            expiryDate = calendar.date(byAdding: .weekOfYear, value: 1, to: purchaseDate) ?? purchaseDate
        case "monthly":
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        case "yearly":
            expiryDate = calendar.date(byAdding: .year, value: 1, to: purchaseDate) ?? purchaseDate
        default:
            // Default to 1 month for unknown periods
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        }
        
        return Int64(expiryDate.timeIntervalSince1970 * 1000)
    }
}

// MARK: - Anonymous Warning View
struct AnonymousWarningView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(Color("orange_900"))
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 1)
            
            Text("Warning: You are logged in anonymously. To avoid losing your subscription if you change devices or reinstall the app, please register your account with an email in Settings.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("orange_900"))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("orange_50"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("orange_900").opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Subscription Management View
struct SubscriptionManagementView: View {
    @State private var showSubscriptionHistory = false
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    private var currentPlan: String {
        let tier = subscriptionSessionManager.getSubscriptionTier()
        let period = subscriptionSessionManager.getSubscriptionPeriod()
        return formatPlanName(tier: tier, period: period)
    }
    
    private var status: String {
        return subscriptionSessionManager.getSubscriptionStatus().capitalized
    }
    
    private var statusColor: Color {
        let status = subscriptionSessionManager.getSubscriptionStatus().lowercased()
        switch status {
        case "active":
            return Color("AndroidGreen")
        case "expired", "cancelled", "inactive":
            return Color("ErrorRed")
        case "grace_period", "account_hold", "pending", "trialing":
            return Color("orange_900")
        default:
            return Color("shade6")
        }
    }
    
    private var autoRenews: String {
        return subscriptionSessionManager.isAutoRenewing() ? "Yes" : "No"
    }
    
    private var nextBillingDate: String {
        let expiryTime = subscriptionSessionManager.getSubscriptionExpiryTime()
        if expiryTime > 0 {
            return formatDate(expiryTime)
        } else {
            return "N/A"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Subscription Management")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color("dark"))
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 12) {
                // Current Plan
                HStack {
                    Text("Current Plan:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                    Spacer()
                    Text(currentPlan)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                }
                
                // Status with color coding
                HStack {
                    Text("Status:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                    Spacer()
                    Text(status)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(statusColor)
                }
                
                // Auto Renews
                HStack {
                    Text("Auto Renews:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                    Spacer()
                    Text(autoRenews)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                }
                
                // Next Billing Date
                HStack {
                    Text("Next Billing Date:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                    Spacer()
                    Text(nextBillingDate)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Manage Subscription Button - Primary style
                Button(action: {
                    openAppStoreSubscriptions()
                }) {
                    Text("Manage Subscription")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("ColorAccent"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("ColorAccent"), lineWidth: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // View History Button - Secondary style with theme-aware background
                Button(action: {
                    showSubscriptionHistory = true
                }) {
                    Text("View History")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("Background Color"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("shade3"), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color("shade2"), Color("shade3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("shade3"), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(
            NavigationLink(
                destination: SubscriptionHistoryView(),
                isActive: $showSubscriptionHistory
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    private func openAppStoreSubscriptions() {
        AppLogger.log(tag: "LOG-APP: SubscriptionView", message: "openAppStoreSubscriptions() opening App Store subscriptions")
        
        // Open App Store subscription management
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Helper Methods (Android Parity)
    
    private func formatPlanName(tier: String, period: String) -> String {
        let formattedTier = tier.capitalized
        let formattedPeriod = period.capitalized
        return "\(formattedTier) \(formattedPeriod)"
    }
    
    private func formatGracePeriodMessage(timeRemaining: Int64) -> String {
        let days = timeRemaining / (24 * 60 * 60 * 1000)
        if days > 0 {
            return "Grace period expires in \(days) day\(days == 1 ? "" : "s")"
        } else {
            let hours = timeRemaining / (60 * 60 * 1000)
            return "Grace period expires in \(max(1, hours)) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    private func formatAccountHoldMessage(timeRemaining: Int64) -> String {
        let days = timeRemaining / (24 * 60 * 60 * 1000)
        if days > 0 {
            return "Account hold ends in \(days) day\(days == 1 ? "" : "s")"
        } else {
            let hours = timeRemaining / (60 * 60 * 1000)
            return "Account hold ends in \(max(1, hours)) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getCancellationMessage() -> String {
        // Android parity: Show cancellation details
        let expiryTime = subscriptionSessionManager.getSubscriptionExpiryTime()
        if expiryTime > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
            if expiryTime > currentTime {
                return "Subscription cancelled. Access continues until \(formatDate(expiryTime))"
            } else {
                return "Subscription cancelled and expired on \(formatDate(expiryTime))"
            }
        } else {
            return "Subscription has been cancelled"
        }
    }
}

// MARK: - SubscriptionTierCard
struct SubscriptionTierCard: View {
    let tier: SubscriptionView.SubscriptionTier
    @State var selectedPeriod: SubscriptionView.SubscriptionPeriod
    let onPeriodChanged: (SubscriptionView.SubscriptionPeriod) -> Void
    let onSubscribe: () -> Void
    let isLoading: Bool
    let pricesLoading: Bool
    let subscriptionsManager: SubscriptionsManagerStoreKit2
    @Binding var showMoreRepliesInfo: Bool
    
    // Session managers for subscription state
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    // State to trigger button text updates when subscription changes
    @State private var subscriptionUpdateTrigger = UUID()
    
    // Helper to get product ID for a period
    private func getProductId(for period: SubscriptionView.SubscriptionPeriod) -> String {
        return "com.peppty.ChatApp.\(tier.title.lowercased()).\(period.suffix)"
    }
    
    // Helper to get price info for a period (Android parity)
    private func getPriceInfo(for period: SubscriptionView.SubscriptionPeriod) -> (price: String, savings: String?) {
        let productId = getProductId(for: period)
        
        if pricesLoading {
            return ("Loading...", nil)
        }
        
        guard let productPrice = subscriptionsManager.getProductPrice(for: productId) else {
            AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getPriceInfo() No price found for product: \(productId)")
            return ("N/A", nil)
        }
        
        // Android parity: Show savings with fire emoji if savings > 1%
        let savingsText = productPrice.savingsPercent > 1 ? "🔥 Save \(Int(productPrice.savingsPercent))%" : nil
        
        AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getPriceInfo() \(tier.title) \(period.title): \(productPrice.formattedPrice), savings: \(productPrice.savingsPercent)%, display: \(savingsText ?? "none")")
        
        // Enhanced debugging for Lite yearly specifically
        if tier.title == "Lite" && period.title == "Yearly" {
            AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "LITE YEARLY DEBUG: ProductPrice - price: \(productPrice.priceValue), savings: \(productPrice.savingsPercent)%, threshold check: \(productPrice.savingsPercent > 1)")
        }
        
        return (productPrice.formattedPrice, savingsText)
    }
    
    // MARK: - Dynamic Button Text Logic (Android Parity)
    
    /// Updates the button text based on current subscription state and selected period
    /// This mirrors the Android updateSubscribeButtonTexts() method exactly
    private func getButtonText() -> String {
        AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Calculating button text for \(tier.title)")
        
        // Get current subscription state
        let isSubscribed = subscriptionSessionManager.isSubscriptionActive()
        let currentTier = subscriptionSessionManager.getSubscriptionTier()
        let currentBasePlanId = subscriptionSessionManager.getBasePlanId()
        let isAutoRenewing = subscriptionSessionManager.isAutoRenewing()
        
        // Get selected plan ID for this tier (iOS format to match App Store Console)
        let selectedPlanId = getProductId(for: selectedPeriod)
        
        AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Current state - subscribed: \(isSubscribed), tier: \(currentTier), basePlanId: \(currentBasePlanId ?? "nil"), autoRenew: \(isAutoRenewing)")
        AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Selected plan for \(tier.title): \(selectedPlanId)")
        AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() iOS Plan ID comparison - current: '\(currentBasePlanId ?? "nil")' vs selected: '\(selectedPlanId)' - equal: \(currentBasePlanId == selectedPlanId)")
        
        // Handle loading state
        if isLoading {
            return "Processing..."
        }
        
        // Handle no subscription state (Android parity)
        if !isSubscribed || currentTier.isEmpty || currentTier == SubscriptionConstants.TIER_NONE {
            AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() No subscription - returning 'Subscribe'")
            return "Subscribe"
        }
        
        // Handle active subscription state (Android parity)
        let currentTierLevel = getTierLevel(currentTier)
        let thisTierLevel = getTierLevel(tier.title.lowercased())
        
        if tier.title.lowercased() == currentTier.lowercased() {
            // Same tier - check if same plan
            if let currentBasePlanId = currentBasePlanId {
                if currentBasePlanId == selectedPlanId {
                    // Same plan - show current plan or re-subscribe
                    let buttonText = isAutoRenewing ? "Current Plan" : "Re-subscribe"
                    AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Same plan - returning '\(buttonText)'")
                    return buttonText
                } else {
                    // Different period for same tier
                    AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Different period for same tier - returning 'Change Period'")
                    return "Change Period"
                }
            } else {
                // Fallback if current plan ID is missing
                AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Missing current plan ID - returning 'Current Plan'")
                return "Current Plan"
            }
        } else {
            // Different tier - upgrade or downgrade
            if thisTierLevel > currentTierLevel {
                AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Higher tier (\(thisTierLevel) > \(currentTierLevel)) - returning 'Upgrade Plan'")
                return "Upgrade Plan"
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "getButtonText() Lower tier (\(thisTierLevel) < \(currentTierLevel)) - returning 'Downgrade Plan'")
                return "Downgrade Plan"
            }
        }
    }
    
    /// Helper method to get numerical level for tier comparison (Android parity)
    /// LITE = 1, PLUS = 2, PRO = 3
    private func getTierLevel(_ tier: String) -> Int {
        switch tier.lowercased() {
        case SubscriptionConstants.TIER_LITE: return 1
        case SubscriptionConstants.TIER_PLUS: return 2
        case SubscriptionConstants.TIER_PRO: return 3
        default: return 0
        }
    }
    
    var body: some View {
        // Card with Android-style CardView design
        VStack(spacing: 0) {
            // Card Content with Gradient Background
            VStack(spacing: 20) {
                // Title with better spacing
                HStack {
                    Text(tier.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(0.5)
                    Spacer()
                }
                
                // Features with improved spacing
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tier.features.enumerated()), id: \.offset) { index, feature in
                        if feature.isEmpty {
                            Spacer()
                                .frame(height: 6)
                        } else if feature.contains("Get More Replies ⓘ") {
                            // Interactive feature with info icon
                            HStack(spacing: 8) {
                                Text("• Get More Replies")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    showMoreRepliesInfo = true
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(feature)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(nil)
                        }
                    }
                }
                
                // Elegant Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.7), Color.white.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.vertical, 8)
                
                // Period Selection with improved design
                VStack(spacing: 10) {
                    ForEach(SubscriptionView.SubscriptionPeriod.allCases, id: \.title) { period in
                        let priceInfo = getPriceInfo(for: period)
                        
                        Button(action: {
                            selectedPeriod = period
                            onPeriodChanged(period)
                            // Button text will automatically update due to getButtonText() being called in the button
                        }) {
                            HStack(spacing: 14) {
                                // Compact Radio button circle
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 18, height: 18)
                                        )
                                    
                                    if selectedPeriod == period {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 10, height: 10)
                                            .scaleEffect(selectedPeriod == period ? 1.0 : 0.8)
                                            .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
                                    }
                                }
                                
                                // Period text
                                Text(period.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                // Savings badge (if applicable)
                                if let savings = priceInfo.savings {
                                    Text(savings)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.25))
                                        )
                                }
                                
                                Spacer()
                                
                                // Price
                                Text(priceInfo.price)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPeriod == period ? Color.white.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(pricesLoading)
                    }
                }
                .padding(.top, 6)
                
                // Enhanced Subscribe Button with dynamic text (Android parity)
                Button(action: onSubscribe) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("dark")))
                                .scaleEffect(0.9)
                        }
                        Text(getButtonText())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .tracking(0.5)
                            .id(subscriptionUpdateTrigger) // Force update when subscription changes
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("Background Color"))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .scaleEffect(isLoading ? 0.98 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isLoading)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || pricesLoading)
                .padding(.top, 12)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: tier.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            // Update button text when subscription status changes
            subscriptionUpdateTrigger = UUID()
            AppLogger.log(tag: "LOG-APP: SubscriptionTierCard", message: "onReceive() Subscription status changed - updating button text for \(tier.title)")
        }
    }
}

#Preview {
    NavigationView {
        SubscriptionView()
    }
}

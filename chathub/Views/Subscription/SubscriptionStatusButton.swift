import SwiftUI

/**
 * Dynamic subscription status button that matches Android MainActivity behavior
 * Shows subscription status in top right corner of main view
 * - For non-subscribers: Shows "Subscriptions" with default styling
 * - For subscribers: Shows tier-specific text with gradient background
 * - Automatically updates when subscription status changes
 */
struct SubscriptionStatusButton: View {
    @Binding var showSubscriptionView: Bool
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    @State private var subscriptionState: SubscriptionState?
    
    // Computed properties matching Android logic
    private var isSubscribed: Bool {
        guard let state = subscriptionState else { return false }
        return state.isActive && state.tier != SubscriptionConstants.TIER_NONE
    }
    
    private var displayText: String {
        guard let state = subscriptionState, isSubscribed else {
            return "Subscriptions"
        }
        
        switch state.tier.lowercased() {
        case SubscriptionConstants.TIER_LITE:
            return "Lite Subscription"
        case SubscriptionConstants.TIER_PLUS:
            return "Plus Subscription"
        case SubscriptionConstants.TIER_PRO:
            return "Pro Subscription"
        default:
            return "Subscriptions"
        }
    }
    
    @ViewBuilder
    private var buttonIcon: some View {
        if isSubscribed {
            // Premium icon with tier-specific styling
            Image("ic_subscription")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
        } else {
            // Default subscription icon
            Image(systemName: "star.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color("orange_900"))
                .font(.system(size: 20, weight: .medium))
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        if isSubscribed, let state = subscriptionState {
            // Tier-specific gradient background
            getTierGradient(for: state.tier)
        } else {
            // Default background
            Capsule()
                .fill(Color("buy_coins_deep_orange_50"))
        }
    }
    
    private var textColor: Color {
        return isSubscribed ? .white : Color("dark")
    }
    
    var body: some View {
        Button(action: {
            AppLogger.log(tag: "LOG-APP: SubscriptionStatusButton", message: "subscriptionButtonTapped() Subscription button tapped")
            showSubscriptionView = true
        }) {
            HStack(spacing: 4) {
                buttonIcon
                
                Text(displayText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
        }
        .background(buttonBackground)
        .onAppear {
            updateSubscriptionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            updateSubscriptionState()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSubscriptionState() {
        AppLogger.log(tag: "LOG-APP: SubscriptionStatusButton", message: "updateSubscriptionState() Updating subscription state")
        subscriptionState = subscriptionSessionManager.getCurrentSubscriptionState()
    }
    
    @ViewBuilder
    private func getTierGradient(for tier: String) -> some View {
        switch tier.lowercased() {
        case SubscriptionConstants.TIER_LITE:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case SubscriptionConstants.TIER_PLUS:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case SubscriptionConstants.TIER_PRO:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color("proGradientStart"), Color("proGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        default:
            Capsule()
                .fill(Color("buy_coins_deep_orange_50"))
        }
    }
}



// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State var showSubscriptionView = false
        
        var body: some View {
            SubscriptionStatusButton(showSubscriptionView: $showSubscriptionView)
                .padding()
                .background(Color("Background Color"))
        }
    }
    
    return PreviewWrapper()
} 
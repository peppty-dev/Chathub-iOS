import SwiftUI

// MARK: - LiveCallPopupView (Android Parity)
// Matches showNewMonetizationDialogForDirectCalls(false) from Android
struct LiveCallPopupView: View {
    @Binding var isPresented: Bool
    
    var onSubscribe: () -> Void
    
    // Pricing information for Plus subscription
    private func getPlusSubscriptionPrice() -> String? {
        let subscriptionsManager = SubscriptionsManagerStoreKit2.shared
        let productId = "com.peppty.ChatApp.plus.weekly" // Use weekly for pricing display
        
        if let cachedPrice = subscriptionsManager.getCachedFormattedPrice(productId: productId, period: "weekly") {
            return cachedPrice
        }
        
        AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "getPlusSubscriptionPrice() No cached price available for Plus subscription")
        return nil
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Static title and description - refined hierarchy
                    VStack(spacing: 12) {
                        Text("Unlock Live")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        Text("To use live feature, you need ChatHub Plus or higher subscription. Upgrade now to enjoy unlimited live feature access.")
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade_800"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        // Lite Subscription Button with matching gradient
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "subscribeButtonTapped() Subscribe button tapped")
                            onSubscribe()
                            isPresented = false
                        }) {
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
                                
                                // Right side - pricing when available with pill background, invisible text when not
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
            AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "onAppear() Popup displayed")
            
            // Track pricing display if available
            if let price = getPlusSubscriptionPrice() {
                AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "Pricing displayed: \(price)")
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "onDisappear() Popup dismissed")
        }
    }
}

// MARK: - Preview
struct LiveCallPopupView_Previews: PreviewProvider {
    static var previews: some View {
        LiveCallPopupView(
            isPresented: .constant(true),
            onSubscribe: { print("Subscribe") }
        )
        .background(Color.black.opacity(0.4))
    }
} 
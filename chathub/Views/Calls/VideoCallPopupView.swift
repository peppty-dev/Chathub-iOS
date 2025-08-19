import SwiftUI

// MARK: - VideoCallPopupView (Android Parity)
// Matches showNewMonetizationDialogForCalls(false) from Android
struct VideoCallPopupView: View {
    @Binding var isPresented: Bool
    
    var onSubscribe: () -> Void
    
    // Pricing information for Pro subscription
    private func getProSubscriptionPrice() -> String? {
        let subscriptionsManager = SubscriptionsManagerStoreKit2.shared
        let productId = "com.peppty.ChatApp.pro.weekly" // Use weekly for pricing display
        
        if let cachedPrice = subscriptionsManager.getCachedFormattedPrice(productId: productId, period: "weekly") {
            return cachedPrice
        }
        
        AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "getProSubscriptionPrice() No cached price available for Pro subscription")
        return nil
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Static title and description - refined hierarchy
                    VStack(spacing: 12) {
                        Text("Unlock Video Calls")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        Text("To make video calls, you need ChatHub Pro subscription. Upgrade now to enjoy unlimited video calls.")
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
                            AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "subscribeButtonTapped() Subscribe button tapped")
                            onSubscribe()
                            isPresented = false
                        }) {
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
            AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "onAppear() Popup displayed")
            
            // Track pricing display if available
            if let price = getProSubscriptionPrice() {
                AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "Pricing displayed: \(price)")
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: VideoCallPopupView", message: "onDisappear() Popup dismissed")
        }
    }
}

// MARK: - Preview
struct VideoCallPopupView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCallPopupView(
            isPresented: .constant(true),
            onSubscribe: { print("Subscribe") }
        )
        .background(Color.black.opacity(0.4))
    }
} 
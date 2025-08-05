import SwiftUI
import Foundation

struct SubscriptionPopupView: View {
    // MARK: - Properties
    
    let tier: SubscriptionTier
    let title: String
    let infoText: String
    
    let watchAdButtonText: String
    let showWatchAdButton: Bool
    var onWatchAd: () -> Void
    
    let subscribeButtonText: String
    var onSubscribe: () -> Void
    
    // Using a binding to control the visibility of the popup
    @Binding var isPresented: Bool

    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: SubscriptionPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container - following guidelines structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Title - no banner ads in popups per guidelines
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16) // layout_marginTop="16dp"
                    
                    // Description text - following guidelines specifications
                    Text(infoText)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4) // lineSpacingExtra="4dp"
                        .padding(.horizontal, 32) // layout_marginHorizontal="32dp"
                        .padding(.top, 16) // layout_marginTop="16dp"
                        .padding(.bottom, 24) // layout_marginBottom="24dp"
                    
                    // Watch Ad Button - if available (following guidelines pattern)
                    if showWatchAdButton {
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: SubscriptionPopupView", message: "primaryButtonTapped() Watch ad button tapped")
                            onWatchAd()
                            isPresented = false
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.tv")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Text(watchAdButtonText)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // gravity="start|center"
                            .frame(minHeight: 56) // minHeight="56dp"
                            .padding(.horizontal, 12) // Internal padding
                            .background(Color("Online")) // Primary action color
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                        .padding(.bottom, 8) // layout_marginBottom="8dp"
                    }
                    
                    // Subscribe Button - following guidelines pattern
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: SubscriptionPopupView", message: "secondaryButtonTapped() Subscribe button tapped")
                        onSubscribe()
                        isPresented = false
                    }) {
                        HStack(spacing: 12) {
                            Image("ic_subscription")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18) // Custom icon size per guidelines
                                .foregroundColor(.white)
                            
                            Text(subscribeButtonText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // gravity="start|center"
                        .frame(minHeight: 56) // minHeight="56dp"
                        .padding(.horizontal, 12) // Internal padding
                        .background(getSubscriptionGradient())
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                    .padding(.top, 8) // layout_marginTop="8dp"
                    .padding(.bottom, 5) // layout_marginBottom="5dp"
                }
                .frame(maxWidth: .infinity) // Fill screen width per guidelines
                .padding(.top, 24)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                )
                .padding(.horizontal, 24) // Horizontal spacing from screen edges
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: SubscriptionPopupView", message: "onAppear() Popup displayed")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: SubscriptionPopupView", message: "onDisappear() Popup dismissed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSubscriptionGradient() -> some View {
        switch tier {
        case .lite:
            return LinearGradient(
                colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .plus:
            return LinearGradient(
                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .pro:
            return LinearGradient(
                colors: [Color("Red1"), Color("redA7")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Preview
struct SubscriptionPopupView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPopupView(
            tier: .pro,
            title: "Subscribe to PRO",
            infoText: "Unlock all premium features with our Pro subscription.",
            watchAdButtonText: "Watch Ad - FREE",
            showWatchAdButton: true,
            onWatchAd: { print("Watch Ad") },
            subscribeButtonText: "SUBSCRIBE TO CHATHUB PRO",
            onSubscribe: { print("Subscribe") },
            isPresented: .constant(true)
        )
        .background(Color.black.opacity(0.4))
    }
} 
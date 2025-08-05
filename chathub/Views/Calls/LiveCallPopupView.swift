import SwiftUI

// MARK: - LiveCallPopupView (Android Parity)
// Matches showNewMonetizationDialogForDirectCalls(false) from Android
struct LiveCallPopupView: View {
    @Binding var isPresented: Bool
    
    var onSubscribe: () -> Void
    
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
                Spacer() // Center vertically
                
                // Popup content
                VStack(spacing: 0) {
                    // Title
                    Text("Unlock Live")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    
                    // Description text
                    Text("To use Live calls, you need ChatHub Plus or Pro Subscription. Upgrade now to enjoy unlimited live calls and other premium features.")
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    
                    // Subscribe Button (Plus subscription)
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "subscribeButtonTapped() Subscribe button tapped")
                        onSubscribe()
                        isPresented = false
                    }) {
                        HStack(spacing: 12) {
                            Image("buy")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                            
                            VStack(spacing: 2) {
                                Text("SUBSCRIBE TO CHATHUB PLUS")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let price = getPlusSubscriptionPrice(), !price.isEmpty {
                                    Text(price)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 56)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(
                                colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "onAppear() Popup displayed")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: LiveCallPopupView", message: "onDisappear() Popup dismissed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPlusSubscriptionPrice() -> String? {
        // TODO: Implement proper price fetching from actual App Store Connect pricing
        // Return nil if no price is available
        return nil // No default price
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
import SwiftUI

// MARK: - ChatPayPopupView (Android Parity)
// Matches dialog_pay_to_chat.xml exactly
struct StartConversationPopUpView: View {
    @Binding var isPresented: Bool
    
    let otherUserId: String
    let otherUserName: String
    let otherUserGender: String
    let otherUserImage: String
    let otherUserDevId: String
    let coins: Int
    let freeMessage: Bool
    
    var onFreeChat: () -> Void
    var onWatchAd: () -> Void
    var onSubscribe: () -> Void
    
    @State private var isDirectMessageReady = false
    @State private var timerText = "Direct Message available in 30s"
    @State private var countdown = 30
    @State private var countdownTimer: Timer?
    
    // Computed property for free message availability based on Android parity
    private var isFreeMessageAvailable: Bool {
        // Check policy violation flags like Android
        let timeMismatched = UserDefaults.standard.bool(forKey: "time_mismatched_sb")
        let multipleReports = UserDefaults.standard.bool(forKey: "multiple_reports_sb")
        let textModerationIssue = UserDefaults.standard.bool(forKey: "text_moderation_issue_sb")
        
        // If any policy violation exists, free messages are not available
        if timeMismatched || multipleReports || textModerationIssue {
            return false
        }
        
        return freeMessage
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "backgroundTapped() Dismissing popup")
                    countdownTimer?.invalidate()
                    isPresented = false
                }
            
            // Main popup container - following guidelines structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Title - changed from "Chat" to "Start Conversation"
                    Text("Start Conversation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16) // layout_marginTop="16dp"
                    
                    // Description text - following guidelines specifications
                    Text(getInfoText())
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4) // lineSpacingExtra="4dp"
                        .padding(.horizontal, 32) // layout_marginHorizontal="32dp"
                        .padding(.top, 16) // layout_marginTop="16dp"
                        .padding(.bottom, 24) // layout_marginBottom="24dp"
                    
                    // Free Chat Button - if available (following guidelines pattern with policy check)
                    if isFreeMessageAvailable {
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "freeChatButtonTapped() Free chat button tapped")
                            countdownTimer?.invalidate()
                            onFreeChat()
                            isPresented = false
                        }) {
                            HStack(spacing: 12) {
                                Image("free")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.white)
                                
                                Text("Inbox Message - FREE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // gravity="start|center"
                            .frame(minHeight: 56) // minHeight="56dp"
                            .padding(.horizontal, 12) // Internal padding
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                        .padding(.bottom, 8) // layout_marginBottom="8dp"
                    }
                    
                    // Direct Message Button (Timer-based) - following guidelines pattern
                    Button(action: {
                        if isDirectMessageReady {
                            AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "directMessageButtonTapped() Direct message button tapped")
                            countdownTimer?.invalidate()
                            onWatchAd() // Keep the same callback for compatibility
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "message")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            Text(isDirectMessageReady ? "Direct Message - FREE" : timerText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // gravity="start|center"
                        .frame(minHeight: 56) // minHeight="56dp"
                        .padding(.horizontal, 12) // Internal padding
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .opacity(isDirectMessageReady ? 1.0 : 0.5)
                    }
                    .disabled(!isDirectMessageReady)
                    .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                    .padding(.bottom, 8) // layout_marginBottom="8dp"
                    
                    // Subscribe Button - following guidelines pattern
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "subscribeButtonTapped() Subscribe button tapped")
                        countdownTimer?.invalidate()
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
                            
                            VStack(spacing: 2) {
                                Text("Direct Message - Subscribe to ChatHub Pro")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let proPrice = getProSubscriptionPrice(), !proPrice.isEmpty {
                                    Text(proPrice)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // gravity="start|center"
                        .frame(minHeight: 56) // minHeight="56dp"
                        .padding(.horizontal, 12) // Internal padding
                        .background(
                            LinearGradient(
                                colors: [Color("proGradientStart"), Color("proGradientEnd")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPresented) // Faster, snappier animation
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "onAppear() Popup displayed")
            // Start timer for direct message availability
            DispatchQueue.main.async {
                startDirectMessageTimer()
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "onDisappear() Popup dismissed")
            countdownTimer?.invalidate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getInfoText() -> String {
        if !isFreeMessageAvailable {
            return "Choose how to message: Send a Free Message (inbox, no notification) or a Direct Message (chat box, with notification) after a short timer or by subscribing.\n\nFree messages are temporarily not available due to policy violation, other app promotions."
        } else {
            return "Choose how to message: Send a Free Message (inbox, no notification) or a Direct Message (chat box, with notification) after a short timer or by subscribing."
        }
    }
    
    private func startDirectMessageTimer() {
        AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "startDirectMessageTimer() Starting 30 second countdown")
        
        countdown = 30
        timerText = "Direct Message available in 30s"
        isDirectMessageReady = false
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
                timerText = "Direct Message available in \(countdown)s"
                AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "startDirectMessageTimer() Countdown: \(countdown)")
            } else {
                // Countdown finished, direct message is now available
                isDirectMessageReady = true
                timerText = "Direct Message - FREE"
                timer.invalidate()
                AppLogger.log(tag: "LOG-APP: StartConversationPopUpView", message: "startDirectMessageTimer() Countdown finished, direct message available")
            }
        }
    }
    
    private func getProSubscriptionPrice() -> String? {
        // TODO: Implement proper price fetching from actual App Store Connect pricing
        // Return nil if no price is available
        return nil // No default price
    }
}

struct ChatPayPopupView_Previews: PreviewProvider {
    static var previews: some View {
        StartConversationPopUpView(
            isPresented: .constant(true),
            otherUserId: "test123",
            otherUserName: "Test User",
            otherUserGender: "Male",
            otherUserImage: "",
            otherUserDevId: "device123",
            coins: 3,
            freeMessage: true,
            onFreeChat: { print("Free Chat") },
            onWatchAd: { print("Watch Ad") },
            onSubscribe: { print("Subscribe") }
        )
        .background(Color.black.opacity(0.4))
    }
} 

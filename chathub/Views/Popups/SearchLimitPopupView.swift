import SwiftUI

struct SearchLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onSearch: () -> Void
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var remainingTime: TimeInterval
    
    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onSearch: @escaping () -> Void,
         onUpgradeToPremium: @escaping () -> Void) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onSearch = onSearch
        self.onUpgradeToPremium = onUpgradeToPremium
        self._remainingTime = State(initialValue: remainingCooldown)
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    dismissPopup()
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Title and description
                    VStack(spacing: 12) {
                        Text("Search Users")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if isLimitReached {
                            VStack(spacing: 8) {
                                Text("You've reached your limit of \(limit) free searches.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if remainingTime > 0 {
                                    Text("Please wait \(formatTime(remainingTime)) or upgrade to Premium for unlimited searches.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            Text("Find specific people! You have \(limit - currentUsage) free searches remaining.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Timer display (if in cooldown)
                    if isLimitReached && remainingTime > 0 {
                        VStack(spacing: 8) {
                            Text("Time Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(remainingTime))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.teal)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.teal.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 16)
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        // Search Button
                        Button(action: searchAction) {
                            HStack {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.title3)
                                Text("Search Users")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isLimitReached && remainingTime > 0 ? [Color.gray, Color.gray] : [Color.teal, Color.teal.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isLimitReached && remainingTime > 0)
                        
                        // Premium Upgrade Button
                        Button(action: upgradeToPremiumAction) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .font(.title3)
                                Text("Get Premium Plus")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            startCountdownTimer()
            AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
        }
    }
    
    private func searchAction() {
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "searchAction() Search tapped")
        dismissPopup()
        onSearch()
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: SearchLimitPopupView", message: "upgradeToPremiumAction() Premium upgrade tapped")
        dismissPopup()
        onUpgradeToPremium()
    }
    
    private func dismissPopup() {
        stopCountdownTimer()
        isPresented = false
    }
    
    private func startCountdownTimer() {
        guard isLimitReached && remainingCooldown > 0 else { return }
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                stopCountdownTimer()
                dismissPopup()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview
struct SearchLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        SearchLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 90,
            isLimitReached: true,
            currentUsage: 15,
            limit: 15,
            onSearch: { print("Search") },
            onUpgradeToPremium: { print("Upgrade to premium") }
        )
    }
}
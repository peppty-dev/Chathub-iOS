import SwiftUI

struct FilterLimitPopupView: View {
    @Binding var isPresented: Bool
    
    let remainingCooldown: TimeInterval
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    
    var onApplyFilter: () -> Void
    var onUpgradeToPremium: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var remainingTime: TimeInterval
    
    init(isPresented: Binding<Bool>, 
         remainingCooldown: TimeInterval,
         isLimitReached: Bool,
         currentUsage: Int,
         limit: Int,
         onApplyFilter: @escaping () -> Void,
         onUpgradeToPremium: @escaping () -> Void) {
        self._isPresented = isPresented
        self.remainingCooldown = remainingCooldown
        self.isLimitReached = isLimitReached
        self.currentUsage = currentUsage
        self.limit = limit
        self.onApplyFilter = onApplyFilter
        self.onUpgradeToPremium = onUpgradeToPremium
        self._remainingTime = State(initialValue: remainingCooldown)
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: FilterLimitPopupView", message: "backgroundTapped() Dismissing popup")
                    dismissPopup()
                }
            
            // Main popup container
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Title and description
                    VStack(spacing: 12) {
                        Text("Apply Filters")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if isLimitReached {
                            VStack(spacing: 8) {
                                Text("You've reached your limit of \(limit) free filter applications.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if remainingTime > 0 {
                                    Text("Please wait \(formatTime(remainingTime)) or upgrade to Premium for unlimited filters.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            Text("Find your perfect match! You have \(limit - currentUsage) free filter applications remaining.")
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
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.indigo.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 16)
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        // Apply Filter Button
                        Button(action: applyFilterAction) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                Text("Apply Filters")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isLimitReached && remainingTime > 0 ? [Color.gray, Color.gray] : [Color.indigo, Color.indigo.opacity(0.8)]),
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
            AppLogger.log(tag: "LOG-APP: FilterLimitPopupView", message: "onAppear() Popup shown - limit reached: \(isLimitReached), remaining: \(remainingTime)s")
        }
        .onDisappear {
            stopCountdownTimer()
        }
    }
    
    private func applyFilterAction() {
        AppLogger.log(tag: "LOG-APP: FilterLimitPopupView", message: "applyFilterAction() Apply filter tapped")
        dismissPopup()
        onApplyFilter()
    }
    
    private func upgradeToPremiumAction() {
        AppLogger.log(tag: "LOG-APP: FilterLimitPopupView", message: "upgradeToPremiumAction() Premium upgrade tapped")
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
struct FilterLimitPopupView_Previews: PreviewProvider {
    static var previews: some View {
        FilterLimitPopupView(
            isPresented: .constant(true),
            remainingCooldown: 240,
            isLimitReached: true,
            currentUsage: 8,
            limit: 8,
            onApplyFilter: { print("Apply filter") },
            onUpgradeToPremium: { print("Upgrade to premium") }
        )
    }
}
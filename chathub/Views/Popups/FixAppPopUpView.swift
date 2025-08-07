import SwiftUI


struct FixAppPopUpView: View {
    let onFix: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "onTapGesture() background tapped, dismissing popup")
                    dismissPopup()
                }
            
            VStack(spacing: 0) {
                // Fix App Container
                VStack(spacing: 0) {
                    VStack(spacing: 20) {
                        // Title
                        Text("Fix App")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Description
                        Text("Fixing app will clear all the local stored data. You might lose your old chats and messages.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Fix Now Button
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "fixNowTapped() fix now button tapped")
                            fixAppData()
                            onFix?()
                            dismissPopup()
                        }) {
                            Text("FIX NOW")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 15)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 15)
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "onAppear() popup appeared")
        }
    }
    
    private func fixAppData() {
        AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "fixAppData() starting app data cleanup")
        
        // Use AsyncClass to properly clear all database tables
        DatabaseCleanupService.shared.deleteDatabase()
        
        // Clear welcome data (UserDefaults)
        clearWelcomeData()
        
        // Show success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "fixAppData() app data cleared successfully")
        }
    }
    
    private func clearWelcomeData() {
        AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "clearWelcomeData() clearing welcome data")
        
        // Set early date in UserDefaults (migrated from Core Data Welcome entity)
        let earlyDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        UserDefaults.standard.set(earlyDate, forKey: "welcome_date")
        UserDefaults.standard.synchronize()
        
        AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "clearWelcomeData() welcome date set to early date in UserDefaults")
    }
    
    private func dismissPopup() {
        AppLogger.log(tag: "LOG-APP: FixAppPopUpView", message: "dismissPopup() dismissing popup")
        dismiss()
    }
}

#Preview {
    FixAppPopUpView(
        onFix: {
            print("Fix tapped")
        }
    )
} 
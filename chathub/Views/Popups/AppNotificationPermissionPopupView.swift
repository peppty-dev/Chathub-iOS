import SwiftUI
import UserNotifications

struct AppNotificationPermissionPopupView: View {
    @Binding var isPresented: Bool
    
    var onAllow: () -> Void
    var onMaybeLater: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by tapping outside
                    onMaybeLater()
                }
            
            // Main popup container
            VStack(spacing: 0) {
                // Title - matching ConversationLimitPopupView
                Text("Enable Notifications")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .padding(.top, 24)
                
                // Description - matching ConversationLimitPopupView spacing
                Text("Get notified of new messages and calls so you never miss important conversations.")
                    .font(.system(size: 14))
                    .foregroundColor(Color("shade_800"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                
                // Button - matching ConversationLimitPopupView style exactly
                VStack(spacing: 12) {
                    // Allow Notifications Button (no arrow, proper height)
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: NotificationPermissionPopup", message: "allowNotifications() User agreed to allow notifications")
                        triggerHapticFeedback()
                        onAllow()
                    }) {
                        HStack(spacing: 0) {
                            // Left side - icon and text (matching ConversationLimitPopupView pattern)
                            HStack(spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                Text("Allow Notifications")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)  // Matching ConversationLimitPopupView height
                        .padding(.horizontal, 12)  // Matching ConversationLimitPopupView padding
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("ColorAccent"))
                        )
                    }
                    
                    // Removed "Maybe Later" button completely
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(Color("shade2"))  // Matching ConversationLimitPopupView background
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)  // Matching ConversationLimitPopupView stroke
            )
            .padding(.horizontal, 20)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24, alignment: .leading)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct NotificationPermissionPopupView_Previews: PreviewProvider {
    static var previews: some View {
        AppNotificationPermissionPopupView(
            isPresented: .constant(true),
            onAllow: {
                print("Allow notifications")
            },
            onMaybeLater: {
                print("Maybe later")  // Still needed for background tap dismissal
            }
        )
        .preferredColorScheme(.light)
        
        AppNotificationPermissionPopupView(
            isPresented: .constant(true),
            onAllow: {
                print("Allow notifications")
            },
            onMaybeLater: {
                print("Maybe later")  // Still needed for background tap dismissal
            }
        )
        .preferredColorScheme(.dark)
    }
}
#endif 

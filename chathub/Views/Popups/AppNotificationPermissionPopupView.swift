import SwiftUI
import UserNotifications

struct AppNotificationPermissionPopupView: View {
    @Binding var isPresented: Bool
    
    var onAllow: () -> Void
    var onMaybeLater: () -> Void
    
    // Retry context detection
    private var isRetryScenario: Bool {
        AppNotificationPermissionService.shared.shouldShowRetryPopup()
    }
    
    private var retryAttempt: Int {
        UserDefaults.standard.integer(forKey: "notification_retry_attempt_count")
    }
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by tapping outside
                    onMaybeLater()
                }
            
            // Main popup content
            VStack(spacing: 0) {
                // Header section with icon and title
                VStack(spacing: 16) {
                    // Notification icon with message context
                    ZStack {
                        Circle()
                            .fill(Color("ColorAccent").opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color("ColorAccent"))
                            
                            Image(systemName: "arrow.up.message.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("ColorAccent"))
                                .opacity(0.7)
                        }
                    }
                    
                    // Title - Dynamic based on retry context
                    Text(isRetryScenario ? "Still missing replies? 🔔" : "Great! Your message was sent! 🎉")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Explanation section
                VStack(spacing: 16) {
                    Text(isRetryScenario ? "Don't miss important messages" : "Stay in the conversation")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("dark"))
                    
                    VStack(spacing: 12) {
                        FeatureRow(
                            icon: "message.badge.fill",
                            text: isRetryScenario ? "You've been chatting - get notified when they reply!" : "Get notified when they reply to your message",
                            color: Color("ColorAccent")
                        )
                        
                        FeatureRow(
                            icon: "person.badge.plus.fill",
                            text: "Never miss new friend requests",
                            color: Color("ColorAccent")
                        )
                        
                        FeatureRow(
                            icon: "phone.badge.plus.fill",
                            text: "Instant alerts for incoming calls",
                            color: Color("ColorAccent")
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
                
                // Action buttons
                VStack(spacing: 12) {
                    // Primary button - Allow notifications
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: NotificationPermissionPopup", message: "allowNotifications() User agreed to allow notifications")
                        triggerHapticFeedback()
                        onAllow()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Allow Notifications")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("ColorAccent"))
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Secondary button - Maybe later
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: NotificationPermissionPopup", message: "maybeLater() User chose maybe later")
                        triggerHapticFeedback()
                        onMaybeLater()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("shade7"))
                            .frame(height: 44)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color("shade2"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
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
                print("Maybe later")
            }
        )
        .preferredColorScheme(.light)
        
        AppNotificationPermissionPopupView(
            isPresented: .constant(true),
            onAllow: {
                print("Allow notifications")
            },
            onMaybeLater: {
                print("Maybe later")
            }
        )
        .preferredColorScheme(.dark)
    }
}
#endif 

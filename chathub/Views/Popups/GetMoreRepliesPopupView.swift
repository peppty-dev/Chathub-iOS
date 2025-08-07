import SwiftUI

struct GetMoreRepliesPopupView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: GetMoreRepliesPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container - following guidelines structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Icon - using message icon to represent messaging feature
                    Image(systemName: "message.badge.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color("ColorAccent"))
                        .padding(.top, 24)
                    
                    // Title - following guidelines
                    Text("Get More Replies")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    
                    // Description text - following guidelines specifications
                    Text("When you subscribe, your messages go through fewer filters when starting new conversations. This means your messages are more likely to reach other users directly, increasing your chances of getting replies and having meaningful conversations.")
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    
                    // Benefits list with icons
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("Fewer message filters applied")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("Higher chance of message delivery")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("More replies from other users")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    
                    // OK Button - following guidelines pattern
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: GetMoreRepliesPopupView", message: "okButtonTapped() OK button tapped")
                        isPresented = false
                    }) {
                        Text("Got it!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .background(Color("ColorAccent"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: GetMoreRepliesPopupView", message: "onAppear() Popup displayed")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: GetMoreRepliesPopupView", message: "onDisappear() Popup dismissed")
        }
    }
}

struct GetMoreRepliesPopupView_Previews: PreviewProvider {
    static var previews: some View {
        GetMoreRepliesPopupView(
            isPresented: .constant(true)
        )
    }
} 
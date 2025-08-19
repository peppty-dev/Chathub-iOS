import SwiftUI

struct HideYourStatusPopupView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: HideYourStatusPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container - following guidelines structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Icon - using eye.slash icon to represent hiding status
                    Image(systemName: "eye.slash.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color("ColorAccent"))
                        .padding(.top, 24)
                    
                    // Title - following guidelines
                    Text("Hide Your Status")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    
                    // Description text - explaining the feature
                    Text("When you subscribe, your chatting status will be hidden from others. Without this feature, when you chat with someone, it becomes visible to other users that you are currently in a conversation.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    
                    // Benefits list - similar to Get More Replies popup
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("Chat privately without others knowing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("Enhanced privacy protection")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 16))
                            
                            Text("No interruptions from other users")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("dark"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    
                    // OK Button - following guidelines pattern
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: HideYourStatusPopupView", message: "okButtonTapped() OK button tapped")
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
            AppLogger.log(tag: "LOG-APP: HideYourStatusPopupView", message: "onAppear() Popup displayed")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: HideYourStatusPopupView", message: "onDisappear() Popup dismissed")
        }
    }
}

struct HideYourStatusPopupView_Previews: PreviewProvider {
    static var previews: some View {
        HideYourStatusPopupView(
            isPresented: .constant(true)
        )
    }
}

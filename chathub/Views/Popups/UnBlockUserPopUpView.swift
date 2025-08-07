import SwiftUI

struct UnBlockUserPopUpView: View {
    let userName: String
    @Binding var isPresented: Bool
    var onUnblock: (() -> Void)?
    var onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: UnBlockUserPopUpView", message: "onTapGesture() background tapped, dismissing popup")
                    dismissPopup()
                }
            
            VStack(spacing: 0) {
                // Unblock Confirmation Container
                VStack(spacing: 0) {
                    
                    VStack(spacing: 15) {
                        // Title
                        Text("Unblock user")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Description
                        Text("Do you want to unblock user ?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Unblock Button
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: UnBlockUserPopUpView", message: "unblockTapped() unblock button tapped for user: \(userName)")
                            onUnblock?()
                            dismissPopup()
                        }) {
                            Text("Unblock")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 20)
                        
                        // Cancel Button
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: UnBlockUserPopUpView", message: "cancelTapped() cancel button tapped")
                            onCancel?()
                            dismissPopup()
                        }) {
                            Text("Cancel")
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
            AppLogger.log(tag: "LOG-APP: UnBlockUserPopUpView", message: "onAppear() popup appeared for user: \(userName)")
        }
    }
    
    private func dismissPopup() {
        AppLogger.log(tag: "LOG-APP: UnBlockUserPopUpView", message: "dismissPopup() dismissing popup")
        isPresented = false
    }
}

struct UnBlockUserPopUpView_Previews: PreviewProvider {
    static var previews: some View {
        UnBlockUserPopUpView(
            userName: "TestUser",
            isPresented: .constant(true),
            onUnblock: {
                print("Unblock tapped")
            },
            onCancel: {
                print("Cancel tapped")
            }
        )
        .previewLayout(.sizeThatFits)
    }
} 
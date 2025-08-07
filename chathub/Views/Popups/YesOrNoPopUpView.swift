import SwiftUI

struct YesOrNoPopUpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let title: String
    let description: String
    let buttonTitle: String
    let onConfirm: (([String]) -> Void)?
    let onCancel: (() -> Void)?
    
    init(title: String, description: String, buttonTitle: String, onConfirm: (([String]) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "backgroundTapped() Dismissing popup")
                    dismissPopup()
                }
            
            // Main popup container - following guidelines structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Title - no banner ads in popups per guidelines
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16) // layout_marginTop="16dp"
                    
                    // Description text - following guidelines specifications
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4) // lineSpacingExtra="4dp"
                        .padding(.horizontal, 32) // layout_marginHorizontal="32dp"
                        .padding(.top, 16) // layout_marginTop="16dp"
                        .padding(.bottom, 24) // layout_marginBottom="24dp"
                    
                    // Button container
                    HStack(spacing: 12) {
                        // Cancel Button - secondary style
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "cancelButtonTapped() Cancel button tapped")
                            onCancel?()
                            dismissPopup()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color("dark"))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 56) // minHeight="56dp"
                                .background(Color("shade2"))
                                .cornerRadius(12)
                        }
                        
                        // Confirm Button - primary action style
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "confirmButtonTapped() Confirm button tapped")
                            onConfirm?([title, buttonTitle])
                            dismissPopup()
                        }) {
                            Text(buttonTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 56) // minHeight="56dp"
                                .background(Color("Red1"))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                    .padding(.bottom, 8) // layout_marginBottom="8dp"
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
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: true)
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "onAppear() Popup displayed")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "onDisappear() Popup dismissed")
        }
    }
    
    private func dismissPopup() {
        AppLogger.log(tag: "LOG-APP: YesOrNoPopUpView", message: "dismissPopup() Dismissing popup")
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    YesOrNoPopUpView(
        title: "Delete Chat",
        description: "Are you sure you want to delete this chat? This action cannot be undone.",
        buttonTitle: "Delete"
    ) { result in
        print("Popup result: \(result)")
    } onCancel: {
        print("Popup cancelled")
    }
} 
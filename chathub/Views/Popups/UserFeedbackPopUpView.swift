import SwiftUI
import FirebaseFirestore

struct UserFeedbackPopUpView: View {
    let otherDeviceId: String
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background overlay - tap to dismiss with enhanced contrast
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "onTapGesture() background tapped, dismissing popup")
                    dismissPopup()
                }
            
            VStack(spacing: 0) {
                // Feedback Container
                VStack(spacing: 0) {
                    // Title
                    Text("Feedback")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .padding(.top, 15)
                        .padding(.horizontal, 40)
                    
                    // Description
                    Text("Give feedback about this person. This feedback will be shown to all the other strangers on this persons profile")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 15)
                        .padding(.horizontal, 20)
                    
                    // Good Experience Button
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "goodExperienceAction() good experience button tapped")
                        submitFeedback(isGood: true)
                    }) {
                        Text("Good Experience")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Bad Experience Button
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "badExperienceAction() bad experience button tapped")
                        submitFeedback(isGood: false)
                    }) {
                        Text("Bad Experience")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
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
    }
    
    // MARK: - Helper Functions
    private func submitFeedback(isGood: Bool) {
        AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "submitFeedback() submitting \(isGood ? "good" : "bad") feedback for deviceId: \(otherDeviceId)")
        
        let db = Firestore.firestore()
        
        // Note: There's a bug in the original UIKit code where good/bad are swapped
        // Following the original logic for compatibility
        let fieldToIncrement = isGood ? "bad_experience" : "good_experience"
        let params: [String: Any] = [fieldToIncrement: FieldValue.increment(1.0)]
        
        db.collection("UserDevData").document(otherDeviceId).setData(params, merge: true) { error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "submitFeedback() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "submitFeedback() successfully submitted feedback")
                }
                
                dismissPopup()
            }
        }
    }
    
    private func dismissPopup() {
        AppLogger.log(tag: "LOG-APP: UserFeedbackPopUpView", message: "dismissPopup() closing feedback popup")
        
        onDismiss?()
        isPresented = false
    }
}

// MARK: - Preview
struct UserFeedbackPopUpView_Previews: PreviewProvider {
    static var previews: some View {
        UserFeedbackPopUpView(
            otherDeviceId: "sample_device_id",
            isPresented: .constant(true)
        )
    }
} 
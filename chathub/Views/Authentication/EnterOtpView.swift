import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct EnterOtpView: View {
    @State private var otp: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var isVerified: Bool = false
    var expectedOtp: String
    var email: String
    var password: String
    var onVerified: (() -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("Background Color")  // @color/background in Android
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // ScrollView content (matches Android ScrollView)
                    ScrollView {
                        VStack(spacing: 0) {
                            // Main form content with consistent styling
                            enterOtpContent()
                        }
                        .padding(.horizontal, 30)  // 30dp marginLeft marginRight in Android
                        .padding(.top, 20)  // 20dp marginTop in Android
                    }
                    .keyboardAdaptive()
                }
                .onTapGesture {
                    // ANDROID PARITY: Hide keyboard on tap outside like other views
                    hideKeyboard()
                }
                
                // Loading Overlay (matches Android ProgressBar)
                if isLoading {
                    loadingOverlay()
                }
            }
            .navigationTitle("Verify Email")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
        .alert("Success", isPresented: $isVerified) {
            Button("Continue") {
                onVerified?()
            }
        } message: {
            Text("Account Created")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func enterOtpContent() -> some View {
        VStack(spacing: 0) {
            // Description Section (no title since we have navigation title)
            VStack(spacing: 12) {
                Text("We sent you an email with verification code, please verify.")
                    .font(.system(size: 16))  // Consistent font size
                    .foregroundColor(Color("shade_600"))  // Subtle secondary text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)  // Extra padding for better readability
            }
            .padding(.bottom, 30)  // Consistent spacing
            
            // OTP Input Field with improved styling
            TextField("Enter verification code", text: $otp)
                .font(.system(size: 18, weight: .medium))  // Larger font for OTP
                .padding(.horizontal, 15)
                .frame(height: 56)  // Standard height for consistency
                .background(Color("shade_200"))  // Theme-aware background
                .cornerRadius(12)  // Rounded corners
                .foregroundColor(Color("dark"))  // Theme-aware text color
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)  // Center align OTP
                .autocorrectionDisabled()
                .onSubmit {
                    verifyOtp()
                }
                .onChange(of: otp) { newValue in
                    // Limit OTP to 4 digits
                    if newValue.count > 4 {
                        otp = String(newValue.prefix(4))
                    }
                }
            
            // Error Message with better styling
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color("ErrorRed"))
                        .font(.system(size: 14))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Color("ErrorRed"))
                    
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal, 4)
            }
            
            // Verify Button with improved styling
            Button(action: { 
                triggerHapticFeedback()
                verifyOtp()
            }) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text("Verifying...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                } else {
                    Text("Verify")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .background(isLoading ? Color("shade_300") : Color("ColorAccent"))
            .cornerRadius(12)
            .disabled(isLoading)
            .opacity(isLoading ? 0.5 : 1.0)
            .padding(.top, 30)  // Spacing from error message or input field
            
            // Info Text with better styling
            VStack(spacing: 8) {
                Text("Please check your email for the verification code")
                    .font(.system(size: 14))
                    .foregroundColor(Color("shade_600"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text("Make sure to check your spam folder if you don't see it in your inbox")
                    .font(.system(size: 12))
                    .foregroundColor(Color("shade_500"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            Spacer(minLength: 40)  // Bottom spacing
        }
    }
    
    @ViewBuilder
    private func loadingOverlay() -> some View {
        // Matches Android ProgressBar behavior - simple center overlay
        Color.black.opacity(0.3)
            .ignoresSafeArea(.all)
        
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color("ColorAccent")))
            .scaleEffect(1.2)
    }
    
    // MARK: - Helper Functions
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerHapticFeedback() {
        // Matching Android's AdMonetizationHelper.triggerHapticFeedback()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func verifyOtp() {
        AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "verifyOtp() tapped with entered OTP: \(otp)")
        
        // Clear previous error
        errorMessage = nil
        
        // Validate OTP input
        guard !otp.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter the OTP"
            return
        }
        
        isLoading = true
        
        if otp == expectedOtp {
            linkFirebaseAccount()
        } else {
            isLoading = false
            errorMessage = "Invalid OTP"
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "Invalid OTP entered.")
        }
    }
    
    private func linkFirebaseAccount() {
        AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "linkFirebaseAccount() called for email: \(email)")
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user session found."
            isLoading = false
            return
        }
        
        let authCredential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        // SECURITY FIX: Add timeout handling for Firebase email linking
        var timeoutCanceled = false
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            timeoutCanceled = true
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "Firebase email linking timeout after 30 seconds")
            errorMessage = "Authentication timeout. Please check your internet connection and try again."
            isLoading = false
        }
        
        user.link(with: authCredential) { authResult, error in
            timeoutTimer.invalidate()
            
            if timeoutCanceled { return }
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "linkFirebaseAccount() failed: \(error.localizedDescription)")
                
                // Handle specific error cases like UIKit version
                if (error as NSError).code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    errorMessage = "Email ID already registered"
                } else {
                    errorMessage = "Error creating account"
                }
                isLoading = false
                return
            }
            
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "linkFirebaseAccount() success")
            saveEmailInFirebase()
        }
    }
    
    private func saveEmailInFirebase() {
        AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveEmailInFirebase() called for email: \(email)")
        
        guard let userId = UserSessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "verifyEmailWithOtp() User ID not found in session")
            return
        }
        
        let data: [String: Any] = [
            "User_email": email,
            "User_password": password,
            "User_verified": true,
            "User_email_verified": true
        ]
        
        Firestore.firestore().collection("Users").document(userId).setData(data, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveEmailInFirebase() failed: \(error.localizedDescription)")
                errorMessage = "Error creating account"
                isLoading = false
                return
            }
            
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveEmailInFirebase() success")
            
            // Set UserDefaults like UIKit version
            UserSessionManager.shared.emailAddress = self.email
            UserSessionManager.shared.isAccountCreated = true
            UserSessionManager.shared.accountCreatedTime = Date().timeIntervalSince1970
            
            saveVerificationEmail()
        }
    }
    
    private func saveVerificationEmail() {
        AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveVerificationEmail() called for email: \(email)")
        
        guard let deviceId = UserSessionManager.shared.deviceId else {
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "sendOtp() Device ID not found in session")
            return
        }
        
        let data: [String: Any] = ["Verification_email": email]
        
        Firestore.firestore().collection("UserDevData").document(deviceId).collection("Verification").document(String(Date().timeIntervalSince1970)).setData(data, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveVerificationEmail() failed: \(error.localizedDescription)")
                errorMessage = "Error creating account"
                isLoading = false
                return
            }
            
            AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "saveVerificationEmail() success")
            
            // Complete UserDefaults setup
            UserSessionManager.shared.emailVerified = true
            
            isLoading = false
            isVerified = true
        }
    }
}

#Preview {
    EnterOtpView(expectedOtp: "1234", email: "test@example.com", password: "password123") {
        AppLogger.log(tag: "LOG-APP: EnterOtpView", message: "OTP Verified successfully")
    }
} 

import SwiftUI
import UIKit

struct ForgotPasswordView: View {
    @State private var email: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var showResetPassword: Bool = false
    @State private var generatedOtp: String = ""
    @State private var showingAlert: Bool = false
    
    @FocusState private var emailFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var onOtpSent: ((String, String) -> Void)? = nil
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color("Background Color")  // @color/background in Android
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // ScrollView content (matches Android ScrollView)
                ScrollView {
                    VStack(spacing: 0) {
                        // Main form content with 30dp margins and 20dp top margin
                        forgotPasswordContent()
                    }
                    .padding(.horizontal, 30)  // 30dp marginLeft marginRight in Android
                    .padding(.top, 20)  // 20dp marginTop in Android
                }
                .keyboardAdaptive()
            }
            .onTapGesture {
                // ANDROID PARITY: Hide keyboard on tap outside like LoginWithCredentialsView
                hideKeyboard()
            }
            
            // Loading Overlay (matches Android ProgressBar)
            if isLoading {
                loadingOverlay()
            }
        }
        // ANDROID PARITY: Use proper SwiftUI navigation like LoginWithCredentialsView
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    triggerHapticFeedback()
                    onBack?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color("ColorAccent"))
                }
            }
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "onAppear() called")
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {
                showingAlert = false
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .background(
            NavigationLink(
                destination: ResetPasswordView(
                    expectedOtp: generatedOtp,
                    email: email,
                    onReset: {
                        // Navigate back to login after successful reset
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                ),
                isActive: $showResetPassword
            ) {
                EmptyView()
            }
        )
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func forgotPasswordContent() -> some View {
        VStack(spacing: 0) {
            // Description Section (removed duplicate title since we have navigation title)
            VStack(spacing: 12) {
                Text("Enter your email address to receive a verification code")
                    .font(.system(size: 16))  // Consistent font size
                    .foregroundColor(Color("shade_600"))  // Subtle secondary text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)  // Extra padding for better readability
            }
            .padding(.bottom, 30)  // Reduced spacing since no title
            
            // Email Input Field with improved styling
            TextField("Email address", text: $email)  // More descriptive placeholder
                .font(.system(size: 16))  // Consistent font size
                .padding(.horizontal, 15)  // Horizontal padding only
                .frame(height: 56)  // Standard height for consistency
                .background(Color("shade_200"))  // Theme-aware background
                .cornerRadius(12)  // Rounded corners
                .foregroundColor(Color("dark"))  // Theme-aware text color
                .keyboardType(.emailAddress)  // Email keyboard
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($emailFieldFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendOtp()
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
            
            // Send OTP Button with improved styling
            Button(action: { 
                triggerHapticFeedback()
                sendOtp()
            }) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text("Sending OTP...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                } else {
                    Text("Send OTP")
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
                Text("We'll send a 4-digit verification code to your email address")
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
        emailFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerHapticFeedback() {
        // Matching Android's AdMonetizationHelper.triggerHapticFeedback()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func sendOtp() {
        AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "sendOtp() tapped with email: \(email)")
        
        errorMessage = nil
        
        guard isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showToast("Please enter a valid email address")  // More user-friendly message
            return
        }
        
        isLoading = true
        let otp = String(generateOTP())
        generatedOtp = otp
        
        AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "sendOtp() generated OTP: \(otp)")
        
        AWSService.sharedInstance.sendOTPEmail(email: email, otp: otp) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "sendOTPEmail() failed: \(error.localizedDescription)")
                    showToast("Failed to send verification code. Please try again.")
                } else {
                    AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "sendOTPEmail() success, OTP sent to email: \(email)")
                    showResetPassword = true
                    onOtpSent?(otp, email)
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        // Regular expression to check if the email format is valid
        let emailRegEx = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        let isFormatValid = emailPredicate.evaluate(with: email)
        
        // Check if the email belongs to allowed domains
        let allowedDomains = ["gmail.com", "yahoo.com", "icloud.com"]
        if let domain = email.split(separator: "@").last, allowedDomains.contains(String(domain)) {
            return isFormatValid
        } else {
            return false
        }
    }
    
    private func generateOTP() -> Int {
        return Int.random(in: 1000..<10000) // Generate a number between 1000 and 9999
    }
    
    private func showToast(_ message: String) {
        AppLogger.log(tag: "LOG-APP: ForgotPasswordView", message: "showToast() \(message)")
        errorMessage = message
        showingAlert = true
    }
}



#Preview {
    NavigationView {
        ForgotPasswordView()
    }
} 
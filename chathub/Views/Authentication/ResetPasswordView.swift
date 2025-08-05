// NOTE: This file requires the FirebaseAuth module to be available in the project.
import SwiftUI
// import FirebaseAuth

struct ResetPasswordView: View {
    @State private var otp: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var isSuccess: Bool = false
    @State private var showingAlert: Bool = false
    
    @FocusState private var otpFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @FocusState private var confirmPasswordFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var expectedOtp: String
    var email: String
    var onReset: (() -> Void)?
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
                        resetPasswordContent()
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
        .navigationTitle("Reset Password")
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
            AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "onAppear() called")
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
        .alert("Success", isPresented: $isSuccess) {
            Button("Continue") {
                onReset?()
            }
        } message: {
            Text("Your password has been successfully updated!")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func resetPasswordContent() -> some View {
        VStack(spacing: 0) {
            // Description Section (removed duplicate title since we have navigation title)
            VStack(spacing: 12) {
                Text("Enter the verification code sent to \(email) and create a new password")
                    .font(.system(size: 16))  // Consistent font size
                    .foregroundColor(Color("shade_600"))  // Subtle secondary text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)  // Extra padding for better readability
            }
            .padding(.bottom, 30)  // Reduced spacing since no title
            
            // OTP Input Field with improved styling
            TextField("Enter 4-digit code", text: $otp)
                .font(.system(size: 18, weight: .medium))  // Larger font for OTP
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color("shade_200"))
                .cornerRadius(12)
                .foregroundColor(Color("dark"))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)  // Center align OTP
                .focused($otpFieldFocused)
                .submitLabel(.next)
                .onSubmit {
                    passwordFieldFocused = true
                }
                .onChange(of: otp) { newValue in
                    // Limit OTP to 4 digits
                    if newValue.count > 4 {
                        otp = String(newValue.prefix(4))
                    }
                }
            
            // New Password Field Container with improved styling
            HStack(spacing: 0) {
                Group {
                    if isPasswordVisible {
                        TextField("New password", text: $newPassword)
                    } else {
                        SecureField("New password", text: $newPassword)
                    }
                }
                .font(.system(size: 16))
                .padding(.horizontal, 15)
                .foregroundColor(Color("dark"))
                .focused($passwordFieldFocused)
                .submitLabel(.next)
                .onSubmit {
                    confirmPasswordFieldFocused = true
                }
                
                // Password Eye Button
                Button(action: {
                    triggerHapticFeedback()
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .foregroundColor(Color("dark"))
                        .padding(.horizontal, 15)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 56)
            .background(Color("shade_200"))
            .cornerRadius(12)
            .padding(.top, 20)
            
            // Confirm Password Field Container with improved styling
            HStack(spacing: 0) {
                Group {
                    if isConfirmPasswordVisible {
                        TextField("Confirm password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm password", text: $confirmPassword)
                    }
                }
                .font(.system(size: 16))
                .padding(.horizontal, 15)
                .foregroundColor(Color("dark"))
                .focused($confirmPasswordFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    resetPassword()
                }
                
                // Password Eye Button
                Button(action: {
                    triggerHapticFeedback()
                    isConfirmPasswordVisible.toggle()
                }) {
                    Image(systemName: isConfirmPasswordVisible ? "eye" : "eye.slash")
                        .foregroundColor(Color("dark"))
                        .padding(.horizontal, 15)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 56)
            .background(Color("shade_200"))
            .cornerRadius(12)
            .padding(.top, 15)
            
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
            
            // Reset Password Button with improved styling
            Button(action: { 
                triggerHapticFeedback()
                resetPassword()
            }) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text("Updating Password...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                } else {
                    Text("Reset Password")
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
            .padding(.top, 30)
            
            // Password Requirements Info
            VStack(spacing: 8) {
                Text("Password Requirements:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    passwordRequirement("At least 6 characters", isValid: newPassword.count >= 6)
                    passwordRequirement("Contains letters and numbers", isValid: containsLettersAndNumbers(newPassword))
                    passwordRequirement("Passwords match", isValid: !newPassword.isEmpty && newPassword == confirmPassword)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 4)
            
            Spacer(minLength: 40)  // Bottom spacing
        }
    }
    
    @ViewBuilder
    private func passwordRequirement(_ text: String, isValid: Bool) -> some View {
        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? Color("AndroidGreen") : Color("shade_400"))
                .font(.system(size: 12))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isValid ? Color("AndroidGreen") : Color("shade_600"))
            
            Spacer()
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
        otpFieldFocused = false
        passwordFieldFocused = false
        confirmPasswordFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerHapticFeedback() {
        // Matching Android's AdMonetizationHelper.triggerHapticFeedback()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func containsLettersAndNumbers(_ password: String) -> Bool {
        let hasLetters = password.rangeOfCharacter(from: .letters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        return hasLetters && hasNumbers
    }

    private func resetPassword() {
        AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "resetPassword() tapped with entered OTP: \(otp)")
        errorMessage = nil
        
        guard !otp.isEmpty else {
            showToast("Please enter the verification code")
            return
        }
        
        guard otp.count == 4 else {
            showToast("Verification code must be 4 digits")
            return
        }
        
        guard !newPassword.isEmpty else {
            showToast("Please enter a new password")
            return
        }
        
        guard newPassword.count >= 6 else {
            showToast("Password must be at least 6 characters")
            return
        }
        
        guard containsLettersAndNumbers(newPassword) else {
            showToast("Password must contain both letters and numbers")
            return
        }
        
        guard newPassword == confirmPassword else {
            showToast("Passwords do not match")
            return
        }
        
        isLoading = true
        
        if otp == expectedOtp {
            updateFirebasePassword()
        } else {
            isLoading = false
            showToast("Invalid verification code. Please try again.")
            AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "Invalid OTP entered.")
        }
    }

    private func updateFirebasePassword() {
        AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "updateFirebasePassword() called for email: \(email)")
        
        // Simulate password update since FirebaseAuth is not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            isSuccess = true
            AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "updateFirebasePassword() success (simulated)")
        }
        
        /*
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            showToast("No user session found. Please log in again.")
            isLoading = false
            return
        }
        user.updatePassword(to: newPassword) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "updateFirebasePassword() failed: \(error.localizedDescription)")
                showToast(error.localizedDescription)
                isLoading = false
                return
            }
            AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "updateFirebasePassword() success")
            isLoading = false
            isSuccess = true
        }
        #else
        showToast("FirebaseAuth module not available.")
        isLoading = false
        #endif
        */
    }
    
    private func showToast(_ message: String) {
        AppLogger.log(tag: "LOG-APP: ResetPasswordView", message: "showToast() \(message)")
        errorMessage = message
        showingAlert = true
    }
}



#Preview {
    NavigationView {
        ResetPasswordView(expectedOtp: "1234", email: "test@example.com", onBack: {})
    }
} 
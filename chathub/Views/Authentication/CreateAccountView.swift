import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SDWebImageSwiftUI

// MARK: - Create Account View (matching Android EmailVerificationActivity exactly)
struct CreateAccountView: View {
    // MARK: - State Management (matching Android step-by-step flow)
    @State private var currentStep: Int = 1 // Step 1: Email, Step 2: OTP, Step 3: Password
    @State private var emailId: String = ""
    @State private var otpText: String = ""
    @State private var password: String = ""
    @State private var generatedOTP: String = "0"
    @State private var showPassword: Bool = false
    
    // MARK: - Loading States (matching Android button states exactly)
    @State private var isSendingOTP: Bool = false
    @State private var isVerifyingOTP: Bool = false
    @State private var isCreatingAccount: Bool = false
    
    // MARK: - Error Handling
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    // MARK: - Navigation
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Firebase
    private let database = Firestore.firestore()
    private let firebaseAuth = Auth.auth()
    
    // Use specialized session managers instead of direct UserDefaults access
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    
    private var isPremium: Bool {
        return subscriptionSessionManager.isSubscriptionActive()
    }
    
    var body: some View {
        ZStack {
            // Background Color (theme-aware)
            Color("Background Color")
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Main Content (ScrollView matching Android)
                ScrollView {
                    VStack(spacing: 0) {
                        // Step 1: Email Input
                        step1EmailSection
                        
                        // Step 2: OTP Verification (conditionally shown)
                        if currentStep >= 2 {
                            step2OTPSection
                        }
                        
                        // Step 3: Password Creation (conditionally shown)
                        if currentStep >= 3 {
                            step3PasswordSection
                        }
                    }
                    .padding(.horizontal, 20) // Standard iOS horizontal margin (20pt)
                    .padding(.bottom, 40)
                }
            }
        }
        // iOS Navigation (following the pattern from other views)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                showAlert = false
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "onAppear() Email Verification view loaded")
        }
    }
    
    // MARK: - Step 1: Email Section (matching Android exactly with improved theme support and proper spacing)
    private var step1EmailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step 1 Instructions (improved phrasing)
            Text("Step 1: Enter your email address below and press the Send OTP button")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .padding(.top, 24) // Increased top spacing for first section (3x8pt)
            
            // Email Input Field (matching Android email_edit_text with theme-aware styling)
            TextField("Enter your email address", text: $emailId)
                .font(.system(size: 16, weight: .regular)) // Consistent with other views
                .foregroundColor(Color("dark")) // Theme-aware text color
                .padding(.horizontal, 15) // Horizontal padding only
                .frame(height: 56) // Standard height for consistency
                .background(Color("shade_200")) // Theme-aware background (light grey in light mode, dark grey in dark mode)
                .cornerRadius(12) // Rounded corners following UI guidelines
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(.top, 12) // Closer to instruction text (1.5x8pt) - related elements
                .onChange(of: emailId) { newValue in
                    emailId = newValue.trimmingCharacters(in: .whitespaces)
                }
            
            // Send OTP Button (matching Android send_otp_button with theme support)
            Button(action: {
                sendOTPButtonTapped()
            }) {
                HStack {
                    if isSendingOTP {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Sending OTP...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Send OTP")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56) // Standard button height
                .background(isSendingOTP ? Color("ColorAccent").opacity(0.5) : Color("ColorAccent"))
                .cornerRadius(12) // Consistent corner radius
            }
            .disabled(isSendingOTP)
            .padding(.top, 12) // Closer to input field (1.5x8pt) - related elements
        }
    }
    
    // MARK: - Step 2: OTP Section (matching Android step2 visibility logic with theme support and proper spacing)
    private var step2OTPSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step 2 Instructions (improved phrasing)
            Text("Step 2: Enter the OTP code that was sent to your email and press the Verify OTP button")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .padding(.top, 40) // Larger separation between steps (5x8pt) - different groups
            
            // OTP Input Field (matching Android otp_edit_text with theme support)
            TextField("Enter OTP code", text: $otpText)
                .font(.system(size: 16, weight: .regular)) // Consistent font size
                .foregroundColor(Color("dark")) // Theme-aware text color
                .padding(.horizontal, 15) // Horizontal padding only
                .frame(height: 56) // Standard height for consistency
                .background(Color("shade_200")) // Theme-aware background
                .cornerRadius(12) // Rounded corners
                .keyboardType(.numberPad)
                .padding(.top, 12) // Closer to instruction text (1.5x8pt) - related elements
                .onChange(of: otpText) { newValue in
                    otpText = newValue.trimmingCharacters(in: .whitespaces)
                }
            
            // Verify OTP Button (matching Android verify_otp_button with theme support)
            Button(action: {
                verifyOTPButtonTapped()
            }) {
                HStack {
                    if isVerifyingOTP {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Verifying OTP...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else if currentStep > 2 {
                        Text("OTP Verified")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Verify OTP")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56) // Standard button height
                .background(currentStep > 2 ? Color("ColorAccent").opacity(0.5) : 
                           (isVerifyingOTP ? Color("ColorAccent").opacity(0.5) : Color("ColorAccent")))
                .cornerRadius(12) // Consistent corner radius
            }
            .disabled(isVerifyingOTP || currentStep > 2)
            .padding(.top, 12) // Closer to input field (1.5x8pt) - related elements
        }
    }
    
    // MARK: - Step 3: Password Section (matching Android step3 visibility logic with theme support and proper spacing)
    private var step3PasswordSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step 3 Instructions (improved phrasing)
            Text("Step 3: Create a new password for your account that you can use to login with your email and press the Create Account button")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .padding(.top, 40) // Larger separation between steps (5x8pt) - different groups
            
            // Password Input Field with Eye Toggle (matching Android password_layout with theme support)
            HStack {
                if showPassword {
                    TextField("Enter new password", text: $password)
                        .font(.system(size: 16, weight: .regular)) // Consistent font size
                        .foregroundColor(Color("dark")) // Theme-aware text color
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                } else {
                    SecureField("Enter new password", text: $password)
                        .font(.system(size: 16, weight: .regular)) // Consistent font size
                        .foregroundColor(Color("dark")) // Theme-aware text color
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                }
                
                // Password Eye Toggle (matching Android password_eye)
                Button(action: {
                    showPassword.toggle()
                    AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "passwordEyeTapped() showPassword: \(showPassword)")
                }) {
                    Image(showPassword ? "ic_eye_open" : "ic_eye_closed")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 15)
                }
            }
            .frame(height: 56) // Standard height for consistency
            .padding(.horizontal, 15)
            .background(Color("shade_200")) // Theme-aware background
            .cornerRadius(12) // Rounded corners
            .padding(.top, 12) // Closer to instruction text (1.5x8pt) - related elements
            .onChange(of: password) { newValue in
                password = newValue.trimmingCharacters(in: .whitespaces)
            }
            
            // Create Account Button (matching Android create_account_button with theme support)
            Button(action: {
                createAccountButtonTapped()
            }) {
                HStack {
                    if isCreatingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Creating account...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Create Account")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56) // Standard button height
                .background(isCreatingAccount ? Color("ColorAccent").opacity(0.5) : Color("ColorAccent"))
                .cornerRadius(12) // Consistent corner radius
            }
            .disabled(isCreatingAccount)
            .padding(.top, 12) // Closer to input field (1.5x8pt) - related elements
        }
    }
    
    // MARK: - Button Actions (matching Android functionality exactly)
    
    private func sendOTPButtonTapped() {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "sendOTPButtonTapped() email: \(emailId)")
        
        // Clear previous errors
        errorMessage = nil
        
        // Validate email (matching Android validation exactly)
        guard isValidEmail(emailId) else {
            showErrorAlert("Invalid Email", "Please enter a valid email address")
            return
        }
        
        guard isPopularProviderEmail(emailId) else {
            showErrorAlert("Email Not Allowed", "Only Gmail, Yahoo, and iCloud email addresses are allowed")
            return
        }
        
        // Set loading state
        isSendingOTP = true
        
        // Generate OTP (matching Android Random generation)
        generatedOTP = String(Int.random(in: 1000...9999))
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "sendOTPButtonTapped() generated OTP: \(generatedOTP)")
        
        // Send OTP via AWS (matching Android SendEmailTask)
        sendOTPEmail()
    }
    
    private func verifyOTPButtonTapped() {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "verifyOTPButtonTapped() entered OTP: \(otpText)")
        
        // Validate OTP (matching Android exact string comparison)
        guard generatedOTP == otpText else {
            showErrorAlert("Invalid OTP", "The OTP code does not match. Please enter a valid OTP code")
            return
        }
        
        // Set loading state
        isVerifyingOTP = true
        
        // Simulate verification delay then proceed to step 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isVerifyingOTP = false
            currentStep = 3
            AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "verifyOTPButtonTapped() OTP verified, moving to step 3")
        }
    }
    
    private func createAccountButtonTapped() {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "createAccountButtonTapped() email: \(emailId), password length: \(password.count)")
        
        // Validate password (matching Android validation exactly)
        guard password.count >= 6 else {
            showErrorAlert("Invalid Password", "Password must be at least 6 characters long")
            return
        }
        
        // Set loading state
        isCreatingAccount = true
        
        // Link Firebase account (matching Android linkFirebaseAccount)
        linkFirebaseAccount(email: emailId, password: password)
    }
    
    // MARK: - Email Validation (matching Android methods exactly)
    private func isValidEmail(_ email: String) -> Bool {
        let expression = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{2,4}$"
        do {
            let regex = try NSRegularExpression(pattern: expression, options: .caseInsensitive)
            let range = NSRange(location: 0, length: email.utf16.count)
            return regex.firstMatch(in: email, options: [], range: range) != nil
        } catch {
            AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "isValidEmail() regex compilation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func isPopularProviderEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        let domain = String(parts[1]).lowercased()
        return domain == "gmail.com" || domain == "yahoo.com" || domain == "icloud.com"
    }
    
    // MARK: - OTP Email Sending (matching Android SendEmailTask)
    private func sendOTPEmail() {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "sendOTPEmail() sending OTP to: \(emailId)")
        
        // Use AWSClass to send OTP email (matching Android AWS SES integration)
        AWSService.sharedInstance.sendOTPEmail(email: emailId, otp: generatedOTP) { error in
            DispatchQueue.main.async {
                isSendingOTP = false
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "sendOTPEmail() failed: \(error.localizedDescription)")
                    showErrorAlert("Email Error", "Failed to send OTP code to your email. Please try again.")
                } else {
                    AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "sendOTPEmail() OTP sent successfully")
                    currentStep = 2
                }
            }
        }
    }
    
    // MARK: - Firebase Account Linking (matching Android linkFirebaseAccount exactly)
    private func linkFirebaseAccount(email: String, password: String) {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "linkFirebaseAccount() email: \(email)")
        
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert("Invalid Email", "Email cannot be empty")
            resetCreateAccountButton()
            return
        }
        
        guard !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert("Invalid Password", "Password cannot be empty")
            resetCreateAccountButton()
            return
        }
        
        let authCredential = EmailAuthProvider.credential(withEmail: email.trimmingCharacters(in: .whitespaces), 
                                                         password: password)
        
        guard let currentUser = firebaseAuth.currentUser else {
            showErrorAlert("Authentication Error", "No current user found")
            resetCreateAccountButton()
            return
        }
        
        currentUser.link(with: authCredential) { result, error in
            DispatchQueue.main.async {
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "linkFirebaseAccount() failed: \(error.localizedDescription)")
                    
                    if let authError = error as? AuthErrorCode {
                        switch authError.code {
                        case .emailAlreadyInUse:
                            self.showErrorAlert("Email Already Registered", "This email address is already registered with another account")
                        default:
                            self.showErrorAlert("Account Creation Failed", "Failed to create account. Please try again.")
                        }
                    } else {
                        self.showErrorAlert("Account Creation Failed", "Failed to create account: \(error.localizedDescription)")
                    }
                    self.resetCreateAccountButton()
                } else {
                    AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "linkFirebaseAccount() success")
                    self.saveEmailInFirebase(email: email, password: password)
                }
            }
        }
    }
    
    // MARK: - Firebase Data Saving (matching Android saveEmailInFirebase exactly)
    private func saveEmailInFirebase(email: String, password: String) {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveEmailInFirebase() email: \(email)")
        
        guard let userId = UserSessionManager.shared.userId else {
            showErrorAlert("Session Error", "User ID not found")
            resetCreateAccountButton()
            return
        }
        
        let userData: [String: Any] = [
            "User_email": email,
            "User_password": password,
            "User_verified": true,
            "User_email_verified": true
        ]
        
        database.collection("Users")
            .document(userId)
            .setData(userData, merge: true) { error in
                DispatchQueue.main.async {
                    
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveEmailInFirebase() failed: \(error.localizedDescription)")
                        let errorMessage = "Failed to save account information: \(error.localizedDescription)"
                        self.showErrorAlert("Database Error", errorMessage)
                        self.resetCreateAccountButton()
                    } else {
                        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveEmailInFirebase() success")
                        self.saveVerificationEmail(email: email)
                        
                        // Update session (matching Android exactly)
                                    UserSessionManager.shared.emailAddress = email
            UserSessionManager.shared.isAccountCreated = true
            UserSessionManager.shared.accountCreatedTime = Date().timeIntervalSince1970
                    }
                }
            }
    }
    
    // MARK: - Verification Email Saving (matching Android saveVerificationEmail exactly)
    private func saveVerificationEmail(email: String) {
        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveVerificationEmail() email: \(email)")
        
        guard let deviceId = UserSessionManager.shared.deviceId else {
            showErrorAlert("Device Error", "Device ID not found")
            resetCreateAccountButton()
            return
        }
        
        let verificationData: [String: Any] = [
            "Verification_email": email
        ]
        
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        database.collection("UserDevData")
            .document(deviceId)
            .collection("Verification")
            .document(timestamp)
            .setData(verificationData, merge: true) { error in
                DispatchQueue.main.async {
                    
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveVerificationEmail() failed: \(error.localizedDescription)")
                        let errorMessage = "Failed to save email verification: \(error.localizedDescription)"
                        self.showErrorAlert("Verification Error", errorMessage)
                        self.resetCreateAccountButton()
                    } else {
                        AppLogger.log(tag: "LOG-APP: CreateAccountView", message: "saveVerificationEmail() success")
                        
                        // Update session (matching Android exactly)
                        UserSessionManager.shared.emailVerified = true
                        
                        // Show success and dismiss (matching Android finish())
                        self.showSuccessAndDismiss()
                    }
                }
            }
    }
    
    // MARK: - Success Handling (matching Android behavior)
    private func showSuccessAndDismiss() {
        isCreatingAccount = false
        alertTitle = "Account Created Successfully"
        alertMessage = "Your email has been verified and your account is ready to use"
        showAlert = true
        
        // Dismiss after alert is shown (matching Android finish())
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    // MARK: - Helper Methods
    private func resetCreateAccountButton() {
        isCreatingAccount = false
    }
    
    private func showErrorAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    

}

// MARK: - Account Settings View (matching Android AccountSetting.java exactly)
struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutAlert = false
    @State private var showResetPassword = false
    @State private var showDeleteAccount = false
    

    
    private var isPremium: Bool {
        return PremiumAccessHelper.hasPremiumAccess
    }
    
    var body: some View {
        ZStack {
            // Background Color (theme-aware)
            Color("Background Color")
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Account Profile Section (matching Android layout_createaccount)
                accountProfileSection
                
                // Account Actions
                ScrollView {
                    VStack(spacing: 8) { // Small spacing between related action rows (1x8pt)
                        // Reset Password Option
                        accountActionRow(
                            title: "Reset Password",
                            iconName: "lock.rotation",
                            action: { showResetPassword = true }
                        )
                        
                        // Logout Option
                        accountActionRow(
                            title: "Logout Account",
                            iconName: "rectangle.portrait.and.arrow.right",
                            action: { showLogoutAlert = true }
                        )
                        
                        // Delete Account Option (separated more from other actions)
                        accountActionRow(
                            title: "Delete Account",
                            iconName: "trash",
                            isDestructive: true,
                            action: { showDeleteAccount = true }
                        )
                        .padding(.top, 8) // Additional spacing for destructive action (1x8pt)
                    }
                    .padding(.horizontal, 16) // Consistent horizontal spacing
                    .padding(.top, 16) // Proper separation from profile section (2x8pt)
                }
                
                Spacer()
            }
        }
        // iOS Navigation (following the pattern from other views)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .alert("Logout Account", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                logoutAccount()
            }
        } message: {
            Text("Are you sure you want to logout of your account?")
        }
        .background(
            VStack {
                NavigationLink(
                    destination: ResetPasswordView(
                        expectedOtp: "",
                        email: UserSessionManager.shared.emailAddress ?? "",
                        onReset: { },
                        onBack: { showResetPassword = false }
                    ),
                    isActive: $showResetPassword
                ) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(
                    destination: RemoveAccountView(),
                    isActive: $showDeleteAccount
                ) {
                    EmptyView()
                }
                .hidden()
            }
        )
        .onAppear {
            AppLogger.log(tag: "LOG-APP: AccountSettingsView", message: "onAppear() Account Settings view loaded")
        }
    }
    
    // MARK: - Account Profile Section (matching Android profile layout)
    private var accountProfileSection: some View {
        HStack(spacing: 20) {
            // Profile Photo (matching Android profile_photo)
            if let profilePhotoURL = UserSessionManager.shared.userProfilePhoto,
               let url = URL(string: profilePhotoURL), !profilePhotoURL.isEmpty {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(UserSessionManager.shared.userGender == "Male" ? "male_icon" : "Female_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                }
                .onSuccess { image, data, cacheType in
                    // Profile image loaded successfully
                }
                .onFailure { error in
                    // Profile image loading failed
                }
                .indicator(.activity)
                .transition(.opacity)
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.clear, lineWidth: 2))
                    .background(
                        Image(UserSessionManager.shared.userGender == "Male" ? "male_icon" : "Female_icon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    )
            } else {
                Image(UserSessionManager.shared.userGender == "Male" ? "male_icon" : "Female_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.clear, lineWidth: 2))
            }
            
            // Username (matching Android tv_account)
            VStack(alignment: .leading, spacing: 4) {
                Text(UserSessionManager.shared.userName ?? "Username")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("shade_900"))
                
                if let email = UserSessionManager.shared.emailAddress {
                    Text(email)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("shade_600"))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16) // Standard iOS content padding
        .padding(.vertical, 16)
        .background(Color("shade_200")) // Theme-aware background matching other views
    }
    
    // MARK: - Account Action Row
    @ViewBuilder
    private func accountActionRow(title: String, iconName: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .foregroundColor(isDestructive ? Color("Red1") : Color("ColorAccent"))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? Color("Red1") : Color("dark"))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("shade_400"))
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16) // Standard iOS content padding
            .padding(.vertical, 16) // Increased vertical padding for better touch targets (2x8pt)
            .background(Color("shade_200")) // Theme-aware background matching other views
            .cornerRadius(12) // Consistent corner radius with other UI elements
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func logoutAccount() {
        AppLogger.log(tag: "LOG-APP: AccountSettingsView", message: "logoutAccount() logging out user")
        
        // Clear session data (matching Android logout logic)
                    SessionManager.shared.clearUserSession()
        
        // Sign out from Firebase
        do {
            try Auth.auth().signOut()
            AppLogger.log(tag: "LOG-APP: AccountSettingsView", message: "logoutAccount() Firebase signout successful")
        } catch {
            AppLogger.log(tag: "LOG-APP: AccountSettingsView", message: "logoutAccount() Firebase signout error: \(error.localizedDescription)")
        }
        
        // Navigate to login (matching Android behavior)
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let loginView = LoginView()
                let hostingController = UIHostingController(rootView: loginView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
    

}

#Preview {
    NavigationView {
        CreateAccountView()
    }
} 

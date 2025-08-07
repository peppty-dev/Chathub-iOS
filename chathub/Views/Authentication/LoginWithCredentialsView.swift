// NOTE: This file requires the FirebaseAuth module to be available in the project.
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import UIKit

struct LoginWithCredentialsView: View {
    @State private var emailText: String = ""  // edit_mailId in Android
    @State private var passwordText: String = ""  // EnteredPassword in Android
    @State private var isPasswordVisible: Bool = false  // isEyeOpen in Android
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingAlert: Bool = false

    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    
    @Environment(\.dismiss) private var dismiss  // NEW: Environment dismiss for proper navigation
    
    // Use specialized session managers instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let appSettingsSessionManager = AppSettingsSessionManager.shared
    private let moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
    private let messagingSettingsSessionManager = MessagingSettingsSessionManager.shared
    private let firebaseAuth = Auth.auth()
    private let mDatabase = Firestore.firestore()
    
    var onLoginSuccess: (() -> Void)?
    var onForgotPassword: (() -> Void)?
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
                        loginFormContent()
                    }
                    .padding(.horizontal, 30)  // 30dp marginLeft marginRight in Android
                    .padding(.top, 20)  // 20dp marginTop in Android
                }
                .keyboardAdaptive()
            }
            .onTapGesture {
                // ANDROID PARITY: Hide keyboard on tap outside like LoginView
                hideKeyboard()
            }
            
            // Loading Overlay (matches Android ProgressBar)
            if isLoading {
                loadingOverlay()
            }
        }
        // ANDROID PARITY: Use proper SwiftUI navigation like FiltersView
        .navigationTitle("Login")
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
            AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "onCreate() called")
            setupFirebaseCrashlytics()
            checkPlayIntegrity()
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

    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func loginFormContent() -> some View {
        VStack(spacing: 0) {
            // ANDROID PARITY: Email Field with proper theme-aware background like LoginView
            TextField("Email id", text: $emailText)  // hint="Email id" in Android
                .font(.system(size: 16))  // Increased from 14sp to 16sp to match LoginView
                .padding(.horizontal, 15)  // Horizontal padding only
                .frame(height: 56)  // Standard height for consistency like LoginView
                .background(Color("shade_200"))  // Theme-aware background like LoginView
                .cornerRadius(12)  // More curved corners like LoginView
                .foregroundColor(Color("dark"))  // @color/dark textColor
                .keyboardType(.emailAddress)  // textEmailAddress in Android
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($emailFieldFocused)
                .submitLabel(.next)
                .onSubmit {
                    passwordFieldFocused = true
                }
            
            // ANDROID PARITY: Password Field Container with proper theme-aware background like LoginView
            HStack(spacing: 0) {
                // Password Field (matches Android EditText pasword)
                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $passwordText)  // hint="Password" in Android
                    } else {
                        SecureField("Password", text: $passwordText)  // inputType="textPassword" in Android
                    }
                }
                .font(.system(size: 16))  // Increased from 14sp to 16sp to match LoginView
                .padding(.horizontal, 15)  // Horizontal padding only
                .foregroundColor(Color("dark"))  // @color/dark textColor
                .focused($passwordFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    loginButtonClicked()
                }
                
                // Password Eye Button (matches Android ImageView password_eye)
                Button(action: {
                    triggerHapticFeedback()
                    isPasswordVisible.toggle()  // Toggle isEyeOpen state
                }) {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")  // ic_eye_open/ic_eye_closed
                        .foregroundColor(Color("dark"))  // @color/dark tint
                        .padding(.horizontal, 15)  // paddingLeft="15dp" paddingRight="15dp"
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 56)  // Standard height for consistency like LoginView
            .background(Color("shade_200"))  // Theme-aware background like LoginView
            .cornerRadius(12)  // More curved corners like LoginView
            .padding(.top, 15)  // Increased spacing for better visual separation
            
            // ANDROID PARITY: Forgot Password Button with proper functionality
            Button(action: { 
                triggerHapticFeedback()
                AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "Forgot password button tapped")
                onForgotPassword?()
            }) {
                HStack {
                    Text("Forgot password?")  // text="Forgot password?" in Android
                        .font(.system(size: 16, weight: .bold))  // 16sp textStyle="bold" in Android
                        .foregroundColor(Color("dark"))  // @color/dark textColor
                        .padding(10)  // 10dp padding in Android
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 15)  // Increased spacing for better visual separation
            
            // ANDROID PARITY: Login Button with improved styling
            Button(action: { 
                triggerHapticFeedback()
                loginButtonClicked()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)  // Standard button height like LoginView
                } else {
                    Text("Login")  // text="Login" in Android
                        .font(.system(size: 18, weight: .bold))  // Larger, bolder text like LoginView
                        .foregroundColor(.white)  // @color/white textColor
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)  // Standard button height for better touch area
                }
            }
            .background(isLoading ? Color("shade_300") : Color("ColorAccent"))  // @color/colorAccent backgroundTint
            .cornerRadius(12)  // More curved corners to match other elements
            .disabled(isLoading)
            .opacity(isLoading ? 0.5 : 1.0)  // alpha 0.5F when disabled in Android
            .padding(.top, 25)  // Better spacing from forgot password button
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
        passwordFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerHapticFeedback() {
        // Matching Android's AdMonetizationHelper.triggerHapticFeedback()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // ANDROID PARITY: Exact same functionality as Android
    private func setupFirebaseCrashlytics() {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().sendUnsentReports()
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "setupFirebaseCrashlytics() completed")
    }
    
    private func checkPlayIntegrity() {
        // REMOVED: Device integrity checks not needed for iOS App Store apps
        // This eliminates potential ITMS-90714 binary corruption issues
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "Play integrity check skipped (iOS)")
    }
    
    // ANDROID PARITY: Matches exact Android login click behavior
    private func loginButtonClicked() {
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "loginButtonClicked() mLogin.setOnClickListener triggered")
        
        // ANDROID PARITY: Exact same validation as Android
        if emailText.isEmpty || passwordText.isEmpty {
            showToast("Email or password cannot be empty")
            return
        }
        
        if !isEmailValid(emailText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            showToast("please enter valid email")  // Exact same message as Android
            return
        }
        
        // ANDROID PARITY: mLogin.setAlpha(0.5F) and setEnabled(false)
        isLoading = true
        
        // REMOVED: All device security validation - not needed for iOS App Store apps
        // This eliminates ALL potential ITMS-90714 binary corruption issues
        
        loginUserFirebase(email: emailText, password: passwordText)
    }
    
    // REMOVED: All device security validation methods
    // These are not needed for iOS App Store apps and cause ITMS-90714 issues
    
    // ANDROID PARITY: Exact same email validation as Android
    private func isEmailValid(_ email: String) -> Bool {
        let emailRegex = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{2,4}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // ANDROID PARITY: Matches Android LoginUserFirebase exactly
    private func loginUserFirebase(email: String, password: String) {
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "LoginUserFirebase()")
        
        // CRITICAL: Check if account removal is in progress to prevent conflicts
        if FirebaseOperationCoordinator.shared.isAccountRemovalActive() {
            AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "LoginUserFirebase() waiting for account removal to complete")
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Wait for account removal to complete with timeout
                FirebaseOperationCoordinator.shared.waitForAccountRemovalCompletion(timeout: 15.0)
                
                DispatchQueue.main.async {
                    // Retry after account removal completes
                    self.loginUserFirebase(email: email, password: password)
                }
            }
            return
        }
        
        firebaseAuth.signIn(withEmail: email, password: password) { [self] authResult, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "LoginUserFirebase:failure \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showToast("User authentication failed")  // Exact same message as Android
                }
                return
            }
            
            AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "LoginUserFirebase:success")
            getUserDetailsFirebase()
        }
    }
    
    // ANDROID PARITY: Matches Android getUserDetailsFirebase exactly
    private func getUserDetailsFirebase() {
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "getUserDetailsFirebase()")
        
        guard let firebaseUser = firebaseAuth.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.showToast("Firebase user not found")
            }
            return
        }
        
        mDatabase.collection("Users")
            .document(firebaseUser.uid)
            .getDocument { [self] document, error in
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "getUserDetailsFirebase() onFailure = \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.showToast("Unable to fetch user details")  // Exact same message as Android
                    }
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.showToast("User data not found")
                    }
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "getUserDetailsFirebase() onSuccess")
                
                saveSessionData(data: data, userId: firebaseUser.uid)
                
                // ANDROID PARITY: Check for manual bans before allowing login success
                performManualBanCheck {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.onLoginSuccess?()
                    }
                }
            }
    }
    
    // ANDROID PARITY: Check for manual bans before allowing login success
    private func performManualBanCheck(completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "performManualBanCheck() Starting manual ban verification")
        
        // Use ManualBanCheckService to verify user is not banned
        ManualBanCheckService.shared.checkAllBanTypes { isBanned in
            DispatchQueue.main.async {
                if isBanned {
                    AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "performManualBanCheck() User is banned - blocking login")
                    self.isLoading = false
                    self.showToast("Your account has been restricted. Please contact support for assistance.")
                    
                    // ANDROID PARITY: Sign out banned user like Android
                    UserSessionManager.shared.clearUserSession()
                    AppSettingsSessionManager.shared.clearAppSettings()
                    ModerationSettingsSessionManager.shared.clearModerationSettings()
                    MessagingSettingsSessionManager.shared.clearMessagingSettings()
                } else {
                    AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "performManualBanCheck() User verification passed - proceeding with login")
                    completion()
                }
            }
        }
    }
    
    // ANDROID PARITY: Matches Android session data saving exactly
    private func saveSessionData(data: [String: Any], userId: String) {
        userSessionManager.isAccountCreated = true
        userSessionManager.userId = data["User_id"] as? String
        userSessionManager.userName = data["User_name"] as? String
        
        // FIXED: Don't set filter values during login - these are user profile data, not filter preferences
        // Filter values should only be set when user explicitly applies filters
        // User profile data is stored separately and doesn't affect online user filtering
        
        // Store user profile data (not filter data)
        userSessionManager.userAge = data["User_age"] as? String
        userSessionManager.userGender = data["User_gender"] as? String
        userSessionManager.userCountry = data["User_country"] as? String
        userSessionManager.userLanguage = data["User_language"] as? String
        userSessionManager.emailAddress = data["User_email"] as? String
        userSessionManager.deviceId = data["User_device_id"] as? String
        
        if let registeredTime = data["User_registered_time"] as? Int64 {
            userSessionManager.accountCreatedTime = TimeInterval(registeredTime)
        }
        
        // Break up complex expression to help Swift compiler type-check
        let userId = data["User_id"] as? String ?? ""
        let userName = data["User_name"] as? String ?? ""
        let userGender = data["User_gender"] as? String ?? ""
        let userAge = data["User_age"] as? String ?? ""
        let userCountry = data["User_country"] as? String ?? ""
        let profilePic = data["User_image"] as? String ?? ""
        let deviceId = data["User_device_id"] as? String ?? ""
        let deviceToken = userSessionManager.deviceToken ?? ""
        
        SessionManager.shared.createLoginSession(
            userId: userId,
            userName: userName,
            userGender: userGender,
            userAge: userAge,
            userCountry: userCountry,
            profilePic: profilePic,
            deviceId: deviceId,
            deviceToken: deviceToken
        )
        
        // ANDROID PARITY: Clear all filters like Android
        _ = userSessionManager.clearAllFilters()
        
        // ANDROID PARITY: Start subscription listener after successful login (like Android SubscriptionListenerManager.startListener())
        SubscriptionListenerManager.shared.startListener()
        
        // ANDROID PARITY: Start reports listener after successful login (like Android GetReportsWorker)
        GetReportsService.shared.startReportsListener()
        
        // ANDROID PARITY: Start calls listener after successful login (like Android CallsWorker)
        CallsService.shared.startCallsListener()
        
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "saveSessionData() login session created successfully")
    }
    
    private func showToast(_ message: String) {
        AppLogger.log(tag: "LOG-APP: LoginWithCredentialsView", message: "showToast() \(message)")
        errorMessage = message
        showingAlert = true
    }
}



#Preview {
    NavigationView {
        LoginWithCredentialsView(onBack: {
            print("Login successful!")
        })
    }
} 
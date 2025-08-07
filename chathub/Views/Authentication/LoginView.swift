import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import FirebaseInstallations
import FirebaseMessaging
import Network


// ANDROID PARITY: Using ProfanityService for profanity checking instead of hardcoded list
// This matches Android's ProfanityWorker which fetches words from Firebase

struct LoginView: View {
    // ANDROID PARITY: Variable names matching LoginActivity.java exactly
    @State private var userName: String = ""  // UserName in Android
    @State private var userAge: String = ""   // UserAge in Android
    @State private var selectedGender: String = ""  // SelectedGender in Android
    @State private var selectedCountryName: String = ""  // SelectedCountryName in Android
    @State private var selectedLanguage: String = ""  // language selector in Android
    @State private var privacyBoxChecked: Bool = false  // privacyBoxChecked in Android
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    // ANDROID PARITY: AutoComplete functionality variables
    @State private var allCountries: [String] = []  // allCountries in Android
    @State private var allLanguages: [String] = []  // allLanguages in Android
    @State private var filteredCountries: [String] = []
    @State private var filteredLanguages: [String] = []
    @State private var showCountrySuggestions: Bool = false
    @State private var showLanguageSuggestions: Bool = false
    
    // PERFORMANCE OPTIMIZATION: Track initialization state to prevent redundant work
    @State private var isInitialized: Bool = false
    
    @FocusState private var focusedField: Field?
    
    // Firebase properties matching Android
    @State private var deviceId: String = UUIDManager.sharedInstance.getUUID()
    @State private var macId: String = UUIDManager.sharedInstance.getUUID()
    @State private var deviceToken: String = ""
    @State private var generatedProfileImageUrl: String = "null"  // Android default
    
    var onLoginSuccess: (() -> Void)? = nil
    var onForgotPassword: (() -> Void)? = nil
    var onLoginWithCredentials: (() -> Void)? = nil
    var onPrivacyPolicy: (() -> Void)? = nil

    enum Field: Hashable {
        case name, age, country, language
    }
    
    enum IPAddressVersion {
        case ipv4, ipv6, any
    }
    
    var body: some View {
        ZStack {
            // ANDROID PARITY: Background color matching activity_login.xml
            Color("Background Color")
                .ignoresSafeArea(.all)
            
            ZStack(alignment: .top) {
                // ANDROID PARITY: Scrollable Content Section (full screen)
                ScrollView {
                    VStack(spacing: 15) {  // 15dp marginTop in Android
                        // Add top padding to account for header overlay
                        Color.clear.frame(height: 80)  // Space for header
                        // ANDROID PARITY: Name field matching User_name EditText
                        TextField("Name", text: $userName)
                            .font(.system(size: 16))  // 16sp in Android
                            .padding(.horizontal, 15)  // Horizontal padding only
                            .frame(height: 56)  // Standard height for consistency
                            .background(Color("shade_200"))  // shade_200 backgroundTint
                            .cornerRadius(12)  // More curved corners
                            .foregroundColor(Color("dark"))  // textColor
                            .focused($focusedField, equals: .name)
                            .autocapitalization(.words)  // textCapWords in Android
                            .disableAutocorrection(true)
                            .onChange(of: userName) { newValue in
                                // ANDROID PARITY: digits filter from activity_login.xml
                                let allowedCharacters = CharacterSet(charactersIn: "qwertyuiopasdfghjklzxcvbnm1234567890QWERTYUIOPASDFGHJKLZXCVBNM")
                                let filtered = newValue.unicodeScalars.filter { allowedCharacters.contains($0) }
                                let newName = String(String.UnicodeScalarView(filtered))
                                if newName.count > 14 { 
                                    userName = String(newName.prefix(14)) 
                                } else {
                                    userName = newName
                                }
                                
                                // ANDROID PARITY: Check profanity while typing like Android TextWatcher
                                if !newName.isEmpty {
                                    checkUsernameProfanity(newName)
                                }
                            }
                        
                        // ANDROID PARITY: Age field matching User_age EditText
                        TextField("Age", text: $userAge)
                            .font(.system(size: 16))  // 16sp in Android
                            .padding(.horizontal, 15)  // Horizontal padding only
                            .frame(height: 56)  // Standard height for consistency
                            .background(Color("shade_200"))  // shade_200 backgroundTint
                            .cornerRadius(12)  // More curved corners
                            .foregroundColor(Color("dark"))  // textColor
                            .keyboardType(.numberPad)  // inputType="number" in Android
                            .focused($focusedField, equals: .age)
                            .onChange(of: userAge) { newValue in
                                // ANDROID PARITY: maxLength="2" from activity_login.xml
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue { userAge = filtered }
                                if userAge.count > 2 { userAge = String(userAge.prefix(2)) }
                            }
                        
                        // ANDROID PARITY: Gender RadioGroup matching gender_group
                        HStack {
                            // ANDROID PARITY: Male RadioButton
                            Button(action: { selectedGender = "Male" }) {
                                HStack {
                                    Image(systemName: selectedGender == "Male" ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(Color("ColorAccent"))
                                    Text("Male")
                                        .font(.system(size: 16))  // 16sp in Android
                                        .foregroundColor(Color("shade_600"))  // textColor in Android
                                }
                            }
                            .padding(.trailing, 24)  // 24dp marginEnd in Android
                            
                            // ANDROID PARITY: Female RadioButton
                            Button(action: { selectedGender = "Female" }) {
                                HStack {
                                    Image(systemName: selectedGender == "Female" ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(Color("ColorAccent"))
                                    Text("Female")
                                        .font(.system(size: 16))  // 16sp in Android
                                        .foregroundColor(Color("shade_600"))  // textColor in Android
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 15)  // Horizontal padding only
                        .frame(height: 56)  // Standard height for consistency
                        .background(Color("shade_200"))  // shade_200 backgroundTint
                        .cornerRadius(12)  // More curved corners
                        
                        // ANDROID PARITY: Country AutoCompleteTextView with inline suggestions
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                TextField("Country", text: $selectedCountryName)
                                    .font(.system(size: 16))  // 16sp in Android
                                    .padding(.horizontal, 15)  // Horizontal padding only
                                    .frame(height: 56)  // Standard height for consistency
                                    .background(Color("shade_200"))  // shade_200 backgroundTint
                                    .cornerRadius(12)  // More curved corners
                                    .foregroundColor(Color("dark"))  // textColor
                                    .focused($focusedField, equals: .country)
                                    .autocapitalization(.words)  // textCapWords in Android
                                    .disableAutocorrection(true)
                                    .onChange(of: selectedCountryName) { newValue in
                                        // ANDROID PARITY: TextWatcher onTextChanged
                                        if allCountries.contains(newValue) {
                                            // Valid country selected
                                            showCountrySuggestions = false
                                        } else {
                                            // Filter suggestions
                                            filteredCountries = allCountries.filter { country in
                                                country.lowercased().contains(newValue.lowercased())
                                            }
                                            showCountrySuggestions = !newValue.isEmpty && !filteredCountries.isEmpty
                                        }
                                    }
                                    .onTapGesture {
                                        // PERFORMANCE OPTIMIZATION: Only initialize if not already done
                                        if !isInitialized {
                                            initializeDataIfNeeded()
                                        }
                                        showCountrySuggestions = true
                                        filteredCountries = allCountries
                                    }
                                
                                // ANDROID PARITY: AutoCompleteTextView dropdown suggestions
                                if showCountrySuggestions && !filteredCountries.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(Array(filteredCountries.prefix(5).enumerated()), id: \.offset) { index, country in
                                            Button(action: {
                                                selectedCountryName = country
                                                showCountrySuggestions = false
                                                focusedField = nil
                                            }) {
                                                HStack {
                                                    Text(country)
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color("dark"))
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 15)
                                                .padding(.vertical, 10)
                                                .background(Color("Background Color"))  // popupBackground in Android
                                            }
                                            
                                            if index < min(4, filteredCountries.count - 1) {
                                                Divider()
                                                    .background(Color("shade_200"))
                                            }
                                        }
                                    }
                                    .background(Color("Background Color"))  // popupBackground
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("shade_200"), lineWidth: 1)
                                    )
                                    .frame(maxHeight: 200)  // dropDownHeight="200dp" in Android
                                }
                            }
                        }
                        
                        // ANDROID PARITY: Language AutoCompleteTextView with inline suggestions
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                TextField("Language", text: $selectedLanguage)
                                    .font(.system(size: 16))  // 16sp in Android
                                    .padding(.horizontal, 15)  // Horizontal padding only
                                    .frame(height: 56)  // Standard height for consistency
                                    .background(Color("shade_200"))  // shade_200 backgroundTint
                                    .cornerRadius(12)  // More curved corners
                                    .foregroundColor(Color("dark"))  // textColor
                                    .focused($focusedField, equals: .language)
                                    .autocapitalization(.words)  // textCapWords in Android
                                    .disableAutocorrection(true)
                                    .onChange(of: selectedLanguage) { newValue in
                                        // ANDROID PARITY: TextWatcher onTextChanged
                                        if allLanguages.contains(newValue) {
                                            // Valid language selected
                                            showLanguageSuggestions = false
                                        } else {
                                            // Filter suggestions
                                            filteredLanguages = allLanguages.filter { language in
                                                language.lowercased().contains(newValue.lowercased())
                                            }
                                            showLanguageSuggestions = !newValue.isEmpty && !filteredLanguages.isEmpty
                                        }
                                    }
                                    .onTapGesture {
                                        // PERFORMANCE OPTIMIZATION: Only initialize if not already done
                                        if !isInitialized {
                                            initializeDataIfNeeded()
                                        }
                                        // LANGUAGE FIX: Ensure we have the latest language list
                                        allLanguages = CountryLanguageHelper.shared.getAllLanguages()
                                        showLanguageSuggestions = true
                                        filteredLanguages = allLanguages
                                        AppLogger.log(tag: "LOG-APP: LoginView", message: "Language field tapped - showing \(filteredLanguages.count) languages")
                                    }
                                
                                // ANDROID PARITY: AutoCompleteTextView dropdown suggestions
                                if showLanguageSuggestions && !filteredLanguages.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(Array(filteredLanguages.prefix(5).enumerated()), id: \.offset) { index, language in
                                            Button(action: {
                                                selectedLanguage = language
                                                showLanguageSuggestions = false
                                                focusedField = nil
                                            }) {
                                                HStack {
                                                    Text(language)
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color("dark"))
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 15)
                                                .padding(.vertical, 10)
                                                .background(Color("Background Color"))  // popupBackground in Android
                                            }
                                            
                                            if index < min(4, filteredLanguages.count - 1) {
                                                Divider()
                                                    .background(Color("shade_200"))
                                            }
                                        }
                                    }
                                    .background(Color("Background Color"))  // popupBackground
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("shade_200"), lineWidth: 1)
                                    )
                                    .frame(maxHeight: 200)  // dropDownHeight="200dp" in Android
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)  // 20dp marginHorizontal in Android
                    .padding(.top, 20)  // Reduced top padding since header now has its own padding
                    
                    // ANDROID PARITY: Privacy Policy Section
                    VStack(spacing: 40) {  // Increased spacing to match language button to privacy button spacing
                        Button(action: { onPrivacyPolicy?() }) {
                            Text("View our privacy policy and terms and conditions")
                                .font(.system(size: 13))  // Slightly larger for better readability
                                .foregroundColor(Color("dark"))  // Better theme-aware color
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)  // Standard height for consistency
                                .background(Color("shade_200"))  // Light grey in light mode, dark grey in dark mode
                                .cornerRadius(12)  // More curved corners
                        }
                        
                        // ANDROID PARITY: CheckBox matching check_box - Updated to match WelcomeView design
                        Button(action: {
                            privacyBoxChecked.toggle()
                            AppLogger.log(tag: "LOG-APP: LoginView", message: "privacyBoxChecked toggled to: \(privacyBoxChecked)")
                            // Haptic feedback for better user experience
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(alignment: .top, spacing: 16) {
                                // Custom checkbox visual matching WelcomeView
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(privacyBoxChecked ? Color("ColorAccent") : Color("Background Color"))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    privacyBoxChecked ? Color("ColorAccent") : Color("shade4"),
                                                    lineWidth: 2
                                                )
                                        )
                                    
                                    if privacyBoxChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .scaleEffect(privacyBoxChecked ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: privacyBoxChecked)
                                .padding(.top, 2)
                                
                                Text("By clicking you accept to our privacy policy and terms")
                                    .font(.system(size: 13))  // Slightly larger for better readability
                                    .foregroundColor(Color("dark"))  // Better theme-aware color
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)  // Allow multiple lines if needed
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .padding(.horizontal, 4)  // Minimal horizontal padding
                    }
                    .padding(.horizontal, 20)  // 20dp marginHorizontal in Android
                    .padding(.top, 40)  // Better spacing from fields above
                    
                    // ANDROID PARITY: Error display area for showCustomToast (moved above Enter button for better visibility)
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 10)  // Add bottom padding for spacing from button
                    }
                    
                    // ANDROID PARITY: Enter Button matching Enter_btn MaterialButton
                    Button(action: { 
                        clickListeners()  // Call Android-style click handler
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)  // Standard button height
                        } else {
                            HStack(spacing: 12) {
                                Text("Enter")
                                    .font(.system(size: 18, weight: .bold))  // Larger, bolder text
                                    .foregroundColor(.white)  // textColor white in Android
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)  // Standard button height for better touch area
                        }
                    }
                    .background(Color("ColorAccent"))  // backgroundTint in Android
                    .cornerRadius(12)  // More curved corners to match other elements
                    .disabled(!privacyBoxChecked || isLoading)  // enabled state logic
                    .opacity(privacyBoxChecked ? 1.0 : 0.5)  // alpha 0.5 when disabled
                    .padding(.horizontal, 20)  // 20dp marginHorizontal in Android
                    .padding(.top, showError ? 5 : 25)  // Reduced top padding when error is shown
                    .padding(.bottom, 40)  // 40dp marginBottom in Android
                }
                .onTapGesture {
                    // ANDROID PARITY: Hide keyboard on tap outside
                    focusedField = nil
                    showCountrySuggestions = false
                    showLanguageSuggestions = false
                }
                
                // ANDROID PARITY: Header overlay with blur effect
                VStack {
                    HStack {
                        Text("ChatHub")
                            .font(.system(size: 34, weight: .bold))  // 34sp in Android
                            .foregroundColor(Color("dark"))
                        Spacer()
                        Button(action: { onLoginWithCredentials?() }) {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(Color("ColorAccent"))
                        }
                    }
                    .padding(.horizontal, 25)  // 25dp margin in Android
                    .padding(.top, 25)
                    .padding(.bottom, 15)
                    .background(.ultraThinMaterial)  // Blur background
                    
                    Spacer()  // Push header to top
                }
            }
            
            // ANDROID PARITY: Progress Bar overlay matching progress_bar
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea(.all)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("shade_900")))
                    .padding(10)  // 10dp padding in Android
                    .background(Color("shade_300"))  // backgroundTint in Android
                    .cornerRadius(8)  // background_corner
            }
        }

        .onAppear {
            AppLogger.log(tag: "LOG-APP: LoginView", message: "onCreate() called")
            // PERFORMANCE OPTIMIZATION: Initialize data asynchronously to prevent UI lag
            initializeDataIfNeeded()
            // ANDROID PARITY: Initialize profanity service early like Android ProfanityWorker
            initializeProfanityService()
            
            // NOTIFICATION: Listen for language updates to refresh suggestions
            NotificationCenter.default.addObserver(
                forName: CountryLanguageHelper.languagesDidUpdateNotification,
                object: nil,
                queue: .main
            ) { _ in
                AppLogger.log(tag: "LOG-APP: LoginView", message: "Languages updated - refreshing language list")
                // Refresh language list when full list becomes available
                allLanguages = CountryLanguageHelper.shared.getAllLanguages()
                // If language field is focused and suggestions are showing, refresh them
                if focusedField == .language && showLanguageSuggestions {
                    if selectedLanguage.isEmpty {
                        filteredLanguages = allLanguages
                    } else {
                        filteredLanguages = allLanguages.filter { language in
                            language.lowercased().contains(selectedLanguage.lowercased())
                        }
                 }
             }
         }
     }
     .onDisappear {
         // CLEANUP: Remove notification observer
         NotificationCenter.default.removeObserver(self, name: CountryLanguageHelper.languagesDidUpdateNotification, object: nil)
     }
 }
 
 // PERFORMANCE OPTIMIZATION: Initialize data efficiently to prevent keyboard lag
 private func initializeDataIfNeeded() {
     // Skip if already initialized
     guard !isInitialized else { return }
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() called")
     
     // ANDROID PARITY: Initialize country list exactly like Android (fast operation)
     allCountries = CountryLanguageHelper.shared.getAllCountries()
     
     // ANDROID PARITY: Initialize language list exactly like Android (now optimized)
     allLanguages = CountryLanguageHelper.shared.getAllLanguages()
     
     // Mark as initialized to prevent redundant work
     isInitialized = true
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() initialized \(allCountries.count) countries and \(allLanguages.count) languages")
     
     // ANDROID PARITY: Check for existing session like Android onCreate (lines 195-215)
     if Auth.auth().currentUser != nil && UserSessionManager.shared.userId != nil {
         handleExistingSession()
     } else {
         // ANDROID PARITY: Clear session on auth failure like Android (lines 211-215)
         AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() no existing session, clearing session data")
         
         // ANDROID PARITY: Sign out from Firebase like Android mAuth.signOut()
         do {
             try Auth.auth().signOut()
             AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() Firebase sign out successful")
         } catch {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() Firebase sign out error: \(error.localizedDescription)")
         }
         
         // ANDROID PARITY: Clear session like Android sessionManager.clearSession()
         UserSessionManager.shared.clearUserSession()
         AppSettingsSessionManager.shared.clearAppSettings()
         ModerationSettingsSessionManager.shared.clearModerationSettings()
         MessagingSettingsSessionManager.shared.clearMessagingSettings()
         
                 // Session clearing - advertising functionality removed
         
         AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeDataIfNeeded() session cleanup completed")
     }
 }
 
 // ANDROID PARITY: Initialize profanity service early like Android ProfanityWorker
 private func initializeProfanityService() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "initializeProfanityService() called")
     
     // ANDROID PARITY: Start profanity work like Android ProfanityWorker.doWork()
     ProfanityService.shared.startProfanityWork()
     
     // ANDROID PARITY: Check for profanity updates like Android FirebaseServices.checkProfanityUpdate()
     ProfanityService.shared.checkProfanityUpdate()
 }
 
 // ANDROID PARITY: Check username profanity while typing like Android TextWatcher
 private func checkUsernameProfanity(_ username: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUsernameProfanity() checking: \(username)")
     
     // ANDROID PARITY: Use doesContainProfanityNumbersAllowed like Android LoginActivity
     if Profanity.share.doesContainProfanityNumbersAllowed(username) {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUsernameProfanity() profanity detected in username: \(username)")
         // ANDROID PARITY: Increment text moderation score like Android
         incrementTextModerationScore()
     }
 }
 
 // ANDROID PARITY: Increment text moderation score like Android sessionManager.setHiveTextModerationScore
 private func incrementTextModerationScore() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "incrementTextModerationScore() incrementing moderation score")
             let currentScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
        ModerationSettingsSessionManager.shared.hiveTextModerationScore = currentScore + 10
        AppLogger.log(tag: "LOG-APP: LoginView", message: "incrementTextModerationScore() new score: \(ModerationSettingsSessionManager.shared.hiveTextModerationScore)")
 }
 
 // ANDROID PARITY: findViews() method from LoginActivity.java (kept for compatibility)
 private func findViews() {
     // PERFORMANCE OPTIMIZATION: Delegate to optimized method
     initializeDataIfNeeded()
 }
 
 private func handleExistingSession() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "handleExistingSession() - User already logged in")
     // ANDROID PARITY: Clear filters and navigate like Android
     clearAllFilters()
     // REMOVED: Games fetch moved to centralized AppDelegate initialization
     MessagingSettingsSessionManager.shared.lastMessageReceivedTime = Date().timeIntervalSince1970
     
     // ANDROID PARITY: Set user online status when existing user opens app (like Android)
     OnlineStatusService.shared.setUserOnline()
     
     // ANDROID PARITY: Start subscription listener for existing user (like Android SubscriptionListenerManager.startListener())
     SubscriptionListenerManager.shared.startListener()
     
     // ANDROID PARITY: Start reports listener for existing users (like Android GetReportsWorker)
     GetReportsService.shared.startReportsListener()
     
     // ANDROID PARITY: Start calls listener for existing users (like Android CallsWorker)
     CallsService.shared.startCallsListener()
     
     // ANDROID PARITY: Check for manual bans before allowing existing user to proceed
     performManualBanCheck {
         // ANDROID PARITY: Check welcome timer like Android
         let currentTime = Date().timeIntervalSince1970
         if (UserSessionManager.shared.welcomeTimer + 3600) < currentTime {
             // Navigate to WelcomeActivity equivalent
             self.onLoginSuccess?()
         } else {
             // Navigate to MainActivity equivalent
             self.onLoginSuccess?()
         }
     }
 }
 
 // ANDROID PARITY: clearAllFilters() method from LoginActivity.java
 private func clearAllFilters() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "clearAllFilters() called")
     // ANDROID PARITY: Clear filter settings in SessionManager like Android sessionManager.clearAllFilters()
             let success = UserSessionManager.shared.clearAllFilters()
     AppLogger.log(tag: "LOG-APP: LoginView", message: "clearAllFilters() completed with success: \(success)")
 }

 // ANDROID PARITY: clickListeners() method from LoginActivity.java - Enter button logic
 private func clickListeners() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "clickListeners() Enter button clicked")
     
     // ANDROID PARITY: Hide keyboard like Android
     focusedField = nil
     showCountrySuggestions = false
     showLanguageSuggestions = false
     
     // ANDROID PARITY: Disable button and show loading like Android
     isLoading = true
     
     // ANDROID PARITY: Exact validation logic from Android EnterBtn.setOnClickListener
     do {
         let deviceId = UUIDManager.sharedInstance.getUUID()  // Android device_id equivalent
         
         // ANDROID PARITY: Profanity check using doesContainProfanityNumbersAllowed like Android LoginActivity
         if Profanity.share.doesContainProfanityNumbersAllowed(userName) {
             showCustomToast("Username contains inappropriate characters, username not allowed. Please use a proper username.")
             isLoading = false
             // ANDROID PARITY: Increment text moderation score like Android
             incrementTextModerationScore()
             return
         } else if userName.count < 4 {
             showCustomToast("User name should not be less than 4 letters")
             isLoading = false
             return
         } else if userName.count > 14 {
             showCustomToast("User name should be less than 14 letters")
             isLoading = false
             return
         } else if let ageInt = Int(userAge), ageInt < 18 {
             showCustomToast("User age should be greater than 18 years")
             isLoading = false
             return
         } else if selectedGender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
             showCustomToast("Please Select a Gender")
             isLoading = false
             return
         } else if selectedCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !allCountries.contains(selectedCountryName) {
             showCustomToast("Please select a country from the list")
             isLoading = false
             return
         } else if !privacyBoxChecked {
             showCustomToast("Please Accept Privacy Policy And Terms")
             isLoading = false
             return
         } else if selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !allLanguages.contains(selectedLanguage) {
             showCustomToast("Please select a language from the list")
             isLoading = false
             return
         } else if deviceId.isEmpty {
             showCustomToast("Unable to get device details")
             isLoading = false
             return
         } else {
             // ANDROID PARITY: All validations passed, call createFirebaseInstallation
             createFirebaseInstallation()
         }
     } catch {
         showCustomToast("Error \(error.localizedDescription)")
         isLoading = false
     }
 }
 
 // ANDROID PARITY: showCustomToast() method from LoginActivity.java
 private func showCustomToast(_ message: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "showCustomToast() \(message)")
     errorMessage = message
     showError = true
     
     // Auto-hide after 3 seconds like Android Toast
     DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
         self.showError = false
     }
 }
 
 // Removed local containsProfanity function - now using ProfanityService.shared consistently
 
 // ANDROID PARITY: createFirebaseInstallation() method from LoginActivity.java
 private func createFirebaseInstallation() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseInstallation()")
     
     Installations.installations().installationID { [self] (id, error) in
         if let error = error {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseInstallation() error: \(error.localizedDescription)")
             self.isLoading = false
             self.showCustomToast("Error in creating firebase installation. Please try again after few minutes")
             return
         }
         
         if id != nil {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseInstallation() successful")
             self.firebaseSignInUserAnonymously()
         } else {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseInstallation() failed - ID was nil")
             self.isLoading = false
             self.showCustomToast("Error in creating firebase installation. Please try again after few minutes")
         }
     }
 }
 
 // ANDROID PARITY: firebaseSignInUserAnonymously() method from LoginActivity.java
 private func firebaseSignInUserAnonymously() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "firebaseSignInUserAnonymously()")
     
     // CRITICAL: Check if account removal is in progress to prevent conflicts
     if FirebaseOperationCoordinator.shared.isAccountRemovalActive() {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "firebaseSignInUserAnonymously() waiting for account removal to complete")
         
         DispatchQueue.global(qos: .userInitiated).async {
             // Wait for account removal to complete with timeout
             FirebaseOperationCoordinator.shared.waitForAccountRemovalCompletion(timeout: 15.0)
             
             DispatchQueue.main.async {
                 // Retry after account removal completes
                 self.firebaseSignInUserAnonymously()
             }
         }
         return
     }
     
     // ANDROID PARITY: Verify Firebase Auth instance like Android
     let firebaseAuth = Auth.auth()
     if firebaseAuth.currentUser == nil {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "Firebase Auth current user is null, proceeding with anonymous sign in")
     }
     
     // ANDROID PARITY: Check if already signed in like Android
     if firebaseAuth.currentUser != nil {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "User already signed in, proceeding with checkUserNameUniqueness")
         checkUserNameUniqueness()
         return
     }
     
     // SECURITY FIX: Add timeout handling for Firebase authentication
     var timeoutCanceled = false
     let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
         timeoutCanceled = true
         AppLogger.log(tag: "LOG-APP: LoginView", message: "Firebase authentication timeout after 30 seconds")
         isLoading = false
         showCustomToast("Authentication timeout. Please check your internet connection and try again.")
     }
     
     firebaseAuth.signInAnonymously { (authResult, error) in
         timeoutTimer.invalidate()
         
         if timeoutCanceled { return }
         
         if let error = error {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "firebaseSignInUserAnonymously() failed: \(error.localizedDescription)")
             self.isLoading = false
             let errorMessage = "Error while signing in. \(error.localizedDescription)"
             showCustomToast(errorMessage)
             Crashlytics.crashlytics().record(error: error)
             return
         }
         
         if authResult?.user != nil {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "firebaseSignInUserAnonymously() onComplete successful")
             checkUserNameUniqueness()
         } else {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "firebaseSignInUserAnonymously() onComplete failed: user was nil")
             self.isLoading = false
             showCustomToast("Error while signing in. Unknown error")
         }
     }
 }
 
 // ANDROID PARITY: checkUserNameUniqueness() method from LoginActivity.java
 private func checkUserNameUniqueness() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUserNameUniqueness()")
     
     let db = Firestore.firestore()
     db.collection("Users")
         .whereField("User_name", isEqualTo: userName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: ""))
         .getDocuments { [self] (querySnapshot, error) in
             
             if let error = error {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUserNameUniqueness() error: \(error.localizedDescription)")
                 self.isLoading = false
                 showCustomToast("Error in creating user in firebase. Please try again after few minutes")
                 return
             }
             
             if let snapshot = querySnapshot, !snapshot.documents.isEmpty {
                 // ANDROID PARITY: Username exists, add random number like Android
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUserNameUniqueness() username already exists")
                 
                 let randomNumber = Int.random(in: 0...9)  // Generates number between 0 and 9
                 self.userName = self.userName + String(randomNumber)
                 
                 self.showCustomToast("Username already exists checking with a slighty different username")
                 
                 // ANDROID PARITY: Recursive call with new username
                 checkUserNameUniqueness()
             } else {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "checkUserNameUniqueness() username does not exist")
                 self.createFirebaseMessagingDeviceToken()
             }
         }
 }
 
 // ANDROID PARITY: createFirebaseMessagingDeviceToken() method from LoginActivity.java
 // iOS UX IMPROVEMENT: Create account with placeholder token, get real token contextually later
 private func createFirebaseMessagingDeviceToken() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseMessagingDeviceToken() creating account with placeholder token")
     
     // iOS UX IMPROVEMENT: Use placeholder token for account creation
     // Real FCM token will be obtained when user tries to send first message
     let placeholderToken = "ios_pending_notification_permission_\(Date().timeIntervalSince1970)"
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "createFirebaseMessagingDeviceToken() using placeholder token for better UX")
     
     self.deviceToken = placeholderToken
     self.saveUserInFirebase(deviceToken: placeholderToken)
 }
 
 // ANDROID PARITY: saveUserInFirebase() method from LoginActivity.java
 private func saveUserInFirebase(deviceToken: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase()")
     
     guard let firebaseUser = Auth.auth().currentUser else {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase() firebaseUser null")
         isLoading = false
         showCustomToast("Error in creating user in firebase. Please try again after few minutes")
         return
     }
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase() firebaseUser not null")
     
     let deviceId = UUIDManager.sharedInstance.getUUID()
     
     // ANDROID PARITY: Get MAC address like Android
     var userMac = ""
     // iOS doesn't allow MAC address access, use device ID as fallback
     userMac = deviceId
     
     // ANDROID PARITY: Get IP addresses like Android
     let ipv4Address = getIPAddress(version: .ipv4) ?? "it_was_null"
     let ipv6Address = getIPAddress(version: .ipv6) ?? "it_was_null"
     
     do {
         // ANDROID PARITY: Create User map exactly like Android
         let userData: [String: Any] = [
             "User_name": userName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: ""),
             "user_name_lowercase": userName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
             "User_gender": selectedGender,
             "User_age": userAge,
             "User_country": selectedCountryName,
             "User_device_token": deviceToken,
             "User_device_id": deviceId,
             "User_register_user_time": FieldValue.serverTimestamp(),
             "last_time_seen": FieldValue.serverTimestamp(),
             "user_language": selectedLanguage,
             "is_user_online": true,
             "User_image": "null",  // Will be updated later when image is ready
             "User_id": firebaseUser.uid,
             "User_registered_time": Int64(Date().timeIntervalSince1970),
             "emulator": false,  // Always false for iOS App Store builds
             "mac_id": userMac,
             "platform": "iOS",  // Changed from "android" to "iOS"
             "ipv4_address": ipv4Address,
             "ipv6_address": ipv6Address
         ]
         
         // ANDROID PARITY: Add move_to_inbox for Female like Android
         var finalUserData = userData
         if selectedGender == "Female" {
             finalUserData["move_to_inbox"] = true
         }
         
         let db = Firestore.firestore()
         db.collection("Users").document(firebaseUser.uid).setData(finalUserData, merge: true) { error in
             if let error = error {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase() error: \(error.localizedDescription)")
                 self.isLoading = false
                 showCustomToast("Error in creating user in firebase. Please try again after few minutes")
                 return
             }
             
             AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase() user created successfully")
             
             // ANDROID PARITY: Call all the same methods as Android
             checkAndSetupFirstTimeDeviceAccount(deviceId: deviceId)
             setupFirebaseAccountGenderCounter()
             setupSession(deviceToken: deviceToken)
             // REMOVED: Games fetch moved to centralized AppDelegate initialization
             
             // CRITICAL FIX: Add small delay to ensure Firebase document is fully created before setting online status
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                 // ANDROID PARITY: Set user online status after successful account creation (like Android)
                 OnlineStatusService.shared.setUserOnline()
                 
                 // ANDROID PARITY: Start reports listener for new users (like Android GetReportsWorker)
                 GetReportsService.shared.startReportsListener()
                 
                 // ANDROID PARITY: Start calls listener for new users (like Android CallsWorker)
                 CallsService.shared.startCallsListener()
             }
             
             // ANDROID PARITY: Check for manual bans before allowing login success
             performManualBanCheck {
                 self.isLoading = false
                 onLoginSuccess?()
             }
         }
     } catch {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "saveUserInFirebase() error: \(error.localizedDescription)")
         isLoading = false
         showCustomToast("Error in creating user in firebase. Please try again after few minutes")
     }
 }
 
 // ANDROID PARITY: setupSession() method from LoginActivity.java
 private func setupSession(deviceToken: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "setupSession()")
     
     guard let firebaseUser = Auth.auth().currentUser else {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "setupSession() firebaseUser is null")
         return
     }
     
     let userSessionManager = UserSessionManager.shared
     let appSettingsSessionManager = AppSettingsSessionManager.shared
     let messagingSettingsSessionManager = MessagingSettingsSessionManager.shared
     
     // ANDROID PARITY: Create login session like Android
     userSessionManager.userId = firebaseUser.uid
     userSessionManager.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
     userSessionManager.userGender = selectedGender.trimmingCharacters(in: .whitespacesAndNewlines)
     userSessionManager.userAge = userAge.trimmingCharacters(in: .whitespacesAndNewlines)
     userSessionManager.userCountry = selectedCountryName.trimmingCharacters(in: .whitespacesAndNewlines)
     userSessionManager.userProfilePhoto = generatedProfileImageUrl
     userSessionManager.deviceToken = deviceToken
     
     // ANDROID PARITY: Set user known language like Android
     userSessionManager.userLanguage = selectedLanguage
     
     // ANDROID PARITY: Set welcome timer like Android
     let unixTimeForWelcome = Date().timeIntervalSince1970 - 3600
     userSessionManager.welcomeTimer = unixTimeForWelcome
     
     // ANDROID PARITY: Set device ID like Android
     userSessionManager.deviceId = UUIDManager.sharedInstance.getUUID()
     
     // ANDROID PARITY: Set move to inbox for Female like Android
     if selectedGender == "Female" {
         messagingSettingsSessionManager.moveToInboxSelected = true
     }
     
     // ANDROID PARITY: Set network session like Android
     let userMac = UUIDManager.sharedInstance.getUUID()  // iOS fallback
     let ipv4 = getIPAddress(version: .ipv4) ?? "it_was_null"
     let ipv6 = getIPAddress(version: .ipv6) ?? "it_was_null"
     userSessionManager.macAddress = userMac
     userSessionManager.userIPv4 = ipv4
     userSessionManager.userIPv6 = ipv6
     
     // ANDROID PARITY: Set call seconds like Android
     messagingSettingsSessionManager.callSeconds = 300
     
     // ANDROID PARITY: Clear all filters like Android
     clearAllFilters()
     
     // ANDROID PARITY: Start subscription listener after account creation (like Android SubscriptionListenerManager.startListener())
     SubscriptionListenerManager.shared.startListener()
     
     // ANDROID PARITY: Call getProfile() like Android
     getProfile()
     
     // Synchronize all session managers
     userSessionManager.synchronize()
     appSettingsSessionManager.synchronize()
     messagingSettingsSessionManager.synchronize()
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "setupSession() done")
 }
 
 // ANDROID PARITY: setupFirebaseAccountGenderCounter() method from LoginActivity.java
 private func setupFirebaseAccountGenderCounter() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "setupFirebaseAccountGenderCounter()")
     
     let deviceId = UUIDManager.sharedInstance.getUUID()
     var putNotification: [String: Any] = [:]
     
     if selectedGender == "Male" {
         putNotification["male_accounts"] = FieldValue.increment(Int64(1))
     } else {
         putNotification["female_accounts"] = FieldValue.increment(Int64(1))
     }
     
     let db = Firestore.firestore()
     db.collection("UserDevData").document(deviceId).setData(putNotification, merge: true) { error in
         if let error = error {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "setupFirebaseAccountGenderCounter() onFailure: \(error.localizedDescription)")
         } else {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "setupFirebaseAccountGenderCounter() onSuccess")
         }
     }
 }
 
 // ANDROID PARITY: checkAndSetupFirstTimeDeviceAccount() method from LoginActivity.java
 // ANDROID PARITY: Check for manual bans before allowing login success
 private func performManualBanCheck(completion: @escaping () -> Void) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "performManualBanCheck() Starting manual ban verification")
     
     // Use ManualBanCheckService to verify user is not banned
     ManualBanCheckService.shared.checkAllBanTypes { isBanned in
         DispatchQueue.main.async {
             if isBanned {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "performManualBanCheck() User is banned - blocking login")
                 self.isLoading = false
                 self.showCustomToast("Your account has been restricted. Please contact support for assistance.")
                 
                 // ANDROID PARITY: Sign out banned user like Android
                 UserSessionManager.shared.clearUserSession()
                 AppSettingsSessionManager.shared.clearAppSettings()
                 ModerationSettingsSessionManager.shared.clearModerationSettings()
                 MessagingSettingsSessionManager.shared.clearMessagingSettings()
             } else {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "performManualBanCheck() User verification passed - proceeding with login")
                 completion()
             }
         }
     }
 }
 
 private func checkAndSetupFirstTimeDeviceAccount(deviceId: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "checkAndSetupFirstTimeDeviceAccount()")
     
     if deviceId.isEmpty {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "Device ID is null or empty")
         return
     }
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "deviceId = \(deviceId)")
     
     let db = Firestore.firestore()
     db.collection("UserDevData")
         .document(deviceId)
         .getDocument { (documentSnapshot, error) in
             
             if let error = error {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "Error checking first time device status: \(error.localizedDescription)")
                 return
             }
             
             if let snapshot = documentSnapshot,
                !snapshot.exists || !(snapshot.data()?.keys.contains("first_account_created_time") ?? false) {
                 // This is the first account from this device
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "First account from this device, setting timestamp")
                 
                 let firstTimeData: [String: Any] = [
                     "first_account_created_time": FieldValue.serverTimestamp()
                 ]
                 
                 db.collection("UserDevData")
                     .document(deviceId)
                     .setData(firstTimeData, merge: true) { error in
                         if let error = error {
                             AppLogger.log(tag: "LOG-APP: LoginView", message: "Error saving first time device data: \(error.localizedDescription)")
                         } else {
                             AppLogger.log(tag: "LOG-APP: LoginView", message: "First time device data saved successfully")
                             DispatchQueue.main.async {
                                 UserSessionManager.shared.firstAccountCreatedTime = Date().timeIntervalSince1970
                                 AppLogger.log(tag: "LOG-APP: LoginView", message: "First account time saved in session")
                             }
                         }
                     }
             } else {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "Not the first account from this device")
                 // Retrieve the first account time from Firestore and save it in session
                 db.collection("UserDevData")
                     .document(deviceId)
                     .getDocument { (documentSnapshot1, error) in
                         if let error = error {
                             AppLogger.log(tag: "LOG-APP: LoginView", message: "Error retrieving first account time: \(error.localizedDescription)")
                             return
                         }
                         
                         if let snapshot1 = documentSnapshot1,
                            let data = snapshot1.data(),
                            let timestamp = data["first_account_created_time"] as? Timestamp {
                             DispatchQueue.main.async {
                                 UserSessionManager.shared.firstAccountCreatedTime = TimeInterval(timestamp.seconds)
                                 AppLogger.log(tag: "LOG-APP: LoginView", message: "First account time retrieved and saved in session")
                             }
                         }
                     }
             }
         }
 }
 

 
 private func getIPAddress(version: IPAddressVersion = .any) -> String? {
     // Use NWPathMonitor for safe network interface detection
     let monitor = NWPathMonitor()
     let queue = DispatchQueue(label: "NetworkMonitor")
     
     var result: String?
     let semaphore = DispatchSemaphore(value: 0)
     
     monitor.pathUpdateHandler = { path in
         if path.status == .satisfied {
             // Safe way to get IP address without C interop
             if version == .ipv4 || version == .any {
                 result = self.getIPv4Address()
             } else if version == .ipv6 || version == .any {
                 result = self.getIPv6Address()
             }
         }
         semaphore.signal()
     }
     
     monitor.start(queue: queue)
     semaphore.wait()
     monitor.cancel()
     
     return result
 }

 private func getIPv4Address() -> String? {
     // Use URLSession to make a request to an IP detection service
     // This is safer than direct C network calls
     guard let url = URL(string: "https://api.ipify.org") else {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "getIPv4Address() failed to create URL")
         return "it_was_null"
     }
     
     let semaphore = DispatchSemaphore(value: 0)
     var ipAddress: String?
     
     URLSession.shared.dataTask(with: url) { data, response, error in
         if let data = data, let ip = String(data: data, encoding: .utf8) {
             ipAddress = ip.trimmingCharacters(in: .whitespacesAndNewlines)
             AppLogger.log(tag: "LOG-APP: LoginView", message: "getIPv4Address() success: \(ipAddress ?? "nil")")
         } else {
             AppLogger.log(tag: "LOG-APP: LoginView", message: "getIPv4Address() failed: \(error?.localizedDescription ?? "Unknown error")")
         }
         semaphore.signal()
     }.resume()
     
     semaphore.wait()
     return ipAddress ?? "it_was_null"
 }

 private func getIPv6Address() -> String? {
     // Similar implementation for IPv6
     return "it_was_null" // Fallback as in original code
 }
 
 // ANDROID PARITY: getProfile() method from LoginActivity.java
 private func getProfile() {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile()")
     
     let sessionManager = SessionManager.shared
     
     guard let userId = sessionManager.userId,
           !userId.isEmpty,
           userId != " " else {
         AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() userId is null or empty")
         return
     }
     
     AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() fetching profile for userId: \(userId)")
     
     let db = Firestore.firestore()
     
     // ANDROID PARITY: First fetch subscription data like Android GetProfileWorker
     var subscriptionTier = "none"
     var subscriptionExpiry: Int64 = 0
     
     let subscriptionGroup = DispatchGroup()
     
     // Fetch subscription data
     subscriptionGroup.enter()
     db.collection("Users")
         .document(userId)
         .collection("Subscriptions")
         .document("current_state")
         .getDocument { (document, error) in
             defer { subscriptionGroup.leave() }
             
             if let error = error {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() subscription fetch error: \(error.localizedDescription)")
             } else if let document = document, document.exists {
                 if let tier = document.data()?["tier"] as? String {
                     subscriptionTier = tier
                 }
                 if let expiry = document.data()?["expiryTimeMillis"] as? Int64 {
                     subscriptionExpiry = expiry
                 }
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() subscription data - tier: \(subscriptionTier), expiry: \(subscriptionExpiry)")
             } else {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() subscription document 'current_state' not found for user: \(userId)")
             }
         }
     
     // ANDROID PARITY: Fetch main user profile data like Android GetProfileWorker
     subscriptionGroup.notify(queue: .main) {
         db.collection("Users")
             .document(userId)
             .getDocument { [self] (document, error) in
                 
                 if let error = error {
                     AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() error: \(error.localizedDescription)")
                     return
                 }
                 
                 guard let document = document, document.exists else {
                     AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() user document does not exist")
                     return
                 }
                 
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() user document found")
                 
                 let data = document.data() ?? [:]
                 
                 // ANDROID PARITY: Extract all profile fields like Android GetProfileWorker
                 let platform = data["platform"] as? String ?? "null"
                 let userImage = data["User_image"] as? String ?? "null"
                 let userAge = data["User_age"] as? String ?? "null"
                 let userGender = data["User_gender"] as? String ?? "null"
                 let userLanguage = data["user_language"] as? String ?? "null"
                 let userRegisteredTime = data["User_registered_time"] as? Int64 ?? 0
                 let userCountry = data["User_country"] as? String ?? "null"
                 let userDeviceId = data["User_device_id"] as? String ?? "null"
                 let userDeviceToken = data["User_device_token"] as? String ?? "null"
                 let city = data["userRetrievedCity"] as? String ?? "null"
                 let emailVerified = data["User_verified"] as? Bool ?? false
                 let moveToInbox = data["move_to_inbox"] as? Bool ?? false
                 // Removed: let watchModeNumber = data["watch_mode_number"] as? Int64 ?? 0
                 let groupsNumber = data["groups_number"] as? Int64 ?? 0
                 
                 // ANDROID PARITY: Update session with profile data like Android
                 sessionManager.userProfilePhoto = userImage
                 sessionManager.userAge = userAge
                 sessionManager.userGender = userGender
                 sessionManager.userLanguage = userLanguage
                 sessionManager.userCountry = userCountry
                 sessionManager.deviceId = userDeviceId
                 sessionManager.deviceToken = userDeviceToken
                 sessionManager.moveToInboxSelected = moveToInbox
                 
                 // ANDROID PARITY: Store subscription data in session
                 sessionManager.subscriptionTier = subscriptionTier
                 sessionManager.subscriptionExpiry = subscriptionExpiry
                 
                 // ANDROID PARITY: Determine premium status like Android
                 let currentTime = Date().timeIntervalSince1970 * 1000 // Convert to milliseconds
                 let isPremium = subscriptionTier != "none" && 
                                !subscriptionTier.isEmpty && 
                                subscriptionExpiry > Int64(currentTime)
                 
                 sessionManager.isPremiumActive = isPremium
                 
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "getProfile() profile data updated in session - premium: \(isPremium)")
                 
                 // ANDROID PARITY: Fetch device data like Android GetProfileWorker
                 if let deviceId = sessionManager.deviceId, !deviceId.isEmpty {
                     self.fetchDeviceData(deviceId: deviceId)
                 }
                 
                 sessionManager.synchronize()
             }
     }
 }
 
 // ANDROID PARITY: Helper method to fetch device data like Android GetProfileWorker
 private func fetchDeviceData(deviceId: String) {
     AppLogger.log(tag: "LOG-APP: LoginView", message: "fetchDeviceData() for deviceId: \(deviceId)")
     
     let db = Firestore.firestore()
     
     db.collection("UserDevData")
         .document(deviceId)
         .getDocument { (document, error) in
             
             if let error = error {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "fetchDeviceData() error: \(error.localizedDescription)")
                 return
             }
             
             guard let document = document, document.exists else {
                 AppLogger.log(tag: "LOG-APP: LoginView", message: "fetchDeviceData() device document does not exist")
                 return
             }
             
             AppLogger.log(tag: "LOG-APP: LoginView", message: "fetchDeviceData() device document found")
             
             let data = document.data() ?? [:]
             let sessionManager = SessionManager.shared
             
             // ANDROID PARITY: Extract device statistics like Android GetProfileWorker
             let maleAccounts = data["male_accounts"] as? Int64 ?? 0
             let femaleAccounts = data["female_accounts"] as? Int64 ?? 0
             let reports = data["reports"] as? Int64 ?? 0
             let blocks = data["blocks"] as? Int64 ?? 0
             let femaleChats = data["female_chats"] as? Int64 ?? 0
             let maleChats = data["male_chats"] as? Int64 ?? 0
             let voiceCalls = data["voice_calls"] as? Int64 ?? 0
             let videoCalls = data["video_calls"] as? Int64 ?? 0
             let live = data["live"] as? Int64 ?? 0
             let goodExperience = data["good_experience"] as? Int64 ?? 0
             let badExperience = data["bad_experience"] as? Int64 ?? 0
             
             // ANDROID PARITY: Store device statistics in session (if needed)
             // Note: iOS SessionManager may not have all these fields, so we'll log them for now
             AppLogger.log(tag: "LOG-APP: LoginView", message: "fetchDeviceData() device stats - male: \(maleAccounts), female: \(femaleAccounts), reports: \(reports)")
             
             sessionManager.synchronize()
         }
 }
}

// ANDROID PARITY: Helper functions matching Android getAllCountries() and getAllLanguages()
extension LoginView {
    func getAllCountries() -> [String] {
        return CountryLanguageHelper.shared.getAllCountries()
    }
    
    func getAllLanguages() -> [String] {
        return CountryLanguageHelper.shared.getAllLanguages()
    }
}



struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 

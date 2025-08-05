import SwiftUI
import Network
import FirebaseFirestore
import FirebaseAuth
import FirebaseCrashlytics
import Foundation

struct WelcomeView: View {
    @State private var termsAccepted: Bool = false
    @State private var showPrivacySheet: Bool = false
    @State private var networkConnected: Bool = true
    @State private var networkMonitor: NWPathMonitor?
    @State private var isInitialized: Bool = false
    
    // Android parity: Back button handling
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    var onEnter: (() -> Void)?
    
    // Use specialized session managers instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let appSettingsSessionManager = AppSettingsSessionManager.shared
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    private let mDatabase = Firestore.firestore()
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                welcomeContent
            }
        } else {
            NavigationView {
                welcomeContent
            }
        }
    }
    
    private var welcomeContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Section - More welcoming and friendly
                VStack(spacing: 16) {
                    // Welcome emoji and title
                    VStack(spacing: 8) {
                        // Removed the hand emoji from here
                        
                        Text("Welcome to")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        Text("ChatHub!")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                    }
                    

                }
                .padding(.top, 24)

                // Illustration Section - More inviting presentation
                VStack(spacing: 28) {
                    // Main illustration with hand emoji overlay
                    ZStack {
                        Image("chathub")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(width: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .accessibilityLabel("Welcome to ChatHub")
                            .shadow(color: Color("ColorAccent").opacity(0.1), radius: 12, x: 0, y: 6)
                        
                        // Hand emoji overlay on bottom-left
                        VStack {
                            Spacer()
                            HStack {
                                Text("👋")
                                    .font(.system(size: 48))
                                    .offset(x: -10, y: 10) // Slight offset to position it nicely on the left
                                Spacer()
                            }
                        }
                        .frame(maxHeight: 200)
                        .frame(width: 160)
                    }
                        .padding(.horizontal, 20)

                    // Community Guidelines - Reframed as helpful tips
                    VStack(spacing: 24) {
                        // Community Guidelines with friendly approach
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(Color("ColorAccent"))
                                    .font(.system(size: 18, weight: .medium))
                                Text("Community Guidelines")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color("dark"))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                GuidelineRow(
                                    icon: "shield.checkered",
                                    text: "Keep personal details private for your safety",
                                    color: Color("ColorAccent")
                                )
                                
                                GuidelineRow(
                                    icon: "hand.raised.fill",
                                    text: "Share respectful and appropriate content only",
                                    color: Color("ColorAccent")
                                )
                                
                                GuidelineRow(
                                    icon: "message.circle.fill",
                                    text: "Enjoy conversations within our secure platform",
                                    color: Color("ColorAccent")
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color("ColorAccent").opacity(0.08),
                                            Color("ColorAccent").opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color("ColorAccent").opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Age and Support - Softer presentation
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color("shade6"))
                                    .font(.system(size: 16))
                                Text("Quick Note")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color("dark"))
                                Spacer()
                            }
                            
                            VStack(spacing: 10) {
                                Text("This app is designed for users 18 and older. If you're younger or feel uncomfortable at any time, we understand and support your decision to leave.")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color("shade7"))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(4)
                                
                                HStack {
                                    Image(systemName: "envelope.circle.fill")
                                        .foregroundColor(Color("ColorAccent"))
                                        .font(.system(size: 14))
                                    Text("Need assistance? We're here to help: chatstrangersapps@gmail.com")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color("ColorAccent"))
                                }
                                .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("shade1"))
                        )
                        .padding(.horizontal, 20)
                    }
                }

                // Terms and Actions Section - More positive framing
                VStack(spacing: 32) {
                    // Privacy policy button with friendlier design
                    Button(action: { showPrivacySheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Review Our Terms & Privacy")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(Color("ColorAccent"))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("ColorAccent").opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color("ColorAccent").opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 24)

                    // Agreement section with positive language
                    VStack(spacing: 20) {
                        // Make the entire Ready to Join area clickable
                        Button(action: {
                            termsAccepted.toggle()
                            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "termsAccepted toggled to: \(termsAccepted)")
                            // Haptic feedback for better user experience
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(alignment: .top, spacing: 16) {
                                // Custom checkbox visual
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(termsAccepted ? Color("ColorAccent") : Color("Background Color"))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    termsAccepted ? Color("ColorAccent") : Color("shade4"),
                                                    lineWidth: 2
                                                )
                                        )
                                    
                                    if termsAccepted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .scaleEffect(termsAccepted ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: termsAccepted)
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ready to Join?")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color("dark"))
                                    
                                    Text("By continuing, you're agreeing to be part of our respectful community and confirming you've read our terms. We ask for this confirmation periodically to keep everyone safe and happy.")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(Color("shade7"))
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(4)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .padding(.horizontal, 24)

                        // Primary Action Button - More inviting design
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "WelcomeTapped() Continue button tapped")
                            handleOkButtonTap()
                        }) {
                            HStack(spacing: 12) {
                                Text("Start Chatting! 🚀")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        termsAccepted
                                            ? AnyShapeStyle(LinearGradient(
                                                colors: [Color("ColorAccent"), Color("ColorAccent").opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            : AnyShapeStyle(Color("shade4"))
                                    )
                            )
                            .shadow(
                                color: termsAccepted ? Color("ColorAccent").opacity(0.3) : Color.clear,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        }
                        .disabled(!termsAccepted)
                        .scaleEffect(termsAccepted ? 1.0 : 0.98)
                        .animation(.easeInOut(duration: 0.2), value: termsAccepted)
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color("Background Color"))
        .onAppear {
            if !isInitialized {
                viewDidLoad()
                isInitialized = true
            }
        }
        .onDisappear(perform: {
            networkMonitor?.cancel()
            networkMonitor = nil
        })
        .background(
            NavigationLink(
                destination: PrivacyPolicyWebView(),
                isActive: $showPrivacySheet
            ) {
                EmptyView()
            }
            .hidden()
        )
        .navigationTitle("")
#if os(iOS)
        .navigationBarHidden(true)
#endif
        // Android parity: Back button handling with gesture
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Android parity: Handle back gesture (swipe from left edge)
                    if value.startLocation.x < 20 && value.translation.width > 100 {
                        handleBackButtonPressed()
                    }
                }
        )
        // Android parity: Toast message overlay
        .overlay(
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        
                        Text(toastMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("shade7"))
                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 50)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onTapGesture {
                                showToast = false
                            }
                    }
                    .animation(.easeInOut(duration: 0.4), value: showToast)
                }
            }
        )
    }
    
    // MARK: - Android Parity Lifecycle Methods
    
    /// Android parity: onCreate() equivalent
    private func viewDidLoad() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "viewDidLoad() Welcome screen displayed")
        
        // Android parity: Setup Firebase Crashlytics (matching Android onCreate)
        setupFirebaseCrashlytics()
        
        // Android parity: Set text moderation score
        setTextModerationScore()
        
        // Android parity: Check MAC ID
        checkMacId()
        
        // Android parity: Initialize background tasks (iOS equivalent of WorkManager)
        initializeBackgroundTasks()
        
        // Android parity: Setup network monitoring
        setupNetworkMonitoring()
    }
    
    // MARK: - Android Parity Network Check
    
    /// Android parity: checkConnection() equivalent
    private func checkConnection() -> Bool {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "checkConnection() networkConnected: \(networkConnected)")
        return networkConnected
    }
    
    private func setupNetworkMonitoring() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setupNetworkMonitoring() Setting up network monitoring")
        
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [self] path in
            DispatchQueue.main.async {
                self.networkConnected = path.status == .satisfied
                AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setupNetworkMonitoring() Network status changed: \(self.networkConnected)")
            }
        }
        
        networkMonitor?.start(queue: queue)
    }
    
    // MARK: - Android Parity Button Handler
    
    /// Android parity: ok_btn.setOnClickListener() equivalent
    private func handleOkButtonTap() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "handleOkButtonTap() Button tapped")
        
        if !termsAccepted {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "handleOkButtonTap() Terms not accepted")
            // iOS equivalent of Android Toast
            showToastMessage("Read the terms and click check box to agree then enter.")
        } else if !checkConnection() {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "handleOkButtonTap() No internet connection")
            showToastMessage("No Internet Connection")
        } else {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "handleOkButtonTap() Proceeding to main app")
            setUpUserComesInToApp()
            onEnter?()
        }
    }
    
    // MARK: - Android Parity Firebase Operations
    
    /// Android parity: setUpUserComesInToApp() equivalent
    private func setUpUserComesInToApp() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Setting up user session")
        
        // ENHANCEMENT: Clear all filters when welcome screen appears (every 1 hour)
        // This provides a fresh start experience and prevents stale filters
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Clearing all filters for fresh start")
        let filtersClearedSuccess = userSessionManager.clearAllFilters()
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Filters cleared successfully: \(filtersClearedSuccess)")
        
        // Filters cleared - no additional refresh notification needed
        if filtersClearedSuccess {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Filters cleared successfully")
        }
        
        let unixTime = Date().timeIntervalSince1970
        userSessionManager.welcomeTimer = unixTime
        
        guard let userId = userSessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() userId is nil")
            return
        }
        
        let lastTimeOpensApp: [String: Any] = [
            "userAuthId": Auth.auth().currentUser?.uid ?? ""
        ]
        
        mDatabase.collection("Users")
            .document(userId)
            .setData(lastTimeOpensApp, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Firebase error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setUpUserComesInToApp() Firebase success")
                }
            }
    }
    
    /// Android parity: setTextModerationScore() equivalent
    private func setTextModerationScore() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setTextModerationScore() Setting text moderation score")
        
        guard let deviceId = userSessionManager.deviceId else {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setTextModerationScore() deviceId is nil")
            return
        }
        
        // Android parity: Get text moderation score from session (iOS equivalent of getHiveTextModerationScore)
        let textModerationScore = ModerationSettingsSessionManager.shared.hiveTextModerationScore
        
        let dataParams: [String: Any] = [
            "text_moderation_score": FieldValue.increment(Int64(textModerationScore))
        ]
        
        mDatabase.collection("UserDevData")
            .document(deviceId)
            .setData(dataParams, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setTextModerationScore() Firebase error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setTextModerationScore() Firebase success")
                }
            }
    }
    
    // MARK: - Android Parity MAC ID Management
    
    /// Android parity: checkMacId() equivalent
    private func checkMacId() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "checkMacId() Checking MAC ID")
        
        if userSessionManager.macAddress == nil || 
           userSessionManager.macAddress == "null" || 
           userSessionManager.macAddress?.isEmpty == true {
            
            if !checkMacIdExistsInDeviceStorage() {
                createAndSaveMacIdInDeviceStorage()
            }
        }
    }
    
    /// Android parity: checkMacIdExistsInDeviceStorage() equivalent (iOS uses Keychain)
    private func checkMacIdExistsInDeviceStorage() -> Bool {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "checkMacIdExistsInDeviceStorage() Checking stored MAC ID")
        
        // iOS equivalent: Use UUIDClass to get persistent device identifier
        let deviceId = UUIDManager.sharedInstance.getUUID()
        
        if deviceId.isEmpty || deviceId.count < 10 || deviceId.count > 50 {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "checkMacIdExistsInDeviceStorage() Invalid device ID")
            return false
        } else {
            userSessionManager.macAddress = deviceId
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "checkMacIdExistsInDeviceStorage() Valid device ID found")
            return true
        }
    }
    
    /// Android parity: createAndSaveMacIdInDeviceStorage() equivalent
    private func createAndSaveMacIdInDeviceStorage() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "createAndSaveMacIdInDeviceStorage() Creating new MAC ID")
        
        let min = 11
        let max = 99
        let random = Int.random(in: min...max)
        
        let createdMacId = "Created_Mac_Id_\(random)_\(Int(Date().timeIntervalSince1970))"
        
        // iOS equivalent: Save to session manager
        userSessionManager.macAddress = createdMacId
        
        // Android parity: Save to Firebase
        guard let userId = userSessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "createAndSaveMacIdInDeviceStorage() userId is nil")
            return
        }
        
        let dataParams: [String: String] = [
            "created_mac_id": createdMacId
        ]
        
        mDatabase.collection("Users")
            .document(userId)
            .setData(dataParams, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "createAndSaveMacIdInDeviceStorage() Firebase error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: WelcomeView", message: "createAndSaveMacIdInDeviceStorage() MAC ID saved to Firebase")
                }
            }
        
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "createAndSaveMacIdInDeviceStorage() Created MAC ID: \(createdMacId)")
    }
    
    // MARK: - Android Parity Background Tasks
    
    /// Android parity: WorkManager equivalent for iOS
    private func initializeBackgroundTasks() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "initializeBackgroundTasks() Initializing background tasks")
        
        // Android parity: GamesWorker equivalent
        if !SessionManager.shared.gamesFetched {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "initializeBackgroundTasks() Starting games fetch task")
            GamesService.shared.fetchGamesIfNeeded { success in
                AppLogger.log(tag: "LOG-APP: WelcomeView", message: "initializeBackgroundTasks() Games fetch completed: \(success)")
            }
        }
        
        // Android parity: ProfanityWorker equivalent
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "initializeBackgroundTasks() Starting profanity update task")
        ProfanityService.shared.checkProfanityUpdate()
        
        // Android parity: IpDetailsWorker equivalent
        let userRetrievedIp = userSessionManager.userRetrievedIp ?? "null"
        let userRetrievedCity = userSessionManager.userRetrievedCity ?? "null"
        let userRetrievedState = userSessionManager.userRetrievedState ?? "null"
        let userRetrievedCountry = userSessionManager.userRetrievedCountry ?? "null"
        
        if userRetrievedIp == "null" || userRetrievedCity == "null" || 
           userRetrievedState == "null" || userRetrievedCountry == "null" {
            AppLogger.log(tag: "LOG-APP: WelcomeView", message: "initializeBackgroundTasks() Starting IP details fetch task")
            IPAddressService().getIPAddress()
        }
    }
    
    // MARK: - Utility Methods
    
    /// iOS equivalent of Android Toast
    private func showToastMessage(_ message: String) {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "showToastMessage() \(message)")
        
        toastMessage = message
        showToast = true
        
        // Auto-hide toast after 2 seconds (matching Android Toast.LENGTH_SHORT)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showToast = false
        }
    }
    
    // MARK: - Android Parity Firebase Crashlytics Setup
    
    /// Android parity: setupFirebaseCrashlytics() equivalent
    private func setupFirebaseCrashlytics() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setupFirebaseCrashlytics() Setting up Firebase Crashlytics")
        
        // Android parity: FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        
        // Android parity: crashlytics.sendUnsentReports()
        Crashlytics.crashlytics().sendUnsentReports()
        
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "setupFirebaseCrashlytics() Firebase Crashlytics setup completed")
    }
    
    // MARK: - Android Parity Back Button Handling
    
    /// Android parity: onBackPressed() equivalent
    private func handleBackButtonPressed() {
        AppLogger.log(tag: "LOG-APP: WelcomeView", message: "handleBackButtonPressed() Back gesture detected")
        
        // Android parity: Toast.makeText(getApplicationContext(), "scroll down to click on okay button", Toast.LENGTH_SHORT).show()
        showToastMessage("scroll down to click on okay button")
    }
}

#Preview {
    WelcomeView()
}

// MARK: - New Guideline Row Component for better visual organization
struct GuidelineRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
            
            Spacer()
        }
    }
}


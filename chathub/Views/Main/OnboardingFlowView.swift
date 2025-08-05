import SwiftUI
import FirebaseCore
import FirebaseAuth

enum OnboardingScreen {
    case welcome, login, enterOtp(expectedOtp: String, email: String, password: String), forgotPassword, resetPassword(expectedOtp: String, email: String), loginWithCredentials, privacyPolicy
}

enum AppState {
    case launch
    case onboarding
    case mainApp
}

class AppRootManager: ObservableObject {
    @Published var currentState: AppState = .launch
    @Published var needsWelcome = false
    private let welcomeInterval: TimeInterval = 3600 // 1 hour
    
    init() {
        // Start with launch screen, then evaluate app state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.evaluateAppState()
        }
    }
    
    func switchToMainApp() {
        AppLogger.log(tag: "LOG-APP: AppRootManager", message: "switchToMainApp() transitioning to main app")
        currentState = .mainApp
    }
    
    func switchToOnboarding() {
        AppLogger.log(tag: "LOG-APP: AppRootManager", message: "switchToOnboarding() transitioning to onboarding")
        currentState = .onboarding
    }
    
    private func evaluateAppState() {
        // Use specialized session managers instead of monolithic SessionManager
        let userSessionManager = UserSessionManager.shared
        let appSettingsSessionManager = AppSettingsSessionManager.shared
        
        // CRITICAL: Check if account removal is in progress
        if FirebaseOperationCoordinator.shared.isAccountRemovalActive() {
            AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() account removal in progress, forcing onboarding state")
            currentState = .onboarding
            return
        }
        
        // OPTIMIZATION: Quick auth state check without heavy operations
        let hasFirebaseUser = Auth.auth().currentUser != nil
        let hasSessionUserId = userSessionManager.userId != nil && !(userSessionManager.userId?.isEmpty ?? true)
        
        // Check if user is authenticated
        if hasFirebaseUser && hasSessionUserId {
            // User is authenticated, check if welcome is needed
            let lastTime = userSessionManager.welcomeTimer
            let currentTime = Date().timeIntervalSince1970
            let timeSinceWelcome = currentTime - lastTime
            
            AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() user authenticated - lastTime: \(lastTime), currentTime: \(currentTime), timeSinceWelcome: \(timeSinceWelcome)")
            
            if lastTime > 0 && (lastTime + welcomeInterval) < currentTime {
                needsWelcome = true
                AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() welcome needed - time since last welcome: \(timeSinceWelcome)s (threshold: \(welcomeInterval)s)")
            } else {
                needsWelcome = false
                AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() welcome not needed - time since last welcome: \(timeSinceWelcome)s")
            }
            currentState = .mainApp
        } else {
            // User not authenticated, show onboarding
            AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() user not authenticated, showing onboarding - hasFirebaseUser: \(hasFirebaseUser), hasSessionUserId: \(hasSessionUserId)")
            currentState = .onboarding
        }
        
        AppLogger.log(tag: "LOG-APP: AppRootManager", message: "evaluateAppState() currentState: \(currentState), needsWelcome: \(needsWelcome)")
    }
    
    func handleAppBecameActive() {
        // OPTIMIZATION: Debounce rapid state evaluations during account removal
        if FirebaseOperationCoordinator.shared.isAccountRemovalActive() {
            AppLogger.log(tag: "LOG-APP: AppRootManager", message: "handleAppBecameActive() account removal active, deferring evaluation")
            
            // OPTIMIZATION: Schedule evaluation after account removal completes
            DispatchQueue.global(qos: .userInitiated).async {
                // Wait briefly for account removal to complete
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    if !FirebaseOperationCoordinator.shared.isAccountRemovalActive() {
                        self.evaluateAppState()
                    }
                }
            }
            return
        }
        
        // ANDROID PARITY: Don't update welcomeTimer here - only evaluate state
        // The welcomeTimer should only be updated when user completes welcome screen
        // This prevents welcome screen from disappearing when returning from email app
        AppLogger.log(tag: "LOG-APP: AppRootManager", message: "handleAppBecameActive() app became active, evaluating state without updating timer")
        evaluateAppState()
    }
}

struct AppRootView: View {
    @StateObject private var appRootManager = AppRootManager()
    
    var body: some View {
        Group {
            switch appRootManager.currentState {
            case .launch:
                LaunchScreenView()
            case .onboarding:
                OnboardingFlowView(onComplete: {
                    appRootManager.switchToMainApp()
                })
            case .mainApp:
                if appRootManager.needsWelcome {
                    WelcomeView(onEnter: {
                        UserSessionManager.shared.welcomeTimer = Date().timeIntervalSince1970
                        appRootManager.needsWelcome = false
                    })
                } else {
                    MainView()
                }
            }
        }
        .environmentObject(appRootManager)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            appRootManager.handleAppBecameActive()
        }
    }
}

struct OnboardingFlowView: View {
    @State private var screen: OnboardingScreen = .login
    var onComplete: () -> Void

    var body: some View {
        switch screen {
        case .welcome:
            WelcomeView(onEnter: {
                UserSessionManager.shared.welcomeTimer = Date().timeIntervalSince1970
                onComplete()
            })
        case .login:
            LoginView(
                onLoginSuccess: { screen = .welcome },
                onForgotPassword: { screen = .forgotPassword },
                onLoginWithCredentials: { screen = .loginWithCredentials },
                onPrivacyPolicy: { screen = .privacyPolicy }
            )
        case .enterOtp(let expectedOtp, let email, let password):
            // NOTE: EnterOtpView already has its own NavigationView, no need to wrap it
            EnterOtpView(expectedOtp: expectedOtp, email: email, password: password, onVerified: { screen = .welcome })
        case .forgotPassword:
            // ANDROID PARITY: Wrap ForgotPasswordView in NavigationView for proper navigation
            NavigationView {
                ForgotPasswordView(
                    onOtpSent: { otp, email in screen = .resetPassword(expectedOtp: otp, email: email) },
                    onBack: { screen = .login }
                )
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single view style on iPad
        case .resetPassword(let expectedOtp, let email):
            // ANDROID PARITY: Wrap ResetPasswordView in NavigationView for proper navigation
            NavigationView {
                ResetPasswordView(
                    expectedOtp: expectedOtp, 
                    email: email, 
                    onReset: { screen = .login },
                    onBack: { screen = .forgotPassword }
                )
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single view style on iPad
        case .loginWithCredentials:
            // ANDROID PARITY: Wrap LoginWithCredentialsView in NavigationView for proper navigation
            NavigationView {
                LoginWithCredentialsView(
                    onLoginSuccess: { screen = .welcome },
                    onForgotPassword: { screen = .forgotPassword },
                    onBack: { screen = .login }
                )
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single view style on iPad
        case .privacyPolicy:
            // ANDROID PARITY: Wrap PrivacyPolicyContentView in NavigationView for proper navigation
            NavigationView {
                PrivacyPolicyEmbeddedView(onBack: { screen = .login })
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force single view style on iPad
        }
    }
}

#Preview {
    AppRootView()
} 

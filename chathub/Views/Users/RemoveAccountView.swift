import SwiftUI
import FirebaseFirestore
import FirebaseAuth


// MARK: - Firebase Operation Coordinator
/// Prevents race conditions between account removal and login operations
class FirebaseOperationCoordinator {
    static let shared = FirebaseOperationCoordinator()
    private var isAccountRemovalInProgress = false
    private let operationQueue = DispatchQueue(label: "firebase.operations", qos: .userInitiated)
    
    private init() {}
    
    func startAccountRemoval() -> Bool {
        return operationQueue.sync {
            guard !isAccountRemovalInProgress else {
                AppLogger.log(tag: "LOG-APP: FirebaseOperationCoordinator", message: "startAccountRemoval() already in progress")
                return false
            }
            isAccountRemovalInProgress = true
            AppLogger.log(tag: "LOG-APP: FirebaseOperationCoordinator", message: "startAccountRemoval() started")
            return true
        }
    }
    
    func finishAccountRemoval() {
        operationQueue.sync {
            isAccountRemovalInProgress = false
            AppLogger.log(tag: "LOG-APP: FirebaseOperationCoordinator", message: "finishAccountRemoval() completed")
        }
    }
    
    func isAccountRemovalActive() -> Bool {
        return operationQueue.sync {
            return isAccountRemovalInProgress
        }
    }
    
    func waitForAccountRemovalCompletion(timeout: TimeInterval = 15.0) {
        let startTime = CFAbsoluteTimeGetCurrent()
        while isAccountRemovalActive() && (CFAbsoluteTimeGetCurrent() - startTime) < timeout {
            Thread.sleep(forTimeInterval: 0.1)
        }
        AppLogger.log(tag: "LOG-APP: FirebaseOperationCoordinator", message: "waitForAccountRemovalCompletion() finished")
    }
}

// MARK: - Remove Account View (matching Android RemoveAccountActivity exactly)
struct RemoveAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var customFeedback: String = ""
    @State private var isRemoving = false
    @State private var showRemoveConfirmation = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Checkbox states (matching Android exactly - c_zero to c_seven + new options)
    @State private var c_zero = false  // A lot of messages
    @State private var c_one = false   // Notifications problem
    @State private var c_two = false   // Inappropriate messages
    @State private var c_three = false // Coins
    @State private var c_four = false  // Advertisements
    @State private var c_five = false  // No one replies
    @State private var c_six = false   // Can't find people who talk decent
    @State private var c_seven = false // Everything is good, I might come back with a new account
    @State private var c_eight = false // Limits
    @State private var c_nine = false  // Subscription price too high
    
    private let database = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header section with improved visual hierarchy
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Help us improve")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color("dark"))
                            
                            Text("Let us know why you're leaving so we can make the app better for everyone.")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color("shade6"))
                                .lineSpacing(2)
                        }
                        .padding(.top, 8)
                        
                        // Feedback options section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What's your main concern?")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("dark"))
                            
                            VStack(spacing: 12) {
                                CheckboxRow(isChecked: $c_zero, text: "A lot of messages")
                                CheckboxRow(isChecked: $c_one, text: "Notifications problem")
                                CheckboxRow(isChecked: $c_two, text: "Inappropriate messages")
                                CheckboxRow(isChecked: $c_three, text: "Coins")
                                CheckboxRow(isChecked: $c_four, text: "Advertisements")
                                CheckboxRow(isChecked: $c_five, text: "No one replies")
                                CheckboxRow(isChecked: $c_six, text: "Can't find people who talk decent")
                                CheckboxRow(isChecked: $c_seven, text: "Everything is good, I might come back with a new account")
                                CheckboxRow(isChecked: $c_eight, text: "Limits")
                                CheckboxRow(isChecked: $c_nine, text: "Subscription price too high")
                            }
                        }
                        
                        // Custom feedback section with improved design
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional feedback")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("dark"))
                            
                            ZStack(alignment: .topLeading) {
                                if customFeedback.isEmpty {
                                    Text("Tell us more about your experience (optional)")
                                        .font(.system(size: 15))
                                        .foregroundColor(Color("shade5"))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                }
                                
                                Group {
                                    if #available(iOS 16.0, *) {
                                        TextEditor(text: $customFeedback)
                                            .font(.system(size: 15))
                                            .foregroundColor(Color("dark"))
                                            .scrollContentBackground(.hidden)
                                            .background(Color.clear)
                                    } else {
                                        TextEditor(text: $customFeedback)
                                            .font(.system(size: 15))
                                            .foregroundColor(Color("dark"))
                                            .background(Color.clear)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .onAppear {
                                    UITextView.appearance().backgroundColor = UIColor.clear
                                }
                            }
                            .frame(minHeight: 100, alignment: .topLeading)
                            .background(Color("shade1"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("shade3"), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                        
                        // Warning section with improved visual design
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color("ErrorRed"))
                                
                                Text("This action cannot be undone")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color("ErrorRed"))
                                
                                Spacer()
                            }
                            
                            Text("You won't be able to access your chats, messages, or account after removal.")
                                .font(.system(size: 14))
                                .foregroundColor(Color("shade6"))
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color("ErrorRed").opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("ErrorRed").opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        
                        // Remove Account Button with improved design
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeAccountTapped() button pressed")
                            handleRemoveAccount()
                        }) {
                            HStack(spacing: 12) {
                                if isRemoving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                    
                                    Text("Removing Account...")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Remove Account")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: isRemoving ? 
                                    [Color("ErrorRed").opacity(0.6), Color("ErrorRed").opacity(0.4)] :
                                    [Color("ErrorRed"), Color("ErrorRed").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color("ErrorRed").opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(isRemoving)
                        .scaleEffect(isRemoving ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isRemoving)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(Color("Background Color"))
        }
        .navigationTitle("Remove Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Confirm Account Removal", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeAccountAlert() cancel tapped")
                isRemoving = false
            }
            Button("Remove Account", role: .destructive) {
                AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeAccountAlert() remove confirmed")
                // Keep loading state active during the process
                updateStatusToServer()
            }
        } message: {
            Text("Are you sure you want to remove your account?\n\nThis action cannot be undone and you'll lose access to all your chats and messages.")
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") {
                isRemoving = false
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "onAppear() view appeared")
        }
    }
    
    // MARK: - Handle Remove Account (matching Android logic exactly)
    private func handleRemoveAccount() {
        // Check for test account (matching Android exactly)
        if SessionManager.shared.emailAddress == "testingaccount@gmail.com" {
            alertMessage = "You can not delete test account."
            showAlert = true
            return
        }
        
        // Check if at least one feedback is selected (matching Android validation exactly - excluding c_zero)
        if c_one || c_two || c_three || c_four || c_five || c_six || c_seven || c_eight || c_nine {
            saveFeedback()
            showRemoveConfirmation = true
            
            // Update button state (matching Android exactly)
            isRemoving = true
        } else {
            alertMessage = "Select atleast one feedback"
            showAlert = true
        }
    }
    
    // MARK: - Save Feedback (matching Android saveFeedback() exactly)
    private func saveFeedback() {
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "saveFeedback() saving feedback to Firebase")
        
        let feedbackData: [String: Any] = [
            "User_id": SessionManager.shared.userId ?? "",
            "User_gender": SessionManager.getKeyUserGender(),
            "user_country": "\(SessionManager.shared.userRetrievedCountry ?? "")_\(SessionManager.shared.userCountry ?? "")",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "alot_messages": c_zero,
            "alot_notifications": c_one,
            "inaprop_messages": c_two,
            "coins": c_three,
            "ads": c_four,
            "no_one_replies": c_five,
            "cant_find_decent_people": c_six,
            "everything_good": c_seven,
            "limits": c_eight,
            "subscription_price_too_high": c_nine,
            "custom": customFeedback,
            "time_stamp": FieldValue.serverTimestamp()
        ]
        
        // Save to Firebase (matching Android collection structure exactly)
        database.collection("Feedback")
            .document(Bundle.main.bundleIdentifier ?? "com.peppty.ChatApp")
            .collection("Exit_Feedback")
            .document(String(Int(Date().timeIntervalSince1970)))
            .setData(feedbackData) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "saveFeedback() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "saveFeedback() feedback saved successfully")
                }
            }
    }
    
    // MARK: - Update Status to Server (matching Android updateStatusToServer() exactly)
    private func updateStatusToServer() {
        // CRITICAL: Start Firebase operation coordination
        guard FirebaseOperationCoordinator.shared.startAccountRemoval() else {
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() account removal already in progress")
            return
        }
        
        guard let userId = SessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() no user ID")
            // Continue with account removal even without user ID
            removeFirebaseAccount()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() updating user status to server")
        
        // OPTIMIZATION: Move Firebase operations to background thread to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            let statusUpdate: [String: Any] = [
                "is_user_online": false,
                "last_time_seen": FieldValue.serverTimestamp(),
                "removed_account": true
            ]
            
            // OPTIMIZATION: Reduced timeout from 10 to 3 seconds for faster navigation
            let timeoutWorkItem = DispatchWorkItem {
                AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() timeout reached, continuing with removal")
                self.removeFirebaseAccount()
            }
            
            // Set 3 second timeout for faster user experience
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3, execute: timeoutWorkItem)
            
            let database = Firestore.firestore()
            database.collection("Users")
                .document(userId)
                .setData(statusUpdate, merge: true) { error in
                    // Cancel timeout since operation completed
                    timeoutWorkItem.cancel()
                    
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() error: \(error.localizedDescription)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "updateStatusToServer() status updated successfully")
                    }
                    
                    // ANDROID PARITY: After successful status update, call removeAccount() (not removeFirebaseAccount())
                    self.removeFirebaseAccount()
                }
        }
    }
    
    // MARK: - Remove Firebase Account (matching Android removeAccount() exactly)
    private func removeFirebaseAccount() {
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() deleting Firebase Auth user")
        
        // CRITICAL: Capture current user reference before any potential changes
        let currentUser = Auth.auth().currentUser
        let currentUserId = currentUser?.uid
        
        guard let user = currentUser else {
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() no current user")
            // ANDROID PARITY: Continue with cleanup even if no user
            performCompleteAccountCleanup()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() attempting to delete user: \(currentUserId ?? "unknown")")
        
        // OPTIMIZATION: Move Firebase Auth deletion to background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // OPTIMIZATION: Reduced timeout from 10 to 3 seconds for faster navigation
            let timeoutWorkItem = DispatchWorkItem {
                AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() timeout reached, continuing with cleanup")
                self.performCompleteAccountCleanup()
            }
            
            // Set 3 second timeout for faster user experience
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3, execute: timeoutWorkItem)
            
            // CRITICAL: Use captured user reference to prevent race conditions
            user.delete { error in
                // Cancel timeout since operation completed
                timeoutWorkItem.cancel()
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() error: \(error.localizedDescription)")
                    
                    // CRITICAL: Force sign out if delete fails to prevent stale auth state
                    do {
                        try Auth.auth().signOut()
                        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() forced sign out after delete failure")
                    } catch {
                        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() sign out also failed: \(error.localizedDescription)")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "removeFirebaseAccount() Firebase user deleted successfully: \(currentUserId ?? "unknown")")
                }
                
                // ANDROID PARITY: After user deletion (successful or failed), perform all cleanup
                self.performCompleteAccountCleanup()
            }
        }
    }
    
    // MARK: - Complete Account Cleanup (matching Android cleanup exactly)
    private func performCompleteAccountCleanup() {
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() starting comprehensive cleanup")
        
        // ANDROID PARITY: Step 1 - Clear local database (matches AsyncClass.deleteDatabase())
        DatabaseCleanupService.shared.deleteDatabase()
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() database clearing initiated")
        
        // ANDROID PARITY: Step 2 - Clear all session data (matches SessionManager.EraseAllData())
        SessionManager.shared.clearUserSession()
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() session data cleared")
        
        // ANDROID PARITY: Step 3 - Session clearing (advertising functionality removed)
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() Session data cleared")
        
        // ANDROID PARITY: Step 4 - Clear subscription session data (matches SubscriptionSessionManager clearing in Android)
        SubscriptionSessionManager.shared.clearAllSubscriptionData()
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() Subscription session cleared")
        
        // ANDROID PARITY: Step 5 - Force garbage collection (matches System.gc())
        autoreleasepool {
            // This helps with memory cleanup similar to Android's System.gc()
        }
        
        // ANDROID PARITY: Step 6 - Clear app cache (matches deleteCache())
        clearCache()
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() cache cleared")
        
        // ANDROID PARITY: Step 7 - Navigate to login (matches LaunchActivityClass.LaunchLoginActivity())
        DispatchQueue.main.async {
            NavigationManager.shared.navigateToLogin()
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() navigated to login")
            
            // CRITICAL: Finish Firebase operation coordination after all operations complete
            FirebaseOperationCoordinator.shared.finishAccountRemoval()
        }
        
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "performCompleteAccountCleanup() comprehensive cleanup completed")
    }
    
    // MARK: - Clear Cache (matching Android deleteCache() exactly)
    private func clearCache() {
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "clearCache() clearing app cache using centralized CacheManager")
        
        // ANDROID PARITY: Use centralized CacheManager for comprehensive cache clearing
        CacheManager.shared.clearCachesForAccountRemoval()
        
        AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "clearCache() comprehensive cache clearing completed")
    }
}

// MARK: - Checkbox Row Component (improved UI design)
struct CheckboxRow: View {
    @Binding var isChecked: Bool
    let text: String
    
    var body: some View {
        Button(action: {
            isChecked.toggle()
            AppLogger.log(tag: "LOG-APP: RemoveAccountView", message: "CheckboxRow() toggled: \(text) = \(isChecked)")
        }) {
            HStack(spacing: 16) {
                // Custom checkbox with better visual design
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isChecked ? Color("ColorAccent") : Color("Background Color"))
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isChecked ? Color("ColorAccent") : Color("shade4"), lineWidth: 2)
                        )
                    
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isChecked)
                
                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isChecked ? Color("ColorAccent").opacity(0.05) : Color("shade1").opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isChecked ? Color("ColorAccent").opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isChecked ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isChecked)
    }
}

#Preview {
    NavigationView {
        RemoveAccountView()
    }
} 
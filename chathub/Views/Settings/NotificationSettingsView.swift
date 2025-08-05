import SwiftUI
import UserNotifications
import FirebaseFirestore

// MARK: - NotificationSettings ViewModel
class NotificationSettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = true
    @Published var isLoading: Bool = false
    
    private var sessionManager = SessionManager.shared
    private var mDatabase = Firestore.firestore()
    
    init() {
        checkNotificationStatus()
    }
    
    private func checkNotificationStatus() {
        AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "checkNotificationStatus() Loading notification status from session")
        
        // Get status from SessionManager (Android parity)
        notificationsEnabled = sessionManager.getNotificationsEnabled()
        
        AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "checkNotificationStatus() Notifications enabled: \(notificationsEnabled)")
    }
    
    func toggleNotifications(_ enabled: Bool) {
        AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "toggleNotifications() Setting notifications to: \(enabled)")
        
        isLoading = true
        notificationsEnabled = enabled
        
        setNotifications(enabled)
    }
    
    private func setNotifications(_ notification: Bool) {
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Error: No user ID found")
            isLoading = false
            return
        }
        
        if notification {
            // Deleting user ID so they get notifications (Android parity)
            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Enabling notifications - removing from blocked list")
            
            mDatabase.collection("Users")
                .document(userId)
                .collection("BlockedNotificationList")
                .document(userId)
                .delete { [weak self] error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Error deleting from blocked list: \(error.localizedDescription)")
                        } else {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Successfully enabled notifications")
                            self?.sessionManager.setNotificationsEnabled(true)
                        }
                    }
                }
        } else {
            // Adding user ID so they won't get notifications (Android parity)
            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Disabling notifications - adding to blocked list")
            
            let blockData: [String: Any] = [
                "blocked_notification_id": userId
            ]
            
            mDatabase.collection("Users")
                .document(userId)
                .collection("BlockedNotificationList")
                .document(userId)
                .setData(blockData, merge: true) { [weak self] error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Error adding to blocked list: \(error.localizedDescription)")
                        } else {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsViewModel", message: "setNotifications() Successfully disabled notifications")
                            self?.sessionManager.setNotificationsEnabled(false)
                        }
                    }
                }
        }
    }
}

// MARK: - NotificationSettings View
struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @Environment(\.presentationMode) var presentationMode
    

    
    // Session management
    private var sessionManager = SessionManager.shared
    private var isSubscribed: Bool {
        SubscriptionSessionManager.shared.isUserSubscribedToLite() ||
        SubscriptionSessionManager.shared.isUserSubscribedToPlus() ||
        SubscriptionSessionManager.shared.isUserSubscribedToPro()
    }
    
    // iOS Permission Status (New)
    @State private var iOSPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var iOSPermissionStatusText: String = "Checking..."
    @State private var showPermissionAlert: Bool = false
    @State private var showNotificationPermissionPopup: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                // Notification Toggle Section
                HStack {
                    Text("Notifications")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("dark"))
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Toggle("", isOn: $viewModel.notificationsEnabled)
                            .onChange(of: viewModel.notificationsEnabled) { newValue in
                                viewModel.toggleNotifications(newValue)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                
                // iOS Permission Status Section (New)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("iOS Notification Permission")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("dark"))
                        
                        Spacer()
                        
                        Button(action: {
                            checkAndRequestiOSPermission()
                        }) {
                            Text("Check Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("ColorAccent"))
                        }
                    }
                    
                    Text(iOSPermissionStatusText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("shade1").opacity(0.3))
                )
                .padding(.horizontal, 20)
                
                // Description Text (Android parity - exact text match)
                Text("If you turn off notification you wont receive any notifications from ChatHub.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Notification settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .onAppear {
            setupView()
        }
        // MARK: - Notification Permission Popup Overlay
        .overlay(
            Group {
                if showNotificationPermissionPopup {
                    AppNotificationPermissionPopupView(
                        isPresented: $showNotificationPermissionPopup,
                        onAllow: {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "notificationPermissionPopup onAllow() User agreed from settings")
                            
                            // Request permission from settings context
                            AppNotificationPermissionService.shared.requestNotificationPermissionWithContext(
                                context: "from_settings_manual"
                            ) { granted in
                                AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "notificationPermissionPopup iOS permission result: \(granted)")
                                showNotificationPermissionPopup = false
                                
                                // Refresh permission status
                                checkiOSPermissionStatus()
                                
                                if granted {
                                    // Reset retry mechanism on success
                                    AppNotificationPermissionService.shared.resetRetryMechanism()
                                }
                            }
                        },
                        onMaybeLater: {
                            AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "notificationPermissionPopup onMaybeLater() User chose maybe later from settings")
                            showNotificationPermissionPopup = false
                        }
                    )
                    .zIndex(1000)
                }
            }
        )
        .alert("Open Settings", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Notifications are disabled in iOS Settings. Please enable them in Settings > Notifications > ChatHub to receive notifications.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "setupView() Setting up notification settings view")
        
        checkiOSPermissionStatus()
    }
    

    
    // MARK: - iOS Permission Management
    
    private func checkiOSPermissionStatus() {
        AppNotificationPermissionService.shared.checkPermissionStatus { status in
            iOSPermissionStatus = status
            updatePermissionStatusText(status)
        }
    }
    
    private func updatePermissionStatusText(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            iOSPermissionStatusText = "Not requested yet. Tap 'Check Status' to enable notifications."
        case .denied:
            iOSPermissionStatusText = "Denied. Tap 'Check Status' to open iOS Settings and enable notifications."
        case .authorized, .provisional:
            iOSPermissionStatusText = "✅ Enabled. You'll receive notifications when app notifications are turned on above."
        case .ephemeral:
            iOSPermissionStatusText = "Temporary access. Tap 'Check Status' for full access."
        @unknown default:
            iOSPermissionStatusText = "Unknown status. Tap 'Check Status' to refresh."
        }
    }
    
    private func checkAndRequestiOSPermission() {
        AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "checkAndRequestiOSPermission() Checking iOS permission status")
        
        AppNotificationPermissionService.shared.checkPermissionStatus { status in
            switch status {
            case .notDetermined:
                // Show custom popup for permission request
                AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "checkAndRequestiOSPermission() Permission not determined, showing popup")
                showNotificationPermissionPopup = true
                
            case .denied:
                // Show alert to open settings
                AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "checkAndRequestiOSPermission() Permission denied, showing settings alert")
                showPermissionAlert = true
                
            case .authorized, .provisional:
                // Already granted, just refresh status
                AppLogger.log(tag: "LOG-APP: NotificationSettingsView", message: "checkAndRequestiOSPermission() Permission already granted")
                checkiOSPermissionStatus()
                
                // Reset retry mechanism if permission is granted
                AppNotificationPermissionService.shared.resetRetryMechanism()
                
            case .ephemeral:
                // Show alert to get full permission
                showPermissionAlert = true
                
            @unknown default:
                // Unknown status, refresh
                checkiOSPermissionStatus()
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingsView()
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            NotificationSettingsView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif 

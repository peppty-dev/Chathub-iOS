import Foundation
import FirebaseFirestore

/// AppUpdateService - iOS equivalent of Android AppUpdateWorker
/// Handles app update availability checking with 100% Android parity
class AppUpdateService {
    
    // MARK: - Singleton
    static let shared = AppUpdateService()
    private init() {}
    
    // MARK: - Properties (Android Parity)
    private let sessionManager = SessionManager.shared
    private let database = Firestore.firestore()
    private var appUpdateListener: ListenerRegistration?
    private var isListenerActive = false
    
    // MARK: - Public Methods (Android Parity)
    
    /// Starts the app update listener - equivalent to FirebaseServices.checkAppUpdateAvailability()
    /// This is the main method that should be called to start listening for app update availability
    func startAppUpdateListener() {
        AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "startAppUpdateListener() starting Firebase app update listener")
        
        // Remove existing listener if active
        if isListenerActive {
            stopAppUpdateListener()
        }
        
        // Set up Firebase listener (matching FirebaseServices.checkAppUpdateAvailability exactly)
        appUpdateListener = database.collection("VersionControle")
            .document("LiveAppVersion")
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let self = self else { return }
                guard let document = snapshot else { return }
                guard let data = document.data() else { return }
                
                let ios_app_version = data["iOS_build"] as? Int ?? 0
                let ios_maintanance = data["ios_maintanance"] as? Bool ?? false
                
                guard let info = Bundle.main.infoDictionary else { return }
                let currentVersion = info["CFBundleVersion"] as? String ?? "0"
                
                AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "startAppUpdateListener() Update check - current: \(currentVersion), available: \(ios_app_version)")
                
                if ios_maintanance {
                    AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "startAppUpdateListener() App is in maintenance mode")
                    self.showMaintenanceScreen()
                }
                
                if Int(currentVersion)! < ios_app_version {
                    AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "startAppUpdateListener() App update available")
                    DispatchQueue.global().async {
                        DispatchQueue.main.async {
                            self.showUpdateScreen()
                        }
                    }
                }
            }
        
        isListenerActive = true
        AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "startAppUpdateListener() app update listener started successfully")
    }
    
    /// Stops the app update listener
    func stopAppUpdateListener() {
        AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "stopAppUpdateListener() stopping Firebase app update listener")
        
        appUpdateListener?.remove()
        appUpdateListener = nil
        isListenerActive = false
        
        AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "stopAppUpdateListener() app update listener stopped")
    }
    
    /// Gets listener status
    func isAppUpdateListenerActive() -> Bool {
        return isListenerActive
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Shows maintenance screen
    private func showMaintenanceScreen() {
        DispatchQueue.main.async {
            // Navigate to maintenance screen - will be implemented when UI is ready
            AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "showMaintenanceScreen() App is in maintenance mode - should show maintenance screen")
        }
    }
    
    /// Shows update screen
    private func showUpdateScreen() {
        DispatchQueue.main.async {
            // Navigate to update screen - will be implemented when UI is ready
            AppLogger.log(tag: "LOG-APP: AppUpdateService", message: "showUpdateScreen() App update available - should show update screen")
        }
    }
} 
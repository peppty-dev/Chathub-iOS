import Foundation
import FirebaseFirestore

/// OnlineStatusService - iOS equivalent of Android SetOnlineWorker
/// Handles user online status management with 100% Android parity
class OnlineStatusService {
    
    // MARK: - Singleton
    static let shared = OnlineStatusService()
    private init() {}
    
    // MARK: - Properties
    private let sessionManager = SessionManager.shared
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Constants
    private let updateTimeoutSeconds = 10.0
    
    // MARK: - Public Methods
    
    /// Set user online status - Android parity (SetOnlineWorker.doWork())
    func setUserOnline() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "setUserOnline() setting user online")
        updateUserOnlineStatus(isOnline: true)
    }
    
    /// Set user offline status - Android parity
    func setUserOffline() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "setUserOffline() setting user offline")
        updateUserOnlineStatus(isOnline: false)
    }
    
    /// Update user's online status in Firebase - Android parity
    /// - Parameter isOnline: true when user is online/active, false when offline/background
    func updateUserOnlineStatus(isOnline: Bool) {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() isOnline=\(isOnline)")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() User ID is null or empty")
            return
        }
        
        // Update local session state
        sessionManager.userOnline = isOnline
        
        // Prepare Firebase update data
        var updateData: [String: Any] = [
            "is_user_online": isOnline
        ]
        
        // Add timestamp based on status
        if isOnline {
            updateData["last_time_seen"] = FieldValue.serverTimestamp()
        } else {
            updateData["last_time_seen"] = FieldValue.serverTimestamp()
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() Updating Firebase for user: \(userId)")
        
        // Start background task to ensure completion
        startBackgroundTask()
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        // Set timeout for the operation
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: updateTimeoutSeconds, repeats: false) { [weak self] _ in
            AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() Timeout reached for user: \(userId)")
            self?.endBackgroundTask()
        }
        
        userRef.setData(updateData, merge: true) { [weak self] error in
            timeoutTimer.invalidate()
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() Error updating online status: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateUserOnlineStatus() Online status updated successfully: \(isOnline)")
            }
            
            self?.endBackgroundTask()
        }
    }
    
    /// Get current user online status - Android parity
    func isUserOnline() -> Bool {
        return sessionManager.userOnline
    }
    
    /// Start automatic online status monitoring - Android parity
    func startOnlineStatusMonitoring() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "startOnlineStatusMonitoring() starting monitoring")
        
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUserOnline()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUserOffline()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUserOnline()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUserOffline()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUserOffline()
        }
        
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "startOnlineStatusMonitoring() monitoring started successfully")
    }
    
    /// Stop online status monitoring - Android parity
    func stopOnlineStatusMonitoring() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "stopOnlineStatusMonitoring() stopping monitoring")
        
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "stopOnlineStatusMonitoring() monitoring stopped successfully")
    }
    
    /// Update user's last seen time - Android parity
    func updateLastSeenTime() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateLastSeenTime() updating last seen timestamp")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateLastSeenTime() User ID is null or empty")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.setData([
            "last_time_seen": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateLastSeenTime() Error updating last seen time: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "updateLastSeenTime() Last seen time updated successfully")
            }
        }
    }
    
    /// Force update online status for reconnection scenarios - Android parity
    func forceUpdateOnlineStatus() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "forceUpdateOnlineStatus() forcing online status update")
        
        // Always set to online when forcing update (user is actively using the app)
        updateUserOnlineStatus(isOnline: true)
    }
    
    /// Clean up user's online status on logout - Android parity
    func cleanupOnlineStatusOnLogout() {
        AppLogger.log(tag: "LOG-APP: OnlineStatusService", message: "cleanupOnlineStatusOnLogout() cleaning up on logout")
        
        // Set user offline before clearing session
        setUserOffline()
        
        // Clear local session state
        sessionManager.userOnline = false
        
        // Stop monitoring
        stopOnlineStatusMonitoring()
    }
    
    // MARK: - Private Methods
    
    /// Start background task to ensure Firebase update completes
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    /// End background task
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    deinit {
        stopOnlineStatusMonitoring()
        endBackgroundTask()
    }
} 
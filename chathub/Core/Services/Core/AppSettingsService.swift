import Foundation
import FirebaseFirestore
import FirebaseAuth

/// iOS equivalent of Android AppSettingsWorker
/// Provides background Firebase listener for app settings with 100% Android parity
class AppSettingsWorker {
    static let shared = AppSettingsWorker()
    
    private let db = Firestore.firestore()
    private var appSettingsListener: ListenerRegistration?
    
    // ANDROID PARITY: Background queue equivalent to Executors.newSingleThreadExecutor()
    private let backgroundQueue = DispatchQueue(label: "com.peppty.ChatApp.AppSettingsWorker", qos: .utility)
    
    private init() {}
    
    /// Main work function - equivalent to Android's doWork()
    /// Sets up Firebase listener for app settings with authentication guard
    func doWork() {
        AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() starting AppSettings worker")
        
        // ANDROID PARITY: Execute on background thread like Executors.newSingleThreadExecutor()
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Guard: Check if user is authenticated before attaching listener (Android parity)
            guard Auth.auth().currentUser != nil else {
                AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() User not authenticated, skipping AppSettings listener attachment.")
                return
            }
            
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() Could not find bundle identifier")
                return
            }
            
            // Remove existing listener if any
            if let existingListener = self.appSettingsListener {
                existingListener.remove()
                self.appSettingsListener = nil
                AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() Removed existing AppSettings listener")
            }
            
            // ANDROID PARITY: Set up Firebase listener with background execution (matching Android exactly)
            self.appSettingsListener = self.db.collection("AppSettings")
                .document(bundleIdentifier)
                .addSnapshotListener(includeMetadataChanges: false) { [weak self] documentSnapshot, error in
                    guard let self = self else { return }
                    
                    // ANDROID PARITY: Process data on background thread like Android's Executors.newSingleThreadExecutor()
                    self.backgroundQueue.async {
                        if let error = error {
                            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() Firebase error: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documentSnapshot = documentSnapshot else {
                            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() No document snapshot received")
                            return
                        }
                        
                        guard documentSnapshot.exists else {
                            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() AppSettings document does not exist")
                            return
                        }
                        
                        guard let data = documentSnapshot.data() else {
                            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() AppSettings document data was empty")
                            return
                        }
                        
                        AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() addSnapshotListener() - processing app settings")
                        self.updateSessionManager(with: data)
                    }
                }
            
            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "doWork() AppSettings listener attached successfully")
        }
    }
    
    /// Updates SessionManager with Firebase data - matches Android implementation exactly
    /// ANDROID PARITY: Runs on background thread like Android's SessionManager operations
    private func updateSessionManager(with data: [String: Any]) {
        let sessionManager = SessionManager.shared
        
        // ==========================================
        // App Version and Update Settings
        // ==========================================
        if let version = data["version"] as? Int64 {
            sessionManager.liveAppVersion = version
        }
        
        if let updateMandatory = data["updateMandatory"] as? Bool {
            sessionManager.updateMandatory = updateMandatory
        }
        
        if let maintenance = data["maintenance"] as? Bool {
            sessionManager.maintenance = maintenance
        }
        
        if let updateDetails = data["updateDetails"] as? String {
            sessionManager.updateDetails = updateDetails
        }
        
        // ==========================================
        // Feature Toggle Settings
        // ==========================================
        if let extraFeaturesEnabled = data["extraFeaturesEnabled"] as? Bool {
            sessionManager.extraFeaturesEnabled = extraFeaturesEnabled
        }
        
        // ==========================================
        // Direct Communication Settings
        // ==========================================
        if let liveEnabled = data["liveEnabled"] as? Bool {
            sessionManager.liveEnabled = liveEnabled
        }
        
        // ==========================================
        // Advertisement Settings (Gender-specific)
        // ==========================================
        if sessionManager.keyUserGender?.lowercased() == "male" {
            if let adIntervalSeconds = data["adIntervalSeconds"] as? Int64 {
                sessionManager.adIntervalSeconds = adIntervalSeconds
            }
        } else {
            if let adIntervalSecondsWoman = data["adIntervalSecondsWoman"] as? Int64 {
                sessionManager.adIntervalSeconds = adIntervalSecondsWoman
            }
        }
        
        if let enableInFeedAds = data["enableInFeedAds"] as? Bool {
            sessionManager.enableInFeedAds = enableInFeedAds
        }
        
        if sessionManager.keyUserGender?.lowercased() == "male" {
            if let inFeedAdsCount = data["inFeedAdsCount"] as? Int64 {
                sessionManager.inFeedAdsCount = inFeedAdsCount
            }
        } else {
            if let inFeedAdsCountWoman = data["inFeedAdsCountWoman"] as? Int64 {
                sessionManager.inFeedAdsCount = inFeedAdsCountWoman
            }
        }
        
        // ==========================================
        // App Analytics and Rating Settings
        // ==========================================
        if let appActivityCount = data["appActivityCount"] as? Int64 {
            sessionManager.appActivityCount = appActivityCount
        }
        
        if let maxChatsForRateUsRequest = data["maxChatsForRateUsRequest"] as? Int64 {
            sessionManager.maxChatsForRateUsRequest = maxChatsForRateUsRequest
        }
        
        if let maxRateUsRequests = data["maxRateUsRequests"] as? Int64 {
            sessionManager.maxRateUsRequests = maxRateUsRequests
        }
        
        // ==========================================
        // AI Chat Configuration Settings (Gender-specific)
        // ==========================================
        if sessionManager.keyUserGender?.lowercased() == "male" {
            if let aiChatEnabled = data["aiChatEnabled"] as? Bool {
                sessionManager.aiChatEnabled = aiChatEnabled
            }
        } else {
            if let aiChatEnabledWoman = data["aiChatEnabledWoman"] as? Bool {
                sessionManager.aiChatEnabled = aiChatEnabledWoman
            }
        }
        
        if let maxIdleSecondsForAiChatEnabling = data["maxIdleSecondsForAiChatEnabling"] as? Int64 {
            sessionManager.maxIdleSecondsForAiChatEnabling = maxIdleSecondsForAiChatEnabling
        }
        
        if let minOfflineSecondsForAiChatEnabling = data["minOfflineSecondsForAiChatEnabling"] as? Int64 {
            sessionManager.minOfflineSecondsForAiChatEnabling = minOfflineSecondsForAiChatEnabling
        }
        
        if let aiChatBotURL = data["aiChatBotURL"] as? String {
            sessionManager.aiChatBotURL = aiChatBotURL
        }
        
        // ==========================================
        // Monetization and Limits Settings
        // ==========================================
        if let newUserFreePeriodSeconds = data["newUserFreePeriodSeconds"] as? Int64 {
            sessionManager.newUserFreePeriodSeconds = newUserFreePeriodSeconds
        }
        
        if let featureMonetizationPopUpCoolDownSeconds = data["featureMonetizationPopUpCoolDownSeconds"] as? Int64 {
            sessionManager.featureMonetizationPopUpCoolDownSeconds = featureMonetizationPopUpCoolDownSeconds
        }
        
        // ==========================================
        // Free User Message Limit Settings
        // ==========================================
        if let freeMessagesLimit = data["freeMessagesLimit"] as? Int64 {
            sessionManager.freeMessagesLimit = Int(freeMessagesLimit)
        }
        
        if let freeMessagesCooldownSeconds = data["freeMessagesCooldownSeconds"] as? Int64 {
            sessionManager.freeMessagesCooldownSeconds = Int(freeMessagesCooldownSeconds)
        }
        
        // ==========================================
        // Free User Conversation Limit Settings
        // ==========================================
        if let freeConversationsLimit = data["freeConversationsLimit"] as? Int64 {
            sessionManager.freeConversationsLimit = Int(freeConversationsLimit)
        }
        
        if let freeConversationsCooldownSeconds = data["freeConversationsCooldownSeconds"] as? Int64 {
            sessionManager.freeConversationsCooldownSeconds = Int(freeConversationsCooldownSeconds)
        }
        
        // ==========================================
        // Free User Refresh Limit Settings
        // ==========================================
        if let freeRefreshLimit = data["freeRefreshLimit"] as? Int64 {
            sessionManager.freeRefreshLimit = Int(freeRefreshLimit)
        }
        
        if let freeRefreshCooldownSeconds = data["freeRefreshCooldownSeconds"] as? Int64 {
            sessionManager.freeRefreshCooldownSeconds = TimeInterval(freeRefreshCooldownSeconds)
        }
        
        // ==========================================
        // Free User Filter Limit Settings
        // ==========================================
        if let freeFilterLimit = data["freeFilterLimit"] as? Int64 {
            sessionManager.freeFilterLimit = Int(freeFilterLimit)
        }
        
        if let freeFilterCooldownSeconds = data["freeFilterCooldownSeconds"] as? Int64 {
            sessionManager.freeFilterCooldownSeconds = Int(freeFilterCooldownSeconds)
        }
        
        // ==========================================
        // Free User Search Limit Settings
        // ==========================================
        if let freeSearchLimit = data["freeSearchLimit"] as? Int64 {
            sessionManager.freeSearchLimit = Int(freeSearchLimit)
        }
        
        if let freeSearchCooldownSeconds = data["freeSearchCooldownSeconds"] as? Int64 {
            sessionManager.freeSearchCooldownSeconds = Int(freeSearchCooldownSeconds)
        }
        
        // Ensure changes are saved immediately (Android parity)
        sessionManager.synchronize()
        AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "updateSessionManager() Successfully updated UserDefaults with AppSettings")
    }
    
    /// Removes the Firebase listener
    func removeListener() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            if let listener = self.appSettingsListener {
                listener.remove()
                self.appSettingsListener = nil
                AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "removeListener() AppSettings listener removed")
            }
        }
    }
    
    /// Restarts the AppSettings worker - useful after login/logout
    func restart() {
        AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "restart() Restarting AppSettings worker")
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            // Remove listener first
            if let listener = self.appSettingsListener {
                listener.remove()
                self.appSettingsListener = nil
            }
            // Then restart
            self.doWork()
        }
    }
}

// MARK: - Legacy AppSettingsService for backward compatibility
/// Maintains backward compatibility while delegating to AppSettingsWorker
class AppSettingsService {
    static let shared = AppSettingsService()
    
    private init() {}
    
    /// Fetches app settings - delegates to AppSettingsWorker
    func fetchAppSettings() {
        AppLogger.log(tag: "LOG-APP: AppSettingsService", message: "fetchAppSettings() Delegating to AppSettingsWorker")
        AppSettingsWorker.shared.doWork()
    }
} 
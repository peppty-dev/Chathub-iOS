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
        if let version = data["liveAppVersionCode"] as? Int64 {
            sessionManager.liveAppVersion = version
        }
        
        if let updateMandatory = data["isUpdateMandatory"] as? Bool {
            sessionManager.updateMandatory = updateMandatory
        }
        
        if let maintenance = data["isMaintenanceMode"] as? Bool {
            sessionManager.maintenance = maintenance
        }
        
        if let updateMessage = data["updateMessage"] as? String {
            sessionManager.updateDetails = updateMessage
        }
        
        // ==========================================
        // Direct Communication Settings
        // ==========================================
        if let liveEnabled = data["isLiveEnabled"] as? Bool {
            sessionManager.liveEnabled = liveEnabled
        }
        
        // ==========================================
        // App Analytics and Rating Settings
        // ==========================================
        if let minChatsBeforeRatePrompt = data["minChatsBeforeRatePrompt"] as? Int64 {
            sessionManager.maxChatsForRateUsRequest = minChatsBeforeRatePrompt
        }
        
        if let maxRatePrompts = data["maxRatePrompts"] as? Int64 {
            sessionManager.maxRateUsRequests = maxRatePrompts
        }
        
        // ==========================================
        // AI Chat Configuration Settings (Gender-specific)
        // ==========================================
        if let aiChatEnabledMale = data["isAiChatEnabled"] as? Bool {
            sessionManager.aiChatEnabled = aiChatEnabledMale
            AppLogger.log(tag: "LOG-APP: AppSettingsService", message: "parseAppSettingsData() aiChatEnabled (male) set to: \(aiChatEnabledMale)")
        }
        
        if let aiChatEnabledFemale = data["isAiChatEnabledFemale"] as? Bool {
            sessionManager.aiChatEnabledWoman = aiChatEnabledFemale
            AppLogger.log(tag: "LOG-APP: AppSettingsService", message: "parseAppSettingsData() aiChatEnabledWoman (female) set to: \(aiChatEnabledFemale)")
        }
        
        if let maxIdleSecondsForAiChatEnabling = data["aiChatEnableMaxIdleSeconds"] as? Int64 {
            sessionManager.maxIdleSecondsForAiChatEnabling = maxIdleSecondsForAiChatEnabling
        }
        
        if let minOfflineSecondsForAiChatEnabling = data["aiChatEnableMinOfflineSeconds"] as? Int64 {
            sessionManager.minOfflineSecondsForAiChatEnabling = minOfflineSecondsForAiChatEnabling
        }
        
        if let aiChatBotURL = data["aiChatbotUrl"] as? String {
            sessionManager.aiChatBotURL = aiChatBotURL
        }
        // Optionally store AI API key if provided via settings (reuses existing storage)
        // Prefer the new standard key name: aiChatbotKey
        let appSettingsApiKey =
            (data["aiChatbotKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (data["aiChatbotApiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (data["ai_chatbot_api_key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (data["hugging_face_api_key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let apiKey = appSettingsApiKey, !apiKey.isEmpty {
            sessionManager.aiApiKey = apiKey
            AppLogger.log(tag: "LOG-APP: AppSettingsWorker", message: "updateSessionManager() Stored AI API key from AppSettings")
        }
        
        // ==========================================
        // Monetization and Limits Settings
        // ==========================================
        if let freeTrialEndsAtSeconds = data["freeTrialEndsAtSeconds"] as? Int64 {
            sessionManager.newUserFreePeriodSeconds = freeTrialEndsAtSeconds
        }
        
        if let featureMonetizationPopupCooldownSeconds = data["featureMonetizationPopupCooldownSeconds"] as? Int64 {
            sessionManager.featureMonetizationPopUpCoolDownSeconds = featureMonetizationPopupCooldownSeconds
        }
        
        // ==========================================
        // Free User Message Limit Settings
        // ==========================================
        if let freeMessagesLimit = data["freeMessagesLimit"] as? Int64 {
            // Store message limit configs in SessionManager for consistency with other limit features
            sessionManager.freeMessagesLimit = Int(freeMessagesLimit)
        }
        
        if let freeMessagesCooldownSeconds = data["freeMessagesCooldownSeconds"] as? Int64 {
            // Store message limit configs in SessionManager for consistency with other limit features
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
        // Shadow Ban (Text Moderation) Settings
        // ==========================================
        if let sbDuration = data["textModerationShadowBanLockDurationSeconds"] as? Int64 {
            // Store in UserDefaults with a well-known key so ModerationManagerService can read it
            sessionManager.defaults.set(Int(sbDuration), forKey: "TEXT_MODERATION_SB_LOCK_DURATION_SECONDS")
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
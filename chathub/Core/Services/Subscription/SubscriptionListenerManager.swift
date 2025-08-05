import Foundation

/// iOS equivalent of Android SubscriptionListenerManager
/// Manages the lifecycle of subscription listeners with continuous retry until user authentication
class SubscriptionListenerManager {
    
    // MARK: - Singleton
    static let shared = SubscriptionListenerManager()
    private init() {}
    
    // MARK: - Properties (Android Parity) - Use specialized managers
    private static let TAG = "SubscriptionListenerManager"
    private static let RETRY_DELAY_MS: TimeInterval = 15.0 // 15 seconds like Android
    
    private let userSessionManager = UserSessionManager.shared
    private var isListenerActive = false
    private var retryCount = 0
    private var currentAttemptingUserId: String? = nil
    private var retryTimer: Timer?
    
    // MARK: - Public Methods (Android Parity)
    
    /// Attempts to start the subscription listener with unlimited retries
    /// iOS equivalent of Android startListener()
    func startListener() {
        let userId = userSessionManager.userId
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startListener() attempting to start listener. Current UserID: \(userId?.isEmpty == false ? "PRESENT" : "NULL_OR_EMPTY")")
        
        if let userId = userId, !userId.isEmpty {
            // User ID is available, initialize the repository
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startListener() UserID found. Initializing repository for user: \(userId)")
            
            // Initialize SubscriptionRepository with Firebase listener (Android parity)
            SubscriptionRepository.shared.startListening()
            
            // Initialize subscription billing manager
            Task { @MainActor in
                SubscriptionBillingManager.shared.checkPremiumDetailsFromFirebase()
            }
            
            isListenerActive = true
            currentAttemptingUserId = userId
            retryCount = 0
            stopRetryTimer() // Remove any pending retries
            
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startListener() Subscription listener initialized successfully")
            
        } else if currentAttemptingUserId == nil {
            // User ID is not available, schedule UNLIMITED retries (Android parity)
            retryCount += 1
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startListener() UserID not found. Scheduling retry attempt \(retryCount) (unlimited) in \(Self.RETRY_DELAY_MS)s")
            
            currentAttemptingUserId = nil // Mark that we're attempting for null user
            scheduleRetry()
            
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startListener() Listener start skipped: Already attempting for user: \(currentAttemptingUserId ?? "null")")
        }
    }
    
    /// Explicitly stops the listener (e.g., on user logout)
    /// iOS equivalent of Android stopListener()
    func stopListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopListener() Explicitly stopping listener")
        
        stopRetryTimer() // Cancel any pending retries
        
        // Stop SubscriptionRepository listener (Android parity)
        SubscriptionRepository.shared.stopListening()
        
        isListenerActive = false
        retryCount = 0
        currentAttemptingUserId = nil
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopListener() Listener stopped successfully")
    }
    
    /// Check if listener is active
    func getListenerStatus() -> Bool {
        return isListenerActive
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Schedules a retry attempt - iOS equivalent of Android retryRunnable
    private func scheduleRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_MS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleRetry() Executing scheduled retry attempt")
            self.startListener() // CONTINUOUS RETRY - calls itself again
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Force restart listener (for external triggers)
    func restartListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "restartListener() Force restarting subscription listener")
        stopListener()
        startListener()
    }
} 
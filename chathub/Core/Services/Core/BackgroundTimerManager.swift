import UIKit
import Foundation

/// Manages background processing for feature limit cooldowns
/// Ensures timers continue running even when app is backgrounded or popups are dismissed
class BackgroundTimerManager {
    static let shared = BackgroundTimerManager()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    private var preciseExpirationTimers: [String: Timer] = [:] // Feature-specific precise timers
    private var isMonitoring = false
    
    // Notification names for cooldown events
    static let refreshCooldownExpiredNotification = Notification.Name("RefreshCooldownExpired")
    static let filterCooldownExpiredNotification = Notification.Name("FilterCooldownExpired")
    static let messageCooldownExpiredNotification = Notification.Name("MessageCooldownExpired")
    static let conversationCooldownExpiredNotification = Notification.Name("ConversationCooldownExpired")
    static let searchCooldownExpiredNotification = Notification.Name("SearchCooldownExpired")
    static let anyFeatureCooldownExpiredNotification = Notification.Name("AnyFeatureCooldownExpired")
    
    private init() {
        setupAppLifecycleObservers()
    }
    
    // MARK: - Public Interface
    
    /// Start monitoring all feature cooldowns in background
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Starting background cooldown monitoring")
        isMonitoring = true
        
        startBackgroundTask()
        startBackgroundTimer()
    }
    
    /// Stop background monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Stopping background cooldown monitoring")
        isMonitoring = false
        
        stopBackgroundTimer()
        endBackgroundTask()
    }
    
        /// Force check all cooldowns immediately
    func checkAllCooldowns() {
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkAllCooldowns() STARTING - Debug app launch cooldown detection")
        
        let cooldownSummary = getCooldownSummary()
        if !cooldownSummary.isEmpty {
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Checking all feature cooldowns - Active: \(cooldownSummary)")
        } else {
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "No active cooldowns detected")
        }

        // DEBUG: Check refresh state before and after
        let refreshManager = RefreshLimitManager.shared
        let beforeState = "inCooldown: \(refreshManager.isInCooldown()), remaining: \(refreshManager.getRemainingCooldown())s, usage: \(refreshManager.getCurrentUsageCount())"
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkAllCooldowns() BEFORE refresh check - \(beforeState)")
        
        checkRefreshCooldown()
        checkFilterCooldown()
        checkSearchCooldown()
        checkConversationCooldown()
        
        let afterState = "inCooldown: \(refreshManager.isInCooldown()), remaining: \(refreshManager.getRemainingCooldown())s, usage: \(refreshManager.getCurrentUsageCount())"
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkAllCooldowns() AFTER refresh check - \(afterState)")
    }
    
    /// Force check all cooldowns and return summary of what was reset
    func checkAllCooldownsWithReport() -> [String] {
        var resetFeatures: [String] = []
        
        // Check each feature and track what was reset
        let refreshWasInCooldown = RefreshLimitManager.shared.isInCooldown()
        let filterWasInCooldown = FilterLimitManager.shared.isInCooldown()
        let searchWasInCooldown = SearchLimitManager.shared.isInCooldown()
        let conversationWasInCooldown = ConversationLimitManagerNew.shared.isInCooldown()
        
        checkRefreshCooldown()
        checkFilterCooldown() 
        checkSearchCooldown()
        checkConversationCooldown()
        
        // Check if anything was reset
        if refreshWasInCooldown && !RefreshLimitManager.shared.isInCooldown() {
            resetFeatures.append("refresh")
        }
        if filterWasInCooldown && !FilterLimitManager.shared.isInCooldown() {
            resetFeatures.append("filter")
        }
        if searchWasInCooldown && !SearchLimitManager.shared.isInCooldown() {
            resetFeatures.append("search")
        }
        if conversationWasInCooldown && !ConversationLimitManagerNew.shared.isInCooldown() {
            resetFeatures.append("conversation")
        }
        
        if !resetFeatures.isEmpty {
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Background check reset cooldowns for: \(resetFeatures.joined(separator: ", "))")
        }
        
        return resetFeatures
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "App entered background - starting background task")
        startBackgroundTask()
        
        // Check cooldowns before backgrounding
        checkAllCooldowns()
    }
    
    @objc private func appWillEnterForeground() {
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "App entering foreground - checking expired cooldowns")
        
        // Enhanced debugging for app resume issue
        let filterManager = FilterLimitManager.shared
        let beforeReset = filterManager.isInCooldown() ? filterManager.getRemainingCooldown() : 0
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "DEBUGGING: Before checkAllCooldowns - Filter remaining: \(beforeReset)s, inCooldown: \(filterManager.isInCooldown())")
        
        // Check for expired cooldowns when returning to foreground
        checkAllCooldowns()
        
        let afterReset = filterManager.isInCooldown() ? filterManager.getRemainingCooldown() : 0
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "DEBUGGING: After checkAllCooldowns - Filter remaining: \(afterReset)s, inCooldown: \(filterManager.isInCooldown())")
        
        // Update precise timers for any active cooldowns
        setupPreciseExpirationTimers()
        
        // End background task as we're now in foreground
        endBackgroundTask()
    }
    
    @objc private func appWillTerminate() {
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "App terminating - cleaning up background tasks")
        stopMonitoring()
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        // End existing task first
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FeatureLimitCooldownMonitoring") { [weak self] in
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Background task time expired")
            self?.endBackgroundTask()
        }
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Started background task with ID: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Ending background task with ID: \(backgroundTaskID.rawValue)")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    // MARK: - Background Timer
    
    private func startBackgroundTimer() {
        stopBackgroundTimer()
        
        // Check cooldowns every 1 second for maximum responsiveness and precision
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAllCooldowns()
        }
        
        // Set up precise expiration timers for active cooldowns
        setupPreciseExpirationTimers()
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Started background timer with 1s interval + precise expiration timers")
    }
    
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        // Stop all precise expiration timers
        for (feature, timer) in preciseExpirationTimers {
            timer.invalidate()
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Stopped precise timer for \(feature)")
        }
        preciseExpirationTimers.removeAll()
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Stopped background timer and all precise timers")
    }
    
    // MARK: - Cooldown Checking
    
    private func checkRefreshCooldown() {
        let manager = RefreshLimitManager.shared
        
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkRefreshCooldown() Starting - Usage: \(manager.getCurrentUsageCount()), Limit: \(manager.getLimit())")
        
        // CRITICAL FIX: Check cooldown state more robustly to handle precision issues
        let cooldownStart = manager.getCooldownStartTime()
        
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = manager.getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkRefreshCooldown() Checking cooldown - Start: \(cooldownStart), Current: \(currentTime), Elapsed: \(elapsed)s, Duration: \(cooldownDuration)s, Remaining: \(remaining)s")
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            // Check remaining time directly instead of relying on isInCooldown() which has precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Refresh cooldown expired in background - auto-resetting (remaining: \(remaining)s)")
                manager.resetCooldown()
                
                // Notify UI about expiration
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.refreshCooldownExpiredNotification, object: nil)
                    NotificationCenter.default.post(name: Self.anyFeatureCooldownExpiredNotification, object: "refresh")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Refresh cooldown active - \(remaining)s remaining")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "checkRefreshCooldown() No cooldown active (cooldownStart: \(cooldownStart))")
        }
    }
    
    private func checkFilterCooldown() {
        let manager = FilterLimitManager.shared
        
        // CRITICAL FIX: Check cooldown state more robustly to handle precision issues
        let cooldownStart = manager.getCooldownStartTime()
        
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = manager.getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Filter cooldown expired in background - auto-resetting (remaining: \(remaining)s)")
                manager.resetCooldown()
                
                // Notify UI about expiration
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.filterCooldownExpiredNotification, object: nil)
                    NotificationCenter.default.post(name: Self.anyFeatureCooldownExpiredNotification, object: "filter")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Filter cooldown active - \(remaining)s remaining")
            }
        }
    }
    
    private func checkSearchCooldown() {
        let manager = SearchLimitManager.shared
        
        // CRITICAL FIX: Check cooldown state more robustly to handle precision issues
        let cooldownStart = manager.getCooldownStartTime()
        
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = manager.getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Search cooldown expired in background - auto-resetting (remaining: \(remaining)s)")
                manager.resetCooldown()
                
                // Notify UI about expiration
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.searchCooldownExpiredNotification, object: nil)
                    NotificationCenter.default.post(name: Self.anyFeatureCooldownExpiredNotification, object: "search")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Search cooldown active - \(remaining)s remaining")
            }
        }
    }
    
    private func checkConversationCooldown() {
        let manager = ConversationLimitManagerNew.shared
        
        // CRITICAL FIX: Check cooldown state more robustly to handle precision issues
        let cooldownStart = manager.getCooldownStartTime()
        
        if cooldownStart > 0 {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let elapsed = currentTime - cooldownStart
            let cooldownDuration = manager.getCooldownDuration()
            let remaining = max(0, cooldownDuration - TimeInterval(elapsed))
            
            // Fix: Use tolerance of 1 second to handle timing precision issues
            if remaining <= 1.0 {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Conversation cooldown expired in background - auto-resetting (remaining: \(remaining)s)")
                manager.resetCooldown()
                
                // Notify UI about expiration
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.conversationCooldownExpiredNotification, object: nil)
                    NotificationCenter.default.post(name: Self.anyFeatureCooldownExpiredNotification, object: "conversation")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Conversation cooldown active - \(remaining)s remaining")
            }
        }
    }
    
    // MARK: - Precise Expiration Timers
    
    /// Set up precise timers that fire exactly when cooldowns expire
    private func setupPreciseExpirationTimers() {
        // Clear existing precise timers
        for timer in preciseExpirationTimers.values {
            timer.invalidate()
        }
        preciseExpirationTimers.removeAll()
        
        // Set up precise timer for refresh feature
        if let expirationTime = getFeatureExpirationTime("refresh", manager: RefreshLimitManager.shared) {
            setupPreciseTimerFor(feature: "refresh", expirationTime: expirationTime) {
                self.checkRefreshCooldown()
            }
        }
        
        // Set up precise timer for filter feature
        if let expirationTime = getFeatureExpirationTime("filter", manager: FilterLimitManager.shared) {
            setupPreciseTimerFor(feature: "filter", expirationTime: expirationTime) {
                self.checkFilterCooldown()
            }
        }
        
        // Set up precise timer for search feature
        if let expirationTime = getFeatureExpirationTime("search", manager: SearchLimitManager.shared) {
            setupPreciseTimerFor(feature: "search", expirationTime: expirationTime) {
                self.checkSearchCooldown()
            }
        }
    }
    
    private func getFeatureExpirationTime(_ featureName: String, manager: BaseFeatureLimitManager) -> Date? {
        guard manager.isInCooldown() else { return nil }
        
        let remaining = manager.getRemainingCooldown()
        guard remaining > 0 else { return nil }
        
        let expirationTime = Date().addingTimeInterval(remaining)
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "\(featureName) cooldown expires at: \(expirationTime), remaining: \(remaining)s")
        return expirationTime
    }
    
    private func setupPreciseTimerFor(feature: String, expirationTime: Date, action: @escaping () -> Void) {
        let timeInterval = expirationTime.timeIntervalSinceNow
        guard timeInterval > 0 else {
            // Already expired, check immediately
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "\(feature) cooldown already expired, checking immediately")
            action()
            return
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Precise timer fired for \(feature) cooldown expiration")
            action()
            self?.preciseExpirationTimers.removeValue(forKey: feature)
        }
        
        preciseExpirationTimers[feature] = timer
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Set precise timer for \(feature) to fire in \(timeInterval)s")
    }
    
    /// Public method to update precise timers when cooldowns start
    /// Only called by BackgroundTimerManager internally to prevent cross-feature interference
    func updatePreciseTimers() {
        AppLogger.log(tag: "LOG-APP: BackgroundTimerManager", message: "Updating precise expiration timers (internal call only)")
        setupPreciseExpirationTimers()
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopMonitoring()
    }
}

// MARK: - Extensions for Feature-Specific Handling

extension BackgroundTimerManager {
    /// Check if any cooldowns are active
    var hasActiveCooldowns: Bool {
        return RefreshLimitManager.shared.isInCooldown() ||
               FilterLimitManager.shared.isInCooldown() ||
               SearchLimitManager.shared.isInCooldown()
    }
    
    /// Get summary of all active cooldowns
    func getCooldownSummary() -> [String: TimeInterval] {
        var summary: [String: TimeInterval] = [:]
        
        if RefreshLimitManager.shared.isInCooldown() {
            summary["refresh"] = RefreshLimitManager.shared.getRemainingCooldown()
        }
        
        if FilterLimitManager.shared.isInCooldown() {
            summary["filter"] = FilterLimitManager.shared.getRemainingCooldown()
        }
        
        if SearchLimitManager.shared.isInCooldown() {
            summary["search"] = SearchLimitManager.shared.getRemainingCooldown()
        }
        
        if ConversationLimitManagerNew.shared.isInCooldown() {
            summary["conversation"] = ConversationLimitManagerNew.shared.getRemainingCooldown()
        }
        
        return summary
    }
}
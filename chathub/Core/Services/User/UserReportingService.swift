import Foundation
import FirebaseFirestore

/// UserReportingService - iOS equivalent of Android UserReportingWorker
/// Handles user reporting functionality and multiple reports warnings with 100% Android parity
class UserReportingService {
    
    // MARK: - Singleton
    static let shared = UserReportingService()
    private init() {}
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let sessionManager = SessionManager.shared
    
    // MARK: - Constants
    private let oneHourInSeconds: TimeInterval = 3600
    private let fiveMinutesInSeconds: TimeInterval = 300
    
    // MARK: - Public Methods
    
    /// Block user from reporting until specified timestamp - Android parity
    func blockUserReporting(until timestamp: TimeInterval) {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "blockUserReporting() until: \(timestamp)")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "blockUserReporting() userId is nil")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        let updateData: [String: Any] = [
            "userReportBlockedUntil": timestamp,
            "userReportBlockedAt": Date().timeIntervalSince1970
        ]
        
        userRef.updateData(updateData) { [weak self] error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "blockUserReporting() error blocking user reporting: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "blockUserReporting() user reporting blocked successfully until \(Date(timeIntervalSince1970: timestamp))")
            }
            
            // Update SessionManager regardless of Firestore success/failure
            self?.sessionManager.userReportBlockedUntil = timestamp
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "blockUserReporting() updated SessionManager with block until timestamp \(timestamp)")
        }
    }
    
    /// Record user report submission - Android parity
    func recordUserReportSubmission() {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() userId is nil")
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        
        // Update local SessionManager data
        var reportTimes = sessionManager.userReportTimesList
        reportTimes.append(currentTime)
        
        // Keep only reports from last 5 minutes
        reportTimes = reportTimes.filter { currentTime - $0 < fiveMinutesInSeconds }
        sessionManager.userReportTimesList = reportTimes
        
        let reportCount = reportTimes.count
        sessionManager.userReportTimes = reportCount
        
        // Update Firestore
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() error getting document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                // Update existing document
                let updateData: [String: Any] = [
                    "userReportTimes": reportCount,
                    "userReportTimesList": reportTimes,
                    "lastReportSubmission": currentTime
                ]
                
                userRef.updateData(updateData) { error in
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() error recording report submission: \(error.localizedDescription)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() report submission recorded successfully")
                    }
                }
            } else {
                // Create new document
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() user document does not exist, creating new record")
                
                let newData: [String: Any] = [
                    "userReportTimes": reportCount,
                    "userReportTimesList": reportTimes,
                    "lastReportSubmission": currentTime,
                    "createdAt": currentTime
                ]
                
                userRef.setData(newData) { error in
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() error creating report submission record: \(error.localizedDescription)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "recordUserReportSubmission() initial report submission recorded successfully")
                    }
                }
            }
        }
        
        // Check if user should be blocked from reporting
        if reportCount >= 3 {
            let blockUntil = currentTime + fiveMinutesInSeconds
            blockUserReporting(until: blockUntil)
        }
    }
    
    /// Fetch user report stats and update UserDefaults - Android parity
    func fetchUserReportStatsAndUpdateUserDefaults() {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "fetchUserReportStatsAndUpdateUserDefaults() started")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "fetchUserReportStatsAndUpdateUserDefaults() userId is nil")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "fetchUserReportStatsAndUpdateUserDefaults() error: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists, let data = document.data() {
                let reportCount = data["userTotalReports"] as? Int ?? 0
                let lastReportTime = data["userLastReportTimestamp"] as? TimeInterval ?? 0
                
                self?.sessionManager.userTotalReports = reportCount
                self?.sessionManager.userLastReportTimestamp = lastReportTime
                
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "fetchUserReportStatsAndUpdateUserDefaults() updated SessionManager with reportCount=\(reportCount), lastReportTime=\(lastReportTime)")
                
                // Check if multiple reports warning should be shown
                self?.checkAndSetMultipleReportsWarningIfNeeded()
            } else {
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "fetchUserReportStatsAndUpdateUserDefaults() user document does not exist")
            }
        }
    }
    
    /// Check if user can report - Android parity
    func canUserReport() -> Bool {
        let blockedUntil = sessionManager.userReportBlockedUntil
        let currentTime = Date().timeIntervalSince1970
        
        // If user is currently blocked, return false
        if currentTime < blockedUntil {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "canUserReport() user is blocked until \(Date(timeIntervalSince1970: blockedUntil))")
            return false
        }
        
        // Check recent report times
        var reportTimes = sessionManager.userReportTimesList
        reportTimes = reportTimes.filter { currentTime - $0 < fiveMinutesInSeconds }
        sessionManager.userReportTimesList = reportTimes
        
        // If 3 or more reports in 5 minutes, user cannot report
        let canReport = reportTimes.count < 3
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "canUserReport() returning \(canReport), recent reports: \(reportTimes.count)")
        
        return canReport
    }
    
    /// Get time until user can report again - Android parity
    func getTimeUntilCanReport() -> TimeInterval {
        let blockedUntil = sessionManager.userReportBlockedUntil
        let currentTime = Date().timeIntervalSince1970
        
        if currentTime < blockedUntil {
            return blockedUntil - currentTime
        }
        
        return 0
    }
    
    /// Reset user reporting restrictions - Android parity
    func resetUserReportingRestrictions() {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "resetUserReportingRestrictions() resetting all restrictions")
        
        sessionManager.userReportBlockedUntil = 0
        sessionManager.userReportTimesList = []
        sessionManager.userReportTimes = 0
        sessionManager.showMultipleReportsWarning = false
        sessionManager.multipleReportsShowWarningCooldownUntilTimestamp = 0
    }
    
    /// Get user report statistics - Android parity
    func getUserReportStats() -> (totalReports: Int, lastReportTime: TimeInterval, recentReports: Int) {
        let totalReports = sessionManager.userTotalReports
        let lastReportTime = sessionManager.userLastReportTimestamp
        let recentReports = sessionManager.userReportTimesList.count
        
        return (totalReports: totalReports, lastReportTime: lastReportTime, recentReports: recentReports)
    }
    
    /// Submit user report to Firebase - Android parity equivalent to FirebaseServices.submitUserReport
    func submitUserReport(reportData: [String: Any], completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "submitUserReport() starting report submission")
        
        guard let reportedUserId = reportData["reported_user_id"] as? String,
              let reportReason = reportData["report_reason"] as? String,
              let reporterUserId = reportData["reporter_user_id"] as? String else {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "submitUserReport() invalid report data")
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let timestamp = Date().timeIntervalSince1970
        
        // Create report document
        let reportDocumentData: [String: Any] = [
            "reported_user_id": reportedUserId,
            "reporter_user_id": reporterUserId,
            "report_reason": reportReason,
            "timestamp": timestamp,
            "status": "pending",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        ]
        
        // Submit to UserReports collection (Android parity)
        db.collection("UserReports")
            .document("\(timestamp)_\(reporterUserId)_\(reportedUserId)")
            .setData(reportDocumentData) { [weak self] error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: UserReportingService", message: "submitUserReport() error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "submitUserReport() report submitted successfully")
                
                // Record the report submission for rate limiting
                self?.recordUserReportSubmission()
                
                completion(true)
            }
    }
    
    /// Send notification to user - Android parity equivalent to FirebaseServices.sendNotificationToUser
    func sendNotificationToUser(userId: String, notificationData: [String: Any]) {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendNotificationToUser() sending notification to user: \(userId)")
        
        let db = Firestore.firestore()
        let timestamp = Date().timeIntervalSince1970
        
        var notificationPayload = notificationData
        notificationPayload["timestamp"] = timestamp
        notificationPayload["read"] = false
        
        // Send notification to user's notifications collection (Android parity)
        db.collection("Notifications")
            .document(userId)
            .collection("Notifications")
            .document(String(Int64(timestamp)))
            .setData(notificationPayload) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendNotificationToUser() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendNotificationToUser() notification sent successfully")
                }
            }
    }
    
    /// Send moderation report - Android parity equivalent to FirebaseServices.sendModerationReport
    func sendModerationReport(reportData: [String: Any]) {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendModerationReport() sending report to moderation system")
        
        let db = Firestore.firestore()
        let timestamp = Date().timeIntervalSince1970
        
        var moderationPayload = reportData
        moderationPayload["timestamp"] = timestamp
        moderationPayload["status"] = "pending_review"
        moderationPayload["priority"] = "normal"
        
        // Send to moderation queue (Android parity)
        db.collection("ModerationQueue")
            .document(String(Int64(timestamp)))
            .setData(moderationPayload) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendModerationReport() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: UserReportingService", message: "sendModerationReport() moderation report sent successfully")
                }
            }
    }
    
    // MARK: - Private Methods
    
    /// Check and set multiple reports warning if needed - Android parity
    private func checkAndSetMultipleReportsWarningIfNeeded() {
        AppLogger.log(tag: "LOG-APP: UserReportingService", message: "checkAndSetMultipleReportsWarningIfNeeded() started")
        
        let currentTime = Date().timeIntervalSince1970
        let cooldownUntil = sessionManager.multipleReportsShowWarningCooldownUntilTimestamp
        
        // Check if still in cooldown
        if currentTime < cooldownUntil {
            AppLogger.log(tag: "LOG-APP: UserReportingService", message: "checkAndSetMultipleReportsWarningIfNeeded() still in cooldown")
            return
        }
        
        let totalReports = sessionManager.userTotalReports
        let lastReportTime = sessionManager.userLastReportTimestamp
        
        // Check if user has multiple reports (threshold: 3 or more reports)
        if totalReports >= 3 {
            // Check if last report was recent (within last 24 hours)
            let twentyFourHoursAgo = currentTime - (24 * oneHourInSeconds)
            
            if lastReportTime > twentyFourHoursAgo {
                sessionManager.showMultipleReportsWarning = true
                sessionManager.multipleReportsShowWarningCooldownUntilTimestamp = currentTime + oneHourInSeconds
                AppLogger.log(tag: "LOG-APP: UserReportingService", message: "checkAndSetMultipleReportsWarningIfNeeded() multiple reports warning flag set")
            }
        }
    }
} 
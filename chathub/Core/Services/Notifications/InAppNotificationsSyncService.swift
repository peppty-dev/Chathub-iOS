import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// iOS equivalent of Android NotificationsWorker
/// Handles notifications synchronization from Firebase to local database with 100% Android parity
/// IMPLEMENTS: Firebase → Local Database → Screen flow
class InAppNotificationsSyncService {
    static let shared = InAppNotificationsSyncService()
    
    private let db = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    private var notificationsListener: ListenerRegistration?
    private var notificationname = [String]()
    
    // MARK: - Continuous Retry Properties (Android Parity)
    private static let TAG = "NotificationsSyncService"
    private static let RETRY_DELAY_SECONDS: TimeInterval = 30.0 // 30 seconds like current implementation
    private var retryTimer: Timer?
    private var retryCount = 0
    private var isRetryingForUserId: String? = nil
    
    private init() {}
    
    /// Starts the notifications listener - equivalent to FirebaseServices.getNotificationsListener()
    /// This is the main method that should be called to start listening for notification updates
    /// IMPLEMENTS: Firebase → Local Database → Screen flow
    func startNotificationsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() starting Firebase notifications listener")
        
        // Debug: Check session manager and user authentication status
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() SessionManager userId: \(sessionManager.userId ?? "nil")")
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() Firebase Auth current user: \(Auth.auth().currentUser?.uid ?? "nil")")
        
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            // Android parity: Continuous retry until user is authenticated
            if isRetryingForUserId == nil {
                retryCount += 1
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
                isRetryingForUserId = nil // Mark that we're retrying for null user
                scheduleContinuousRetry()
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() already retrying for user authentication")
            }
            return
        }
        
        // User authenticated successfully - stop any retry timers and proceed
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = userId
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() User authenticated, starting listener for userId: \(userId)")
        
        // Remove existing listener if active
        if let existingListener = notificationsListener {
            existingListener.remove()
            notificationsListener = nil
        }
        
        // Get last notification time from local database (Android parity)
        let lastTime = getLastNotificationTimeFromLocalDB()
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() Using last notification time from local DB: \(lastTime)")
        
        // Set up Firebase listener (matching FirebaseServices.getNotificationsListener exactly)
        notificationsListener = db.collection("Notifications")
            .document(userId)
            .collection("Notifications")
            .order(by: "notif_time", descending: true)
            .end(before: [lastTime as Any])
            .limit(to: 10)
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() Firebase listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snap = snapshot else { 
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() No snapshot received")
                    return 
                }
                
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() Received \(snap.documentChanges.count) document changes")
                
                snap.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startNotificationsListener() Processing added document: \(diff.document.documentID)")
                        self.processAddedNotificationDocument(diff.document)
                    }
                }
            }
    }
    
    /// Stops the notifications listener
    func stopNotificationsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopNotificationsListener() stopping Firebase notifications listener")
        
        // Stop continuous retry mechanism
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = nil
        
        if let listener = notificationsListener {
            listener.remove()
            notificationsListener = nil
        }
    }
    
    // MARK: - Continuous Retry Methods (Android Parity)
    
    /// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
    private func scheduleContinuousRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
            self.startNotificationsListener() // CONTINUOUS RETRY - calls itself again until user is authenticated
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Process added notification document (from FirebaseServices.getNotificationsListener)
    /// IMPLEMENTS: Firebase → Local Database → Screen flow
    private func processAddedNotificationDocument(_ document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        let documenttime = document.documentID
        let notiftype = data["notif_type"] as? String ?? ""
        let notifsendername = data["notif_sender_name"] as? String ?? ""
        let notifsenderid = data["notif_sender_id"] as? String ?? ""
        let notifsendergender = data["notif_sender_gender"] as? String ?? ""
        let notifsenderimage = data["notif_sender_image"] as? String ?? ""
        let notifotherid = data["notif_other_id"] as? String ?? ""
        

        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() Processing notification from \(notifsendername) (type: \(notiftype))")
        
        // Filter to only process profileview notifications
        guard notiftype == "profileview" else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() Skipping notification type: \(notiftype) - only profileview is supported")
            return
        }
        
        // Use local array to track processed notifications (like FirebaseServices)
        if !notificationname.contains(documenttime) {
            notificationname.append(documenttime)
            
            // CRITICAL: Write to local database FIRST (Firebase → Local Database)
            guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() NotificationDB not available")
                return
            }
            
            // Convert document time to Int64 (Android parity)
            let notifTime = Int64(documenttime) ?? Int64(Date().timeIntervalSince1970)
            
            // Insert into local database with subscription model schema
            notificationDB.insert(
                notifType: notiftype,
                notifSenderName: notifsendername,
                notifSenderId: notifsenderid,
                notifSenderGender: notifsendergender,
                notifSenderImage: notifsenderimage,
                notifOtherId: notifotherid,
                notifTime: notifTime,
                notifSeen: false // New notifications are unseen
            )
            
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() Successfully wrote profileview notification to local database")
            
            // Update session manager's last notification time (Android parity)
            // Use document ID as timestamp since that's how notifications are stored
            sessionManager.notificationLastTime = documenttime
            
            // Notify badge manager of new notification (Local Database → Screen)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
                InAppNotificationBadgeManager.shared.refreshAllBadges()
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() Notified UI of new profileview notification")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processAddedNotificationDocument() Notification already processed: \(documenttime)")
        }
    }
    
    /// Get last notification time from local database (Android parity)
    private func getLastNotificationTimeFromLocalDB() -> Int64 {
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getLastNotificationTimeFromLocalDB() NotificationDB not available, using default")
            return 10000 // Default value like Android
        }
        
        let lastTime = notificationDB.getLastNotificationTime()
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getLastNotificationTimeFromLocalDB() Retrieved last time from local DB: \(lastTime)")
        
        return lastTime > 0 ? lastTime : 10000 // Use default if no notifications exist
    }
    
    /// Android parity: NotificationsWorker.doWork()
    /// Syncs notifications from Firebase to local database
    /// IMPLEMENTS: Firebase → Local Database → Screen flow
    func syncNotificationsFromFirebase(lastNotificationTime: String?, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Starting notifications sync with lastNotificationTime: \(lastNotificationTime ?? "nil")")
        
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() No valid user ID, skipping notifications sync")
            completion(false)
            return
        }
        
        // Guard: Check if user is authenticated (Android parity)
        guard Auth.auth().currentUser != nil else {
            AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() User not authenticated, skipping notifications sync")
            completion(false)
            return
        }
        
        // Parse timestamp (Android parity: exact same logic)
        let lastTime = lastNotificationTime ?? "0"
        var lastNotifTime: Int64
        
        if !lastTime.isEmpty && lastTime != "null" && lastTime != " " {
            AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() LASTNOTIFTIME exists: \(lastTime)")
            lastNotifTime = Int64(lastTime) ?? 0
        } else {
            AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() LASTNOTIFTIME does not exist, using local DB")
            // Use local database last time instead of hardcoded value
            lastNotifTime = getLastNotificationTimeFromLocalDB()
        }
        
        AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() LastNotifTime: \(lastNotifTime)")
        
        // Remove existing listener (Android parity)
        if let existingListener = notificationsListener {
            existingListener.remove()
            notificationsListener = nil
        }
        
        // Set up Firebase listener (Android parity: exact same query structure)
        notificationsListener = db.collection("Notifications")
            .document(userId)
            .collection("Notifications")
            .order(by: "notif_time", descending: true)
            .end(before: [lastNotifTime])
            .limit(to: 10)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Listen error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = querySnapshot?.documentChanges else {
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() No document changes")
                    completion(true)
                    return
                }
                
                var operationCount = 0
                let totalOperations = documents.count
                
                if totalOperations == 0 {
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() No new notifications to sync")
                    completion(true)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Processing \(totalOperations) notification changes")
                
                // Process document changes (Android parity)
                for documentChange in documents {
                    let document = documentChange.document
                    
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Added: \(document.documentID)")
                    
                    // Extract notification data (Android parity: exact same field extraction)
                    let notifType = document.get("notif_type") as? String ?? ""
                    let notifSenderName = document.get("notif_sender_name") as? String ?? ""
                    let notifSenderId = document.get("notif_sender_id") as? String ?? ""
                    let notifSenderGender = document.get("notif_sender_gender") as? String ?? ""
                    let notifSenderImage = document.get("notif_sender_image") as? String ?? ""
                    let notifOtherId = document.get("notif_other_id") as? String ?? ""
                    let notifTime = document.documentID
                    


                    // Filter to only process profileview notifications
                    guard notifType == "profileview" else {
                        AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Skipping notification type: \(notifType) - only profileview is supported")
                        continue
                    }
                    
                    // Parse notification time (Android parity: exact same parsing logic)
                    guard let notifTimeDouble = Double(notifTime) else {
                        AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Invalid notif_time format: \(notifTime)")
                        continue
                    }
                    
                    let notifTimeLong = Int64(notifTimeDouble)
                    
                    // CRITICAL: Write to local database FIRST (Firebase → Local Database)
                    guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
                        AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() NotificationDB not available")
                        continue
                    }
                    
                    // Insert into local database (subscription model)
                    notificationDB.insert(
                        notifType: notifType,
                        notifSenderName: notifSenderName,
                        notifSenderId: notifSenderId,
                        notifSenderGender: notifSenderGender,
                        notifSenderImage: notifSenderImage,
                        notifOtherId: notifOtherId,
                        notifTime: notifTimeLong,
                        notifSeen: false // New notifications are unseen
                    )
                    
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Successfully wrote profileview notification to local database")
                    
                    operationCount += 1
                }
                
                AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Completed sync of \(operationCount)/\(totalOperations) notifications")
                
                // Notify UI of changes (Local Database → Screen)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
                    InAppNotificationBadgeManager.shared.refreshAllBadges()
                    AppLogger.log(tag: "LOG-APP: NotificationsSyncService", message: "syncNotificationsFromFirebase() Notified UI of sync completion")
                }
                
                completion(true)
            }
    }
    
    /// Force sync notifications from Firebase - useful for manual refresh
    func forceSyncNotifications(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "forceSyncNotifications() Force syncing notifications from Firebase")
        
        let lastTime = getLastNotificationTimeFromLocalDB()
        syncNotificationsFromFirebase(lastNotificationTime: String(lastTime), completion: completion)
    }
    
    /// Get notifications from local database only (Local Database → Screen)
    func getNotificationsFromLocalDB() -> [InAppNotificationDetails] {
        return getNotificationsFromLocalDB(limit: nil, offset: nil)
    }
    
    /// Get notifications from local database with paging support (Local Database → Screen)
    func getNotificationsFromLocalDB(limit: Int?, offset: Int?) -> [InAppNotificationDetails] {
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getNotificationsFromLocalDB() NotificationDB not available")
            return []
        }
        
        let notifications = notificationDB.queryWithPaging(limit: limit, offset: offset)
        let pageInfo = limit != nil ? " (page: limit=\(limit!), offset=\(offset ?? 0))" : " (all)"
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getNotificationsFromLocalDB() Retrieved \(notifications.count) notifications from local database\(pageInfo)")
        

        
        return notifications
    }
    
    /// Mark notifications as seen in local database (Android parity)
    func markNotificationsAsSeenInLocalDB() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "markNotificationsAsSeenInLocalDB() Marking notifications as seen")
        
        guard let notificationDB = DatabaseManager.shared.getNotificationDB() else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "markNotificationsAsSeenInLocalDB() NotificationDB not available")
            return
        }
        
        notificationDB.markAllNotificationsAsSeen()
        
        // Notify badge manager (Local Database → Screen)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
            InAppNotificationBadgeManager.shared.refreshAllBadges()
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "markNotificationsAsSeenInLocalDB() Notified UI of seen status change")
        }
    }
    

} 

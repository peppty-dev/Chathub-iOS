import Foundation
import FirebaseFirestore

class SubscriptionRepository {
    static let shared = SubscriptionRepository()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // Use specialized UserSessionManager instead of monolithic SessionManager
    private var userID: String? {
        return UserSessionManager.shared.userId
    }
    
    private init() {}
    
    // Start listening to Firebase for subscription status changes
    func startListening() {
        guard let userID = userID else {
            AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "startListening: No userID")
            return
        }
        stopListening()
        listener = db.collection("subscriptions").document(userID).addSnapshotListener { snapshot, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "Firebase listener error: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data(), let isActive = data["active"] as? Bool else {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "No subscription data or 'active' field")
                return
            }
            AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "Firebase listener: active=\(isActive)")
            
            // This is a simplified update. A more robust implementation would
            // fetch the full state and update the session manager.
            if let status = data["status"] as? String,
               let tier = data["tier"] as? String,
               let period = data["period"] as? String,
               let startTimeMillis = data["startTimeMillis"] as? Int64,
               let productId = data["productId"] as? String {
                
                SubscriptionSessionManager.shared.updateFromSubscriptionState(
                    isActive: isActive,
                    tier: tier,
                    period: period,
                    status: status,
                    startTimeMillis: startTimeMillis,
                    expiryTimeMillis: data["expiryTimeMillis"] as? Int64,
                    willAutoRenew: data["willAutoRenew"] as? Bool ?? false,
                    productId: productId,
                    purchaseToken: data["purchaseToken"] as? String,
                    basePlanId: data["basePlanId"] as? String
                )
            }
        }
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "Started Firebase listener for userID=\(userID)")
    }
    
    // Stop listening
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // Save subscription status to Firebase after purchase/restore
    func saveSubscriptionStatus(isActive: Bool) {
        guard let userID = userID else {
            AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "saveSubscriptionStatus: No userID")
            return
        }
        db.collection("subscriptions").document(userID).setData(["active": isActive], merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "Error saving subscription: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "Saved subscription status: active=\(isActive)")
            }
        }
    }
    
    // Save full subscription state to Firestore (Android parity with queue integration)
    func saveFullSubscriptionState(
        userId: String,
        isActive: Bool,
        status: String,
        tier: String,
        period: String,
        basePlanId: String?,
        purchaseTime: Int64,
        startTimeMillis: Int64,
        expiryTimeMillis: Int64?,
        willAutoRenew: Bool,
        purchaseToken: String?,
        productId: String,
        orderId: String? = nil,
        isNewPurchase: Bool = false,
        gracePeriodEndMillis: Int64 = 0,
        accountHoldEndMillis: Int64 = 0
    ) {
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "saveFullSubscriptionState() Saving subscription state for userId=\(userId), isNewPurchase=\(isNewPurchase)")
        
        // --- Save to UserDefaults for local cache (Android Parity) ---
        SubscriptionSessionManager.shared.updateFromSubscriptionState(
            isActive: isActive,
            tier: tier,
            period: period,
            status: status,
            startTimeMillis: startTimeMillis,
            expiryTimeMillis: expiryTimeMillis,
            willAutoRenew: willAutoRenew,
            productId: productId,
            purchaseToken: purchaseToken,
            basePlanId: basePlanId
        )

        // --- Prepare data for Firestore sync ---
        let subscriptionData: [String: Any] = [
            "userId": userId,
            "isActive": isActive,
            "status": status,
            "tier": tier,
            "period": period,
            "basePlanId": basePlanId ?? NSNull(),
            "purchaseTime": purchaseTime,
            "startTimeMillis": startTimeMillis,
            "expiryTimeMillis": expiryTimeMillis ?? 0,
            "willAutoRenew": willAutoRenew,
            "purchaseToken": purchaseToken ?? NSNull(),
            "productId": productId,
            "orderId": orderId ?? NSNull(),
            "isNewPurchase": isNewPurchase,
            "gracePeriodEndMillis": gracePeriodEndMillis,
            "accountHoldEndMillis": accountHoldEndMillis
        ]
        
        // --- Try immediate Firestore sync (Android parity) ---
        let docRef = db.collection("Users").document(userId).collection("Subscription").document("current_state")
        docRef.setData(subscriptionData.compactMapValues { $0 }, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "saveFullSubscriptionState() Immediate sync failed: \(error.localizedDescription)")
                
                // --- Queue for background retry (Android parity: WorkManager retry) ---
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "saveFullSubscriptionState() Adding to background sync queue")
                SubscriptionSyncQueue.shared.addPendingUpdate(subscriptionData)
                
                // Trigger immediate background sync attempt
                BackgroundTaskManager.shared.executeImmediateSubscriptionSync()
                
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "saveFullSubscriptionState() Immediate sync successful for userId=\(userId)")
            }
        }
    }
    
    /// Triggers inactive subscription state update (Android parity: triggerInactiveStateUpdate)
    func triggerInactiveStateUpdate(userId: String) {
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "triggerInactiveStateUpdate() Triggering inactive state update for user: \(userId)")
        
        let inactiveData: [String: Any] = [
            "userId": userId,
            "isInactiveUpdate": true
        ]
        
        // --- Try immediate Firestore sync ---
        let inactiveStateData: [String: Any] = [
            "userId": userId,
            "isActive": false,
            "status": "inactive",
            "tier": "none",
            "period": "none",
            "basePlanId": NSNull(),
            "purchaseTime": 0,
            "startTimeMillis": 0,
            "expiryTimeMillis": 0,
            "willAutoRenew": false,
            "purchaseToken": NSNull(),
            "productId": NSNull(),
            "gracePeriodEndMillis": 0,
            "accountHoldEndMillis": 0
        ]
        
        let docRef = db.collection("Users").document(userId).collection("Subscription").document("current_state")
        docRef.setData(inactiveStateData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "triggerInactiveStateUpdate() Immediate inactive sync failed: \(error.localizedDescription)")
                
                // --- Queue for background retry ---
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "triggerInactiveStateUpdate() Adding inactive update to background sync queue")
                SubscriptionSyncQueue.shared.addPendingUpdate(inactiveData)
                
                // Trigger immediate background sync attempt
                BackgroundTaskManager.shared.executeImmediateSubscriptionSync()
                
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "triggerInactiveStateUpdate() Immediate inactive sync successful for userId=\(userId)")
                
                // Update local session manager
                SubscriptionSessionManager.shared.updateFromSubscriptionState(
                    isActive: false,
                    tier: "none",
                    period: "none",
                    status: "inactive",
                    startTimeMillis: 0,
                    expiryTimeMillis: 0,
                    willAutoRenew: false,
                    productId: "",
                    purchaseToken: nil,
                    basePlanId: nil
                )
            }
        }
    }
    
    func fetchSubscriptionHistory(completion: @escaping (Result<[SubscriptionHistoryItem], Error>) -> Void) {
        guard let userID = userID else {
            let error = NSError(domain: "SubscriptionRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            completion(.failure(error))
            return
        }
        
        db.collection("Users").document(userID).collection("SubscriptionHistory")
            .order(by: "purchaseTime", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let historyItems = documents.compactMap { doc -> SubscriptionHistoryItem? in
                    let data = doc.data()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    
                    let _ = (data["purchaseTime"] as? Timestamp)?.dateValue() ?? Date()
                    let _ = (data["expiryTimeMillis"] as? Timestamp)?.dateValue()
                    
                    return SubscriptionHistoryItem(
                        id: doc.documentID,
                        documentId: doc.documentID,
                        productId: data["productId"] as? String ?? "",
                        tier: data["tier"] as? String ?? "unknown",
                        period: data["period"] as? String ?? "unknown",
                        status: data["status"] as? String ?? "unknown",
                        isActive: data["isActive"] as? Bool ?? false,
                        willAutoRenew: data["willAutoRenew"] as? Bool ?? false,
                        startTimeMillis: data["startTimeMillis"] as? Int64 ?? 0,
                        expiryTimeMillis: data["expiryTimeMillis"] as? Int64 ?? 0,
                        lastUpdatedTimeMillis: data["lastUpdatedTimeMillis"] as? Int64 ?? 0,
                        lastNotificationType: data["lastNotificationType"] as? Int,
                        orderId: data["orderId"] as? String,
                        basePlanId: data["basePlanId"] as? String,
                        subscriptionState: data["subscriptionState"] as? String,
                        needsVerification: data["needsVerification"] as? Bool ?? false,
                        gracePeriodEndMillis: data["gracePeriodEndMillis"] as? Int64 ?? 0,
                        accountHoldEndMillis: data["accountHoldEndMillis"] as? Int64 ?? 0,
                        pauseResumeTimeMillis: data["pauseResumeTimeMillis"] as? Int64 ?? 0
                    )
                }
                
                completion(.success(historyItems))
            }
    }
    
    // MARK: - Pagination Support (Android Parity)
    
    struct HistoryPageResult {
        let items: [SubscriptionHistoryItem]
        let lastDocument: DocumentSnapshot?
        let isLastPage: Bool
    }
    
    func fetchSubscriptionHistoryPage(
        pageSize: Int,
        startAfter: DocumentSnapshot?,
        completion: @escaping (Result<HistoryPageResult, Error>) -> Void
    ) {
        guard let userID = userID else {
            let error = NSError(domain: "SubscriptionRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            completion(.failure(error))
            return
        }
        
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "fetchSubscriptionHistoryPage() Loading page with size \(pageSize)")
        
        var query = db.collection("Users").document(userID).collection("Subscription")
            .order(by: "lastUpdatedTimeMillis", descending: true)
            .limit(to: pageSize)
        
        // Exclude the canonical document from history (Android parity)
        query = query.whereField(FieldPath.documentID(), isNotEqualTo: "current_state")
        
        if let startAfter = startAfter {
            query = query.start(afterDocument: startAfter)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "fetchSubscriptionHistoryPage() Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "fetchSubscriptionHistoryPage() No documents found")
                completion(.success(HistoryPageResult(items: [], lastDocument: nil, isLastPage: true)))
                return
            }
            
            let historyItems = documents.compactMap { doc -> SubscriptionHistoryItem? in
                let data = doc.data()
                
                // Skip current_state document (double check)
                if doc.documentID == "current_state" {
                    return nil
                }
                
                return SubscriptionHistoryItem(
                    id: doc.documentID,
                    documentId: doc.documentID,
                    productId: data["productId"] as? String ?? "",
                    tier: data["tier"] as? String ?? "unknown",
                    period: data["period"] as? String ?? "unknown",
                    status: data["status"] as? String ?? "unknown",
                    isActive: data["isActive"] as? Bool ?? false,
                    willAutoRenew: data["willAutoRenew"] as? Bool ?? false,
                    startTimeMillis: data["startTimeMillis"] as? Int64 ?? 0,
                    expiryTimeMillis: data["expiryTimeMillis"] as? Int64 ?? 0,
                    lastUpdatedTimeMillis: data["lastUpdatedTimeMillis"] as? Int64 ?? 0,
                    lastNotificationType: data["lastNotificationType"] as? Int,
                    orderId: data["orderId"] as? String,
                    basePlanId: data["basePlanId"] as? String,
                    subscriptionState: data["subscriptionState"] as? String,
                    needsVerification: data["needsVerification"] as? Bool ?? false,
                    gracePeriodEndMillis: data["gracePeriodEndMillis"] as? Int64 ?? 0,
                    accountHoldEndMillis: data["accountHoldEndMillis"] as? Int64 ?? 0,
                    pauseResumeTimeMillis: data["pauseResumeTimeMillis"] as? Int64 ?? 0
                )
            }
            
            let lastVisibleDoc = documents.isEmpty ? nil : documents.last
            let isLastPage = documents.count < pageSize
            
            AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "fetchSubscriptionHistoryPage() Loaded \(historyItems.count) items. Last page: \(isLastPage)")
            
            let result = HistoryPageResult(
                items: historyItems,
                lastDocument: lastVisibleDoc,
                isLastPage: isLastPage
            )
            
            completion(.success(result))
        }
    }
    
    // MARK: - Queue Management (Android Parity)
    
    /// Gets the current background sync queue size for monitoring
    func getBackgroundSyncQueueSize() -> Int {
        return SubscriptionSyncQueue.shared.getQueueSize()
    }
    
    /// Clears all pending background sync updates (use with caution)
    func clearBackgroundSyncQueue() {
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "clearBackgroundSyncQueue() Clearing all pending background sync updates")
        SubscriptionSyncQueue.shared.clearAllPendingUpdates()
    }
    
    /// Forces immediate execution of background sync for all pending updates
    func forceBackgroundSync() {
        let queueSize = SubscriptionSyncQueue.shared.getQueueSize()
        AppLogger.log(tag: "LOG-APP: SubscriptionRepository", message: "forceBackgroundSync() Forcing background sync for \(queueSize) pending updates")
        
        if queueSize > 0 {
            BackgroundTaskManager.shared.executeImmediateSubscriptionSync()
        }
    }
} 
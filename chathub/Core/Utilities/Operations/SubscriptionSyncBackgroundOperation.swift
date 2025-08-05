import Foundation
import FirebaseFirestore

/// iOS equivalent of Android's SubscriptionFirestoreUpdateWorker
/// Handles background synchronization of subscription data to Firestore with retry logic
class SubscriptionSyncBackgroundOperation: Operation, @unchecked Sendable {
    
    private static let FIRESTORE_TIMEOUT_SECONDS: TimeInterval = 30
    private static let CURRENT_STATE_DOC_ID = "current_state"
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() Starting subscription sync background operation")
        
        // Get pending updates from persistent storage
        let pendingUpdates = SubscriptionSyncQueue.shared.getPendingUpdates()
        
        guard !pendingUpdates.isEmpty else {
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() No pending subscription updates to sync")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() Processing \(pendingUpdates.count) pending subscription updates")
        
        let dispatchGroup = DispatchGroup()
        let db = Firestore.firestore()
        
        for update in pendingUpdates {
            if self.isCancelled { break }
            
            guard let userId = update["userId"] as? String,
                  let updateId = update["updateId"] as? String else {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() Skipping update with missing userId or updateId")
                continue
            }
            
            dispatchGroup.enter()
            
            // Process different types of updates (Android parity)
            if let isInactiveUpdate = update["isInactiveUpdate"] as? Bool, isInactiveUpdate {
                processInactiveUpdate(userId: userId, updateId: updateId, db: db, group: dispatchGroup)
            } else {
                processActiveUpdate(update: update, userId: userId, updateId: updateId, db: db, group: dispatchGroup)
            }
        }
        
        // Wait for all operations to complete with timeout
        let result = dispatchGroup.wait(timeout: .now() + Self.FIRESTORE_TIMEOUT_SECONDS)
        
        if result == .timedOut {
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() Firestore operations timed out after \(Self.FIRESTORE_TIMEOUT_SECONDS) seconds")
        } else {
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "main() All subscription sync operations completed")
        }
    }
    
    // MARK: - Private Methods
    
    /// Processes inactive subscription update (Android parity: isInactiveUpdate = true)
    private func processInactiveUpdate(userId: String, updateId: String, db: Firestore, group: DispatchGroup) {
        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processInactiveUpdate() Processing EXPLICIT INACTIVE subscription update for user: \(userId)")
        
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
        
        let currentStateRef = db.collection("Users")
            .document(userId)
            .collection("Subscription")
            .document(Self.CURRENT_STATE_DOC_ID)
        
        currentStateRef.setData(inactiveStateData, merge: true) { [weak self] error in
            defer { group.leave() }
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processInactiveUpdate() Error setting inactive state for user: \(userId). Error: \(error.localizedDescription)")
                // Keep in queue for retry
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processInactiveUpdate() Inactive state set successfully for user: \(userId)")
                // Remove from queue on success
                SubscriptionSyncQueue.shared.removePendingUpdate(updateId)
            }
        }
    }
    
    /// Processes active subscription update (Android parity: new purchase or existing update)
    private func processActiveUpdate(update: [String: Any], userId: String, updateId: String, db: Firestore, group: DispatchGroup) {
        let isNewPurchase = update["isNewPurchase"] as? Bool ?? false
        let purchaseToken = update["purchaseToken"] as? String
        let purchaseTime = update["purchaseTime"] as? Int64 ?? 0
        
        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Processing \(isNewPurchase ? "NEW PURCHASE" : "EXISTING") subscription for user: \(userId)")
        
        let tier = update["tier"] as? String ?? "none"
        let period = update["period"] as? String ?? "none"
        let basePlanId = update["basePlanId"] as? String
        let expiryTimeMillis = update["expiryTimeMillis"] as? Int64 ?? 0
        let willAutoRenew = update["willAutoRenew"] as? Bool ?? false
        let productId = update["productId"] as? String ?? ""
        let orderId = update["orderId"] as? String
        
        // Build base data (Android parity)
        var baseData: [String: Any] = [
            "userId": userId,
            "isActive": true,
            "status": "active",
            "tier": tier,
            "period": period,
            "basePlanId": basePlanId ?? NSNull(),
            "purchaseTime": purchaseTime,
            "startTimeMillis": purchaseTime,
            "expiryTimeMillis": expiryTimeMillis,
            "willAutoRenew": willAutoRenew,
            "purchaseToken": purchaseToken ?? NSNull(),
            "productId": productId,
            "gracePeriodEndMillis": 0,
            "accountHoldEndMillis": 0
        ]
        
        let currentStateRef = db.collection("Users")
            .document(userId)
            .collection("Subscription")
            .document(Self.CURRENT_STATE_DOC_ID)
        
        // Create batch for atomic operations (Android parity)
        let batch = db.batch()
        
        // Add to purchase history if orderId exists
        if let orderId = orderId, !orderId.isEmpty {
            var purchaseData = baseData
            purchaseData["originalPurchaseTime"] = purchaseTime
            
            let historyRef = db.collection("Users")
                .document(userId)
                .collection("Subscription")
                .document(orderId)
            
            batch.setData(purchaseData, forDocument: historyRef, merge: true)
        }
        
        // Check current state before updating (Android parity: prevent older updates)
        currentStateRef.getDocument { [weak self] (currentDoc, error) in
            defer { group.leave() }
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Error reading current_state for user: \(userId). Error: \(error.localizedDescription)")
                return
            }
            
            let currentPurchaseTime = currentDoc?.data()?["purchaseTime"] as? Int64
            
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Firestore update attempt: incoming purchaseTime=\(purchaseTime), Firestore currentPurchaseTime=\(currentPurchaseTime ?? 0)")
            
            // Only update if incoming data is newer or current data doesn't exist
            if currentPurchaseTime == nil || purchaseTime >= currentPurchaseTime! {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Updating current_state with purchaseTime=\(purchaseTime)")
                
                batch.setData(baseData, forDocument: currentStateRef, merge: true)
                
                batch.commit { error in
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Error merging client-side ACTIVE purchase data. Error: \(error.localizedDescription)")
                        // Keep in queue for retry
                    } else {
                        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Client-side ACTIVE purchase data merged successfully")
                        // Remove from queue on success
                        SubscriptionSyncQueue.shared.removePendingUpdate(updateId)
                    }
                }
            } else {
                AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Skipping update: incoming purchaseTime \(purchaseTime) is older than Firestore currentState \(currentPurchaseTime!)")
                
                // Still commit batch for history (even if current_state not updated)
                batch.commit { error in
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: SubscriptionSyncBackgroundOperation", message: "processActiveUpdate() Error committing history batch: \(error.localizedDescription)")
                    } else {
                        // Remove from queue since we processed it (even if skipped)
                        SubscriptionSyncQueue.shared.removePendingUpdate(updateId)
                    }
                }
            }
        }
    }
}

// MARK: - Subscription Sync Queue

/// Persistent queue for subscription updates that need to be synced to Firestore
/// Provides retry mechanism for failed updates (Android parity)
class SubscriptionSyncQueue {
    static let shared = SubscriptionSyncQueue()
    
    private let userDefaults = UserDefaults.standard
    private let queueKey = "subscription_sync_queue"
    private let queueAccessQueue = DispatchQueue(label: "com.peppty.ChatApp.subscription.sync.queue", attributes: .concurrent)
    
    private init() {}
    
    /// Adds a subscription update to the persistent queue for background sync
    func addPendingUpdate(_ update: [String: Any]) {
        queueAccessQueue.async(flags: .barrier) {
            var updates = self.getPendingUpdatesInternal()
            
            // Add unique ID for tracking
            var updateWithId = update
            updateWithId["updateId"] = UUID().uuidString
            updateWithId["queuedAt"] = Date().timeIntervalSince1970
            
            updates.append(updateWithId)
            
            self.userDefaults.set(updates, forKey: self.queueKey)
            self.userDefaults.synchronize()
            
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncQueue", message: "addPendingUpdate() Added subscription update to queue. Queue size: \(updates.count)")
        }
    }
    
    /// Gets all pending subscription updates from persistent storage
    func getPendingUpdates() -> [[String: Any]] {
        return queueAccessQueue.sync {
            return getPendingUpdatesInternal()
        }
    }
    
    /// Removes a successfully synced update from the queue
    func removePendingUpdate(_ updateId: String) {
        queueAccessQueue.async(flags: .barrier) {
            var updates = self.getPendingUpdatesInternal()
            updates.removeAll { update in
                (update["updateId"] as? String) == updateId
            }
            
            self.userDefaults.set(updates, forKey: self.queueKey)
            self.userDefaults.synchronize()
            
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncQueue", message: "removePendingUpdate() Removed update \(updateId) from queue. Queue size: \(updates.count)")
        }
    }
    
    /// Clears all pending updates (use with caution)
    func clearAllPendingUpdates() {
        queueAccessQueue.async(flags: .barrier) {
            self.userDefaults.removeObject(forKey: self.queueKey)
            self.userDefaults.synchronize()
            
            AppLogger.log(tag: "LOG-APP: SubscriptionSyncQueue", message: "clearAllPendingUpdates() Cleared all pending subscription updates")
        }
    }
    
    /// Gets the current queue size
    func getQueueSize() -> Int {
        return queueAccessQueue.sync {
            return getPendingUpdatesInternal().count
        }
    }
    
    // MARK: - Private Methods
    
    private func getPendingUpdatesInternal() -> [[String: Any]] {
        return userDefaults.array(forKey: queueKey) as? [[String: Any]] ?? []
    }
} 
import Foundation
import UIKit
import FirebaseFirestore
import StoreKit

/**
 * Singleton manager for subscription billing operations
 * iOS equivalent of Android's SubscriptionBillingManager
 */
@MainActor
class SubscriptionBillingManager: ObservableObject {
    
    // MARK: - Properties
    
    private static let TAG = "SubscriptionBillingManager"
    static let shared = SubscriptionBillingManager()
    
    // Callback listeners
    private var listeners: [BillingCallbacks] = []
    
    // Core billing helper
    private var billingHelper: SubscriptionBillingHelper?
    private var isInitialized = false
    
    // MARK: - Continuous Retry Properties (Android Parity)
    private static let RETRY_DELAY_SECONDS: TimeInterval = 30.0 // 30 seconds like current implementation
    private var retryTimer: Timer?
    private var retryCount = 0
    private var isRetryingForUserId: String? = nil
    
    // MARK: - Initialization
    
    private init() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() Constructor called")
    }
    
    // MARK: - Initialization Methods
    
    /// Initialize the billing helper primarily from the Application context.
    /// This establishes the connection and allows querying purchases early.
    func initializeForApplication(database: Firestore, sessionManager: SessionManager) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeForApplication() called")
        
        if billingHelper == nil {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeForApplication() Creating new SubscriptionBillingHelper (from Application)")
            
            billingHelper = SubscriptionBillingHelper(
                viewController: nil,
                database: database,
                sessionManager: sessionManager,
                autoConnect: false
            )
            isInitialized = true
            
            // Ensure listeners registered with the manager are added to the helper
            for listener in listeners {
                billingHelper?.addBillingCallback(listener)
            }
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeForApplication() BillingHelper already exists")
        }
    }
    
    /// Updates the billing helper with the current view controller context when a ViewController is available.
    /// This is necessary for launching purchase flows.
    func initializeWithViewController(_ viewController: UIViewController, database: Firestore, sessionManager: SessionManager) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeWithViewController() called for ViewController: \(type(of: viewController))")
        
        if billingHelper == nil {
            // If helper wasn't created in Application, create it now.
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeWithViewController() Creating new SubscriptionBillingHelper (from ViewController)")
            
            billingHelper = SubscriptionBillingHelper(
                viewController: viewController,
                database: database,
                sessionManager: sessionManager,
                autoConnect: false
            )
            isInitialized = true
        } else {
            // Update the existing helper with the ViewController context
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "initializeWithViewController() Updating existing SubscriptionBillingHelper with ViewController")
            billingHelper?.setViewController(viewController)
        }
        
        // Ensure listeners registered with the manager are added to the helper
        for listener in listeners {
            billingHelper?.addBillingCallback(listener)
        }
    }
    
    /// Legacy initialize method for backward compatibility
    @available(*, deprecated, message: "Use initializeWithViewController instead")
    func initialize(viewController: UIViewController, database: Firestore, sessionManager: SessionManager) {
        initializeWithViewController(viewController, database: database, sessionManager: sessionManager)
    }
    
    // MARK: - Access Methods
    
    func getBillingHelper() -> SubscriptionBillingHelper? {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getBillingHelper() called")
        return billingHelper
    }
    
    // MARK: - Connection Management
    
    func connectToBillingService(maxRetries: Int) async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() called with maxRetries=\(maxRetries)")
        
        if let billingHelper = billingHelper {
            await billingHelper.connectToBillingService(maxRetries: maxRetries)
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() billingHelper is nil")
        }
    }
    
    func isConnected() -> Bool {
        let connected = billingHelper?.isConnected ?? false
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "isConnected() called, returning: \(connected)")
        return connected
    }
    
    // MARK: - Listener Management
    
    func registerListener(_ listener: BillingCallbacks) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "registerListener() called")
        
        if !listeners.contains(where: { $0 === listener }) {
            listeners.append(listener)
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "registerListener() Listener added")
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "registerListener() Listener already registered")
        }
        
        if let billingHelper = billingHelper {
            billingHelper.addBillingCallback(listener)
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "registerListener() Listener added in billingHelper")
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "registerListener() billingHelper is nil")
        }
    }
    
    func unregisterListener(_ listener: BillingCallbacks) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "unregisterListener() called")
        
        listeners.removeAll { $0 === listener }
        
        if let billingHelper = billingHelper {
            billingHelper.removeBillingCallback(listener)
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "unregisterListener() Listener removed from billingHelper")
        }
    }
    
    // MARK: - Purchase Management
    
    func launchNewSubscription(productId: String, selectedPlan: String) async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() called for productId: \(productId), selectedPlan: \(selectedPlan)")
        
        guard let billingHelper = billingHelper else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() billingHelper is nil")
            return
        }
        
        await billingHelper.launchNewSubscription(productId: productId, selectedPlan: selectedPlan)
    }
    
    func launchReplaceSubscription(oldPurchaseToken: String, 
                                   currentProductId: String, 
                                   currentTierLevel: Int, 
                                   productId: String, 
                                   newTierLevel: Int, 
                                   selectedPlan: String) async {
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() called for productId: \(productId)")
        
        guard let billingHelper = billingHelper else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() billingHelper is nil")
            return
        }
        
        await billingHelper.launchReplaceSubscription(
            oldPurchaseToken: oldPurchaseToken,
            currentProductId: currentProductId,
            currentTierLevel: currentTierLevel,
            productId: productId,
            newTierLevel: newTierLevel,
            selectedPlan: selectedPlan
        )
    }
    
    // MARK: - Product Management
    
    func queryProductDetails() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() called")
        
        guard let billingHelper = billingHelper else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() billingHelper is nil")
            return
        }
        
        await billingHelper.queryProductDetails()
    }
    
    func queryExistingPurchases() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() called")
        
        guard let billingHelper = billingHelper else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() billingHelper is nil")
            return
        }
        
        await billingHelper.queryExistingPurchases()
    }
    
    // MARK: - State Management
    
    var products: [Product] {
        return billingHelper?.products ?? []
    }
    
    // MARK: - Premium Details Management (from FirebaseServices)
    
    /// Checks premium details from Firebase - equivalent to FirebaseServices.checkPremiumDetailsFromFirebase()
    func checkPremiumDetailsFromFirebase() {
        guard let userId = SessionManager.shared.userId, !userId.isEmpty else {
            // Android parity: Continuous retry until user is authenticated
            if isRetryingForUserId == nil {
                retryCount += 1
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumDetailsFromFirebase() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
                isRetryingForUserId = nil // Mark that we're retrying for null user
                scheduleContinuousRetry()
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumDetailsFromFirebase() already retrying for user authentication")
            }
            return
        }
        
        // User authenticated successfully - stop any retry timers and proceed
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = userId
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumDetailsFromFirebase() checking premium details for user: \(userId)")
        
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Premium")
            .document("Premium")
            .getDocument { documentSnapshot, error in
                
                guard let document = documentSnapshot else {
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumDetailsFromFirebase() Document does not exist or an error occurred.")
                    return
                }
                
                guard let data = document.data() else {
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumDetailsFromFirebase() Document data is empty.")
                    return
                }
                
                if let premiumActive = data["premium_active"] as? Bool,
                   let premiumSubscription = data["premium_subscription"] as? Bool,
                   let premiumTime = data["premium_time"] as? Int {
                    
                    self.setPremiumDetailsInUserDefaults(premium_time: premiumTime, premium_subscription: premiumSubscription, premium_active: premiumActive)
                    
                    if premiumActive {
                        if premiumSubscription {
                            if (premiumTime + 604800) < (Int(Date().timeIntervalSince1970)) {
                                self.checkPremiumSubscriptionWithApple()
                            }
                        } else {
                            if (premiumTime + 604800) < (Int(Date().timeIntervalSince1970)) {
                                self.setPremiumDetailsInFirebase(premium_time: 0, premium_subscription: false, premium_active: false)
                            }
                        }
                    }
                } else {
                    self.setPremiumDetailsInUserDefaults(premium_time: 0, premium_subscription: false, premium_active: false)
                }
            }
    }
    
    /// Checks premium subscription with Apple - equivalent to FirebaseServices.checkPremiumSubscriptionWithApple()
    func checkPremiumSubscriptionWithApple() {
        guard let userId = SessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() no user ID available")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() checking Apple subscription status")
        
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let receiptString = receiptData.base64EncodedString(options: [])
                
                if receiptString == "ChatHub.Premium.1Week" {
                    let param: [String: Any] = [
                        "premium_time": Int(Int64(Date().timeIntervalSince1970)),
                        "premium_subscription": true,
                        "premium_active": true
                    ]
                    
                    Firestore.firestore().collection("Users").document(userId).setData(param, merge: true)
                    
                    // Update UserDefaults for premium features (migrated from Core Data)
                    let earlyDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
                    let sessionManager = SessionManager.shared
                    
                    // Update NoAds date (replaces NoAds Core Data entity)
                    sessionManager.defaults.set(earlyDate, forKey: "noads_date")
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() Updated noads_date to: \(earlyDate)")
                    
                    // Update CallTime (replaces CallTime Core Data entity)
                    sessionManager.defaults.set(15000, forKey: "call_time")
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() Updated call_time to: 15000")
                    
                    // Update Live time (replaces DirectVideo Core Data entity) - FIXED: Use correct SessionManager key
                    sessionManager.liveSeconds = 15000
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() Updated liveSeconds to: 15000")
                } else {
                    let param: [String: Bool] = [
                        "premium_subscription": false,
                        "premium_active": false
                    ]
                    Firestore.firestore().collection("Users").document(userId).setData(param, merge: true)
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkPremiumSubscriptionWithApple() Couldn't read receipt data with error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sets premium details in Firebase - equivalent to FirebaseServices.setPremiumDetailsInFirebase()
    func setPremiumDetailsInFirebase(premium_time: Int, premium_subscription: Bool, premium_active: Bool) {
        guard let userId = SessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setPremiumDetailsInFirebase() no user ID available")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setPremiumDetailsInFirebase() updating premium details in Firebase")
        
        let param: [String: Any] = [
            "premium_time": premium_time / 1000,
            "premium_subscription": premium_subscription,
            "premium_active": premium_active
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Premium")
            .document("Premium")
            .setData(param, merge: true)
        
        setPremiumDetailsInUserDefaults(premium_time: premium_time, premium_subscription: premium_subscription, premium_active: premium_active)
    }
    
    /// Sets premium details in UserDefaults - equivalent to FirebaseServices.setPremiumDetailsInUserDefaults()
    func setPremiumDetailsInUserDefaults(premium_time: Int, premium_subscription: Bool, premium_active: Bool) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setPremiumDetailsInUserDefaults() updating premium details in UserDefaults")
        
        SessionManager.shared.premiumActive = premium_active
        
        // Migrated to SubscriptionSessionManager for proper separation of concerns
        // Using comprehensive subscription update to maintain compatibility
        SubscriptionSessionManager.shared.updateFromSubscriptionState(
            isActive: premium_subscription,
            tier: premium_active ? "premium" : "none",
            period: "unknown",
            status: premium_subscription ? "active" : "inactive",
            startTimeMillis: Int64(premium_time),
            expiryTimeMillis: nil,
            willAutoRenew: false,
            productId: "legacy_premium",
            purchaseToken: nil,
            basePlanId: nil
        )
    }
    
    // MARK: - Continuous Retry Methods (Android Parity)
    
    /// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
    private func scheduleContinuousRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
            Task { @MainActor in
                self.checkPremiumDetailsFromFirebase() // CONTINUOUS RETRY - calls itself again until user is authenticated
            }
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "cleanup() called")
        
        // Stop continuous retry mechanism
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = nil
        
        billingHelper?.cleanup()
        billingHelper = nil
        listeners.removeAll()
        isInitialized = false
    }
} 
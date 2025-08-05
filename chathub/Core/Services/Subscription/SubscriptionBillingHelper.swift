import Foundation
import StoreKit
import FirebaseFirestore
import FirebaseCrashlytics

/**
 * Helper class to manage App Store billing operations using StoreKit 2
 * iOS equivalent of Android's SubscriptionBillingHelper
 */
@MainActor
class SubscriptionBillingHelper: ObservableObject {
    
    // MARK: - Properties
    
    private static let TAG = "SubscriptionBillingHelper"
    
    // Callback listeners
    private var billingCallbacks: [BillingCallbacks] = []
    
    // Context and dependencies
    private weak var viewController: UIViewController?
    private let database: Firestore
    private let sessionManager: SessionManager
    private let subscriptionSessionManager: SubscriptionSessionManager
    
    // Product management
    @Published var products: [Product] = []
    private var productDetailsMap: [String: Product] = [:]
    private var pendingProductDetails: [String: Product]?
    
    // Connection state
    @Published var isConnected = false
    private var isInitialized = false
    
    // Transaction monitoring
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Initialization
    
    init(viewController: UIViewController? = nil, 
         database: Firestore, 
         sessionManager: SessionManager, 
         autoConnect: Bool = true) {
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() SubscriptionBillingHelper constructor entered")
        
        self.viewController = viewController
        self.database = database
        self.sessionManager = sessionManager
        self.subscriptionSessionManager = SubscriptionSessionManager.shared
        
        if autoConnect {
            Task {
                await connectToBillingService(maxRetries: 5)
            }
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() SubscriptionBillingHelper constructor finished successfully")
    }
    
    deinit {
        // Minimal cleanup to prevent retain cycles - cancel the transaction listener
        // Other cleanup will happen when the object is deallocated
        transactionListener?.cancel()
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "deinit() SubscriptionBillingHelper deallocated successfully")
    }
    
    // MARK: - Connection Management
    
    func connectToBillingService(maxRetries: Int) async {
        guard maxRetries > 0 else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() Failed to connect to billing service after multiple attempts")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() Attempting to start billing connection...")
        
        do {
            await queryProductDetails()
            await queryExistingPurchases()
            startTransactionListener()
            
            isConnected = true
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() Billing client setup finished successfully")
            
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "connectToBillingService() Billing client setup failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            isConnected = false
            
            // Retry with exponential backoff
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await connectToBillingService(maxRetries: maxRetries - 1)
        }
    }
    
    // MARK: - Product Details Management
    
    func queryProductDetails() async {
        guard isConnected || !isInitialized else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() Billing client not connected")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() Querying product details...")
        
        do {
            let products = try await Product.products(for: SubscriptionConstants.allProductIDs)
            
            self.products = products
            self.productDetailsMap.removeAll()
            
            for product in products {
                productDetailsMap[product.id] = product
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() Fetched Product Detail: ID=\(product.id), Name=\(product.displayName), Type=\(product.type)")
                
                // Cache pricing information (Android parity)
                if let subscription = product.subscription {
                    let basePlanId = SubscriptionConstants.getBasePlanId(productId: product.id, period: getPeriodFromSubscription(subscription))
                    let period = SubscriptionConstants.getPeriodForPriceCachingFromBasePlanId(basePlanId)
                    
                    if let period = period {
                        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() Caching price for period: \(period), price: \(product.displayPrice)")
                        // Cache price logic can be added here if needed
                    }
                }
            }
            
            // Notify callbacks
            let productMap = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            notifyProductDetailsReady(productMap)
            
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryProductDetails() Failed to fetch products: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
        }
    }
    
    // MARK: - Purchase Management
    
    func launchNewSubscription(productId: String, selectedPlan: String) async {
        guard let viewController = viewController else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() View controller context is null. Cannot launch flow.")
            return
        }
        
        guard isConnected else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() Billing client not ready for launching subscription")
            return
        }
        
        guard let product = productDetailsMap[productId] else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() Product not found for: \(productId)")
            return
        }
        
        // Get the current userId to set as appAccountToken (Android parity: obfuscatedProfileId)
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() Warning: User ID is empty, cannot set appAccountToken")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() Launching billing flow for new subscription. ProductId: \(productId), BasePlanId: \(selectedPlan), UserId: \(userId)")
        
        do {
            let result = try await product.purchase(options: [.appAccountToken(UUID(uuidString: userId) ?? UUID())])
            await handlePurchaseResult(result)
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchNewSubscription() Purchase failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
        }
    }
    
    func launchReplaceSubscription(oldPurchaseToken: String, 
                                   currentProductId: String, 
                                   currentTierLevel: Int, 
                                   productId: String, 
                                   newTierLevel: Int, 
                                   selectedPlan: String) async {
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Starting replace subscription flow")
        
        guard let product = productDetailsMap[productId] else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Product not found for: \(productId)")
            return
        }
        
        // Determine replacement mode (Android parity)
        let isUpgrade = newTierLevel > currentTierLevel
        let isSameTier = currentProductId == productId
        
        if isSameTier {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Same-tier change detected")
        } else if isUpgrade {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Upgrade detected")
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Downgrade detected")
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Launching replace subscription flow. New ProductId: \(productId), BasePlanId: \(selectedPlan)")
        
        do {
            // For iOS, we don't have the same replacement modes as Android
            // The system handles upgrades/downgrades automatically
            let result = try await product.purchase()
            await handlePurchaseResult(result)
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "launchReplaceSubscription() Replace subscription failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
        }
    }
    
    // MARK: - Purchase Handling
    
    private func handlePurchaseResult(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(let verification):
            await handleSuccessfulPurchase(verification)
        case .userCancelled:
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handlePurchaseResult() User cancelled purchase")
        case .pending:
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handlePurchaseResult() Purchase is pending")
        @unknown default:
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handlePurchaseResult() Unknown purchase result")
        }
    }
    
    private func handleSuccessfulPurchase(_ verification: VerificationResult<StoreKit.Transaction>) async {
        switch verification {
        case .verified(let transaction):
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() Processing verified purchase")
            await processPurchase(transaction)
            await transaction.finish()
        case .unverified(let transaction, let error):
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() Unverified transaction: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            await transaction.finish()
        }
    }
    
    private func processPurchase(_ transaction: StoreKit.Transaction) async {
        guard let userId = sessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processPurchase() No userId available, cannot process purchase")
            return
        }
        
        let productId = transaction.productID
        let tier = SubscriptionConstants.getTierFromProductId(productId)
        let period = getPeriodFromTransaction(transaction)
        let purchaseTime = Int64(transaction.purchaseDate.timeIntervalSince1970 * 1000)
        let transactionId = String(transaction.id)
        
        // Calculate expiry time based on period
        let expiryTime = calculateExpiryTime(purchaseTime: purchaseTime, period: period)
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processPurchase() Purchase details - tier: \(tier), period: \(period), purchaseTime: \(purchaseTime)")
        
        // Update the session manager first (local cache)
        subscriptionSessionManager.updateFromSubscriptionState(
            isActive: true,
            tier: tier,
            period: period,
            status: SubscriptionConstants.STATUS_ACTIVE,
            startTimeMillis: purchaseTime,
            expiryTimeMillis: expiryTime,
            willAutoRenew: true,
            productId: productId,
            purchaseToken: transactionId,
            basePlanId: SubscriptionConstants.getBasePlanId(productId: productId, period: period)
        )
        
        // Also update main session manager for backwards compatibility
        sessionManager.premiumActive = true
        sessionManager.synchronize()
        
        // Update Firestore via the repository with queue integration (Android parity)
        SubscriptionRepository.shared.saveFullSubscriptionState(
            userId: userId,
            isActive: true,
            status: SubscriptionConstants.STATUS_ACTIVE,
            tier: tier,
            period: period,
            basePlanId: SubscriptionConstants.getBasePlanId(productId: productId, period: period),
            purchaseTime: purchaseTime,
            startTimeMillis: purchaseTime,
            expiryTimeMillis: expiryTime,
            willAutoRenew: true,
            purchaseToken: transactionId,
            productId: productId,
            orderId: transactionId,
            isNewPurchase: true
        )
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "processPurchase() Purchase processing completed successfully")
    }
    
    // MARK: - Existing Purchases Query
    
    func queryExistingPurchases() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() Querying existing purchases...")
        
        var foundActiveSubscription = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productType == .autoRenewable {
                    foundActiveSubscription = true
                    await handleExistingSubscription(transaction)
                }
            case .unverified(let transaction, let error):
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() Unverified transaction: \(error.localizedDescription)")
            }
        }
        
        if foundActiveSubscription {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() Found active subscription")
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryExistingPurchases() No active subscription found")
            notifyNoSubscriptionFound()
            enqueueInactiveStateUpdate()
        }
    }
    
    private func handleExistingSubscription(_ transaction: StoreKit.Transaction) async {
        let productId = transaction.productID
        let tier = SubscriptionConstants.getTierFromProductId(productId)
        let period = getPeriodFromTransaction(transaction)
        
        if let product = productDetailsMap[productId] {
            notifySubscriptionFound(
                transaction: transaction,
                product: product,
                subscriptionTier: tier,
                subscriptionPeriod: period
            )
        }
    }
    
    // MARK: - Transaction Listener
    
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            await processPurchase(transaction)
            await transaction.finish()
        case .unverified(let transaction, let error):
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleTransactionUpdate() Unverified transaction update: \(error.localizedDescription)")
            await transaction.finish()
        }
    }
    
    // MARK: - Callback Management
    
    func addBillingCallback(_ callback: BillingCallbacks) {
        if !billingCallbacks.contains(where: { $0 === callback }) {
            billingCallbacks.append(callback)
            
            // If we have pending product details, notify immediately
            if let pendingProductDetails = pendingProductDetails {
                callback.onProductDetailsReady(pendingProductDetails)
                self.pendingProductDetails = nil
            }
        }
    }
    
    func removeBillingCallback(_ callback: BillingCallbacks) {
        billingCallbacks.removeAll { $0 === callback }
    }
    
    // MARK: - Callback Notifications
    
    private func notifyProductDetailsReady(_ productDetailsMap: [String: Product]) {
        for callback in billingCallbacks {
            callback.onProductDetailsReady(productDetailsMap)
        }
        
        // Store for future callbacks
        pendingProductDetails = productDetailsMap
    }
    
    private func notifyNoSubscriptionFound() {
        for callback in billingCallbacks {
            callback.onNoSubscriptionFound()
        }
    }
    
    private func notifySubscriptionFound(transaction: StoreKit.Transaction, product: Product, subscriptionTier: String, subscriptionPeriod: String) {
        for callback in billingCallbacks {
            callback.onSubscriptionFound(
                transaction: transaction,
                product: product,
                subscriptionTier: subscriptionTier,
                subscriptionPeriod: subscriptionPeriod
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPeriodFromTransaction(_ transaction: StoreKit.Transaction) -> String {
        // For iOS, we need to determine period from product ID or subscription info
        let productId = transaction.productID
        return getPeriodFromProductId(productId)
    }
    
    private func getPeriodFromSubscription(_ subscription: Product.SubscriptionInfo) -> String {
        // Determine period from subscription period
        switch subscription.subscriptionPeriod.unit {
        case .day:
            if subscription.subscriptionPeriod.value == 7 {
                return SubscriptionConstants.PERIOD_WEEKLY
            }
        case .week:
            return SubscriptionConstants.PERIOD_WEEKLY
        case .month:
            return SubscriptionConstants.PERIOD_MONTHLY
        case .year:
            return SubscriptionConstants.PERIOD_YEARLY
        @unknown default:
            return SubscriptionConstants.PERIOD_MONTHLY
        }
        
        // Default fallback
        return SubscriptionConstants.PERIOD_MONTHLY
    }
    
    private func getPeriodFromProductId(_ productId: String) -> String {
        // This is a simplified approach - in a real implementation,
        // you might want to store this mapping or derive it from the product configuration
        if productId.lowercased().contains("weekly") {
            return SubscriptionConstants.PERIOD_WEEKLY
        } else if productId.lowercased().contains("yearly") {
            return SubscriptionConstants.PERIOD_YEARLY
        } else {
            return SubscriptionConstants.PERIOD_MONTHLY
        }
    }
    
    private func calculateExpiryTime(purchaseTime: Int64, period: String) -> Int64 {
        let purchaseTimeSeconds = purchaseTime / 1000
        let calendar = Calendar.current
        let purchaseDate = Date(timeIntervalSince1970: TimeInterval(purchaseTimeSeconds))
        
        var expiryDate: Date
        
        switch period.lowercased() {
        case SubscriptionConstants.PERIOD_WEEKLY:
            expiryDate = calendar.date(byAdding: .weekOfYear, value: 1, to: purchaseDate) ?? purchaseDate
        case SubscriptionConstants.PERIOD_MONTHLY:
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        case SubscriptionConstants.PERIOD_YEARLY:
            expiryDate = calendar.date(byAdding: .year, value: 1, to: purchaseDate) ?? purchaseDate
        default:
            // Default to 1 month for unknown periods
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        }
        
        return Int64(expiryDate.timeIntervalSince1970 * 1000)
    }
    
    // MARK: - Inactive State Management
    
    private func enqueueInactiveStateUpdate() {
        guard let userId = sessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "enqueueInactiveStateUpdate() No userId available")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "enqueueInactiveStateUpdate() Enqueuing inactive state update for userId: \(userId)")
        
        // Update local session first
        subscriptionSessionManager.updateFromSubscriptionState(
            isActive: false,
            tier: SubscriptionConstants.TIER_NONE,
            period: SubscriptionConstants.PERIOD_MONTHLY,
            status: SubscriptionConstants.STATUS_INACTIVE,
            startTimeMillis: 0,
            expiryTimeMillis: 0,
            willAutoRenew: false,
            productId: "",
            purchaseToken: nil,
            basePlanId: nil
        )
        
        sessionManager.premiumActive = false
        sessionManager.synchronize()
        
        // Update Firestore
        SubscriptionRepository.shared.saveFullSubscriptionState(
            userId: userId,
            isActive: false,
            status: SubscriptionConstants.STATUS_INACTIVE,
            tier: SubscriptionConstants.TIER_NONE,
            period: SubscriptionConstants.PERIOD_MONTHLY,
            basePlanId: nil,
            purchaseTime: 0,
            startTimeMillis: 0,
            expiryTimeMillis: 0,
            willAutoRenew: false,
            purchaseToken: nil,
            productId: "",
            orderId: nil,
            isNewPurchase: false
        )
    }
    
    // MARK: - Context Management
    
    func setViewController(_ viewController: UIViewController?) {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "setViewController() called with ViewController: \(viewController?.description ?? "nil")")
        self.viewController = viewController
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        transactionListener?.cancel()
        transactionListener = nil
        billingCallbacks.removeAll()
        isConnected = false
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "cleanup() SubscriptionBillingHelper cleaned up")
    }
}

// MARK: - BillingCallbacks Protocol

protocol BillingCallbacks: AnyObject {
    func onProductDetailsReady(_ productDetailsMap: [String: Product])
    func onNoSubscriptionFound()
    func onSubscriptionFound(transaction: StoreKit.Transaction, product: Product, subscriptionTier: String, subscriptionPeriod: String)
    func onPendingPurchaseFound(transaction: StoreKit.Transaction)
} 
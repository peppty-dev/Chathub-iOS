import Foundation
import StoreKit
import CryptoKit
import FirebaseFirestore

/**
 * Comprehensive StoreKit manager for handling subscription purchases
 * iOS equivalent of Android's Google Play Billing with full parity
 */
@MainActor
class SubscriptionsManagerStoreKit2: ObservableObject {
    
    // MARK: - Properties
    
    private static let TAG = "SubscriptionsManagerStoreKit2"
    static let shared = SubscriptionsManagerStoreKit2()
    
    // Product management
    @Published var products: [Product] = []
    @Published var loadedTransactions: [StoreKit.Transaction] = []
    
    // State management
    @Published var isLoading = false
    @Published var purchaseState: PurchaseState = .idle
    
    // Product details map for quick access (Android parity)
    private var productDetailsMap: [String: Product] = [:]
    private var priceCache: [String: ProductPrice] = [:]
    private var lastPriceCacheUpdate: Date?
    
    // Transaction listener
    private var transactionListener: Task<Void, Error>?
    
    // Dependencies
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    private let subscriptionRepository = SubscriptionRepository.shared
    private let sessionManager = SessionManager.shared
    
    // Product IDs (matching Android structure with Apple's recommended period format)
    private let productIDs: Set<String> = [
        "com.peppty.ChatApp.lite.weekly",
        "com.peppty.ChatApp.lite.monthly", 
        "com.peppty.ChatApp.lite.yearly",
        "com.peppty.ChatApp.plus.weekly",
        "com.peppty.ChatApp.plus.monthly",
        "com.peppty.ChatApp.plus.yearly",
        "com.peppty.ChatApp.pro.weekly",
        "com.peppty.ChatApp.pro.monthly",
        "com.peppty.ChatApp.pro.yearly"
    ]
    
    // MARK: - Purchase State
    
    enum PurchaseState {
        case idle
        case loading
        case purchasing
        case success
        case failed(Error)
        case cancelled
    }
    
    // MARK: - Product Price Structure
    
    struct ProductPrice {
        let formattedPrice: String
        let priceValue: Decimal
        let currencyCode: String
        let period: String
        let tier: String
        let savingsPercent: Double
        
        init(product: Product, period: String, tier: String, savingsPercent: Double = 0.0) {
            // Custom price formatting to remove space between currency symbol and amount
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = product.priceFormatStyle.currencyCode
            formatter.locale = product.priceFormatStyle.locale
            
            // Remove unnecessary decimal places for whole numbers (e.g., $3.00 becomes $3)
            let priceValue = product.price as NSDecimalNumber
            if priceValue.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                // Whole number - no decimal places needed
                formatter.maximumFractionDigits = 0
                formatter.minimumFractionDigits = 0
            } else {
                // Has decimal places - show them
                formatter.maximumFractionDigits = 2
                formatter.minimumFractionDigits = 2
            }
            
            // Format the price and remove any spaces between currency symbol and amount
            let defaultFormattedPrice = formatter.string(from: priceValue) ?? product.displayPrice
            self.formattedPrice = defaultFormattedPrice.replacingOccurrences(of: " ", with: "")
            
            self.priceValue = product.price
            self.currencyCode = product.priceFormatStyle.currencyCode
            self.period = period
            self.tier = tier
            self.savingsPercent = savingsPercent
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init() SubscriptionsManagerStoreKit2 initialized")
        startTransactionListener()
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading (Android Parity)
    
    func loadProducts() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadProducts() Starting product load")
        
        isLoading = true
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts
                self.productDetailsMap.removeAll()
                
                // Build product details map for quick access (Android parity)
                for product in storeProducts {
                    self.productDetailsMap[product.id] = product
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadProducts() Product loaded: \(product.id) - \(product.displayPrice)")
                }
                
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadProducts() Loaded \(storeProducts.count) products")
                
                // Cache prices immediately after loading
                self.updatePriceCache()
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "loadProducts() Failed to load products: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Price Management (Android Parity)
    
    private func updatePriceCache() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updatePriceCache() Updating price cache and saving to SubscriptionSessionManager")
        
        priceCache.removeAll()
        
        // Group products by tier for savings calculation
        var tierProducts: [String: [Product]] = [:]
        
        for product in products {
            let (tier, period) = parseProductId(product.id)
            if !tierProducts.keys.contains(tier) {
                tierProducts[tier] = []
            }
            tierProducts[tier]?.append(product)
        }
        
        // Calculate savings and cache prices
        for (tier, tierProductList) in tierProducts {
            let savings = calculateSavings(for: tierProductList)
            
            for product in tierProductList {
                let (_, period) = parseProductId(product.id)
                let savingsPercent = savings[period] ?? 0.0
                
                let productPrice = ProductPrice(
                    product: product,
                    period: period,
                    tier: tier,
                    savingsPercent: savingsPercent
                )
                
                priceCache[product.id] = productPrice
                
                // Android parity: Save to SubscriptionSessionManager for popup usage
                let priceInMicros = Int64(Double(truncating: product.price as NSNumber) * 1_000_000)
                subscriptionSessionManager.setSubscriptionPrice(
                    product.id,
                    period: period,
                    formattedPrice: productPrice.formattedPrice,
                    priceInMicros: priceInMicros
                )
                
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "updatePriceCache() Cached price for \(product.id): \(productPrice.formattedPrice) (Save: \(Int(savingsPercent))%) - Saved to SubscriptionSessionManager")
            }
        }
        
        // Android parity: Update price cache timestamp in SubscriptionSessionManager
        subscriptionSessionManager.updatePriceCacheTimestamp()
        
        lastPriceCacheUpdate = Date()
    }
    
    private func calculateSavings(for products: [Product]) -> [String: Double] {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() Starting savings calculation for tier products")
        
        var savings: [String: Double] = [:]
        
        // Find weekly price as baseline (Android parity)
        guard let weeklyProduct = products.first(where: { parseProductId($0.id).1 == "weekly" }) else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() No weekly product found for savings calculation")
            return savings
        }
        
        let weeklyPriceValue = Double(truncating: weeklyProduct.price as NSNumber)
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() Weekly price baseline: \(weeklyPriceValue)")
        
        for product in products {
            let (tier, period) = parseProductId(product.id)
            let actualPrice = Double(truncating: product.price as NSNumber)
            
            var savingsPercent: Double = 0.0
            
            switch period {
            case "monthly":
                // Monthly savings = ((weekly * 4) - monthly) / (weekly * 4) * 100 (Android parity)
                if weeklyPriceValue > 0 {
                    let expectedMonthlyPrice = weeklyPriceValue * 4
                    if expectedMonthlyPrice > actualPrice {
                        savingsPercent = ((expectedMonthlyPrice - actualPrice) / expectedMonthlyPrice) * 100
                    }
                }
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() \(tier) Monthly - Expected: \(weeklyPriceValue * 4), Actual: \(actualPrice), Savings: \(savingsPercent)%")
                
            case "yearly":
                // Yearly savings = ((weekly * 52) - yearly) / (weekly * 52) * 100 (Android parity)
                if weeklyPriceValue > 0 {
                    let expectedYearlyPrice = weeklyPriceValue * 52
                    if expectedYearlyPrice > actualPrice {
                        savingsPercent = ((expectedYearlyPrice - actualPrice) / expectedYearlyPrice) * 100
                    }
                }
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() \(tier) Yearly - Expected: \(weeklyPriceValue * 52), Actual: \(actualPrice), Savings: \(savingsPercent)%")
                
            case "weekly":
                // Weekly has no savings vs itself (Android parity)
                savingsPercent = 0.0
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() \(tier) Weekly savings: 0% (baseline)")
                
            default:
                savingsPercent = 0.0
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() \(tier) Unknown period '\(period)' - no savings")
            }
            
            savings[period] = savingsPercent
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateSavings() Final savings calculation: \(savings)")
        return savings
    }
    
    func getProductPrice(for productId: String) -> ProductPrice? {
        return priceCache[productId]
    }
    
    func getProduct(for productId: String) -> Product? {
        return productDetailsMap[productId]
    }
    
    // MARK: - Cached Price Retrieval (Android Parity)
    
    /// Retrieves cached price from SubscriptionSessionManager (Android parity)
    /// This is useful for popups and other UI components that need pricing without loading products
    func getCachedFormattedPrice(productId: String, period: String) -> String? {
        let cachedPrice = subscriptionSessionManager.getSubscriptionPrice(productId, period: period)
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getCachedFormattedPrice() Retrieved cached price for \(productId) (\(period)): \(cachedPrice ?? "nil")")
        return cachedPrice
    }
    
    /// Retrieves cached price in micros from SubscriptionSessionManager (Android parity)
    func getCachedPriceMicros(productId: String, period: String) -> Int64 {
        let cachedPriceMicros = subscriptionSessionManager.getSubscriptionPriceMicros(productId, period: period)
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getCachedPriceMicros() Retrieved cached price micros for \(productId) (\(period)): \(cachedPriceMicros)")
        return cachedPriceMicros
    }
    
    /// Checks if cached prices are available for a product (Android parity)
    func hasCachedPrice(productId: String, period: String) -> Bool {
        let hasPrice = subscriptionSessionManager.getSubscriptionPrice(productId, period: period) != nil
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "hasCachedPrice() Checking cached price for \(productId) (\(period)): \(hasPrice)")
        return hasPrice
    }
    
    /// Retrieves all cached prices for a product across all periods (Android parity)
    func getAllCachedPricesForProduct(productId: String) -> [String: String] {
        let periods = ["weekly", "monthly", "yearly"]
        var prices: [String: String] = [:]
        
        for period in periods {
            if let price = subscriptionSessionManager.getSubscriptionPrice(productId, period: period) {
                prices[period] = price
            }
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "getAllCachedPricesForProduct() Retrieved cached prices for \(productId): \(prices)")
        return prices
    }
    
    /// Calculates savings percentage from cached prices (Android parity)
    /// This method can be used by popups to show savings without loading full product details
    func calculateCachedSavingsPercent(productId: String, period: String) -> Double {
        let weeklyPriceMicros = subscriptionSessionManager.getSubscriptionPriceMicros(productId, period: "weekly")
        let periodPriceMicros = subscriptionSessionManager.getSubscriptionPriceMicros(productId, period: period)
        
        guard weeklyPriceMicros > 0 && periodPriceMicros > 0 else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateCachedSavingsPercent() No cached prices available for \(productId)")
            return 0.0
        }
        
        let weeklyPriceValue = Double(weeklyPriceMicros) / 1_000_000.0
        let periodPriceValue = Double(periodPriceMicros) / 1_000_000.0
        
        var savingsPercent: Double = 0.0
        
        switch period {
        case "monthly":
            let expectedMonthlyPrice = weeklyPriceValue * 4
            if expectedMonthlyPrice > periodPriceValue {
                savingsPercent = ((expectedMonthlyPrice - periodPriceValue) / expectedMonthlyPrice) * 100
            }
        case "yearly":
            let expectedYearlyPrice = weeklyPriceValue * 52
            if expectedYearlyPrice > periodPriceValue {
                savingsPercent = ((expectedYearlyPrice - periodPriceValue) / expectedYearlyPrice) * 100
            }
        default:
            savingsPercent = 0.0
        }
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "calculateCachedSavingsPercent() \(productId) \(period): \(savingsPercent)%")
        return savingsPercent
    }
    
    /// Formats cached price with savings for display in popups (Android parity)
    func getCachedPriceDisplayText(productId: String, period: String) -> String {
        guard let formattedPrice = getCachedFormattedPrice(productId: productId, period: period) else {
            return "N/A"
        }
        
        let savingsPercent = calculateCachedSavingsPercent(productId: productId, period: period)
        let periodTitle = period.capitalized
        
        if savingsPercent > 1 {
            return "\(periodTitle) - \(formattedPrice) - 🔥 Save \(Int(savingsPercent))%"
        } else {
            return "\(periodTitle) - \(formattedPrice)"
        }
    }
    
    // MARK: - Purchase Flow (Android Parity)
    
    func purchaseProduct(productId: String) async -> Bool {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Starting purchase for: \(productId)")
        
        guard let product = productDetailsMap[productId] else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Product not found: \(productId)")
            await MainActor.run {
                self.purchaseState = .failed(StoreKitError.productNotFound)
            }
            return false
        }
        
        await MainActor.run {
            self.purchaseState = .purchasing
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Purchase successful for: \(productId)")
                
                let transaction = try checkVerified(verification)
                await handleSuccessfulPurchase(transaction: transaction, product: product)
                
                await MainActor.run {
                    self.purchaseState = .success
                }
                return true
                
            case .userCancelled:
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Purchase cancelled by user")
                await MainActor.run {
                    self.purchaseState = .cancelled
                }
                return false
                
            case .pending:
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Purchase pending approval")
                await MainActor.run {
                    self.purchaseState = .loading
                }
                return false
                
            @unknown default:
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Unknown purchase result")
                await MainActor.run {
                    self.purchaseState = .failed(StoreKitError.unknownError)
                }
                return false
            }
            
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "purchaseProduct() Purchase failed: \(error.localizedDescription)")
            await MainActor.run {
                self.purchaseState = .failed(error)
            }
            return false
        }
    }
    
    // MARK: - Transaction Handling
    
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleTransactionUpdate() Processing transaction update")
        
        do {
            let transaction = try checkVerified(result)
            
            if let product = productDetailsMap[transaction.productID] {
                await handleSuccessfulPurchase(transaction: transaction, product: product)
            }
            
            await transaction.finish()
            
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleTransactionUpdate() Failed to verify transaction: \(error.localizedDescription)")
        }
    }
    
    private func handleSuccessfulPurchase(transaction: StoreKit.Transaction, product: Product) async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() Processing successful purchase for: \(product.id)")
        
        let (tier, period) = parseProductId(product.id)
        
        guard let userId = sessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() No userId available")
            return
        }
        
        let purchaseTime = Int64(transaction.purchaseDate.timeIntervalSince1970 * 1000)
        let expiryTime = calculateExpiryTime(purchaseTime: purchaseTime, period: period)
        
        // Update local session managers (Android parity)
        await MainActor.run {
            subscriptionSessionManager.updateFromSubscriptionState(
                isActive: true,
                tier: tier,
                period: period,
                status: "active",
                startTimeMillis: purchaseTime,
                expiryTimeMillis: expiryTime,
                willAutoRenew: true,
                productId: product.id,
                purchaseToken: String(transaction.id),
                basePlanId: product.id
            )
            
            // Update main session manager for backwards compatibility
            SessionManager.shared.premiumActive = true
            SessionManager.shared.synchronize()
        }
        
        // Save to Firestore with full details (Android parity)
        subscriptionRepository.saveFullSubscriptionState(
            userId: userId,
            isActive: true,
            status: "active",
            tier: tier,
            period: period,
            basePlanId: product.id,
            purchaseTime: purchaseTime,
            startTimeMillis: purchaseTime,
            expiryTimeMillis: expiryTime,
            willAutoRenew: true,
            purchaseToken: String(transaction.id),
            productId: product.id,
            orderId: transaction.originalID.description,
            isNewPurchase: true
        )
        
        // Also save detailed history record (Android parity)
        await saveDetailedHistoryRecord(
            transaction: transaction,
            product: product,
            tier: tier,
            period: period,
            purchaseTime: purchaseTime,
            expiryTime: expiryTime,
            basePlanId: product.id
        )
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() Successfully processed purchase")
        
        // Query existing purchases to refresh subscription status (Android parity)
        // This ensures the subscription status is properly updated after purchase
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "handleSuccessfulPurchase() Querying existing purchases to refresh subscription status")
        await queryCurrentEntitlements()
        
        // Post notification for UI updates (Android parity)
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    // MARK: - Receipt Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "checkVerified() Transaction verification failed")
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "restorePurchases() Starting restore")
        
        do {
            try await AppStore.sync()
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "restorePurchases() Restore completed")
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "restorePurchases() Restore failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Query Current Entitlements
    
    /// Queries current entitlements from StoreKit to refresh subscription status
    /// This is called after successful purchases to ensure status is up-to-date (Android parity)
    func queryCurrentEntitlements() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() Querying current entitlements from StoreKit")
        
        var activeTransactions: [StoreKit.Transaction] = []
        
        // First, collect all active entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productType == .autoRenewable {
                    activeTransactions.append(transaction)
                    AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() Found active subscription: \(transaction.productID) (purchased: \(transaction.purchaseDate))")
                }
            case .unverified(let transaction, let error):
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() Unverified transaction: \(error.localizedDescription)")
            }
        }
        
        if !activeTransactions.isEmpty {
            // Sort by purchase date (newest first) to handle subscription upgrades correctly
            // If purchase dates are equal, prioritize higher tiers (pro > plus > lite)
            activeTransactions.sort { transaction1, transaction2 in
                if transaction1.purchaseDate == transaction2.purchaseDate {
                    let (tier1, _) = parseProductId(transaction1.productID)
                    let (tier2, _) = parseProductId(transaction2.productID)
                    return getTierPriority(tier1) > getTierPriority(tier2)
                }
                return transaction1.purchaseDate > transaction2.purchaseDate
            }
            
            // Use the most recent subscription as the active one
            guard let mostRecentTransaction = activeTransactions.first else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "CRITICAL: activeTransactions.first is nil after sorting")
                return
            }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() Using most recent subscription: \(mostRecentTransaction.productID) (purchased: \(mostRecentTransaction.purchaseDate))")
            
            // Update session manager with the most recent entitlement
            let (tier, period) = parseProductId(mostRecentTransaction.productID)
            let purchaseTime = Int64(mostRecentTransaction.purchaseDate.timeIntervalSince1970 * 1000)
            let expiryTime = calculateExpiryTime(purchaseTime: purchaseTime, period: period)
            
            await MainActor.run {
                subscriptionSessionManager.updateFromSubscriptionState(
                    isActive: true,
                    tier: tier,
                    period: period,
                    status: "active",
                    startTimeMillis: purchaseTime,
                    expiryTimeMillis: expiryTime,
                    willAutoRenew: true,
                    productId: mostRecentTransaction.productID,
                    purchaseToken: String(mostRecentTransaction.id),
                    basePlanId: mostRecentTransaction.productID
                )
                
                // Update main session manager for backwards compatibility
                SessionManager.shared.premiumActive = true
                SessionManager.shared.synchronize()
            }
            
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() Found active subscription - status updated to \(tier) \(period)")
        } else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "queryCurrentEntitlements() No active subscription found")
        }
    }
    
    // MARK: - Manual Refresh
    
    /// Manually refresh subscription status by querying current entitlements
    /// This can be called from UI to refresh subscription status
    func refreshSubscriptionStatus() async {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "refreshSubscriptionStatus() Manually refreshing subscription status")
        await queryCurrentEntitlements()
    }
    

    
    // MARK: - Helper Methods
    
    private func parseProductId(_ productId: String) -> (tier: String, period: String) {
        // Example: com.peppty.ChatApp.lite.weekly
        let components = productId.components(separatedBy: ".")
        guard components.count >= 5 else {
            return ("unknown", "unknown")
        }
        // The tier is the 4th component, period is the 5th
        let tier = components[3]
        let period = components[4]
        return (tier, period)
    }
    
    private func getTierPriority(_ tier: String) -> Int {
        // Higher number = higher priority
        switch tier.lowercased() {
        case "pro":
            return 3
        case "plus":
            return 2
        case "lite":
            return 1
        default:
            return 0
        }
    }
    
    private func calculateExpiryTime(purchaseTime: Int64, period: String) -> Int64 {
        let purchaseTimeSeconds = purchaseTime / 1000
        let calendar = Calendar.current
        let purchaseDate = Date(timeIntervalSince1970: TimeInterval(purchaseTimeSeconds))
        
        var expiryDate: Date
        
        switch period.lowercased() {
        case "weekly":
            expiryDate = calendar.date(byAdding: .weekOfYear, value: 1, to: purchaseDate) ?? purchaseDate
        case "monthly":
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        case "yearly":
            expiryDate = calendar.date(byAdding: .year, value: 1, to: purchaseDate) ?? purchaseDate
        default:
            expiryDate = calendar.date(byAdding: .month, value: 1, to: purchaseDate) ?? purchaseDate
        }
        
        return Int64(expiryDate.timeIntervalSince1970 * 1000)
    }
    
    // MARK: - History Management
    
    private func saveDetailedHistoryRecord(
        transaction: StoreKit.Transaction,
        product: Product,
        tier: String,
        period: String,
        purchaseTime: Int64,
        expiryTime: Int64,
        basePlanId: String?
    ) async {
        guard let userId = sessionManager.userId else {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "saveDetailedHistoryRecord() No userId available")
            return
        }
        
        let db = Firestore.firestore()
        let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
        
        let historyData: [String: Any] = [
            "documentId": String(transaction.id),
            "productId": product.id,
            "tier": tier,
            "period": period,
            "status": "active",
            "isActive": true,
            "willAutoRenew": true,
            "startTimeMillis": purchaseTime,
            "expiryTimeMillis": expiryTime,
            "lastUpdatedTimeMillis": currentTimeMillis,
            "lastNotificationType": 1, // Purchase notification type
            "orderId": transaction.originalID.description,
            "basePlanId": basePlanId ?? "unknown",
            "subscriptionState": "active",
            "needsVerification": false,
            "gracePeriodEndMillis": 0,
            "accountHoldEndMillis": 0,
            "pauseResumeTimeMillis": 0
        ]
        
        // Save with transaction ID as document ID (Android parity)
        let docRef = db.collection("Users")
            .document(userId)
            .collection("Subscription")
            .document(String(transaction.id))
        
        do {
            try await docRef.setData(historyData, merge: true)
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "saveDetailedHistoryRecord() Successfully saved history record")
        } catch {
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "saveDetailedHistoryRecord() Failed to save history: \(error.localizedDescription)")
        }
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case productNotFound
    case verificationFailed
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .verificationFailed:
            return "Transaction verification failed"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
} 

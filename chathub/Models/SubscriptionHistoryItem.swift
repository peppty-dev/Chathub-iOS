import Foundation

struct SubscriptionHistoryItem: Identifiable, Codable {
    let id: String
    let documentId: String
    let productId: String
    let tier: String
    let period: String
    let status: String
    let isActive: Bool
    let willAutoRenew: Bool
    let startTimeMillis: Int64
    let expiryTimeMillis: Int64
    let lastUpdatedTimeMillis: Int64
    let lastNotificationType: Int?
    let orderId: String?
    let basePlanId: String?
    let subscriptionState: String?
    let needsVerification: Bool
    let gracePeriodEndMillis: Int64
    let accountHoldEndMillis: Int64
    let pauseResumeTimeMillis: Int64
    
    // Computed properties for display (Android parity)
    var formattedTitle: String {
        let formattedTier = tier.prefix(1).uppercased() + tier.dropFirst()
        let formattedPeriod = period.prefix(1).uppercased() + period.dropFirst()
        return "\(formattedTier) (\(formattedPeriod))"
    }
    
    var formattedStartDate: String {
        return formatDate(timeMillis: startTimeMillis)
    }
    
    var formattedExpiryDate: String {
        return formatDate(timeMillis: expiryTimeMillis)
    }
    
    var formattedLastUpdatedDate: String {
        return formatDate(timeMillis: lastUpdatedTimeMillis)
    }
    
    // Legacy properties for backward compatibility
    var planName: String { formattedTitle }
    var price: String { "N/A" } // Price not stored in history
    var purchaseDate: String { formattedStartDate }
    var expiresDate: String { formattedExpiryDate }
    
    private func formatDate(timeMillis: Int64) -> String {
        guard timeMillis > 0 else { return "N/A" }
        let date = Date(timeIntervalSince1970: TimeInterval(timeMillis / 1000))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    // Firestore field mapping
    enum CodingKeys: String, CodingKey {
        case id
        case documentId
        case productId
        case tier
        case period
        case status
        case isActive
        case willAutoRenew
        case startTimeMillis
        case expiryTimeMillis
        case lastUpdatedTimeMillis
        case lastNotificationType
        case orderId
        case basePlanId
        case subscriptionState
        case needsVerification
        case gracePeriodEndMillis
        case accountHoldEndMillis
        case pauseResumeTimeMillis
    }
} 
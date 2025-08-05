import SwiftUI

/**
 * Enhanced SubscriptionHistoryRow with improved UI design (Android parity)
 * Matches Android's item_subscription_history.xml layout with better colors and contrast
 */
struct SubscriptionHistoryRow: View {
    let item: SubscriptionHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header section with title and status
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title (Tier and Period) - Primary text
                    Text(item.formattedTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("dark"))
                        .lineLimit(2)
                    
                    // Start Date - Secondary text
                    Text("Started: \(item.formattedStartDate)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("shade6"))
                    
                    // Updated Date - Same styling as Started for consistency
                    Text("Updated: \(item.formattedLastUpdatedDate)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("shade6"))
                }
                
                Spacer()
                
                // Status badge
                Text(item.status.capitalized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusTextColor(for: item.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(statusBackgroundColor(for: item.status))
                    )
            }
            
            // Product Details Section - Organized like Android layout
            VStack(alignment: .leading, spacing: 6) {
                if !item.productId.isEmpty {
                    DetailRow(label: "Product ID:", value: item.productId)
                }
                
                if let orderId = item.orderId, !orderId.isEmpty {
                    DetailRow(label: "Order ID:", value: orderId)
                }
                
                if let basePlanId = item.basePlanId, !basePlanId.isEmpty {
                    DetailRow(label: "Plan ID:", value: basePlanId)
                }
            }
            
            // Additional details section (if needed)
            if item.willAutoRenew || item.expiryTimeMillis > 0 {
                Divider()
                    .background(Color("shade3"))
                
                VStack(alignment: .leading, spacing: 4) {
                    if item.willAutoRenew {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color("AndroidGreen"))
                                .font(.system(size: 12, weight: .medium))
                            
                            Text("Auto-renewing")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("AndroidGreen"))
                        }
                    }
                    
                    if item.expiryTimeMillis > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundColor(Color("shade6"))
                                .font(.system(size: 12, weight: .medium))
                            
                            Text("Expires: \(item.formattedExpiryDate)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("shade6"))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("Background Color"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("shade2"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Views
    
    private func DetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("shade6"))
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color("shade5"))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    // MARK: - Status Colors (UI Guide: 4.5:1 contrast ratio)
    
    private func statusTextColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return Color.white
        case "expired", "cancelled":
            return Color.white
        case "pending":
            return Color.white
        default:
            return Color("bright")
        }
    }
    
    private func statusBackgroundColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return Color("AndroidGreen")
        case "expired", "cancelled":
            return Color("ErrorRed")
        case "pending":
            return Color("orange_900")
        default:
            return Color("shade5")
        }
    }
}

// MARK: - Preview

struct SubscriptionHistoryRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SubscriptionHistoryRow(item: SubscriptionHistoryItem(
                id: "1",
                documentId: "trans_123",
                productId: "com.peppty.ChatApp.plus.yearly",
                tier: "plus",
                period: "yearly",
                status: "active",
                isActive: true,
                willAutoRenew: true,
                startTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) - 86400000, // 1 day ago
                expiryTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) + 31536000000, // 1 year from now
                lastUpdatedTimeMillis: Int64(Date().timeIntervalSince1970 * 1000),
                lastNotificationType: 1,
                orderId: "GPA.1234-5678-9012-34567",
                basePlanId: "com.peppty.ChatApp.plus.yearly",
                subscriptionState: "active",
                needsVerification: false,
                gracePeriodEndMillis: 0,
                accountHoldEndMillis: 0,
                pauseResumeTimeMillis: 0
            ))
            
            SubscriptionHistoryRow(item: SubscriptionHistoryItem(
                id: "2",
                documentId: "purchase_token_456",
                productId: "com.peppty.ChatApp.lite.monthly",
                tier: "lite",
                period: "monthly",
                status: "expired",
                isActive: false,
                willAutoRenew: false,
                startTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) - 5184000000, // 60 days ago
                expiryTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) - 2592000000, // 30 days ago
                lastUpdatedTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) - 2592000000,
                lastNotificationType: 13, // Expired
                orderId: "GPA.9876-5432-1098-76543",
                basePlanId: "com.peppty.ChatApp.lite.monthly",
                subscriptionState: "expired",
                needsVerification: false,
                gracePeriodEndMillis: 0,
                accountHoldEndMillis: 0,
                pauseResumeTimeMillis: 0
            ))
            
            SubscriptionHistoryRow(item: SubscriptionHistoryItem(
                id: "3",
                documentId: "purchase_token_789",
                productId: "com.peppty.ChatApp.plus.monthly",
                tier: "plus",
                period: "monthly",
                status: "pending",
                isActive: false,
                willAutoRenew: true,
                startTimeMillis: Int64(Date().timeIntervalSince1970 * 1000),
                expiryTimeMillis: Int64(Date().timeIntervalSince1970 * 1000) + 2592000000, // 30 days from now
                lastUpdatedTimeMillis: Int64(Date().timeIntervalSince1970 * 1000),
                lastNotificationType: 2,
                orderId: "GPA.5555-6666-7777-88888",
                basePlanId: "com.peppty.ChatApp.plus.monthly",
                subscriptionState: "pending",
                needsVerification: false,
                gracePeriodEndMillis: 0,
                accountHoldEndMillis: 0,
                pauseResumeTimeMillis: 0
            ))
        }
        .padding()
        .background(Color("Background Color"))
        .previewLayout(.sizeThatFits)
    }
} 
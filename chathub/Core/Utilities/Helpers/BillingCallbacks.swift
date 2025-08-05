import Foundation
import StoreKit

/**
 * BillingCallbacks typealias for iOS equivalent of Android BillingCallbacks interface
 * The actual protocol is defined in SubscriptionBillingHelper.swift
 * This file provides a convenient import point for the protocol
 */

// Re-export the BillingCallbacks protocol from SubscriptionBillingHelper
// The protocol is defined as:
// protocol BillingCallbacks: AnyObject {
//     func onProductDetailsReady(_ productDetailsMap: [String: Product])
//     func onNoSubscriptionFound()
//     func onSubscriptionFound(transaction: Transaction, product: Product, subscriptionTier: String, subscriptionPeriod: String)
//     func onPendingPurchaseFound(transaction: Transaction)
// }

// Note: The actual protocol definition is in SubscriptionBillingHelper.swift
// This file serves as a documentation reference for the Android parity 
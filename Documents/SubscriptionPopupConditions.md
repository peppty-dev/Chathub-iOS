# Subscription Popup Conditions Report

## Overview

This document defines which subscription tiers should bypass which limit popups based on the tier inheritance model where each higher tier includes all benefits of lower tiers.

## Tier Inheritance Model

```
Free → Lite → Plus → Pro
 └─────┴──────┴─────┴─→ Each tier includes all features from previous tiers
```

## Limit Popup Subscription Check Matrix

### 1. **Refresh Limit Popup**
**Feature**: Unlocks Refresh functionality
**Unlocked in**: Lite, Plus, Pro
**Subscription Check Condition**:
```swift
// Should bypass popup if user has ANY of these subscriptions:
isUserSubscribedToLite() || isUserSubscribedToPlus() || isUserSubscribedToPro()
```
**Simplified Check**:
```swift
// Since Lite is the lowest tier that unlocks this:
isUserSubscribedToLite()  // This will return true for Lite, Plus, or Pro
```

---

### 2. **Filters Limit Popup**
**Feature**: Unlocks advanced filtering options
**Unlocked in**: Lite, Plus, Pro
**Subscription Check Condition**:
```swift
// Should bypass popup if user has ANY of these subscriptions:
isUserSubscribedToLite() || isUserSubscribedToPlus() || isUserSubscribedToPro()
```
**Simplified Check**:
```swift
// Since Lite is the lowest tier that unlocks this:
isUserSubscribedToLite()  // This will return true for Lite, Plus, or Pro
```

---

### 3. **Search Limit Popup**
**Feature**: Unlocks search functionality
**Unlocked in**: Lite, Plus, Pro
**Subscription Check Condition**:
```swift
// Should bypass popup if user has ANY of these subscriptions:
isUserSubscribedToLite() || isUserSubscribedToPlus() || isUserSubscribedToPro()
```
**Simplified Check**:
```swift
// Since Lite is the lowest tier that unlocks this:
isUserSubscribedToLite()  // This will return true for Lite, Plus, or Pro
```

---

### 4. **Conversation Limit Popup**
**Feature**: No conversation limit (unlimited conversations)
**Unlocked in**: Plus, Pro
**Subscription Check Condition**:
```swift
// Should bypass popup if user has ANY of these subscriptions:
isUserSubscribedToPlus() || isUserSubscribedToPro()
```
**Simplified Check**:
```swift
// Since Plus is the lowest tier that unlocks this:
isUserSubscribedToPlus()  // This will return true for Plus or Pro
```

---

### 5. **Message Limit Popup**
**Feature**: No message limit (unlimited messages in conversations)
**Unlocked in**: Pro only
**Subscription Check Condition**:
```swift
// Should bypass popup ONLY if user has Pro subscription:
isUserSubscribedToPro()
```
**Note**: This is the only feature exclusive to Pro tier

---

## Implementation Guide

### Current Implementation Issues
Based on the tier inheritance model, many popups might currently be checking for specific tiers only, which would incorrectly show limits to higher-tier subscribers.

### Recommended Implementation Pattern

#### Method 1: Individual Tier Checks (Current Pattern)
```swift
// For Discovery Features (Refresh, Filters, Search)
func shouldBypassRefreshLimit() -> Bool {
    return isUserSubscribedToLite() || isUserSubscribedToPlus() || isUserSubscribedToPro()
}

// For Conversation Limits
func shouldBypassConversationLimit() -> Bool {
    return isUserSubscribedToPlus() || isUserSubscribedToPro()
}

// For Message Limits
func shouldBypassMessageLimit() -> Bool {
    return isUserSubscribedToPro()
}
```

#### Method 2: Tier Hierarchy Helper (Recommended)
Create a helper method that understands tier hierarchy:

```swift
extension SubscriptionSessionManager {
    /// Check if user has access to features from a specific tier or higher
    func hasAccessToTierOrHigher(_ targetTier: SubscriptionTier) -> Bool {
        let currentTier = getCurrentTierEnum()
        return currentTier.rawValue >= targetTier.rawValue
    }
}

enum SubscriptionTier: Int, CaseIterable {
    case none = 0
    case lite = 1
    case plus = 2
    case pro = 3
}

// Usage:
func shouldBypassRefreshLimit() -> Bool {
    return hasAccessToTierOrHigher(.lite)
}

func shouldBypassConversationLimit() -> Bool {
    return hasAccessToTierOrHigher(.plus)
}

func shouldBypassMessageLimit() -> Bool {
    return hasAccessToTierOrHigher(.pro)
}
```

## Feature-to-Tier Mapping Summary

| **Popup/Limit** | **Minimum Tier Required** | **Tiers That Should Bypass** | **Check Condition** |
|---|---|---|---|
| **Refresh Limit** | Lite | Lite, Plus, Pro | `isUserSubscribedToLite()` |
| **Filters Limit** | Lite | Lite, Plus, Pro | `isUserSubscribedToLite()` |
| **Search Limit** | Lite | Lite, Plus, Pro | `isUserSubscribedToLite()` |
| **Conversation Limit** | Plus | Plus, Pro | `isUserSubscribedToPlus()` |
| **Message Limit** | Pro | Pro only | `isUserSubscribedToPro()` |

## Additional Considerations

### 1. **Live Call Limits**
- **Feature**: Access to live video calls
- **Unlocked in**: Plus, Pro
- **Check**: `isUserSubscribedToPlus()`

### 2. **Voice/Video Call Limits**
- **Feature**: Access to voice and video calls
- **Unlocked in**: Pro only
- **Check**: `isUserSubscribedToPro()`

### 3. **New User Bypass**
All limits should also check for new user status:
```swift
func shouldBypassAnyLimit() -> Bool {
    return isNewUser() || hasRequiredSubscription()
}
```

## Testing Scenarios

### Test Case 1: Lite Subscriber
- ✅ Should bypass: Refresh, Filters, Search popups
- ❌ Should see: Conversation limit, Message limit popups

### Test Case 2: Plus Subscriber
- ✅ Should bypass: Refresh, Filters, Search, Conversation limit popups
- ❌ Should see: Message limit popup

### Test Case 3: Pro Subscriber
- ✅ Should bypass: ALL popups (Refresh, Filters, Search, Conversation, Message)
- ❌ Should see: No limit popups

### Test Case 4: Free User
- ❌ Should see: ALL limit popups when limits are reached

## Implementation Priority

### High Priority Fixes
1. **Discovery Features**: Ensure Lite+ users never see refresh/filter/search limits
2. **Conversation Limits**: Ensure Plus+ users never see conversation limits
3. **Message Limits**: Ensure only Pro users bypass message limits

### Code Audit Needed
Review all popup conditions to ensure they follow the tier inheritance model and don't incorrectly show limits to users who have already paid to remove them.

# Refresh Feature - Feature Document

## 1. Overview

The Refresh Feature allows users to manually refresh the online user list in the main discovery screen. This feature implements a freemium model where users have limited free refreshes, with unlimited refreshes available for Light subscription and above.

## 2. Feature Purpose

- **Primary Function**: Refresh the online user list to get the latest users according to current filters
- **Business Value**: Encourage subscription upgrades through usage limits
- **User Experience**: Provide users control over when to fetch fresh user data
- **Technical Value**: Balance server load with user engagement

## 3. User Interface Components

### 3.1 Refresh Button
- **Location**: Main discovery screen (DiscoverTabView)
- **Appearance**: Large, prominent button
- **Behavior**: Triggers refresh logic when tapped
- **Current Implementation**: Pull-to-refresh gesture on notification list

### 3.2 Refresh Popup
- **Title**: "Refresh"
- **Description**: Brief explanation of the refresh feature and limits
- **Buttons**:
  - **Primary**: "Refresh" button (with timer animation when on cooldown)
  - **Secondary**: "Subscribe to Light" button

## 4. Business Logic & Rules

### 4.1 Subscription Checks (Priority 1)
```
IF user has Light/Plus/Pro subscription OR is a new user:
    → Allow unlimited refreshes
    → Skip all limit checks
    → Proceed directly to refresh
```

### 4.2 Free User Limits (Priority 2)
For non-subscribed users, check these limits in order:

#### 4.2.1 Usage Count Check
```
IF refresh count < free_refresh_count:
    → Allow refresh
    → Increment usage counter
    → Proceed to refresh
```

#### 4.2.2 Cooldown Check
```
IF refresh count >= free_refresh_count:
    → Check last refresh timestamp
    → IF cooldown period has passed:
        → Reset counter
        → Allow refresh
    → ELSE:
        → Show popup with timer
        → Block refresh
```

## 5. Configuration Values (Firebase Remote Config)

### 5.1 App Settings Keys
These values are stored in `AppSettingsSessionManager` and synced from Firebase:

```swift
// Refresh Configuration Keys
static let freeRefreshCount = "FREE_REFRESH_COUNT"           // Default: 5
static let refreshCooldownSeconds = "REFRESH_COOLDOWN_SECONDS" // Default: 1800 (30 minutes)
```

### 5.2 Default Values
- **Free Refresh Count**: 5 refreshes per period
- **Cooldown Duration**: 30 minutes (1800 seconds)

## 6. Technical Implementation

### 6.1 Current System Components

#### 6.1.1 RefreshLimitManager
- **Location**: `chathub/Core/Services/` (inferred from existing pattern)
- **Responsibility**: Handle refresh limit logic
- **Methods**:
  - `checkRefreshLimit() -> FeatureLimitResult`
  - `performRefresh(completion: @escaping (Bool) -> Void)`

#### 6.1.2 FeatureLimitResult Structure
```swift
struct FeatureLimitResult {
    let canProceed: Bool
    let isLimitReached: Bool
    let currentUsage: Int
    let limit: Int
    let remainingCooldown: TimeInterval
}
```

#### 6.1.3 Subscription Integration
- **Component**: `SubscriptionSessionManager.shared`
- **Methods Used**:
  - `isUserSubscribedToLite() -> Bool`
  - `isUserSubscribedToPlus() -> Bool`
  - `isUserSubscribedToPro() -> Bool`
- **New User Check**: `ConversationLimitManagerNew.shared.isNewUser()`

### 6.2 Data Flow

```
User Taps Refresh
    ↓
Check Subscription Status
    ↓
IF Premium User → Direct Refresh
    ↓
ELSE → Check Free Limits
    ↓
IF Within Limits → Perform Refresh + Increment Counter
    ↓
ELSE → Check Cooldown
    ↓
IF Cooldown Expired → Reset Counter + Allow Refresh
    ↓
ELSE → Show Popup with Timer
```

## 7. Popup Implementation Details

### 7.1 RefreshLimitPopupView
- **Location**: `chathub/Views/Popups/RefreshLimitPopupView.swift`
- **Parent Component**: `DiscoverTabView`
- **State Management**: `@State private var showRefreshLimitPopup: Bool`

### 7.2 Timer Animation
When user is on cooldown:
- **Button State**: Disabled appearance
- **Animation**: Right-to-left progress fill animation
- **Duration**: Matches remaining cooldown time
- **Completion**: Button becomes fully enabled when timer finishes

### 7.3 Visual Design
```swift
// Popup Structure
VStack {
    // Title
    Text("Refresh")
    
    // Description
    Text("Refresh the user list to see new people...")
    
    // Buttons
    HStack {
        // Refresh Button (with timer animation if on cooldown)
        Button("Refresh") { }
        
        // Subscription Button
        Button("Subscribe to Light") { }
    }
}
```

## 8. Integration Points

### 8.1 Current Implementation Status
- ✅ Pull-to-refresh gesture implemented in `DiscoverTabView`
- ✅ `RefreshLimitManager` system exists
- ✅ Popup overlay system in place
- ✅ Subscription check integration complete

### 8.2 Main Entry Points
1. **Pull-to-refresh**: `refreshable` modifier on notification list
2. **Method**: `performRefreshWithLimits()` in `DiscoverTabView`
3. **Popup**: `refreshLimitPopupOverlay` view modifier

### 8.3 Backend Integration
- **Method**: `viewModel.refreshNotifications()`
- **Service**: `InAppNotificationsSyncService.shared`
- **Data Source**: Firebase Firestore → Local SQLite cache

## 9. User Experience Flow

### 9.1 Happy Path (Subscribed User)
1. User pulls down to refresh
2. System checks subscription → Premium detected
3. Immediate refresh without popup
4. Loading indicator shown
5. Fresh user list displayed

### 9.2 Free User - Within Limits
1. User pulls down to refresh
2. System checks subscription → Free user detected
3. System checks usage → Within limit (e.g., 3/5)
4. Immediate refresh with counter increment
5. Fresh user list displayed

### 9.3 Free User - Limit Reached (Cooldown Active)
1. User pulls down to refresh
2. System checks subscription → Free user detected
3. System checks usage → Limit exceeded (5/5)
4. System checks cooldown → Still active (15 minutes remaining)
5. Popup shown with timer animation
6. User sees disabled "Refresh" button with countdown
7. User can choose "Subscribe to Light" or wait

### 9.4 Free User - Limit Reached (Cooldown Expired)
1. User pulls down to refresh
2. System checks subscription → Free user detected
3. System checks usage → Limit exceeded (5/5)
4. System checks cooldown → Expired
5. Counter resets to 0
6. Immediate refresh proceeds
7. Fresh user list displayed

## 10. Error Handling

### 10.1 Network Issues
- Show standard network error message
- Don't consume refresh attempts for failed requests
- Allow retry without penalty

### 10.2 Configuration Issues
- Use hardcoded fallback values if Firebase config fails
- Log configuration errors for debugging
- Continue with default limits (5 refreshes, 30-minute cooldown)

### 10.3 Timer Synchronization
- Store timestamps in Unix epoch format
- Handle device time changes gracefully
- Validate server time when possible

## 11. Analytics & Monitoring

### 11.1 Key Metrics
- Refresh usage frequency per user segment
- Conversion rate from refresh popup to subscription
- Average time between refreshes
- Cooldown abandonment rate

### 11.2 Logging Events
```swift
// Usage Tracking
AppLogger.log("RefreshFeature", "refresh_attempted_premium_user")
AppLogger.log("RefreshFeature", "refresh_attempted_free_user_allowed")
AppLogger.log("RefreshFeature", "refresh_blocked_limit_reached")
AppLogger.log("RefreshFeature", "popup_shown_cooldown_active")
AppLogger.log("RefreshFeature", "subscription_button_tapped_from_refresh")
```

## 12. Testing Scenarios

### 12.1 Subscription States
- [ ] New user (unlimited)
- [ ] Free user
- [ ] Light subscriber (unlimited)
- [ ] Plus subscriber (unlimited)
- [ ] Pro subscriber (unlimited)
- [ ] Expired subscription

### 12.2 Limit Scenarios
- [ ] First refresh (counter: 0 → 1)
- [ ] Multiple refreshes within limit
- [ ] Exact limit reached (5/5)
- [ ] Cooldown period active
- [ ] Cooldown period expired

### 12.3 Edge Cases
- [ ] App backgrounded during cooldown
- [ ] Device time changed
- [ ] Network interrupted during refresh
- [ ] Configuration values changed remotely
- [ ] Subscription status changed mid-session

## 13. Future Enhancements

### 13.1 Potential Improvements
- **Smart Refresh**: Only refresh if significant time has passed
- **Location-Based**: Different limits based on user density
- **Time-Based**: Different limits during peak/off-peak hours
- **Personalized**: Adjust limits based on user engagement patterns

### 13.2 A/B Testing Opportunities
- Different cooldown durations
- Various free refresh counts
- Alternative popup designs
- Timer animation styles

## 14. Dependencies

### 14.1 Internal Dependencies
- `SubscriptionSessionManager` - subscription status
- `AppSettingsSessionManager` - configuration values
- `RefreshLimitManager` - limit enforcement
- `ConversationLimitManagerNew` - new user detection
- `DiscoverTabViewModel` - data refresh logic

### 14.2 External Dependencies
- Firebase Remote Config - configuration values
- Firebase Firestore - user data source
- Local SQLite database - cached user data

---

*This document serves as the definitive specification for the Refresh Feature implementation in the ChatHub iOS application.*
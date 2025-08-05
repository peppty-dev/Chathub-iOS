# Current Refresh Feature Implementation - Feature Document

## Executive Summary

The ChatHub iOS Refresh Feature is a sophisticated freemium monetization system that strategically balances user engagement with subscription conversion through a three-tier permission architecture designed to maximize Lite subscription upgrades while ensuring excellent user experience across all segments. The system operates through a centralized RefreshLimitManager extending BaseFeatureLimitManager, which evaluates every refresh request through a priority-based decision tree that first checks Lite subscription status via SubscriptionSessionManager.isUserSubscribedToLite(), then validates new user status by comparing current time against UserSessionManager.firstAccountCreatedTime and configurable newUserFreePeriodSeconds (typically 2-7 hours), with Lite subscribers and new users receiving unlimited refresh privileges while regular free users encounter an innovative "always-show popup" strategy that displays RefreshLimitPopupView on every refresh attempt regardless of current limit status. This popup contains a dynamic refresh button that transforms based on usage state - showing "Refresh Users" with green gradient when under the 2-refresh limit or "Refresh Available In [timer]" with gray disabled appearance and animated progress bar during the 2-minute cooldown period - alongside a subscription promotion button displaying real-time pricing from SubscriptionsManagerStoreKit2 with purple gradient and crown iconography. The technical implementation employs sophisticated time-based calculations using Unix timestamps stored in SessionManager via UserDefaults, tracking refreshUsageCount and refreshLimitCooldownStartTime with automatic reset mechanisms, while the new user detection algorithm examines device-level firstAccountCreatedTime to prevent abuse while providing genuine newcomers extended exploration periods. The system integrates comprehensive Firebase Analytics tracking through RefreshAnalytics service that captures detailed conversion funnel metrics including button taps, popup interactions, subscription intents, user segmentation bypass events, and system-level cooldown/reset activities, providing rich contextual parameters for each event such as user type, usage counts, remaining cooldowns, pricing displays, time spent in popups, and conversion funnel progression steps. The analytics implementation uses iOS-specific naming conventions with `ios_` prefixes for all events and parameters to ensure clear platform separation in Firebase console, follows established SubscriptionAnalytics patterns, and enables real-time business intelligence for optimizing limit values, cooldown durations, popup messaging, and pricing strategies through detailed user behavior analysis across all three user segments. The system includes comprehensive error handling for network failures, time synchronization issues, and device manipulation attempts, maintains persistent state across app launches, supports Firebase Remote Config for dynamic limit adjustments enabling A/B testing, and creates a balanced ecosystem that provides clear value to all user segments while establishing natural upgrade touchpoints that drive sustainable revenue growth through strategic psychological design, technical precision, and data-driven optimization.

## 1. Overview

This document describes the **current implementation** of the Refresh Feature in the ChatHub iOS application. The feature allows users to manually refresh online user lists and notifications, implementing a freemium model with usage limits for non-premium users and unlimited access for subscribers.

## 2. Current Architecture

### 2.1 Core Components

#### 2.1.1 RefreshLimitManager
- **Location**: `chathub/Core/Services/Core/RefreshLimitManager.swift`
- **Type**: Singleton service extending `BaseFeatureLimitManager`
- **Purpose**: Manages refresh limits and cooldown logic
- **Key Methods**:
  - `checkRefreshLimit() -> FeatureLimitResult`
  - `performRefresh(completion: @escaping (Bool) -> Void)`
  - `resetRefreshUsage()`

#### 2.1.2 BaseFeatureLimitManager
- **Location**: `chathub/Core/Services/Core/FeatureLimitManager.swift`
- **Type**: Abstract base class implementing `FeatureLimitManager` protocol
- **Purpose**: Provides common limit checking logic for all features
- **Key Methods**:
  - `canPerformAction() -> Bool`
  - `incrementUsage()`
  - `getRemainingCooldown() -> TimeInterval`
  - `isInCooldown() -> Bool`
  - `resetCooldown()`

#### 2.1.3 FeatureLimitResult Structure
```swift
struct FeatureLimitResult {
    let canProceed: Bool
    let showPopup: Bool
    let remainingCooldown: TimeInterval
    let currentUsage: Int
    let limit: Int
    
    var isLimitReached: Bool {
        return currentUsage >= limit
    }
}
```

### 2.2 Configuration Management

#### 2.2.1 SessionManager
- **Location**: `chathub/Core/Services/Core/SessionManager.swift`
- **Purpose**: Stores refresh limit configuration values
- **Key Properties**:
  - `freeRefreshLimit: Int` (default: 2 refreshes)
  - `freeRefreshCooldownSeconds: TimeInterval` (default: 120 seconds / 2 minutes)
  - `refreshUsageCount: Int` (current usage counter)
  - `refreshLimitCooldownStartTime: Int64` (cooldown start timestamp)

#### 2.2.2 Configuration Keys
```swift
// UserDefaults Keys (in SessionManager.Keys)
static let freeRefreshLimit = "free_user_refresh_limit"
static let freeRefreshCooldownSeconds = "free_user_refresh_cooldown_seconds"
static let refreshUsageCount = "refresh_usage_count"
static let refreshLimitCooldownStartTime = "refresh_limit_cooldown_start_time"
```

## 3. Current User Interface Implementation

### 3.1 Refresh Mechanisms

#### 3.1.1 Manual Refresh Button (OnlineUsersView)
- **Location**: `chathub/Views/Users/OnlineUsersView.swift` (lines 513-537)
- **Implementation**: Dedicated "Refresh users" button in HStack with "Filter users"
- **Appearance**: 
  - Text: "Refresh users"
  - Icon: `arrow.clockwise.circle.fill` with red color (`Color("Red1")`)
  - Background: Rounded rectangle with blue tint (`Color("blue_50")`)
- **Trigger**: Direct button tap calls `RefreshLimitManager.shared.checkRefreshLimit()`

### 3.2 Popup Implementation

#### 3.2.1 RefreshLimitPopupView
- **Location**: `chathub/Views/Popups/RefreshLimitPopupView.swift`
- **Purpose**: Shows every time a non-Lite/non-new user clicks refresh
- **Used By**: OnlineUsersView for manual refresh button
- **Navigation**: Subscription button opens full `SubscriptionView` via `NavigationLink` (not modal)
- **Design Elements**:
  - **Background**: Enhanced contrast with darker overlay (0.6 opacity) and bordered popup with subtle shadow for better distinction from parent view
  - **Static Title**: "Refresh Users" (never changes regardless of limit status)
  - **Static Description**: "Refresh the user list to see new online users and get fresh connection opportunities." (never changes)
  - **Dynamic Refresh Button Only**: Timer and status information only appears inside the refresh button, not in separate UI elements
  - **Buttons**:
    - **Dynamic Refresh Button**: 
      - Available state: "Refresh Users" with green gradient background
      - Cooldown state: "Refresh Available In [timer]" with gray background, disabled state, and animated progress bar
    - **Subscription Button**: "Subscribe to ChatHub Lite" with matching Lite subscription gradient (liteGradientStart/liteGradientEnd) and star.circle.fill icon, includes weekly pricing display

### 3.3 Popup Display Logic

#### 3.3.1 RefreshLimitPopupView Trigger (OnlineUsersView)
```swift
// Lines 520-525 in OnlineUsersView.swift - Always shown for non-Lite/non-new users
if result.showPopup {
    // Always show popup for non-Lite subscribers and non-new users
    AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Showing refresh popup")
    refreshLimitResult = result
    showRefreshLimitPopup = true
}
```

### 3.3.2 Dynamic Refresh Button Implementation
```swift
// In RefreshLimitPopupView.swift - Button changes based on limit status
if isLimitReached && remainingTime > 0 {
    // Show timer when limit is reached
    VStack(spacing: 2) {
        Text("Refresh Available In")
            .font(.subheadline)
            .fontWeight(.medium)
        Text(formatTime(remainingTime))
            .font(.headline)
            .fontWeight(.bold)
    }
} else {
    // Show normal refresh text when available
    Text("Refresh Users")
        .font(.headline)
        .fontWeight(.semibold)
}
```

## 4. Current Business Logic Implementation

### 4.1 Subscription and New User Check Logic
```swift
// In BaseFeatureLimitManager.swift (lines 67-87)
func canPerformAction() -> Bool {
    // Lite subscription users bypass all limits
    if subscriptionSessionManager.isUserSubscribedToLite() {
        return true
    }
    
    // New users bypass all limits during their free period
    if isNewUser() {
        return true
    }
    
    let currentUsage = getCurrentUsageCount()
    let limit = getLimit()
    
    // If under limit, can proceed
    if currentUsage < limit {
        return true
    }
    
    // If over limit, check if cooldown has expired
    return !isInCooldown()
}
```

### 4.2 New User Detection Logic
```swift
// In BaseFeatureLimitManager.swift (lines 90-104)
private func isNewUser() -> Bool {
    let userSessionManager = UserSessionManager.shared
    let firstAccountTime = userSessionManager.firstAccountCreatedTime
    let newUserPeriod = messagingSessionManager.newUserFreePeriodSeconds
    
    if firstAccountTime <= 0 || newUserPeriod <= 0 {
        return false
    }
    
    let currentTime = Date().timeIntervalSince1970
    let elapsed = currentTime - firstAccountTime
    
    return elapsed < newUserPeriod
}
```

### 4.3 Always-Show Popup Logic
```swift
// In RefreshLimitManager.swift (lines 48-78)
func checkRefreshLimit() -> FeatureLimitResult {
    let currentUsage = getCurrentUsageCount()
    let limit = getLimit()
    let remainingCooldown = getRemainingCooldown()
    
    // Check if user can proceed without popup (Lite subscribers and new users)
    let isLiteSubscriber = subscriptionSessionManager.isUserSubscribedToLite()
    let isNewUserInFreePeriod = isNewUser()
    
    // Lite subscribers and new users bypass popup entirely
    if isLiteSubscriber || isNewUserInFreePeriod {
        return FeatureLimitResult(
            canProceed: true,
            showPopup: false,
            remainingCooldown: 0,
            currentUsage: currentUsage,
            limit: limit
        )
    }
    
            // For all other users, show popup only when they exceed their limit
        let canProceed = canPerformAction()
        
        // Only show popup when user has reached or exceeded their limit
        let shouldShowPopup = currentUsage >= limit
        
        return FeatureLimitResult(
            canProceed: canProceed,
            showPopup: shouldShowPopup,
            remainingCooldown: remainingCooldown,
            currentUsage: currentUsage,
            limit: limit
        )
}
```

### 4.4 Usage Increment Logic
```swift
// In BaseFeatureLimitManager.swift (lines 85-93)
func incrementUsage() {
    let currentUsage = getCurrentUsageCount()
    setUsageCount(currentUsage + 1)
    
    // If this puts us over the limit, start cooldown
    if currentUsage + 1 >= getLimit() && !isInCooldown() {
        startCooldown()
    }
}
```

## 5. Current Default Configuration Values

### 5.1 Hardcoded Defaults (SessionManager)
- **Free Refresh Limit**: 2 refreshes per cooldown period
- **Cooldown Duration**: 120 seconds (2 minutes)
- **Usage Counter**: Starts at 0, increments with each refresh
- **Cooldown Start Time**: Unix timestamp when limit is reached

### 5.2 Fallback Logic
```swift
// Default values when UserDefaults is empty (in SessionManager)
var freeRefreshLimit: Int {
    get { 
        let value = defaults.integer(forKey: Keys.freeRefreshLimit)
        return value > 0 ? value : 2 // Default to 2 refreshes
    }
}

var freeRefreshCooldownSeconds: TimeInterval {
    get { 
        let value = defaults.double(forKey: Keys.freeRefreshCooldownSeconds)
        return value > 0 ? value : 120 // Default to 2 minutes
    }
}
```

## 6. Current Data Flow Implementation

### 6.1 OnlineUsersView Manual Refresh Flow
```
User taps "Refresh users" button
    ↓
RefreshLimitManager.shared.checkRefreshLimit() (line 518)
    ↓
IF result.showPopup == true:
    → refreshLimitResult = result (line 523)
    → showRefreshLimitPopup = true (line 524)
    → RefreshLimitPopupView displayed (always for non-Lite/non-new users)
ELSE:
    → RefreshLimitManager.shared.performRefresh() (line 528)
    → viewModel.manualRefreshUsers() (line 531)
    → Direct refresh (Lite subscribers and new users only)
```

### 6.2 OnlineUsersView Automatic Time-Based Flow
```
User navigates to OnlineUsersView
    ↓
OnlineUsersView.onAppear triggered
    ↓
viewModel.fetchUsers() called
    ↓
userSessionManager.shouldRefreshOnlineUsersFromFirebase() checks staleness
    ↓
IF data is stale (> 30 minutes):
    → isLoading = true
    → loadUsersFromLocalDatabase() (show cached data immediately)
    → triggerBackgroundDataSync() (fetch fresh data from Firebase)
    → userSessionManager.setOnlineUsersRefreshTime() (update timestamp)
ELSE:
    → isLoading = false
    → loadUsersFromLocalDatabase() (show cached data only, no network)
```

### 6.3 App Lifecycle Data Flow
```
App Launch/Resume
    ↓
NO automatic refresh triggers
    ↓
User navigates to OnlineUsersView
    ↓
onAppear calls fetchUsers() with 30-minute staleness check
    ↓
IF last refresh > 30 minutes ago: Firebase sync in background
IF last refresh < 30 minutes ago: Use cached data only
```

## 7. Current Entry Points and Automatic Refresh Logic

### 7.1 Active Refresh Triggers
1. **"Refresh users" button** in OnlineUsersView only (manual user action)
2. **onAppear automatic refresh** in OnlineUsersView with 30-minute time-based logic

### 7.2 Automatic Refresh Prevention
The system is specifically designed to **prevent unwanted automatic refreshes** when users close and reopen the app. Key implementation details:

- **No Auto-Refresh on App Launch**: User list does not refresh automatically when app opens
- **No Auto-Refresh on App Resume**: User list does not refresh automatically when app returns from background
- **Only Manual Triggers**: All user list refreshes require explicit user interaction via the "Refresh users" button

### 7.3 Time-Based Automatic Refresh System (30-Minute Logic)

#### 7.3.1 Implementation Overview
The app implements a sophisticated **30-minute staleness detection system** that automatically refreshes user data from Firebase when local cache becomes outdated, but **only when users manually navigate to the OnlineUsersView**.

**Key Configuration**: 30 minutes (1800 seconds) staleness threshold

#### 7.3.2 Time-Based Refresh Logic
```swift
// In UserSessionManager.shouldRefreshOnlineUsersFromFirebase()
func shouldRefreshOnlineUsersFromFirebase() -> Bool {
    let lastRefresh = onlineUsersRefreshTime
    let thirtyMinutesAgo = Date().timeIntervalSince1970 - (30 * 60)
    return lastRefresh < thirtyMinutesAgo
}

// In OnlineUsersViewModel.fetchUsers() - Called from onAppear
let needsFirebaseSync = userSessionManager.shouldRefreshOnlineUsersFromFirebase()

if needsFirebaseSync {
    // Data is older than 30 minutes - trigger Firebase sync
    isLoading = true
    loadUsersFromLocalDatabase() // Show cached data immediately
    triggerBackgroundDataSync() // Fetch fresh data in background
} else {
    // Data is fresh (< 30 minutes) - use cached data only
    isLoading = false
    loadUsersFromLocalDatabase() // Show cached data immediately
}
```

#### 7.3.3 OnlineUsersView onAppear Trigger
```swift
// In OnlineUsersView.swift (lines 609-618)
.onAppear {
    AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - Online users view appeared")
    
    // Android parity: Always call fetchUsers which will handle refresh time logic internally
    // This matches Android OnlineUserListFragment behavior exactly
    AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "viewDidAppear() - Calling fetchUsers with Android parity logic")
    viewModel.fetchUsers()
}
```

#### 7.3.4 Smart Refresh Behavior
- **Fresh Data (< 30 minutes)**: Shows cached users instantly, no loading state, no network requests
- **Stale Data (> 30 minutes)**: Shows cached users immediately while fetching fresh data in background, loading indicator appears
- **No Data**: Shows loading state and fetches from Firebase
- **User Experience**: Always shows data immediately, background syncing provides freshness without blocking UI

#### 7.3.5 Refresh Time Tracking
- **Storage**: `onlineUsersRefreshTime` stored in UserSessionManager via UserDefaults
- **Updates**: Timestamp updated after successful Firebase sync operations
- **Persistence**: Survives app restarts and background/foreground cycles
- **Scope**: Applies to all user list interactions (manual refresh, filters, automatic freshness checks)

### 7.4 Backend Integration Points
- **OnlineUsersView**: `viewModel.fetchUsers()` → Smart time-based refresh logic
- **Manual Refresh**: `viewModel.manualRefreshUsers()` → Firebase Firestore sync (bypasses time check)
- **Data Storage**: Firebase Firestore → Local SQLite cache → UI display
- **Time Tracking**: UserSessionManager → UserDefaults persistence

## 8. Current Subscription Integration

### 8.1 Lite Subscription and New User Bypass Logic
```swift
// Lite subscription users get unlimited refreshes
private var isLiteSubscriber: Bool {
    subscriptionManager.isUserSubscribedToLite()
}

// New users get unlimited refreshes during their free period
private var isNewUserInFreePeriod: Bool {
    let firstAccountTime = UserSessionManager.shared.firstAccountCreatedTime
    let newUserPeriod = SessionManager.shared.newUserFreePeriodSeconds
    
    if firstAccountTime <= 0 || newUserPeriod <= 0 {
        return false
    }
    
    let currentTime = Date().timeIntervalSince1970
    let elapsed = currentTime - firstAccountTime
    
    return elapsed < TimeInterval(newUserPeriod)
}
```

### 8.2 Subscription Services Used
- **SubscriptionSessionManager.shared**: Lite subscription status checking specifically
- **UserSessionManager.shared**: First account creation time for new user detection
- **SessionManager.shared**: New user free period configuration
- **SubscriptionsManagerStoreKit2.shared**: Pricing information for popup display

## 9. Current Timer and Animation Implementation

### 9.1 Cooldown Timer (RefreshLimitPopupView)
```swift
@State private var countdownTimer: Timer?
@State private var remainingTime: TimeInterval

private func startCountdownTimer() {
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        if remainingTime > 0 {
            remainingTime -= 1
        } else {
            stopCountdownTimer()
            dismissPopup()
        }
    }
}
```

### 9.2 Timer Display Format
- Shows time in MM:SS format (e.g., "02:45" for 2 minutes 45 seconds)
- Updates every second with live countdown
- Button becomes enabled when timer reaches 00:00

## 10. Current Error Handling

### 10.1 Network Error Handling
- No specific refresh consumption on network failures
- Uses standard error messages from view models
- Allows retry without penalty

### 10.2 Configuration Error Handling
- Falls back to hardcoded defaults if UserDefaults fails
- Logs errors through `AppLogger.log()` system
- Continues operation with default limits

## 11. Current Logging Implementation

### 11.1 Key Log Messages
```swift
// RefreshLimitManager logs
AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "performRefresh() Refresh performed. Usage: \(getCurrentUsageCount())/\(getLimit())")
AppLogger.log(tag: "LOG-APP: RefreshLimitManager", message: "performRefresh() Refresh blocked. In cooldown: \(isInCooldown()), remaining: \(result.remainingCooldown)s")

// DiscoverTabView logs
AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performRefreshWithLimits() Checking refresh limits")
AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performRefreshWithLimits() Can proceed - performing refresh")
AppLogger.log(tag: "LOG-APP: DiscoverView", message: "performRefreshWithLimits() Showing refresh limit popup")

// OnlineUsersView logs
AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Refresh button tapped - Android parity logic")
AppLogger.log(tag: "LOG-APP: OnlineUsersView", message: "refreshButtonTapped() Showing refresh limit popup")
```

## 12. Current State Management

### 12.1 DiscoverTabView State Variables
```swift
@State private var showRefreshLimitPopup: Bool = false
@State private var refreshLimitResult: FeatureLimitResult?
```

### 12.2 MainView State Variables
```swift
@State private var showRefreshPopUp = false
```

### 12.3 OnlineUsersView State Binding
```swift
@Binding var showRefreshPopUp: Bool
```

## 13. Current Popup Styling

### 13.1 RefreshLimitPopupView Design
- **Background**: System background with 16pt corner radius
- **Shadow**: 10pt radius for depth
- **Padding**: 32pt horizontal, 24pt vertical
- **Colors**: Uses system colors and app theme colors
- **Animation**: Scale and opacity transition with spring animation

### 13.2 Consistent Design
- **Background**: System background with corner radius and shadow
- **Buttons**: Consistent styling across all refresh-related popups
- **Timer Animation**: Live countdown with visual progress indication

## 14. Current Integration Dependencies

### 14.1 Internal Dependencies
- `SubscriptionSessionManager` - Lite subscription status validation
- `SessionManager` - configuration storage and new user period settings
- `UserSessionManager` - first account creation time for new user detection
- `OnlineUsersViewModel` - user list refresh logic
- `SubscriptionsManagerStoreKit2` - pricing information for popup display

### 14.2 External Dependencies
- **UserDefaults** - persistent configuration storage
- **Firebase Firestore** - backend data source
- **Timer** - cooldown countdown functionality

## 15. User Flow Priority Logic

### 15.1 Refresh Permission Priority
The system checks user eligibility in the following order:

1. **Lite Subscription Check** (Highest Priority)
   - If user has active Lite subscription → Allow unlimited refreshes
   - Skip all other checks

2. **New User Check** (Second Priority)  
   - If user is within new user free period → Allow unlimited refreshes
   - Skip limit and cooldown checks

3. **Usage Limit Check** (Third Priority)
   - If user hasn't exceeded free refresh limit → Allow refresh
   - Increment usage counter

4. **Cooldown Check** (Lowest Priority)
   - If user exceeded limit but cooldown expired → Reset counter and allow refresh
   - If still in cooldown → Show popup with timer

### 15.2 Business Logic Flow
```
User taps "Refresh users" button
    ↓
Is Lite Subscriber?
    ↓ YES → Direct refresh (no popup)
    ↓ NO
Is New User (within free period)?
    ↓ YES → Direct refresh (no popup)
    ↓ NO
Always show RefreshLimitPopupView
    ↓
User sees popup with:
    - Refresh button (changes based on limit status)
    - Subscribe to ChatHub Lite button
    ↓
Refresh button behavior:
    - If under limit: "Refresh Users" (green, enabled)
    - If over limit: Shows timer and progress bar (gray, disabled)
```

## 16. Current Known Issues and Limitations

### 16.1 Simplified Implementation
- Only one refresh mechanism: manual refresh button in OnlineUsersView
- Pull-to-refresh functionality removed from DiscoverTabView
- Consistent popup design using RefreshLimitPopupView

### 16.2 Configuration Source
- Uses hardcoded defaults instead of Firebase Remote Config
- No dynamic configuration updates during runtime
- Limited ability to adjust limits remotely

### 16.3 User Experience Considerations
- Very restrictive limits for non-Lite subscribers: only 2 refreshes per 2-minute cooldown
- New users get unlimited refreshes during their initial free period (configurable, typically 2-7 hours)
- Lite subscription required for unlimited refresh access after new user period expires

## 17. Firebase Analytics Implementation

### 17.1 Analytics Architecture
The refresh feature implements comprehensive Firebase Analytics tracking through a dedicated `RefreshAnalytics` service that follows the established `SubscriptionAnalytics` pattern. This provides deep insights into user behavior, conversion funnels, and business metrics.

**iOS-Specific Naming Strategy**: All event names and parameter keys are prefixed with `ios_` to clearly distinguish iOS analytics data from Android analytics data in Firebase console. This prevents data mixing and enables platform-specific analysis and optimization strategies.

### 17.2 Key Events Tracked
- **User Actions**: Button taps, popup interactions, refresh completions
- **System Events**: Limit reached, cooldown periods, automatic resets
- **Business Events**: Subscription button clicks, pricing displays, conversion funnel progression
- **User Segmentation**: Lite subscribers, new users, free users with detailed context

### 17.3 Analytics Events List (iOS-specific naming)
```swift
// Core Refresh Events
ios_refresh_button_tapped          // Every button tap with context
ios_refresh_popup_shown           // Popup display with trigger reason
ios_refresh_popup_dismissed       // How and when popup was closed
ios_refresh_performed             // Successful refresh completion
ios_refresh_blocked_limit_reached // Hit usage limit
ios_refresh_blocked_cooldown      // In cooldown period

// Business Conversion Events  
ios_refresh_subscription_button_tapped  // Subscription intent from popup
ios_refresh_pricing_displayed          // Pricing information shown

// User Segment Events
ios_refresh_new_user_bypass           // New user unlimited access
ios_refresh_lite_subscriber_bypass    // Lite subscriber unlimited access

// System Events
ios_refresh_limit_reset              // Automatic limit reset
ios_refresh_cooldown_completed       // Cooldown period finished
```

### 17.4 Analytics Parameters (iOS-specific naming)
Each event includes rich contextual parameters with iOS-specific prefixes:
- **User Context**: `ios_user_id`, `ios_subscription_status`, `ios_user_type`, `ios_is_anonymous`
- **Usage Data**: `ios_current_usage`, `ios_usage_limit`, `ios_remaining_cooldown_seconds`, `ios_session_refresh_count`
- **Business Context**: `ios_subscription_price_displayed`, `ios_conversion_funnel_step`, `ios_popup_trigger_reason`
- **Technical Context**: `ios_app_version`, `ios_platform`, `ios_timestamp`, `ios_session_id`

### 17.5 Analytics Integration Points
- **RefreshLimitManager**: Tracks refresh outcomes and blocking reasons
- **OnlineUsersView**: Tracks button taps and user segment bypass logic
- **RefreshLimitPopupView**: Tracks popup interactions, timing, and subscription clicks
- **Automatic Triggers**: System events like cooldown completion and limit resets

## 18. UI/UX Design Principles

### 18.1 Popup Visual Design
**Design Reference**: All styling follows `LiveCallPopupView.swift` patterns for consistent app-wide modal presentation standards.
- **Enhanced Background Contrast**: Dark overlay (0.4 opacity) matching LiveCallPopupView standards for optimal visibility
- **Consistent Modal Background**: Uses Color("shade2") following app-wide popup design patterns from LiveCallPopupView
- **Professional Corner Radius**: 20px with .continuous style matching live popup for modern iOS appearance
- **Refined Visual Effects**: Enhanced border (1.5px, 80% opacity) for subtle definition without shadow
- **Adaptive Themes**: Popup background uses custom shade2 color that automatically adapts to light/dark themes
- **Standard Typography Hierarchy**: System fonts matching live popup - title (18pt bold), description (14pt), buttons (14pt bold)

#### Standard Font Hierarchy Structure (LiveCallPopupView Pattern):
1. **Primary Title**: `.system(size: 18, weight: .bold)` + Color("dark") - "Refresh Users" - most prominent  
2. **Description**: `.system(size: 14)` + Color("shade_800") - explanation text - secondary importance  
3. **Button Icons**: `.title3` - action icons - visual emphasis
4. **Button Text**: `.system(size: 14, weight: .bold)` - primary actions - consistent with live popup
5. **Timer/Pricing**: `.system(size: 14, weight: .medium)` - dynamic information - subtle hierarchy

### 18.2 Content Strategy
- **Static Information**: Title and description never change to provide consistent user understanding
- **Dynamic Elements**: Only the refresh button changes state to show timer and availability
- **No Misleading Content**: Descriptions don't manipulate users with changing limit information

### 18.3 Button Design Consistency
- **Subscription Button**: Uses exact same gradient and icon as main subscription views for brand consistency
- **Navigation Behavior**: Opens full SubscriptionView as new screen intent (not modal) matching main app subscription button behavior
- **Color Gradients**: Lite subscription uses `liteGradientStart` and `liteGradientEnd` colors
- **Icon Consistency**: `star.circle.fill` matches subscription status buttons throughout the app

### 18.4 Smart Limit Logic
- **Correct Usage Flow**: With limit=2, users can complete 2 refreshes without any restrictions
- **Popup Timing**: Shows only when user attempts 3rd refresh (`currentUsage >= limit`)
- **Cooldown Activation**: Cooldown starts when user first exceeds limit, not during successful refreshes
- **No Premature Blocking**: Users get full use of their allocated refreshes before any restrictions

#### Detailed Flow with Limit=2:
1. **1st Refresh**: `currentUsage=0` → Proceed, increment to 1, no popup
2. **2nd Refresh**: `currentUsage=1` → Proceed, increment to 2, no popup  
3. **3rd Attempt**: `currentUsage=2` → Show popup (no timer yet), block action
4. **User Clicks Refresh in Popup**: Start cooldown, show timer for future attempts

### 18.5 Advanced Liquid Animation System
- **Dual Animation Architecture**: Combines countdown progress (left-to-right shrinking) with realistic liquid wave effects for premium user experience
- **Progress Bar Foundation**: Gray overlay anchored to left edge shrinks rightward as time decreases, revealing green gradient from right side
- **Psychologically Correct Direction**: Left-to-right shrinking animation mirrors mental model of countdown timers (time draining away, not increasing)

#### 18.5.1 Wave Animation Components
- **WaveProgressView**: Custom SwiftUI component using Path and Timer-based animation for realistic liquid edge effects
- **Directional Wave Flow**: Sine wave patterns flow vertically along right edge with bidirectional oscillation (up-to-down, then down-to-up)
- **Individual Wave Heights**: Each wave position has independent height oscillation ranging from 50% to 130% of base height (1px to 2.6px)
- **Dual Animation Cycles**: Directional flow and height variations operate on different time scales for complex, natural patterns

#### 18.5.2 Wave Animation Parameters
- **Base Wave Height**: 2px for subtle, professional appearance
- **Wave Length**: 20px spacing between wave peaks for multiple visible waves
- **Update Frequency**: 60 FPS (0.016s intervals) for butterscotch-smooth animation
- **Directional Speed**: 0.125 increment per frame for moderate oscillation pace
- **Height Time Scale**: 0.5x directional speed for slower, independent height changes
- **Wave Count**: Approximately 2-3 complete wave cycles visible simultaneously

#### 18.5.3 Oscillation Behavior
- **Bidirectional Flow**: Waves flow from top-to-bottom, then reverse to bottom-to-top in π to -π range cycles
- **Individual Height Cycles**: Each wave position uses unique phase offset (y/waveLength * 3.0) for staggered height animations
- **Natural Liquid Motion**: Combined directional flow + height variations create realistic liquid draining effect
- **Continuous Animation**: No pauses or stops - waves continuously flow and height-oscillate throughout cooldown

#### 18.5.4 Technical Implementation
- **Timer-Based Animation**: Uses `Timer.scheduledTimer` for precise control independent of SwiftUI animation system
- **Path-Based Rendering**: Custom Path construction with sine wave calculations for smooth curves
- **Memory Management**: Proper timer cleanup in `onDisappear` to prevent memory leaks
- **Performance Optimized**: 60 FPS updates with minimal computational overhead

#### 18.5.5 Animation Evolution & Refinements
The liquid animation system underwent multiple iterations to achieve the current sophisticated implementation:

**Phase 1 - Basic Progress Bar**:
- Simple gray rectangle shrinking with linear animation
- Static visual with no liquid characteristics

**Phase 2 - Initial Wave Implementation**:
- Added basic sine wave pattern to right edge
- Single global wave animation with uniform height
- Animation issues: choppy movement, wrong direction

**Phase 3 - Direction Correction**:
- Fixed animation direction to proper left-to-right shrinking
- Corrected visual flow to match countdown psychology
- Improved smoothness with optimized timing

**Phase 4 - Smooth Animation**:
- Increased update frequency from 1.0s to 0.1s intervals (10x smoother)
- Changed from 1.0s linear animation to 0.2s easeInOut for fluidity
- Created "butterscotch-smooth" countdown experience

**Phase 5 - Enhanced Wave Motion**:
- Added bidirectional wave oscillation (forward/backward flow)
- Implemented proper vertical wave movement instead of horizontal shifting
- Multiple wave cycles for realistic liquid appearance

**Phase 6 - Speed Optimization**:
- Reduced oscillation speed by 50% for comfortable viewing
- Balanced wave frequency and amplitude for professional appearance
- Fine-tuned animation parameters for optimal user experience

**Phase 7 - Individual Wave Heights**:
- Implemented position-based height variation for each wave
- Added time-dependent height oscillation independent of directional flow
- Created complex, natural liquid patterns with staggered wave animations

**Final Result**: Premium liquid draining animation combining multiple sophisticated effects for industry-leading countdown user experience.

### 18.6 Manual Action Requirement
- **No Auto-Refresh**: When countdown completes, popup remains open waiting for user action
- **Manual Trigger**: User must explicitly click refresh button even after cooldown expires
- **Visual State Change**: Button appearance changes from disabled/timer to enabled/green when ready
- **User Control**: Ensures users have full control over when refresh action occurs

### 18.7 Structured Button Layout Design
- **Left-Right Alignment Strategy**: All buttons use consistent left-aligned content with right-aligned dynamic elements
- **Optimized Padding System**: 8px padding on both left and right sides for tighter, more compact button layout
- **Static Left Content**: Icon and primary text never change position or content
- **Dynamic Right Content**: Timer/pricing aligned to right side with same 8px padding

#### Refresh Button Structure:
- **Left**: Arrow icon + "Refresh Users" (always consistent)
- **Right**: Timer display only during cooldown (maintains spacing when absent)
- **Font Consistency**: .headline for all text elements

#### Subscription Button Structure:
- **Left**: Star icon + "Subscribe to Lite" (shortened from "ChatHub Lite")
- **Right**: Pricing information when available (maintains spacing when absent)  
- **Font Consistency**: .headline for both main text and pricing

### 18.8 Layout Stability Features
- **No Content Shifts**: Primary text and icons never move regardless of button state
- **Consistent Dimensions**: Button heights remain identical in all states using invisible placeholder text
- **Height Preservation**: Invisible text elements (`opacity: 0`) maintain layout structure when dynamic content is absent
- **Balanced Spacing**: Equal padding prevents cramped or stretched appearance
- **Professional Polish**: Structured layout creates premium app feel

#### Height Consistency Implementation:
- **Refresh Button**: Uses invisible "00:00" timer text when countdown not active
- **Subscription Button**: Uses invisible "$0.00/week" pricing text when price unavailable
- **Same Typography**: Invisible elements use identical font and weight as visible counterparts

## 19. App Lifecycle and Refresh Behavior

### 19.1 App State Change Handling
The ChatHub iOS app is designed to **respect user control** and **prevent unwanted data usage** by avoiding automatic refreshes on app lifecycle events:

#### 19.1.1 App Launch Behavior
- **No Automatic Refresh**: When app launches, user lists are NOT automatically refreshed
- **Cached Data Display**: Shows previously cached user data immediately
- **User Control**: Users must manually navigate to OnlineUsersView to trigger any refresh logic
- **Network Conservation**: No network requests on app startup for user list data

#### 19.1.2 App Resume from Background
- **No Automatic Refresh**: When app returns from background, user lists are NOT automatically refreshed
- **OnlineStatusService**: Only updates user's own online status (not user list data)
- **Preserved State**: All cached data and UI state remain unchanged
- **Manual Navigation**: Users must manually visit OnlineUsersView to trigger 30-minute staleness check

#### 19.1.3 OnlineUsersView Navigation
- **Smart Refresh**: Only triggers when user actively navigates to the OnlineUsersView
- **30-Minute Check**: Evaluates data staleness only when user explicitly visits the view
- **Immediate Display**: Always shows cached data first, then optionally syncs fresh data in background
- **User Initiated**: All refresh actions stem from user navigation choices, not automatic app events

### 19.2 Comparison with Other Features
Unlike some other app features that may refresh on app resume (like ChatsViewModel), the OnlineUsersView specifically avoids automatic refresh to:
- **Reduce Data Usage**: Prevent unnecessary Firebase API calls
- **Improve Performance**: Avoid blocking UI with loading states on app resume
- **Enhance User Experience**: Show content immediately without refresh delays
- **Respect User Intent**: Only refresh when users explicitly navigate to discover new users

### 19.3 Time-Based Refresh vs. Manual Refresh
- **Time-Based (30-minute)**: Automatic background sync when navigating to OnlineUsersView if data is stale
- **Manual Refresh**: Explicit user action via "Refresh users" button, subject to refresh limits for non-Lite users
- **Both Respect Limits**: Manual refresh button triggers RefreshLimitManager, time-based refresh updates timestamp for all users
- **Different Purposes**: Time-based maintains data freshness, manual refresh gives users control over immediate updates

## 20. File Locations Summary

### 20.1 Core Services
- `chathub/Core/Services/Core/RefreshLimitManager.swift` - Main refresh limit logic
- `chathub/Core/Services/Core/FeatureLimitManager.swift` - Base limit manager  
- `chathub/Core/Services/Core/SessionManager.swift` - Configuration storage and 30-minute refresh logic
- `chathub/Core/Services/Core/UserSessionManager.swift` - Refresh time tracking and staleness detection
- `chathub/Core/Services/Analytics/RefreshAnalytics.swift` - Comprehensive analytics tracking

### 20.2 UI Components
- `chathub/Views/Users/OnlineUsersView.swift` - Manual refresh button, popup, and onAppear logic
- `chathub/Views/Popups/RefreshLimitPopupView.swift` - Refresh limit popup
- `chathub/Views/Main/MainView.swift` - Main app view

### 20.3 View Models
- `chathub/ViewModels/OnlineUsersViewModel.swift` - User list refresh logic, time-based refresh, and data management

---

*This document reflects the current state of the Refresh Feature implementation in the ChatHub iOS application as of the latest codebase analysis.*
# Online Users Loading and Display Implementation Analysis

## Overview

This document provides a comprehensive analysis of how online user lists are loaded from Firebase, stored in local SQLite database, and displayed throughout the ChatHub iOS application. It covers all triggers, conditions, functions, and implementation details related to online users management.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Data Flow and Loading Triggers](#data-flow-and-loading-triggers)
4. [Local Database Operations](#local-database-operations)
5. [Firebase Loading Implementation](#firebase-loading-implementation)
6. [Filter Integration](#filter-integration)
7. [Refresh Mechanisms](#refresh-mechanisms)
8. [App Lifecycle Integration](#app-lifecycle-integration)
9. [User Interface Integration](#user-interface-integration)
10. [Error Handling and Edge Cases](#error-handling-and-edge-cases)
11. [Performance Optimizations](#performance-optimizations)
12. [Session Management](#session-management)

## Architecture Overview

The online users system follows a three-tier architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Interface│    │  Business Logic │    │   Data Sources  │
│                 │    │                 │    │                 │
│ OnlineUsersView │────│OnlineUsersVM    │────│ OnlineUsersDB   │
│ OnlineUserRow   │    │                 │    │ Firebase        │
│ FiltersView     │    │ Filters         │    │ SessionManager  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Design Principles

1. **Android Parity**: Implementation matches Android version exactly
2. **Local-First**: Always load from SQLite database first, then sync with Firebase
3. **30-Minute Staleness**: Automatic Firebase refresh after 30 minutes
4. **Rate Limiting**: Refresh limits based on subscription tier
5. **Filter Integration**: Filters trigger fresh Firebase sync

## Core Components

### 1. OnlineUsersViewModel (Main Controller)

**Location**: `chathub/ViewModels/OnlineUsersViewModel.swift`

**Key Properties**:
```swift
@Published var users: [OnlineUser] = []
@Published var filter: OnlineUserFilter = OnlineUserFilter()
@Published var isLoading: Bool = false
@Published var errorMessage: String? = nil
@Published var hasMore: Bool = true

private let onlineUsersDB = OnlineUsersDB.shared
private let userSessionManager = UserSessionManager.shared
private let pageSize = 10
private var currentPage = 0
```

**Primary Functions**:
- `initialLoadIfNeeded()` - Entry point for view appearances
- `fetchUsers()` - Main loading logic with 30-minute staleness check
- `loadUsersFromLocalDatabase()` - Instant local database loading
- `refreshUsersFromLocalDatabase()` - Complete local refresh for filters
- `fetchMoreUsers()` - Pagination from local database
- `forceRefreshUsers()` - Firebase refresh for filters (clears database)
- `manualRefreshUsers()` - Firebase refresh for manual refresh button
- `applyFilter()` - Apply new filter with Firebase sync
- `triggerBackgroundDataSync()` - Firebase Firestore query execution

### 2. OnlineUsersDB (Local Database)

**Location**: `chathub/Core/Database/OnlineUsersDB.swift`

**Database Schema**:
```sql
CREATE TABLE IF NOT EXISTS OnlineUsers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    user_name TEXT NOT NULL DEFAULT '',
    user_image TEXT DEFAULT '',
    user_gender TEXT DEFAULT '',
    user_country TEXT DEFAULT '',
    user_language TEXT DEFAULT '',
    user_age TEXT DEFAULT '',
    user_device_id TEXT DEFAULT '',
    user_device_token TEXT DEFAULT '',
    user_area TEXT DEFAULT '',
    user_city TEXT DEFAULT '',
    user_state TEXT DEFAULT '',
    user_decent_time INTEGER DEFAULT 0,
    user_last_time_seen INTEGER DEFAULT 0,
    isAd INTEGER DEFAULT 0,
    UNIQUE(user_id) ON CONFLICT REPLACE
);
```

**Key Functions**:
- `query()` - Retrieve all users ordered by last_time_seen DESC
- `insert()` - Insert/update user with complete data
- `deleteAllOnlineUsers()` - Clear entire table
- `clearCorruptedData()` - Remove invalid/ad users
- `getAreaUsers()`, `getCityUsers()`, `getStateUsers()` - Location-based queries
- `isUserInOnlineUserList()` - Check user existence
- `selectLastOnlineUserTime()` - Get latest user timestamp

### 3. OnlineUsersView (User Interface)

**Location**: `chathub/Views/Users/OnlineUsersView.swift`

**Key Features**:
- Filter button triggering `FiltersView`
- Refresh button with rate limiting
- Infinite scrolling with pagination
- Navigation to user profiles
- Loading states and error handling

### 4. OnlineUsersService (Firebase Integration)

**Location**: `chathub/Core/Services/User/OnlineUsersService.swift`

**Purpose**: Android equivalent of OnlineUsersWorker
**Key Functions**:
- `fetchOnlineUsers()` - Main Firebase fetching with filters
- `buildQuery()` - Construct Firestore queries with filters
- `getAllUsers()` - Execute Firestore query with pagination

## Data Flow and Loading Triggers

### 1. Initial App Usage (First Time Only)

**Trigger**: User opens OnlineUsersView with no cached data
**Condition**: `users.isEmpty = true`
**Flow**:
```
OnlineUsersView.onAppear
    ↓
viewModel.initialLoadIfNeeded()
    ↓
users.isEmpty = true → viewModel.fetchUsers()
    ↓
loadUsersFromLocalDatabase() → localUsers = []
    ↓
needsFirebaseSync = true (empty database)
    ↓
triggerBackgroundDataSync() → Firebase Query
    ↓
Firebase documents → onlineUsersDB.insert()
    ↓
setOnlineUsersRefreshTime() → Update timestamp
    ↓
loadUsersFromLocalDatabase() → Update UI
```

### 2. 30-Minute Automatic Refresh

**Trigger**: User opens OnlineUsersView after 30+ minutes since last refresh
**Condition**: `userSessionManager.shouldRefreshOnlineUsersFromFirebase() = true`
**Implementation**:
```swift
func shouldRefreshOnlineUsersFromFirebase() -> Bool {
    let lastRefresh = onlineUsersRefreshTime
    let thirtyMinutesAgo = Date().timeIntervalSince1970 - (30 * 60)
    return lastRefresh < thirtyMinutesAgo
}
```

**Flow**:
```
OnlineUsersView.onAppear
    ↓
viewModel.initialLoadIfNeeded()
    ↓
users.count > 0 → viewModel.fetchUsers()
    ↓
loadUsersFromLocalDatabase() → Show cached data instantly
    ↓
shouldRefreshOnlineUsersFromFirebase() = true
    ↓
Clear all filters (for fresh data)
    ↓
triggerBackgroundDataSync() → Firebase Query
    ↓
setOnlineUsersRefreshTime() → Update timestamp
    ↓
loadUsersFromLocalDatabase() → Merge new data
```

### 3. Manual Refresh Button

**Trigger**: User taps "Refresh users" button
**Rate Limiting**: Based on subscription tier and usage
**Flow**:
```
OnlineUsersView.handleRefreshButtonTapped()
    ↓
RefreshLimitManager.checkRefreshLimit()
    ↓
IF showPopup = true:
    RefreshLimitPopupView → User confirmation
    ↓
RefreshLimitManager.performRefresh()
    ↓
viewModel.manualRefreshUsers()
    ↓
triggerBackgroundDataSync() (keeps existing filters)
    ↓
refreshUsersFromLocalDatabase() → Complete UI refresh
```

### 4. Apply New Filters

**Trigger**: User applies filters in FiltersView and taps "Apply"
**Rate Limiting**: Based on subscription tier and usage (2 filter applications per 2-minute cooldown for free users)
**Flow**:
```
FiltersView.applyFilters()
    ↓
Save filter criteria to UserSessionManager
    ↓
performFilterWithLimits()
    ↓
FilterLimitManager.checkFilterLimit()
    ↓
IF showPopup = true (non-Lite/non-new users):
    FilterLimitPopupView → User confirmation
    ↓
    IF confirmed: handleFilterAction()
    ↓
FilterLimitManager.performFilter()
    ↓
proceedWithFilterApplication()
    ↓
deleteAllOnlineUsers() → Clear cached results
    ↓
onFiltersApplied callback to OnlineUsersView
    ↓
viewModel.applyFilter(newFilter)
    ↓
forceRefreshUsers()
    ↓
clearOnlineUsersDatabase() → Clear local data
    ↓
isLoading = true, users = [] → Clear UI
    ↓
triggerBackgroundDataSync() → Firebase Query with filters
    ↓
refreshUsersFromLocalDatabase() → Show filtered results
```

### 5. Clear Filters

**Trigger**: User clears filters in FiltersView
**Behavior**: Only clears filter state, no data reload
**Flow**:
```
FiltersView.onFiltersCleared
    ↓
viewModel.clearFilterLocallyOnly()
    ↓
filter = OnlineUserFilter() → Reset filter object
    ↓
saveFilter() → Update UserSessionManager
    ↓
No database operations or UI changes
    ↓
User must manually refresh to see unfiltered data
```

### 6. Pagination (Load More)

**Trigger**: User scrolls near bottom of list
**Condition**: `index == viewModel.users.count - 5`
**Flow**:
```
OnlineUserRow.onAppear (last 5 users)
    ↓
viewModel.fetchMoreUsers()
    ↓
hasMore = true && !isLoading
    ↓
onlineUsersDB.query() → Get all local users
    ↓
applyLocalFilters() → Apply current filters
    ↓
Paginate: startIndex = currentPage * pageSize
    ↓
Extract next page and filter duplicates
    ↓
users.append(uniqueNewUsers) → Update UI
    ↓
currentPage += 1, hasMore = endIndex < filteredUsers.count
```

## Local Database Operations

### Database Initialization

**Location**: `OnlineUsersDB.init()` → `createTableIfNeeded()`
**Timing**: Application startup via DatabaseManager
**Features**:
- Creates table with complete schema if not exists
- Creates performance indexes (user_id, last_time_seen, etc.)
- Handles database migrations and schema updates

### Data Corruption Handling

**Function**: `clearCorruptedData()`
**Called**: OnlineUsersViewModel initialization
**Purpose**: Remove invalid records
**Query**:
```sql
DELETE FROM OnlineUsers 
WHERE user_id IS NULL 
   OR user_id = '' 
   OR user_name IS NULL 
   OR user_name = '' 
   OR length(user_id) < 3 
   OR length(user_name) < 1 
   OR user_id LIKE '%_ad_%';
```

### Primary Query Operations

**Main Query**: `query()` - Returns all users ordered by last activity
```sql
SELECT * FROM OnlineUsers 
ORDER BY user_last_time_seen DESC 
LIMIT 250;
```

**Location-Based Queries**:
- `getAreaUsers(userArea: String)` - Filter by user_area
- `getCityUsers(userCity: String)` - Filter by user_city  
- `getStateUsers(userState: String)` - Filter by user_state

**Utility Queries**:
- `isUserInOnlineUserList(userId: String)` - Check existence
- `selectLastOnlineUserTime()` - Get latest timestamp for pagination

### Insert/Update Operations

**Primary Insert**: `insert()` with 15 parameters matching Firebase data
**Features**:
- INSERT OR REPLACE for upsert behavior
- Proper UTF-8 string handling with strdup/free
- Comprehensive parameter validation
- Async execution on dedicated database queue

**Legacy Support**: `insert()` with old parameter format for backward compatibility

## Firebase Loading Implementation

### Firebase Query Construction

**Location**: `OnlineUsersViewModel.triggerBackgroundDataSync()`
**Base Query**:
```swift
var query: Query = Firestore.firestore().collection("Users")
    .order(by: "last_time_seen", descending: true)
    .limit(to: 50)
```

### Filter Application

**Gender Filters**:
```swift
if male && !female {
    query = query.whereField("User_gender", isEqualTo: "Male")
}
if female && !male {
    query = query.whereField("User_gender", isEqualTo: "Female")
}
// Both selected = no gender filter applied
```

**Location Filters**:
```swift
if !country.isEmpty {
    query = query.whereField("User_country", isEqualTo: country)
}
if !language.isEmpty {
    query = query.whereField("user_language", isEqualTo: language)
}
if !nearby.isEmpty {
    query = query.whereField("user_city", isEqualTo: nearby)
}
```

### Data Processing and Storage

**Flow**:
1. Execute Firebase query asynchronously
2. Process each document:
   - Extract user data with null checks
   - Skip current user (exclude self)
   - Skip users with empty names
3. Insert each valid user into SQLite database
4. Call completion handler
5. Update UI from local database

**Error Handling**:
- Network errors logged but don't crash app
- Invalid documents skipped with logging
- Malformed data filtered out during processing

## Filter Integration

### FilterLimitPopupView Component

**Location**: `chathub/Views/Popups/FilterLimitPopupView.swift`

**Purpose**: Rate limiting interface for filter applications with subscription promotion

**Key Features**:

1. **Dynamic State Display**:
```swift
// When user has remaining filters
Text("Apply advanced filters to find your perfect match. Upgrade to ChatHub Lite subscription to unlock unlimited filter applications.")

// When user is in cooldown
Text("You've used your \(limit) free filter applications. Subscribe to ChatHub Lite for unlimited access or wait for the timer to reset.")
```

2. **Real-Time Progress Bar**:
```swift
// Decreases from right to left as cooldown progresses
Rectangle()
    .fill(LinearGradient(colors: [Color("liteGradientStart"), Color("liteGradientEnd")]))
    .frame(width: geometry.size.width * CGFloat(remainingTime / totalCooldownDuration))
    .animation(.linear(duration: 0.1), value: remainingTime)
```

3. **Dual Timer System**:
- **UI Timer**: Updates every 0.1 seconds for smooth animation
- **Background Timer**: Safety net checking every 1 second for precision
- **Background Safety**: Continues operation even when app is backgrounded

4. **Action Buttons**:
- **Apply Filters Button**: Enabled when user has remaining applications or cooldown expired
- **Subscribe to Lite Button**: Direct upgrade with pricing display
- **Right-side Indicators**: Shows remaining filters count or countdown timer

5. **Analytics Integration**:
```swift
// Track popup display, user interactions, and conversion events
FilterAnalytics.shared.trackFilterPopupShown()
FilterAnalytics.shared.trackFilterPopupDismissed()
FilterAnalytics.shared.trackSubscriptionButtonTapped()
```

### Filter State Management

**Storage**: `UserSessionManager` individual properties
```swift
// Gender: "Male", "Female", or nil
userSessionManager.filterGender

// Location filters
userSessionManager.filterCountry
userSessionManager.filterLanguage
userSessionManager.filterNearbyOnly: Bool

// Age filters
userSessionManager.filterMinAge
userSessionManager.filterMaxAge
```

### Filter Loading

**Location**: `OnlineUsersViewModel.loadFiltersFromSessionManager()`
**Process**:
1. Load individual filter properties from UserSessionManager
2. Convert to OnlineUserFilter object
3. Handle special cases (e.g., "both" gender selection)

### Local Filter Application

**Function**: `applyLocalFilters(to users: [Users]) -> [Users]`
**Filters Applied**:

1. **Gender Filter**:
```swift
if filter.male && !filter.female && user.user_gender.lowercased() != "male" {
    return false // Exclude user
}
```

2. **Country Filter**:
```swift
if !filter.country.isEmpty && user.user_country != filter.country {
    return false
}
```

3. **Language Filter**:
```swift
if !filter.language.isEmpty && user.user_language != filter.language {
    return false
}
```

4. **Age Range Filter**:
```swift
if let minAge = Int(filter.minAge), let userAge = Int(user.user_age) {
    if userAge < minAge { return false }
}
```

5. **Nearby Filter**:
```swift
if filter.nearby == "yes" {
    let currentUserCity = UserSessionManager.shared.userRetrievedCity
    if user.user_city != currentUserCity { return false }
}
```

### Filter Behavior Modes

**Apply Filters**: Forces Firebase refresh with database clearing
**Clear Filters**: Only resets filter state, no data changes
**Periodic Refresh**: Automatically clears filters for fresh data

## Refresh Mechanisms

### 1. Rate Limiting System

**Manager**: `RefreshLimitManager.shared`
**Rules**:
- **Lite Subscribers**: Unlimited refreshes
- **New Users**: Free period with unlimited refreshes  
- **Regular Users**: Limited refreshes with cooldown periods

**Implementation**:
```swift
func checkRefreshLimit() -> FeatureLimitResult {
    // Check subscription status
    // Check user account age
    // Check current usage vs limits
    // Return result with popup/proceed decision
}
```

### 2. Refresh Button Handling

**Location**: `OnlineUsersView.handleRefreshButtonTapped()`
**Flow**:
1. Check refresh limits via `RefreshLimitManager`
2. Track analytics for button taps
3. Show popup for rate-limited users
4. Allow direct refresh for premium users
5. Execute `manualRefreshUsers()` on approval

### 3. Refresh Types

**Manual Refresh** (`manualRefreshUsers()`):
- Keeps existing database data during refresh
- Preserves current filter settings
- Shows loading state without clearing UI
- Smooth user experience with background sync

**Force Refresh** (`forceRefreshUsers()`):
- Clears database before refresh  
- Used for filter applications
- Clears UI immediately
- Ensures filter changes are applied correctly

**Automatic Refresh** (30-minute logic):
- Triggered by `shouldRefreshOnlineUsersFromFirebase()`
- Clears filters for fresh data
- Background sync with cached data visible
- Updates timestamp after successful completion

### 4. Filter Limit System

**Manager**: `FilterLimitManager.shared`
**Implementation**: Extends `BaseFeatureLimitManager` for consistency with refresh and search limits

**Rules**:
- **Lite Subscribers**: Unlimited filter applications, no popups
- **New Users**: Free period with unlimited filters during onboarding
- **Regular Users**: 2 filter applications per 2-minute cooldown period

**Rate Limiting Flow**:
1. User applies filters in FiltersView
2. `FilterLimitManager.checkFilterLimit()` - Check current usage vs limits
3. **Always Show Popup Strategy**: Non-Lite/non-new users see `FilterLimitPopupView`
4. Popup displays current usage, remaining filters, or cooldown timer
5. User can proceed with filter application or upgrade to Lite subscription

**Key Features**:
- **Real-time Countdown**: Progress bar and timer during cooldown periods
- **Subscription Promotion**: Direct upgrade to Lite subscription with pricing
- **Analytics Tracking**: Comprehensive usage and conversion tracking
- **Background Safety**: Cooldown continues even if app is backgrounded

## App Lifecycle Integration

### Initialization Sequence

**Application Launch**:
1. `OnlineUsersViewModel.init()` - Initialize but don't load data
2. `clearCorruptedData()` - Clean up invalid records
3. `loadFilter()` - Load saved filter preferences
4. Data loading deferred until view appears

**View Appearance**:
1. `OnlineUsersView.onAppear` - View lifecycle trigger
2. `initialLoadIfNeeded()` - Check if loading required
3. `fetchUsers()` - Main loading logic with 30-minute check
4. `hasInitiallyLoaded` flag prevents redundant loads

### Background/Foreground Handling

**No Automatic Refresh**: The system deliberately prevents automatic refreshes when app becomes active or returns from background to avoid unwanted network usage.

**User-Triggered Only**: All refreshes require explicit user interaction via:
- Manual refresh button
- Filter applications  
- View navigation (with 30-minute staleness check)

### Background Task System

**Status**: ❌ **REMOVED** - Unnecessary resource consumption

**Previous Implementation**: 
- Was located in `chathub/Core/Utilities/Managers/BackgroundTaskManager.swift`
- Scheduled Firebase fetches every 8 minutes when app was backgrounded
- Executed `OnlineUsersService.shared.fetchOnlineUsers()` in background
- Used `OnlineUsersBackgroundOperation` for iOS BGTaskScheduler integration

**Removal Rationale**:
1. **Battery Efficiency**: Background network requests every 8 minutes drain battery unnecessarily
2. **Data Conservation**: Causes unwanted cellular data usage when app is not in use
3. **Cost Optimization**: Reduces Firebase read operations and associated costs
4. **User Experience**: Online users are most relevant when user is actively browsing the app
5. **Local-First Architecture**: App already has comprehensive local database with 30-minute staleness detection
6. **iOS Best Practices**: Background tasks should be reserved for critical user-facing features

**Alternative Strategy**: 
- Rely on foreground-only data loading with intelligent 30-minute refresh logic
- Manual refresh available when users need fresh data immediately
- Filter applications trigger immediate Firebase sync for targeted results
- View appearances handle data loading when users actually need the information

### MainView Integration

**Location**: `chathub/Views/Main/MainView.swift`
**Architecture**: OnlineUsersViewModel created at MainView level
```swift
@StateObject private var onlineUsersViewModel = OnlineUsersViewModel()
```

**Benefits**:
- Persists across tab switches
- Maintains state when navigating away and back
- Prevents redundant initializations
- Shared state across related views

## User Interface Integration

### OnlineUsersView Layout

**Components**:
1. **Filter Button**: Opens FiltersView for filter configuration
2. **Refresh Button**: Triggers manual refresh with rate limiting
3. **User List**: Infinite scroll with pagination
4. **Loading States**: Progress indicators during Firebase sync
5. **Error Handling**: Display error messages when operations fail

### Loading State Management

**Instant Local Loading**:
```swift
// Local database queries are synchronous and instant
let localUsers = self.onlineUsersDB.query()
// UI updates immediately without loading states
```

**Firebase Loading**:
```swift
// Only show loading when actually fetching from Firebase
if needsFirebaseSync {
    isLoading = true
    triggerBackgroundDataSync { 
        self.isLoading = false
    }
}
```

### List Rendering and Updates

**OnlineUserRow**: Individual user display component
- Profile image with online status indicator
- User name and gender information
- Country flag and last seen time
- Navigation to detailed profile view

**Profile Navigation**:
```swift
ForEach(viewModel.users.indices, id: \.self) { index in
    let user = viewModel.users[index]
    ZStack {
        OnlineUserRow(user: user)
        NavigationLink(destination: ProfileView(onlineUser: user)) {
            EmptyView()
        }
        .opacity(0.0)
    }
}
```

**Navigation Flow**:
1. User taps anywhere on `OnlineUserRow`
2. `NavigationLink` triggers navigation to `ProfileView`
3. Complete `OnlineUser` object passed to profile
4. Profile displays user information immediately
5. Additional profile data loaded in background
6. Profile provides access to messaging, calling, and reporting

**Pagination Trigger**:
```swift
.onAppear {
    if index == viewModel.users.count - 5 {
        viewModel.fetchMoreUsers()
    }
}
```

**Data Updates**:
- First load: Replace empty array with initial page
- Pagination: Append unique users to existing array
- Filter refresh: Complete replacement with filtered results
- Manual refresh: Merge new users while preserving scroll position

## Error Handling and Edge Cases

### Database Error Handling

**Connection Issues**:
```swift
guard DatabaseManager.shared.isDatabaseReady() else {
    AppLogger.log(tag: "OnlineUsersDB", message: "Database not ready")
    return []
}
```

**Query Failures**:
```swift
switch result {
case .success(let users):
    return users
case .failure(let error):
    AppLogger.log(tag: "OnlineUsersDB", message: "Query failed: \(error)")
    return []
}
```

### Firebase Error Handling

**Network Errors**:
```swift
if let error = error {
    AppLogger.log(tag: "OnlineUsersViewModel", message: "Firebase error: \(error.localizedDescription)")
    completion?()
    return
}
```

**No Data Scenarios**:
- Empty Firebase response: Continue with existing local data
- No local data + Firebase failure: Show empty state
- Corrupted data: Clean up during initialization

### Edge Cases Handled

1. **Empty Database on First Launch**: Forces Firebase sync regardless of time
2. **Corrupted Records**: Automatic cleanup on initialization
3. **Duplicate Users**: Deduplication during pagination and refresh
4. **Invalid Filter Data**: Graceful fallback to unfiltered results
5. **Network Connectivity**: Graceful degradation to cached data
6. **Memory Pressure**: Limits query results to 250 users maximum

## Performance Optimizations

### Database Optimizations

**Indexes Created**:
```sql
-- Unique index for fast user lookups
CREATE UNIQUE INDEX index_OnlineUsers_user_id ON OnlineUsers(user_id);

-- Performance index for default ordering
CREATE INDEX index_OnlineUsers_user_last_time_seen ON OnlineUsers(user_last_time_seen DESC);

-- Composite indexes for filtering
CREATE INDEX index_OnlineUsers_isAd_last_time ON OnlineUsers(isAd, user_last_time_seen DESC);
CREATE INDEX index_OnlineUsers_user_area ON OnlineUsers(user_area, user_last_time_seen DESC);
CREATE INDEX index_OnlineUsers_user_city ON OnlineUsers(user_city, user_last_time_seen DESC);
CREATE INDEX index_OnlineUsers_user_state ON OnlineUsers(user_state, user_last_time_seen DESC);
```

**Query Limits**:
- Local queries limited to 250 users maximum
- Firebase queries limited to 50 users per request
- Pagination with 10 users per page for UI

### Memory Management

**String Handling**:
```swift
// Proper memory management for C strings
sqlite3_bind_text(statement, 1, strdup(user_id), -1) { ptr in free(ptr) }
```

**Object Lifecycle**:
- Singleton pattern for database connections
- Dedicated serial queues for database operations
- Automatic cleanup of prepared statements

### Network Optimizations

**Intelligent Loading**:
- Local-first architecture minimizes network requests
- 30-minute staleness threshold prevents excessive Firebase calls
- Background sync doesn't block UI updates

**Rate Limiting**:
- Prevents abuse of Firebase quota
- Subscription-based refresh limits
- Cooldown periods for free users

## Session Management

### Refresh Time Tracking

**Storage**: UserSessionManager with UserDefaults persistence
```swift
var onlineUsersRefreshTime: TimeInterval {
    get { defaults.double(forKey: Keys.onlineUsersRefreshTime) }
    set { defaults.set(newValue, forKey: Keys.onlineUsersRefreshTime) }
}
```

**Update Trigger**:
```swift
func setOnlineUsersRefreshTime() {
    onlineUsersRefreshTime = Date().timeIntervalSince1970
}
```

**Called After**:
- Successful Firebase sync operations
- Manual refresh completions
- Filter application completions

### Filter Persistence

**Individual Properties**: Stored separately in UserSessionManager
- `filterGender: String?` - "Male", "Female", or nil
- `filterCountry: String?` - Country code or nil  
- `filterLanguage: String?` - Language code or nil
- `filterNearbyOnly: Bool` - Nearby filter flag
- `filterMinAge: String?` - Minimum age filter
- `filterMaxAge: String?` - Maximum age filter

**Loading**: Filters loaded during ViewModel initialization
**Saving**: Filters saved immediately when applied
**Clearing**: Individual properties reset to nil/false

### Cache Management

**Database Clearing Triggers**:
1. Filter applications (ensures fresh filtered data)
2. Manual cache clearing via CacheManager
3. Database corruption cleanup
4. User logout operations

**Refresh Time Reset Triggers**:
1. Filter clearing operations (forces fresh data on next load)
2. Database cleanup operations
3. Cache manager operations
4. User session resets

## Summary

The online users loading and display system is a sophisticated, multi-layered implementation that prioritizes user experience through local-first data access while maintaining data freshness through intelligent Firebase synchronization. Key aspects include:

1. **Comprehensive Trigger System**: Handles view appearances, manual refreshes, filter applications, and pagination
2. **Intelligent Caching**: 30-minute staleness detection with instant local database access
3. **Optimized Resource Usage**: Removed unnecessary background sync tasks for better battery and data efficiency
4. **Dual Rate Limiting System**: 
   - **Refresh Limits**: Manual refresh button with subscription-based limits and `RefreshLimitPopupView`
   - **Filter Limits**: Filter applications with 2-per-cooldown limits and `FilterLimitPopupView`
5. **Advanced Popup Systems**: Real-time countdown timers, progress bars, subscription promotion, and analytics tracking
6. **Seamless Navigation**: Profile navigation with instant data passing and background enhancement
7. **Robust Error Handling**: Graceful degradation and comprehensive logging
8. **Performance Optimization**: Indexed database queries, memory-conscious operations, and intelligent rate limiting
9. **Android Parity**: Complete compatibility with Android implementation (excluding deprecated background workers)
10. **User Experience Focus**: Instant UI updates, smooth pagination, responsive interactions, and freemium monetization

The system successfully balances data freshness, performance, user experience, and monetization while maintaining scalability and reliability across all usage scenarios. The implementation includes sophisticated rate limiting with popup interfaces that guide users toward subscription upgrades while ensuring fair usage for free users.

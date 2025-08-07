# Online Users Feature Implementation - Feature Document

## Executive Summary

The ChatHub iOS Online Users Feature is the core social discovery system that displays real-time online users for connection and interaction. The system implements a sophisticated three-tier data architecture (Firebase → SQLite → UI) with intelligent caching, 30-minute refresh cycles, and comprehensive filtering capabilities. Users can browse, filter, and interact with online community members through an optimized infinite-scroll interface that supports up to 250 cached users with smart pagination from local storage.

**Core Functionality**: The feature displays a real-time list of online users with profile images, names, gender indicators, and online status. Users can scroll through unlimited profiles, apply comprehensive filters (gender, country, language, age, location), manually refresh the list, and tap users to view detailed profiles. The system implements efficient lazy loading with background Firebase synchronization and local SQLite caching for optimal performance.

**Technical Architecture**: Built on OnlineUsersViewModel with @Published reactive properties, OnlineUsersDB for local persistence, OnlineUsersService for Firebase synchronization, and comprehensive filter integration. Features 30-minute automatic refresh cycles, smart pagination from local cache, duplicate prevention, corruption handling, and seamless navigation to ProfileView for user interaction.

## 1. Overview

This document describes the **current implementation** of the Online Users Feature in the ChatHub iOS application. The feature serves as the primary social discovery mechanism, allowing users to browse, filter, and connect with other online community members.

### 1.1 Feature Status

**Current Status**: ✅ **Fully Operational** - All online user functionality is working correctly with optimized performance and comprehensive filter integration.

**Key Capabilities**:
- Real-time online user discovery with up to 250 cached profiles
- Intelligent 30-minute refresh cycle with background synchronization
- Comprehensive filtering system with 5 filter types (Gender, Country, Language, Age, Nearby)
- Infinite scroll pagination from local SQLite cache
- Smart loading strategies preventing unnecessary Firebase calls
- Seamless navigation to detailed ProfileView for user interaction
- Manual refresh with rate limiting and subscription-based access control
- Corruption-resistant data handling with automatic cleanup
- Gender-based profile image fallbacks and online status indicators

#### 1.1.1 Performance Optimization Implementation
- **Smart Loading**: Initial load only occurs when no data exists, respecting 30-minute refresh cycles
- **Local-First Architecture**: All pagination and scrolling uses local SQLite cache, not Firebase
- **Duplicate Prevention**: Advanced deduplication during pagination prevents UI inconsistencies
- **Memory Efficiency**: Page-based loading (10 users per page) with lazy initialization
- **Background Processing**: All Firebase operations occur on background threads with main thread UI updates

#### 1.1.2 Data Integrity and Corruption Handling
- **Startup Cleanup**: Automatic corrupted data cleanup on ViewModel initialization
- **UTF-8 String Handling**: Comprehensive NULL safety and proper string extraction from SQLite
- **Validation Layers**: Multi-level validation preventing empty or invalid user records
- **Database Recovery**: Graceful handling of database corruption with automatic table recreation

## 2. Architecture Overview

### 2.1 System Components

#### **OnlineUsersView (SwiftUI UI Layer)**
- **Primary Interface**: Main browsing interface with infinite scroll List
- **Filter Integration**: Dedicated filter button accessing FiltersView
- **Manual Refresh**: Rate-limited refresh button with subscription-based access control
- **Navigation**: Seamless transitions to ProfileView for user interaction
- **Loading States**: Smart loading indicators only during actual Firebase operations

#### **OnlineUsersViewModel (Business Logic Layer)**
- **State Management**: @Published reactive properties for users, filters, loading states
- **Data Orchestration**: Coordinates between local database, Firebase, and UI layers
- **Pagination Logic**: Handles infinite scroll with duplicate prevention
- **Filter Application**: Local filter processing with real-time updates
- **Refresh Management**: 30-minute cycle management with smart loading decisions

#### **OnlineUsersDB (Local Persistence Layer)**
- **SQLite Storage**: Local caching of up to 250 users with comprehensive schema
- **CRUD Operations**: Insert, query, update, delete operations with transaction safety
- **Corruption Handling**: Automatic cleanup and recovery mechanisms
- **Performance Optimization**: Indexed queries with proper UTF-8 string handling

#### **OnlineUsersService (Firebase Synchronization Layer)**
- **Background Sync**: Firebase to SQLite synchronization with filter support
- **Query Building**: Dynamic Firebase queries based on active filters
- **Data Processing**: User data extraction and local database insertion
- **Error Handling**: Comprehensive error handling with retry mechanisms

### 2.2 Data Flow Architecture

```
Firebase Users Collection
         ↓
OnlineUsersService (Background Sync)
         ↓
OnlineUsersDB (SQLite Cache - 250 users max)
         ↓
OnlineUsersViewModel (Business Logic + Filtering)
         ↓
OnlineUsersView (SwiftUI UI - 10 users per page)
```

## 3. Data Model and Database Schema

### 3.1 OnlineUser Model (UI Layer)
```swift
struct OnlineUser: Identifiable, Codable, Hashable {
    var id: String              // User unique identifier
    var name: String            // Display name
    var age: String             // User age (optional)
    var country: String         // User country
    var gender: String          // Gender ("Male"/"Female")
    var isOnline: Bool          // Online status
    var language: String        // User language (optional)
    var lastTimeSeen: Date      // Last activity timestamp
    var deviceId: String        // Device identifier
    var profileImage: String    // Profile image URL
}
```

### 3.2 Users Database Model (SQLite Layer)
```swift
struct Users {
    var user_id: String             // Primary key
    var user_name: String           // Required display name
    var user_image: String          // Profile image URL
    var user_gender: String         // Gender classification
    var user_country: String        // Country information
    var user_language: String       // Language preference
    var user_age: String            // Age information
    var user_device_id: String      // Device identifier
    var user_device_token: String   // Push notification token
    var user_area: String           // Geographic area
    var user_city: String           // City information
    var user_state: String          // State/region information
    var user_decent_time: Int64     // Decent time timestamp
    var user_last_time_seen: Int64  // Last activity timestamp
    var isAd: Bool                  // Advertisement flag
}
```

### 3.3 SQLite Database Schema
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

## 4. Data Loading and Refresh Logic

### 4.1 Firebase Fetch Triggers

#### **4.1.1 Initial App Usage (First Time Only)**
**Trigger**: User opens OnlineUsersView with no cached data
**Method**: `initialLoadIfNeeded()` → `fetchUsers()`
**Condition**: `users.isEmpty = true`
**Firebase Call**: Always (no previous data exists)
**Behavior**: Load initial set of users and populate SQLite cache

#### **4.1.2 30-Minute Automatic Refresh**
**Trigger**: User opens OnlineUsersView after 30+ minutes since last refresh
**Method**: `initialLoadIfNeeded()` → `fetchUsers()` → `shouldRefreshOnlineUsersFromFirebase() = true`
**Condition**: `lastRefresh < (currentTime - 30 minutes)`
**Firebase Call**: Yes, with automatic filter clearing for fresh data
**Behavior**: Background sync with filter reset, maintaining UI responsiveness

#### **4.1.3 Manual Refresh Button**
**Trigger**: User taps "Refresh users" button
**Method**: `refreshButtonTapped()` → `manualRefreshUsers()`
**Condition**: User action (subject to rate limiting based on subscription tier)
**Firebase Call**: Always (preserves current filters)
**Behavior**: Background refresh maintaining current filter state

#### **4.1.4 Apply New Filters**
**Trigger**: User applies filters in FiltersView and taps "Apply"
**Method**: Filter callback → `applyFilter()` → `forceRefreshUsers()`
**Condition**: User applies any filter settings
**Firebase Call**: Always (clears local cache first)
**Behavior**: Clear cache and fetch filtered results from Firebase

### 4.2 Smart Loading Prevention

#### **4.2.1 Navigation Return**
**Previous Behavior**: Return from FiltersView → `onAppear` → Unnecessary fetch
**Current Behavior**: Navigation tracking prevents automatic refetch
**Implementation**: `hasAppeared` flag prevents redundant loading

#### **4.2.2 View Re-appearances Within 30 Minutes**
**Previous Behavior**: Every `onAppear` → Database query → UI processing
**Current Behavior**: `initialLoadIfNeeded()` → Check data existence → Skip if present
**Implementation**: Memory-first approach with intelligent loading decisions

#### **4.2.3 Filter Reset (Local Only)**
**Previous Behavior**: Reset → Firebase refresh → Unwanted data changes
**Current Behavior**: Reset → Local filter clear → Preserve current data
**Implementation**: `clearFilterLocallyOnly()` modifies filter state without data reload

### 4.3 30-Minute Refresh Cycle Implementation

```swift
func shouldRefreshOnlineUsersFromFirebase() -> Bool {
    let lastRefresh = onlineUsersRefreshTime
    let thirtyMinutesAgo = Date().timeIntervalSince1970 - (30 * 60)
    return lastRefresh < thirtyMinutesAgo
}
```

**Key Behavior**:
- Automatic filter clearing during periodic refresh ensures fresh unfiltered data
- Background synchronization maintains UI responsiveness
- Smart cache management prevents unnecessary database operations
- Timestamp tracking ensures precise 30-minute intervals

## 5. Pagination and Infinite Scroll

### 5.1 Local Pagination Strategy

#### **5.1.1 Page-Based Loading**
- **Page Size**: 10 users per page for optimal memory usage
- **Data Source**: Local SQLite cache (not Firebase) for instant scrolling
- **Trigger Point**: Load more when user scrolls to 5 users from bottom
- **Duplicate Prevention**: Advanced deduplication prevents UI inconsistencies

#### **5.1.2 Pagination Implementation**
```swift
func fetchMoreUsers() {
    guard hasMore, !isLoading else { return }
    
    // Calculate pagination range from local database
    let startIndex = currentPage * pageSize
    let endIndex = min(startIndex + pageSize, filteredUsers.count)
    
    // Prevent duplicates during pagination
    let existingUserIds = Set(users.compactMap { $0.id })
    let uniqueNewUsers = nextPageUsers.filter { user in
        !existingUserIds.contains(user.id)
    }
    
    users.append(contentsOf: uniqueNewUsers)
    currentPage += 1
}
```

#### **5.1.3 Performance Characteristics**
- **Instant Scrolling**: No network calls during pagination
- **Memory Efficient**: Only loads visible pages plus buffer
- **Background Processing**: All database operations on background threads
- **Main Thread Updates**: UI updates always on main thread for smooth scrolling

### 5.2 Cache Management

#### **5.2.1 SQLite Cache Limits**
- **Maximum Users**: 250 users cached locally
- **Order**: `ORDER BY user_last_time_seen DESC` for most recent first
- **Storage Duration**: Until next Firebase sync or manual refresh
- **Cleanup**: Automatic corruption cleanup on startup

#### **5.2.2 Memory Management**
- **Lazy Loading**: Users loaded only when scrolled into view
- **Image Caching**: SDWebImage for efficient profile image management
- **State Preservation**: Scroll position maintained during navigation
- **Garbage Collection**: Automatic cleanup of off-screen views

## 6. Filter Integration

### 6.1 Filter Types Supported

#### **6.1.1 Gender Filter**
- **Options**: Male, Female, Both
- **Implementation**: Firebase query with `user_gender` field
- **Local Application**: Real-time filtering of cached results
- **UI Indicator**: Gender-specific icons and color coding

#### **6.1.2 Country Filter**
- **Implementation**: Searchable country dropdown with Firebase query
- **Field**: `user_country` field matching
- **Local Processing**: String-based filtering of cached results
- **Validation**: Country name normalization and validation

#### **6.1.3 Language Filter**
- **Implementation**: Language selection with Firebase query
- **Field**: `user_language` field matching
- **Local Processing**: Language code and name matching
- **Support**: International language codes and names

#### **6.1.4 Age Range Filter**
- **Implementation**: Min/max age range selection
- **Field**: `user_age` field with numeric comparison
- **Validation**: Age range validation and boundary checking
- **Local Processing**: Numeric range filtering of cached results

#### **6.1.5 Nearby Location Filter**
- **Implementation**: IP-based geolocation with city matching
- **Field**: `user_city` field with geographic proximity
- **Technology**: IP-based location detection
- **Local Processing**: Geographic proximity calculation

### 6.2 Filter Application Flow

#### **6.2.1 Apply Filters (Firebase Refresh)**
```
User sets filters → FiltersView → OnlineUsersView callback →
applyFilter() → Clear local cache → Firebase query with filters →
Update SQLite cache → Refresh UI with filtered results
```

#### **6.2.2 Clear Filters (Local Only)**
```
User resets filters → FiltersView → OnlineUsersView callback →
clearFilterLocallyOnly() → Clear filter state only →
Preserve current user data → No Firebase call → No UI reload
```

#### **6.2.3 Filter Persistence**
- **Storage**: UserSessionManager for filter state persistence
- **Scope**: Per-session filter memory with cross-app-launch persistence
- **Reset**: Automatic filter clearing during 30-minute refresh cycles
- **Validation**: Filter state validation on app startup

## 7. User Interface Design

### 7.1 OnlineUserRow Component

#### **7.1.1 Layout Structure**
```
HStack {
    ProfileImageSection (65x65dp) {
        CircularProfileImage
        OnlineStatusIndicator (GreenDot)
    }
    ContentSection {
        UserName (16sp, darkText)
        GenderSection {
            GenderIcon (16x16)
            GenderText (16sp, colorCoded)
        }
    }
    CountryFlag (34dp, positioned right)
}
```

#### **7.1.2 Visual Elements**
- **Profile Image**: 65dp circular with 2dp border, gender-based fallbacks
- **Online Status**: 18dp green dot indicator with white border
- **Gender Icons**: Male/female symbols with color coding (blue/orange)
- **Country Flags**: 34dp circular flags positioned on far right
- **Typography**: System font with 16sp sizing for consistency

#### **7.1.3 Android Parity Design**
- **Exact Sizing**: All dimensions match Android dp specifications
- **Color Matching**: AppTheme integration with Android color palette
- **Spacing**: HStack and VStack spacing matching Android LinearLayout
- **Touch Targets**: Proper tap areas for accessibility compliance

### 7.2 List View Implementation

#### **7.2.1 SwiftUI List Configuration**
```swift
List {
    // Filter/Refresh buttons section
    HStack {
        FilterButton()
        RefreshButton()
    }
    
    // User list with infinite scroll
    ForEach(viewModel.users.indices, id: \.self) { index in
        ZStack {
            OnlineUserRow(user: viewModel.users[index])
            NavigationLink(destination: ProfileView(onlineUser: user)) {
                EmptyView()
            }
        }
        .onAppear {
            // Trigger pagination when near bottom
            if index == viewModel.users.count - 5 {
                viewModel.fetchMoreUsers()
            }
        }
    }
}
.listStyle(.plain)
```

#### **7.2.2 Loading States**
- **Initial Load**: ProgressView only when no cached data exists
- **Pagination**: Subtle loading indicator during fetchMoreUsers()
- **Refresh**: Loading state during manual or automatic refresh
- **Error Handling**: Error message display with retry options

#### **7.2.3 Empty States**
- **No Data**: User-friendly message encouraging filter adjustment
- **No Results**: Filter-specific guidance for result optimization
- **Connection Issues**: Network error handling with retry mechanisms
- **Loading Optimization**: Prevent empty state flicker during quick loads

## 8. User Interaction and Navigation

### 8.1 Tap-to-Profile Navigation

#### **8.1.1 Navigation Implementation**
```swift
NavigationLink(destination: ProfileView(onlineUser: user)) {
    EmptyView()
}
.opacity(0.0)
```

#### **8.1.2 ProfileView Data Passing**
- **OnlineUser Object**: Complete user data passed to ProfileView
- **Immediate Display**: Instant profile loading with passed data
- **Background Enhancement**: Additional profile data loaded in background
- **Navigation State**: Proper back navigation with state preservation

#### **8.1.3 ProfileView Integration**
- **Initial Data**: Basic user information displayed immediately
- **Enhanced Loading**: Additional profile details loaded from Firebase
- **Chat Integration**: Seamless transition to MessagesView for communication
- **Action Buttons**: Call, video call, message, and report functionality

### 8.2 Filter Integration Navigation

#### **8.2.1 FiltersView Navigation**
```swift
NavigationLink(destination: FiltersView(...), isActive: $navigateToFilters)
```

#### **8.2.2 Filter Callbacks**
- **Apply Filters**: Triggers Firebase refresh with new filter criteria
- **Clear Filters**: Local-only reset preserving current user data
- **Navigation Return**: Optimized return without unnecessary data reload
- **State Synchronization**: Filter UI state synchronized with ViewModel

### 8.3 Refresh Button Integration

#### **8.3.1 Rate Limiting Integration**
- **Free Users**: 2 refreshes per 2-minute cooldown period
- **Lite Subscribers**: Unlimited refreshes with bypass popup
- **New Users**: Grace period with unlimited refreshes
- **Popup Strategy**: Always-show popup with upgrade options

#### **8.3.2 Subscription Integration**
- **Tier Detection**: Automatic subscription tier detection
- **Bypass Logic**: Subscription-based refresh limit bypass
- **Analytics**: Comprehensive refresh usage analytics
- **Upgrade Promotion**: Strategic upgrade messaging in limit popups

## 9. Performance and Optimization

### 9.1 Memory Management

#### **9.1.1 Lazy Loading Strategy**
- **On-Demand Initialization**: ViewModels created only when needed
- **Image Loading**: SDWebImage lazy loading with memory caching
- **Database Connections**: Connection pooling and proper cleanup
- **Background Tasks**: Automatic cleanup of background operations

#### **9.1.2 Cache Optimization**
- **SQLite Efficiency**: Indexed queries with proper UTF-8 handling
- **Memory Limits**: 250 user cache limit preventing memory bloat
- **Cleanup Strategies**: Automatic corrupted data cleanup on startup
- **Transaction Management**: Batch operations for database efficiency

### 9.2 Network Optimization

#### **9.2.1 Smart Sync Strategy**
- **30-Minute Cycles**: Prevents excessive Firebase usage
- **Background Operations**: All Firebase calls on background threads
- **Retry Logic**: Intelligent retry with exponential backoff
- **Connection Handling**: Proper Firebase listener management

#### **9.2.2 Firebase Query Optimization**
- **Limited Results**: 10 users per Firebase query for efficiency
- **Filter Integration**: Server-side filtering reduces data transfer
- **Timestamp-Based Queries**: Efficient `last_time_seen` ordering
- **Connection Reuse**: Optimal Firebase connection management

### 9.3 UI Performance

#### **9.3.1 SwiftUI Optimization**
- **Efficient Lists**: Proper SwiftUI List implementation with lazy loading
- **State Management**: @Published properties for reactive UI updates
- **Thread Safety**: Main thread UI updates with background processing
- **Memory Efficiency**: Proper view lifecycle management

#### **9.3.2 Image Handling**
- **SDWebImage Integration**: Efficient image loading and caching
- **Placeholder Strategy**: Gender-based placeholder images
- **Memory Management**: Automatic image cache management
- **Loading Optimization**: Progressive image loading with smooth transitions

## 10. Error Handling and Recovery

### 10.1 Database Error Handling

#### **10.1.1 Corruption Recovery**
- **Startup Cleanup**: Automatic corrupted data detection and cleanup
- **Table Recreation**: Automatic table recreation on corruption
- **Data Validation**: Multi-level validation preventing corrupt inserts
- **Recovery Logging**: Comprehensive error logging for debugging

#### **10.1.2 UTF-8 String Handling**
```swift
private func extractString(from statement: OpaquePointer?, column: Int32) -> String {
    guard let cString = sqlite3_column_text(statement, column) else {
        return ""
    }
    return String(cString: cString)
}
```

### 10.2 Network Error Handling

#### **10.2.1 Firebase Connection Issues**
- **Retry Logic**: Exponential backoff for failed requests
- **Timeout Handling**: Proper timeout management for long operations
- **Offline Mode**: Graceful degradation to cached data
- **Error Messaging**: User-friendly error messages with recovery options

#### **10.2.2 Authentication Errors**
- **Token Refresh**: Automatic Firebase token refresh
- **Login State**: Proper authentication state management
- **Session Recovery**: Automatic session recovery on app resume
- **Security**: Secure token storage and management

### 10.3 UI Error States

#### **10.3.1 Loading State Management**
- **Smart Loading**: Loading indicators only during actual operations
- **Timeout Handling**: Loading state cleanup on operation timeout
- **Error Recovery**: Automatic retry options for failed operations
- **User Feedback**: Clear indication of operation status

#### **10.3.2 Empty State Handling**
- **No Data**: Helpful messaging encouraging user action
- **Filter Results**: Context-specific guidance for filter adjustment
- **Network Issues**: Clear indication of connectivity problems
- **Recovery Actions**: Easy-to-find retry and refresh options

## 11. Analytics and Monitoring

### 11.1 User Interaction Analytics

#### **11.1.1 Browsing Behavior**
- **View Tracking**: OnlineUsersView appearance and usage duration
- **Scroll Behavior**: Infinite scroll usage and pagination effectiveness
- **Filter Usage**: Filter application frequency and type preferences
- **Profile Views**: Tap-to-profile conversion rates and user engagement

#### **11.1.2 Performance Metrics**
- **Load Times**: Initial load and pagination performance tracking
- **Cache Efficiency**: Cache hit rates and database performance
- **Error Rates**: Database corruption and network error frequency
- **Memory Usage**: Memory consumption and optimization effectiveness

### 11.2 Business Intelligence

#### **11.2.1 User Discovery Patterns**
- **Popular Filters**: Most commonly used filter combinations
- **Geographic Distribution**: User location and nearby filter usage
- **Gender Preferences**: Gender filter selection patterns
- **Age Demographics**: Age range filter usage and preferences

#### **11.2.2 Feature Effectiveness**
- **Refresh Usage**: Manual refresh frequency and subscription correlation
- **Filter Conversion**: Filter application to profile view conversion
- **Navigation Patterns**: User flow from OnlineUsersView to other features
- **Engagement Metrics**: Time spent browsing and interaction rates

## 12. Future Enhancement Opportunities

### 12.1 Feature Enhancements

#### **12.1.1 Advanced Filtering**
- **Interest-Based Filtering**: Filter by user interests and hobbies
- **Activity Status**: Filter by recent activity and engagement level
- **Compatibility Matching**: AI-powered compatibility suggestions
- **Custom Filters**: User-defined filter combinations and saved searches

#### **12.1.2 Social Features**
- **Favorites**: Save favorite users for quick access
- **Recent Views**: Track recently viewed profiles
- **Mutual Connections**: Display mutual friends and connections
- **Activity Feed**: Real-time activity updates for followed users

### 12.2 Technical Improvements

#### **12.2.1 Performance Optimization**
- **Predictive Loading**: Machine learning for optimized data preloading
- **Advanced Caching**: Multi-level caching with intelligent expiration
- **Network Optimization**: GraphQL integration for optimized queries
- **Real-Time Updates**: WebSocket integration for live user status

#### **12.2.2 User Experience**
- **Personalization**: AI-powered user recommendations
- **Smart Suggestions**: Intelligent filter suggestions based on behavior
- **Enhanced Search**: Full-text search with auto-complete
- **Accessibility**: Enhanced VoiceOver and accessibility features

---

## Conclusion

The Online Users Feature represents a sophisticated and optimized implementation of social discovery functionality. With its intelligent caching strategy, efficient pagination, comprehensive filtering, and robust error handling, the feature provides users with a smooth and responsive browsing experience while maintaining optimal performance and resource usage.

The system's architecture successfully balances user experience with technical efficiency, implementing smart loading strategies that prevent unnecessary Firebase calls while ensuring users always have access to fresh, relevant content. The integration with the broader ChatHub ecosystem through ProfileView navigation, filter system integration, and refresh rate limiting creates a cohesive and engaging user experience.

Current performance metrics indicate optimal functionality across all user tiers, with the 30-minute refresh cycle providing an effective balance between data freshness and resource conservation. The feature's robust error handling and recovery mechanisms ensure reliable operation even under adverse conditions, while comprehensive analytics provide valuable insights for future optimization efforts.
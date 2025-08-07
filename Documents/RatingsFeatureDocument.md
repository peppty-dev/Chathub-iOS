# Ratings Feature Documentation

## Overview

The ChatHub app implements a comprehensive app rating system that is designed to maintain 100% parity with the Android version. The system intelligently prompts users to rate the app based on their engagement level and handles both positive and negative ratings differently to maximize App Store ratings while collecting valuable feedback for improvement.

## System Architecture

### Core Components

1. **RatingService.swift** - Main service handling all rating logic
2. **RatingPopupView.swift** - UI component for the rating popup
3. **FeedbackView.swift** - Full-screen feedback collection view
4. **SessionManager** - Stores message counts and rating configuration
5. **AppSettingsService/AppSettingsWorker** - Fetches rating configuration from Firebase

## Configuration System

### Firebase Remote Configuration

The rating system is configured via Firebase Remote Config with the following parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `maxChatsForRateUsRequest` | Int64 | Minimum messages sent/received before showing rating dialog | 10 |
| `maxRateUsRequests` | Int64 | Maximum number of times to ask for rating | 2 |

**Note**: The system defaults to reasonable values (10 messages minimum, 2 max attempts) to ensure the rating system is active by default. Firebase Remote Config can override these values for fine-tuning.

### Local Storage

The following values are tracked locally in UserDefaults:

- `totalNoOfMessageReceived` - Global count of all received messages
- `totalNoOfMessageSent` - Global count of all sent messages
- `ratingTries` - Number of times user has been shown the rating dialog

## Trigger Conditions

### When Rating Popup Appears

The rating popup is triggered in two scenarios:

#### 1. Automatic Trigger (Main Use Case)
When the user exits a chat conversation (`MessagesView.onDisappear()`) and returns to the main view, the popup appears **in MainView** if all of the following conditions are met:

1. **Message Activity**: 
   - `totalNoOfMessageReceived > maxChatsForRateUsRequest`
   - `totalNoOfMessageSent > maxChatsForRateUsRequest`

2. **Rate Limiting**: 
   - `ratingTries < maxRateUsRequests`

#### 2. Manual Trigger (Settings)
Users can manually trigger the rating popup by tapping **"Rate the app"** in the Settings tab. This bypasses all automatic conditions and shows the popup immediately in SettingsTabView.

### Message Counting Logic

Messages are counted as follows:

**Sent Messages**:
- Incremented in `MessagingSettingsSessionManager.incrementMessageCount()` when user sends a message
- Called from `MessagesView.sendMessage()` after successful Firebase save

**Received Messages**:
- Incremented in `MessagesView.setupMessageListener()` when receiving messages from other users
- Only counts messages from other users (not user's own messages)

## Rating Flow

### 1. Rating Dialog Display

When triggered, the system shows `RatingPopupView` with:
- 5-star rating interface
- Dynamic feedback text and emojis based on selected rating
- "Maybe Later" and "Submit" buttons

#### Rating Descriptions by Star Count:
- **1 star**: "Not meeting your expectations. Help us improve!" 😞
- **2 stars**: "Could be much better. Tell us how!" 😕  
- **3 stars**: "It's okay, but needs improvement" 😐
- **4 stars**: "Great! Rate us on App Store" 😊
- **5 stars**: "Awesome! Share your love on App Store" 🤩

### 2. High Rating Flow (4-5 Stars)

When user selects 4 or 5 stars:

1. **App Store Review Prompt**: Immediately shows iOS native review prompt using `SKStoreReviewController`
2. **Counter Reset**: Sets message counters to `-999999999` to prevent future rating prompts
3. **Analytics Logging**: Logs rating event with tries count
4. **Fallback for Old iOS**: For iOS < 14.0, opens App Store directly with review URL

### 3. Low Rating Flow (1-3 Stars)

When user selects 1-3 stars:

1. **Feedback Collection**: Navigates to `FeedbackView` for detailed feedback
2. **Tries Increment**: Increments `ratingTries` counter
3. **Message Reset**: Resets message counters to 0
4. **Feedback Requirements**: Minimum 10 characters, maximum 500 characters

### 4. "Maybe Later" Option

When user selects "Maybe Later":
- Resets message counters to 0
- Does not increment `ratingTries`
- User will be prompted again after reaching message thresholds

## Feedback System

### Feedback Collection

The feedback system (`FeedbackView.swift`) provides:
- Rich text input with character counting (10-500 characters)
- Rating display showing the user's original star rating
- Professional success confirmation
- Real-time validation

### Firebase Storage

Feedback is stored in Firebase with the following structure:

```
Collection: "Feedback"
Document: Bundle Identifier (e.g., "com.peppty.ChatApp")
Sub-collection: "Rating_Feedback"
Document: Timestamp

Data Structure:
{
  "userId": String,
  "gender": String,
  "country": String,
  "appVersion": String,
  "feedback": String,
  "timestamp": Int (Unix timestamp),
  "rating": Float (1.0-5.0)
}
```

## Analytics Integration

### Firebase Analytics Events

The system logs the following events:

1. **Rating Submission**: 
   - Event: `"app_events"`
   - Parameter: `"rating_ChatHub_{rating}"`

2. **App Store Review Completion**:
   - Event: `"app_events"`
   - Parameter: `"rating_ChatHub_{rating}_after_{tries}"`

## User Experience Design

### Visual Design

- **Color-coded ratings**: Red (1-2), Orange (3), Green (4-5)
- **Smooth animations**: Spring animations for rating selection
- **Accessibility**: Minimum touch target sizes (44x44 points)
- **Responsive layout**: Proper keyboard handling and safe area support

### Timing Strategy

- **Contextual trigger**: Shows after meaningful app engagement (post-conversation)
- **Non-intrusive**: Overlay design that doesn't block navigation
- **Rate limiting**: Respects user choice and limits frequency

## Technical Implementation Details

### Thread Safety

- All UI updates performed on main thread
- Firebase operations handled asynchronously
- Background processing for analytics

### Error Handling

- Graceful fallback for network errors
- Validation for minimum feedback length
- Safe unwrapping of optional Firebase data

### Performance Considerations

- Lightweight service with minimal memory footprint
- Efficient message counting using local storage
- Background Firebase listeners for configuration updates

## Current Status & Behavior

### Default Configuration Behavior

**Updated**: With sensible default values:
- `maxChatsForRateUsRequest`: 10 messages (both sent and received)
- `maxRateUsRequests`: 2 maximum attempts
- Rating popups will appear organically after users are engaged
- This creates an "enabled by default" system with reasonable thresholds

### Configuration Flexibility

Administrators can adjust these values via Firebase Remote Config:
- **Conservative approach**: 15-20 messages, 1-2 attempts (less frequent prompting)
- **Aggressive approach**: 5-10 messages, 3-4 attempts (more frequent prompting)
- **Disabled**: Set `maxRateUsRequests` to 0 to completely disable rating prompts

This ensures users are sufficiently engaged before being prompted while maintaining flexibility for different strategies.

## Android Parity

The iOS implementation maintains 100% functional parity with Android:

- **Identical trigger conditions**: Same message counting logic
- **Matching UI flow**: Same rating descriptions and flow
- **Firebase structure**: Identical data storage format
- **Analytics events**: Same event names and parameters
- **Configuration**: Same remote config parameters

## Future Considerations

### Potential Improvements

1. **Smart Timing**: Consider time-based delays or app usage patterns
2. **User Segmentation**: Different thresholds for different user types
3. **A/B Testing**: Experiment with different messaging or thresholds
4. **Localization**: Translate rating descriptions for international users

### Monitoring & Analytics

Track these metrics to optimize the rating system:
- Rating dialog show rate
- Completion rate by star rating
- App Store rating correlation
- Feedback quality and actionability

## Conclusion

The ChatHub rating system is a well-architected solution that balances user experience with business needs. It effectively channels happy users to the App Store while collecting valuable feedback from users who need improvement. The Firebase-based configuration system allows for easy adjustment without app updates, and the Android parity ensures consistent experience across platforms.

The updated default configuration (10 messages, 2 attempts) ensures the rating system is active out-of-the-box with reasonable engagement thresholds. The naming has been updated to `RatingPopupView` for consistency with other popup components in the app. Administrators can fine-tune these values via Firebase Remote Config based on their specific user engagement goals and rating collection strategies.

# ChatHub iOS Notifications Cloud Function

This Cloud Function handles iOS-specific push notifications for the ChatHub messaging app.

## 🎯 Purpose

This function runs alongside the existing Android notification function but sends iOS-optimized FCM payloads with:

- **`source: "fcm"` field** - Critical for triggering `AppNotificationService.handleFCMMessage()` in the iOS app
- **APNS-specific configuration** - Ensures proper iOS notification behavior
- **`content-available: 1`** - Enables notification delivery when the app is in foreground
- **iOS-specific error handling** - Handles APNs-specific error codes

## 🔧 Technical Details

- **Function Name**: `NotificationsiOS`
- **Trigger**: Firestore document creation/update
- **Path**: `Notifications/{message_reciever_id}/Notifications_chat/{message_sender_id}`
- **Runtime**: Node.js 18
- **Dependencies**: firebase-admin, firebase-functions

## 📁 Project Structure

```
functions/iosFunction/
├── index.js          # Main function code
├── package.json      # Dependencies and scripts
├── README.md         # This documentation
└── .gitignore        # Git ignore rules
```

## 🚀 Deployment

### Prerequisites
- Firebase CLI installed and authenticated
- Firebase project configured
- Node.js 18+ installed

### Install Dependencies
```bash
cd functions/iosFunction
npm install
```

### Deploy Function
```bash
# Deploy only the iOS function
npm run deploy

# Or deploy all functions
npm run deploy-all
```

### View Logs
```bash
# View iOS function logs only
npm run logs

# View all function logs
npm run logs-all
```

## 🔍 How It Works

1. **Trigger**: Function triggers when a document is created/updated in the Firestore path
2. **Validation**: Validates required notification data (sender name, ID, FCM token)
3. **Payload Creation**: Creates iOS-optimized FCM payload with APNS configuration
4. **Send**: Sends notification via Firebase Cloud Messaging
5. **Error Handling**: Handles iOS-specific errors and logs detailed information

## 📱 iOS App Integration

The function sends a data payload with `source: "fcm"` which triggers this method in your iOS app:

```swift
// In AppNotificationService.swift
func handleFCMMessage(_ data: [AnyHashable: Any]) {
    // This method is called when source: "fcm" is present in the data
    // Creates and shows local notification for foreground delivery
}
```

## 🔄 Function Flow

```
Firestore Trigger → Validate Data → Create iOS Payload → Send FCM → Handle Response
                                         ↓
                     Includes: source="fcm", APNS config, content-available=1
```

## 🚨 Error Handling

The function handles these iOS-specific error scenarios:

- **Token Not Registered**: Device uninstalled app or token expired
- **Invalid Token**: Malformed token format
- **Credential Mismatch**: Firebase/APNs configuration issue
- **Invalid APNs Credentials**: APNs certificate/key problem

## 📊 Monitoring

### View Function Logs
```bash
firebase functions:log --only NotificationsiOS
```

### Health Check Endpoint
The function includes a health check endpoint:
```
https://your-region-your-project.cloudfunctions.net/healthCheck
```

## 🔧 Configuration

The function uses the same Firebase project configuration as your existing functions. No additional setup required beyond deployment.

## 🐛 Troubleshooting

### Common Issues

1. **Notifications not appearing on iOS**
   - Check that `source: "fcm"` is present in logs
   - Verify iOS app's `AppNotificationService.handleFCMMessage()` method
   - Check APNs configuration in Firebase Console

2. **Function not triggering**
   - Verify Firestore path matches exactly
   - Check that notification documents are being created
   - Review Firebase Console Functions logs

3. **FCM errors**
   - Check token validity
   - Verify Firebase project APNs configuration
   - Review error codes in function logs

### Debug Commands
```bash
# View real-time logs
firebase functions:log --only NotificationsiOS --follow

# Test locally with emulator
npm run serve

# Check function deployment status
firebase functions:list
```

## 📝 Maintenance

### Updating the Function
1. Edit `index.js` with your changes
2. Run `npm run deploy`
3. Monitor logs to verify deployment

### Dependencies
- Keep `firebase-admin` and `firebase-functions` updated
- Review Node.js version compatibility

## 🔐 Security

- Function uses Firebase Admin SDK with appropriate permissions
- Logs truncate FCM tokens for security
- No sensitive data stored in function code

## 📞 Support

For issues related to this function:
1. Check function logs for error details
2. Verify Firebase project configuration
3. Test with iOS app in debug mode
4. Review APNs configuration in Firebase Console

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * iOS-specific notification handler for ChatHub
 * 
 * This Cloud Function is specifically designed to handle iOS push notifications
 * and runs alongside the existing Android notification function. It triggers on
 * the same Firestore path but sends iOS-optimized FCM payloads.
 * 
 * Key Features:
 * - Includes 'source: fcm' field to trigger AppNotificationService.handleFCMMessage()
 * - Uses APNS-specific configuration for optimal iOS delivery
 * - Includes 'content-available: 1' for foreground notification delivery
 * - Comprehensive error handling with iOS-specific error codes
 * 
 * Firestore Trigger Path: Notifications/{message_reciever_id}/Notifications_chat/{message_sender_id}
 * Function Name: NotificationsiOS
 */
exports.NotificationsiOS = functions.firestore
  .document('Notifications/{message_reciever_id}/Notifications_chat/{message_sender_id}')
  .onWrite(async (change, context) => {

    const newValue = change.after.data();

    // Exit if no data (document deleted or no content)
    if (!newValue) {
      console.log('iOS Function: No data found in notification document - exiting');
      return null;
    }

    const notif_type = newValue.notification_type;

    // Only process chat notifications
    if (notif_type === 'chat') {

      console.log('iOS Function: 🍎 Processing iOS chat notification...');
      console.log('iOS Function: Document path:', context.resource.name);
      console.log('iOS Function: Receiver ID:', context.params.message_reciever_id);
      console.log('iOS Function: Sender ID:', context.params.message_sender_id);

      // Extract notification data
      const sender_name = newValue.notif_sender_name;
      const sender_id = newValue.notif_sender_id;
      const token = newValue.notif_token;
      const notif_id = newValue.notif_id;

      // Validate required fields
      if (!sender_name || !sender_id || !token) {
        console.log('iOS Function: ❌ Missing required notification data');
        console.log('iOS Function: sender_name:', !!sender_name, 'sender_id:', !!sender_id, 'token:', !!token);
        return null;
      }

      // Log notification details (with token truncation for security)
      console.log('iOS Function: 📱 Preparing iOS notification');
      console.log('iOS Function: From:', sender_name, '(ID:', sender_id + ')');
      console.log('iOS Function: To token:', token.substring(0, 20) + '...');
      console.log('iOS Function: Notification ID:', notif_id);

      // MODERN FCM MESSAGE (Using Firebase Admin SDK v9+ send() API)
      // This message structure uses the modern Firebase Admin SDK for better reliability
      // 1. 'source: fcm' field - Critical for triggering AppNotificationService.handleFCMMessage()
      // 2. contentAvailable for background processing
      // 3. iOS-specific APNS configuration for optimal delivery
      const message = {
        token: token,
        
        // Data payload - Available to app when notification is received
        // This data will be passed to your iOS AppNotificationService.handleFCMMessage()
        data: {
          title: sender_name,
          body: "New Message",
          sender_id: sender_id,
          notif_id: notif_id || "default_id",
          notification_type: notif_type,
          source: "fcm", // 🔥 CRITICAL: This field triggers your iOS AppNotificationService.handleFCMMessage()
          content_available: "1" // For background processing
        },
        
        // Notification payload - Controls notification appearance
        notification: {
          title: sender_name,
          body: 'New Message'
        },
        
        // iOS-specific APNS configuration for optimal delivery
        apns: {
          headers: {
            'apns-priority': '10', // High priority for immediate delivery
            'apns-push-type': 'alert'
          },
          payload: {
            aps: {
              alert: {
                title: sender_name,
                body: 'New Message'
              },
              badge: 1,
              sound: 'default',
              'content-available': 1, // Enable background processing
              'mutable-content': 1    // Enable notification service extensions
            }
          }
        }
      };

      console.log('iOS Function: 📦 Modern FCM message created');
      console.log('iOS Function: Message includes source=fcm for proper iOS handling');
      console.log('iOS Function: Full message structure:', JSON.stringify(message, null, 2));

      // Send FCM notification using modern send() API with async/await
      try {
        console.log('iOS Function: 📡 Sending FCM message...');
        const messageId = await admin.messaging().send(message);
        
        console.log('iOS Function: ✅ FCM message sent successfully!');
        console.log('iOS Function: Message ID:', messageId);
        console.log('iOS Function: 🎯 iOS notification delivered - should trigger AppNotificationService.handleFCMMessage()');
        
        return { success: true, messageId: messageId };
        
      } catch (error) {
        // Handle FCM errors with detailed logging
        console.error('iOS Function: ❌ FCM send failed');
        console.error('iOS Function: Error type:', error.constructor.name);
        console.error('iOS Function: Error message:', error.message);
        
        // Log additional error context for debugging
        if (error.code) {
          console.error('iOS Function: Error code:', error.code);
        }
        
        if (error.stack) {
          console.error('iOS Function: Stack trace:', error.stack);
        }
        
        // Handle specific iOS/FCM error cases
        if (error.code) {
          switch (error.code) {
            case 'messaging/registration-token-not-registered':
              console.log('iOS Function: 🗑️ Token no longer valid - device uninstalled app or token expired');
              console.log('iOS Function: Recommendation: Remove token from database');
              break;
              
            case 'messaging/invalid-registration-token':
              console.log('iOS Function: 🚫 Invalid token format - token is malformed');
              console.log('iOS Function: Recommendation: Validate token generation process');
              break;
              
            case 'messaging/mismatched-credential':
              console.log('iOS Function: 🔐 Credential mismatch - Firebase project configuration issue');
              console.log('iOS Function: Recommendation: Check Firebase project settings and APNs configuration');
              break;
              
            case 'messaging/invalid-apns-credentials':
              console.log('iOS Function: 🍎 Invalid APNs credentials - APNs certificate/key issue');
              console.log('iOS Function: Recommendation: Check APNs authentication configuration in Firebase');
              break;
              
            default:
              console.log('iOS Function: ⚠️ Unknown FCM error:', error.code);
              console.log('iOS Function: Full error details:', JSON.stringify(error, null, 2));
          }
        }
        
        // Handle specific Firebase error types
        if (error.constructor.name === 'FirebaseMessagingError' || 
            (error.code && error.code.startsWith('messaging/'))) {
          console.error('iOS Function: 🔥 Firebase Messaging specific error detected');
          
          // Don't re-throw messaging errors to prevent infinite retries
          // These are typically client-side issues (invalid tokens, etc.)
          return { success: false, error: error.code };
        }
        
        // For other errors, still re-throw to allow retries
        // This allows Firebase to retry the function if appropriate
        throw error;
      }

    } else {
      // Non-chat notification types are not handled by this iOS function
      console.log('iOS Function: ⏭️ Non-chat notification type:', notif_type, '- skipping iOS processing');
      return null;
    }
  });

// Export additional utility functions for testing and monitoring
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.json({
    status: 'healthy',
    service: 'ChatHub iOS Notifications',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
    runtime: 'Node.js 20',
    api: 'Firebase Functions v1 (modernized)'
  });
});

console.log('iOS Function: 🚀 ChatHub iOS notification handler loaded and ready');

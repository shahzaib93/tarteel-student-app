# Push Notifications Setup

This document explains how to enable push notifications for incoming calls when the app is closed or in the background.

## Overview

The app uses **Firebase Cloud Messaging (FCM)** to receive push notifications when:
- App is closed
- App is in background
- Device screen is off

When a teacher initiates a call, the server sends a push notification to wake up the student's device and show an incoming call notification.

## Setup Required

### 1. Firebase Configuration (Already Done ✅)
The app already has Firebase configured (`firebase_messaging` package added to `pubspec.yaml`).

### 2. Server-Side Implementation (TODO)

The main server needs to:

1. **Register FCM Tokens**
   - When student logs in, the app will send their FCM token to the server
   - Server endpoint needed: `POST /api/push/register`
   - Request body:
     ```json
     {
       "userId": "student123",
       "role": "student",
       "token": "fcm_token_here",
       "platform": "android" | "ios",
       "updatedAt": "2025-01-13T10:30:00Z"
     }
     ```

2. **Send Push Notifications When Teacher Calls**
   - When teacher initiates a call via WebSocket, also send FCM push notification
   - Use Firebase Admin SDK to send notifications
   - Notification payload:
     ```json
     {
       "notification": {
         "title": "Incoming Call",
         "body": "Teacher Name is calling you"
       },
       "data": {
         "type": "call_invite",
         "callId": "call_123",
         "callerId": "teacher_id",
         "callerName": "Teacher Name",
         "timestamp": "2025-01-13T10:30:00Z"
       },
       "android": {
         "priority": "high",
         "notification": {
           "sound": "default",
           "channelId": "incoming_calls"
         }
       },
       "apns": {
         "payload": {
           "aps": {
             "sound": "default",
             "badge": 1,
             "contentAvailable": true
           }
         }
       }
     }
     ```

3. **Example Server Code (Node.js)**
   ```javascript
   const admin = require('firebase-admin');

   // Initialize Firebase Admin
   admin.initializeApp({
     credential: admin.credential.cert(serviceAccount)
   });

   // When teacher calls student
   async function notifyStudentOfCall(studentToken, teacherName, callId) {
     const message = {
       token: studentToken,
       notification: {
         title: 'Incoming Call',
         body: `${teacherName} is calling you`
       },
       data: {
         type: 'call_invite',
         callId: callId,
         callerName: teacherName,
         timestamp: new Date().toISOString()
       },
       android: {
         priority: 'high',
         notification: {
           sound: 'default',
           channelId: 'incoming_calls'
         }
       },
       apns: {
         payload: {
           aps: {
             sound: 'default',
             contentAvailable: true
           }
         }
       }
     };

     await admin.messaging().send(message);
   }
   ```

### 3. iOS Configuration (TODO)

For iOS push notifications:
1. Add Push Notification capability in Xcode
2. Upload APNs certificate to Firebase Console
3. Update `ios/Runner/Info.plist` if needed

### 4. Android Configuration (TODO)

For Android push notifications:
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/`
3. Ensure notification channel is created (already handled in app code)

## How It Works

1. **Student Opens App** → FCM token generated → Sent to server
2. **Teacher Calls** → Server sends:
   - WebSocket signal (if app is open)
   - FCM push notification (if app is closed)
3. **Student Receives Push** → System shows notification → Tapping opens app → Shows incoming call dialog
4. **Student Accepts/Rejects** → WebRTC call proceeds as normal

## Testing

1. Ensure Firebase is configured with your project
2. Implement server endpoints
3. Get student's FCM token from app logs
4. Test push notification using Firebase Console
5. Test actual call flow

## Current Status

✅ App code ready to receive push notifications
✅ FCM token registration code added
✅ Client-to-client FCM implementation (for testing only)
❌ Server endpoints need to be implemented (for production)
❌ Firebase Admin SDK needs to be set up on server (for production)
❌ APNs certificate for iOS (if using iOS)

## Client-to-Client Testing (Current Implementation)

⚠️ **WARNING**: This is for TESTING ONLY. In production, FCM notifications should be sent from your server, not from client apps.

### How It Works

1. **Student logs in** → `FCMService.initialize()` is called
2. **FCM token generated** → Automatically saved to Firestore `fcm_tokens` collection
3. **Token stored with metadata**:
   ```json
   {
     "token": "fcm_token_here",
     "userId": "student123",
     "platform": "TargetPlatform.android",
     "updatedAt": "2025-01-13T10:30:00Z"
   }
   ```

### Testing Push Notifications

#### Option 1: Using Firebase Console (Easiest)
1. Open Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter the FCM token (from app logs or Firestore)
4. Send the notification

#### Option 2: Using HTTP API
You can send a test notification using curl:

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "Incoming Call",
      "body": "Teacher is calling you"
    },
    "data": {
      "type": "call_invite",
      "callId": "test_123",
      "callerName": "Test Teacher"
    },
    "priority": "high"
  }'
```

Get your Server Key from: Firebase Console → Project Settings → Cloud Messaging → Server Key

#### Option 3: Client-to-Client (Not Recommended)
Since we don't have a server yet, you can retrieve another user's token from Firestore and send notifications from the client app. However, this is **NOT secure** and should only be used for testing.

```dart
// In teacher app (for testing only)
final fcmService = Provider.of<FCMService>(context, listen: false);
final studentToken = await fcmService.getUserFCMToken('student_user_id');

// You would need to use an HTTP library to call FCM API
// This requires exposing your server key in the app (NOT RECOMMENDED)
```

### Getting FCM Tokens for Testing

1. **From App Logs**: When student logs in, check debug console:
   ```
   📱 FCM Token: eA8xG... (long token string)
   ✅ FCM token saved to Firestore
   ```

2. **From Firestore**: Navigate to `fcm_tokens` collection in Firebase Console

### Configuration Required

#### Android
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/`
3. Ensure `google-services` plugin is in `android/build.gradle`

#### iOS
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode project (Runner target)
3. Upload APNs certificate to Firebase Console
4. Add Push Notification capability in Xcode

## Moving to Production

Once you have a backend server, migrate from client-to-client to proper server-side FCM:

1. Remove client-side FCM sending code
2. Implement server endpoints (see examples above)
3. Use Firebase Admin SDK on server
4. Never expose FCM server keys in client apps
5. Validate all push notification requests on server

## Reference

See the React student app implementation:
`/mobile-apps/student-app/src/services/PushNotificationService.js`

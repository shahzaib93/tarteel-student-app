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
❌ Server endpoints need to be implemented
❌ Firebase Admin SDK needs to be set up on server
❌ APNs certificate for iOS (if using iOS)

## Reference

See the React student app implementation:
`/mobile-apps/student-app/src/services/PushNotificationService.js`

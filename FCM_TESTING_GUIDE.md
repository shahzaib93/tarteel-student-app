# FCM Push Notifications - Testing Guide

## Current Status

✅ **Student App Ready**: FCM service implemented and configured
❌ **Signaling Server Missing**: Server doesn't send FCM notifications yet

## The Problem

When a teacher calls a student:
1. ✅ WebSocket signal is sent (if app is open)
2. ❌ FCM push notification is NOT sent (if app is closed)

**Why?** The signaling server at `192.95.33.150:5003` doesn't have FCM integration yet.

## Solution: Update Signaling Server

The signaling server needs to be updated to send FCM notifications when a teacher initiates a call.

### What the Server Needs to Do

When teacher calls (`webrtc-offer` event), the server should:

1. Get the student's FCM token from Firestore
2. Send an FCM notification to wake up the student's app

### Example Server Code

Here's what needs to be added to your signaling server (Node.js + Socket.IO):

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Listen for call offers
io.on('connection', (socket) => {

  // When teacher initiates a call
  socket.on('webrtc-offer', async (data) => {
    const { recipientId, callerName, callerId, offer, callId } = data;

    // 1. Send WebSocket signal (existing code)
    io.to(recipientId).emit('webrtc-offer', {
      callerId,
      callerName,
      offer,
      callId
    });

    // 2. Send FCM push notification (NEW)
    try {
      // Get student's FCM token from Firestore
      const tokenDoc = await db.collection('fcm_tokens').doc(recipientId).get();

      if (tokenDoc.exists) {
        const fcmToken = tokenDoc.data().token;

        // Send push notification
        const message = {
          token: fcmToken,
          notification: {
            title: 'Incoming Call',
            body: `${callerName} is calling you`
          },
          data: {
            type: 'call_invite',
            callId: callId,
            callerId: callerId,
            callerName: callerName,
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
        console.log(`✅ Push notification sent to ${recipientId}`);
      } else {
        console.log(`⚠️ No FCM token found for ${recipientId}`);
      }
    } catch (error) {
      console.error('❌ Error sending push notification:', error);
      // Don't fail the call if push notification fails
    }
  });
});
```

### Dependencies to Install

```bash
npm install firebase-admin
```

### Firebase Service Account Key

Download from: Firebase Console → Project Settings → Service Accounts → Generate new private key

Save as `serviceAccountKey.json` in your signaling server directory.

## Manual Testing (Without Server Update)

Until the signaling server is updated, you can test FCM manually:

### Option 1: Firebase Console (Easiest)

1. Run the student app and login
2. Check debug logs for FCM token:
   ```
   📱 FCM Token: eA8xG...
   ```
3. Go to Firebase Console → Cloud Messaging
4. Click "Send test message"
5. Paste the FCM token
6. Enter:
   - **Title**: "Incoming Call"
   - **Body**: "Teacher is calling you"
7. Send the notification
8. Student app should receive it even when closed!

### Option 2: Using curl

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "STUDENT_FCM_TOKEN_HERE",
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

### Option 3: Postman/Insomnia

Same as curl but using a REST client GUI.

## Expected Behavior After Server Update

1. **App Closed** → Teacher calls → Push notification → Student taps → App opens → Incoming call dialog
2. **App Background** → Teacher calls → Push notification + WebSocket → Incoming call dialog
3. **App Open** → Teacher calls → WebSocket → Incoming call dialog (instant)

## Next Steps

1. ✅ Student app is ready (no changes needed)
2. ❌ Update signaling server to send FCM notifications
3. ✅ Test with Firebase Console to verify FCM works
4. ✅ Test end-to-end after server update

## Troubleshooting

### No notification received?

1. Check FCM token is saved in Firestore:
   - Firebase Console → Firestore → `fcm_tokens` collection
   - Should have a document with student's userId

2. Check Firebase project has Cloud Messaging enabled:
   - Firebase Console → Cloud Messaging
   - Should show "Set up Cloud Messaging" or "Send your first message"

3. Check `google-services.json` and `GoogleService-Info.plist` are correct:
   - Download fresh from Firebase Console if needed
   - Ensure they match your Firebase project

4. Check iOS/Android permissions:
   - iOS: Settings → App → Notifications → Allow
   - Android: Settings → Apps → App → Notifications → Allow

### App crashes when accepting call?

- ✅ Fixed! Camera/microphone permissions are now requested before accessing media
- If still crashing, check debug logs for permission errors

## Summary

**What works**: FCM infrastructure is complete in student app
**What's missing**: Signaling server needs to send FCM notifications
**Workaround**: Test FCM manually using Firebase Console
**Permanent fix**: Update signaling server with code above

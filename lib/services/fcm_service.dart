import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ⚠️ WARNING: This is for TESTING ONLY
/// In production, FCM notifications should be sent from your server, not from client apps.
/// Storing FCM server keys in the app is a security risk.
class FCMService with ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? _userId;

  String? get fcmToken => _fcmToken;

  /// Initialize FCM and request permissions
  Future<void> initialize(String userId) async {
    _userId = userId;

    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCM: User granted provisional permission');
      } else {
        debugPrint('❌ FCM: User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        debugPrint('📱 FCM Token: $_fcmToken');
        await _saveTokenToFirestore();
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _saveTokenToFirestore();
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is in background but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      debugPrint('✅ FCM Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore() async {
    if (_fcmToken == null || _userId == null) return;

    try {
      await _firestore.collection('fcm_tokens').doc(_userId).set({
        'token': _fcmToken,
        'userId': _userId,
        'platform': defaultTargetPlatform.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message received: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // The app is already open, so incoming call dialog will show via WebSocket
    // No need to show notification
  }

  /// Handle messages when app is opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📬 App opened from notification: ${message.messageId}');
    debugPrint('   Data: ${message.data}');

    // Navigate to call screen or show incoming call dialog
    // This will be handled by the main app based on the data
  }

  /// Get another user's FCM token from Firestore
  Future<String?> getUserFCMToken(String userId) async {
    try {
      final doc = await _firestore.collection('fcm_tokens').doc(userId).get();

      if (doc.exists) {
        return doc.data()?['token'] as String?;
      }

      debugPrint('⚠️ No FCM token found for user: $userId');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Clean up on logout
  Future<void> cleanup() async {
    if (_userId != null) {
      try {
        // Optionally delete token from Firestore
        await _firestore.collection('fcm_tokens').doc(_userId).delete();
        debugPrint('🗑️ FCM token removed from Firestore');
      } catch (e) {
        debugPrint('❌ Error cleaning up FCM: $e');
      }
    }

    _fcmToken = null;
    _userId = null;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');

  // When app is completely closed, this will receive the notification
  // The notification will appear in system tray automatically
}

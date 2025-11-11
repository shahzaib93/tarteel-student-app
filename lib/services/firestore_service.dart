import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all teachers
  Stream<List<Map<String, dynamic>>> getTeachers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  /// Get specific teacher
  Future<Map<String, dynamic>?> getTeacher(String teacherId) async {
    try {
      final doc = await _firestore.collection('users').doc(teacherId).get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching teacher: $e');
      return null;
    }
  }

  /// Get call logs for student
  Stream<List<Map<String, dynamic>>> getCallLogs(String studentId) {
    return _firestore
        .collection('callLogs')
        .where('studentId', isEqualTo: studentId)
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          // Convert Timestamps to DateTime
          'startTime': (data['startTime'] as Timestamp?)?.toDate(),
          'endTime': (data['endTime'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  /// Get messages for user
  Stream<List<Map<String, dynamic>>> getMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  /// Send a message
  Future<void> sendMessage({
    required String senderId,
    required String recipientId,
    required String content,
    String type = 'text',
  }) async {
    try {
      await _firestore.collection('messages').add({
        'senderId': senderId,
        'recipientId': recipientId,
        'content': content,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [senderId, recipientId],
        'read': false,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Get user data
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  /// Update user online status
  Future<void> setOnlineStatus(String userId, bool online) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }
}

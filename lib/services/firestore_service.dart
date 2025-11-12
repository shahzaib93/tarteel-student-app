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
        .collection('calls')
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

  /// Get student by ID
  Future<Map<String, dynamic>?> getStudentById(String studentId) async {
    try {
      final doc = await _firestore.collection('users').doc(studentId).get();

      if (doc.exists && doc.data()?['role'] == 'student') {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching student: $e');
      return null;
    }
  }

  /// Get teacher by ID (alias for getTeacher for consistency)
  Future<Map<String, dynamic>?> getTeacherById(String teacherId) async {
    return getTeacher(teacherId);
  }

  /// Get teacher status stream (for real-time updates)
  Stream<Map<String, dynamic>?> getTeacherStream(String teacherId) {
    return _firestore
        .collection('users')
        .doc(teacherId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    });
  }

  /// Get call logs as list with pagination support
  ///
  /// [limit] - Maximum number of calls to fetch (default: 10)
  /// [offset] - Number of calls to skip (for pagination)
  ///
  /// Note: Using offset is not the most efficient approach for Firestore.
  /// Consider implementing cursor-based pagination with startAfter for production.
  Future<List<Map<String, dynamic>>> getCallLogsAsList(
    String studentId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = _firestore
          .collection('calls')
          .where('studentId', isEqualTo: studentId)
          .orderBy('startTime', descending: true);

      // Apply limit
      query = query.limit(limit + offset);

      final snapshot = await query.get();

      // Skip offset documents (not efficient, but works for now)
      final docs = offset > 0
          ? snapshot.docs.skip(offset).toList()
          : snapshot.docs;

      return docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'startTime': (data['startTime'] as Timestamp?)?.toDate(),
          'endTime': (data['endTime'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching call logs: $e');
      return [];
    }
  }

  /// Get unread message count
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error fetching unread message count: $e');
      return 0;
    }
  }

  /// Get scheduled classes for a date range
  Stream<List<Map<String, dynamic>>> getScheduledClasses(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection('scheduledClasses')
        .where('studentId', isEqualTo: studentId)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'scheduledTime': data['scheduledTime'],
        };
      }).toList();
    });
  }

  /// Get conversations for a user with real-time updates
  Stream<List<Map<String, dynamic>>> getConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'lastMessageTime': (data['lastMessageTime'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  /// Get messages for a conversation with real-time updates
  Stream<List<Map<String, dynamic>>> getMessagesForConversation(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
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

  /// Send a message to another user
  Future<Map<String, dynamic>> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required String senderName,
    required String receiverName,
    required String senderRole,
    required String receiverRole,
    String type = 'text',
  }) async {
    try {
      // Create conversation ID (sorted participant IDs joined with underscore)
      final participants = [senderId, receiverId]..sort();
      final conversationId = participants.join('_');

      // Create or update conversation
      await _createOrUpdateConversation(
        conversationId: conversationId,
        participants: participants,
        senderId: senderId,
        senderName: senderName,
        receiverName: receiverName,
        senderRole: senderRole,
        receiverRole: receiverRole,
        lastMessage: content,
      );

      // Add message
      await _firestore.collection('messages').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'type': type,
        'conversationId': conversationId,
        'senderRole': senderRole,
        'receiverRole': receiverRole,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'metadata': {
          'senderName': senderName,
          'receiverName': receiverName,
        },
      });

      return {'success': true};
    } catch (e) {
      debugPrint('Error sending message: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create or update conversation
  Future<void> _createOrUpdateConversation({
    required String conversationId,
    required List<String> participants,
    required String senderId,
    required String senderName,
    required String receiverName,
    required String senderRole,
    required String receiverRole,
    required String lastMessage,
  }) async {
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    final conversationDoc = await conversationRef.get();

    if (conversationDoc.exists) {
      // Update existing conversation
      final data = conversationDoc.data()!;
      final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});

      // Increment unread count for receiver
      for (var participantId in participants) {
        if (participantId != senderId) {
          unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
        }
      }

      await conversationRef.update({
        'lastMessage': lastMessage.substring(0, lastMessage.length > 100 ? 100 : lastMessage.length),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
      });
    } else {
      // Create new conversation
      await conversationRef.set({
        'id': conversationId,
        'participants': participants,
        'participantRoles': [senderRole, receiverRole],
        'participantNames': [senderName, receiverName],
        'lastMessage': lastMessage.substring(0, lastMessage.length > 100 ? 100 : lastMessage.length),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {
          senderId: 0,
          participants.firstWhere((id) => id != senderId): 1,
        },
      });
    }
  }

  /// Mark messages as read in a conversation
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      // Get unread messages for this user
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      // Mark all as read
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      // Reset unread count in conversation
      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();

      if (conversationDoc.exists) {
        final data = conversationDoc.data()!;
        final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        unreadCount[userId] = 0;

        await conversationRef.update({'unreadCount': unreadCount});
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Get users by role
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching users by role: $e');
      return [];
    }
  }

  /// Calculate call statistics for a student
  ///
  /// Note: This method fetches up to 1000 calls to calculate statistics.
  /// For better performance with large datasets, consider using Firestore
  /// aggregation queries instead.
  Future<Map<String, dynamic>> getCallStatistics(String studentId) async {
    try {
      // Fetch up to 1000 calls for statistics calculation
      // TODO: Replace with Firestore aggregation queries for better performance
      final calls = await getCallLogsAsList(studentId, limit: 1000);

      final totalCalls = calls.length;
      final completedCalls = calls.where((call) {
        final status = call['status'] as String?;
        return status == 'ended' || status == 'completed';
      }).length;

      final successRate = totalCalls > 0 ? ((completedCalls / totalCalls) * 100).round() : 0;

      // Calculate total duration
      int totalDuration = 0;
      for (var call in calls) {
        final duration = call['duration'] as int? ?? 0;
        totalDuration += duration;
      }

      final averageDuration = totalCalls > 0 ? (totalDuration / totalCalls).round() : 0;

      // Count by status
      final rejectedCalls = calls.where((c) => c['status'] == 'rejected').length;
      final failedCalls = calls.where((c) => c['status'] == 'failed').length;

      return {
        'totalCalls': totalCalls,
        'successfulCalls': completedCalls,
        'rejectedCalls': rejectedCalls,
        'failedCalls': failedCalls,
        'successRate': successRate,
        'totalDuration': totalDuration,
        'averageDuration': averageDuration,
        'totalRecordingSize': 0, // Not tracking recording size yet
      };
    } catch (e) {
      debugPrint('Error calculating call statistics: $e');
      return {
        'totalCalls': 0,
        'successfulCalls': 0,
        'rejectedCalls': 0,
        'failedCalls': 0,
        'successRate': 0,
        'totalDuration': 0,
        'averageDuration': 0,
        'totalRecordingSize': 0,
      };
    }
  }
}

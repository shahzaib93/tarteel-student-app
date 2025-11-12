import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _isCacheLoaded = false; // Cache flag

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    // Skip loading if data is already cached
    if (_isCacheLoaded) {
      debugPrint('📦 Using cached messages data');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = authService.currentUser!.uid;
      final conversations = <Map<String, dynamic>>[];

      // Get student info to find assigned teacher
      final studentDoc = await firestoreService.getStudentById(userId);

      // 1. Load assigned teacher
      if (studentDoc != null && studentDoc['assignedTeacher'] != null) {
        final teacherId = studentDoc['assignedTeacher'] as String;
        final teacherDoc = await firestoreService.getTeacherById(teacherId);

        if (teacherDoc != null) {
          conversations.add({
            'userId': teacherId,
            'userName': teacherDoc['username'] ?? 'Teacher',
            'role': 'teacher',
            'isOnline': teacherDoc['isOnline'] == true,
            'conversationId': _getConversationId(userId, teacherId),
          });
        }
      }

      // 2. Load admin users
      final admins = await firestoreService.getUsersByRole('admin');
      if (admins.isNotEmpty) {
        final admin = admins.first;
        conversations.add({
          'userId': admin['id'],
          'userName': admin['username'] ?? 'Admin',
          'role': 'admin',
          'isOnline': admin['isOnline'] == true,
          'conversationId': _getConversationId(userId, admin['id']),
        });
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _isCacheLoaded = true; // Mark data as cached
        });
        debugPrint('💾 Messages data cached successfully');
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getConversationId(String userId1, String userId2) {
    final participants = [userId1, userId2]..sort();
    return participants.join('_');
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversations.isEmpty) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final selectedConversation = _conversations[_tabController.index];
    final content = _messageController.text.trim();

    _messageController.clear();

    try {
      await firestoreService.sendMessage(
        senderId: authService.currentUser!.uid,
        receiverId: selectedConversation['userId'],
        content: content,
        senderName: authService.userName,
        receiverName: selectedConversation['userName'],
        senderRole: 'student',
        receiverRole: selectedConversation['role'],
      );

      // Auto-scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_conversations.isEmpty) {
      return const Scaffold(
        appBar: null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.message_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No conversations available',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Header with tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: _conversations.map((conv) {
                    return Tab(
                      child: _buildTabLabel(conv),
                    );
                  }).toList(),
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: _conversations.isEmpty
                ? const Center(child: Text('No conversations'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: firestoreService.getMessagesForConversation(
                      _conversations[_tabController.index]['conversationId'],
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data ?? [];

                      // Mark messages as read
                      if (messages.isNotEmpty && authService.currentUser != null) {
                        Future.microtask(() {
                          firestoreService.markMessagesAsRead(
                            _conversations[_tabController.index]
                                ['conversationId'],
                            authService.currentUser!.uid,
                          );
                        });
                      }

                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'Start a conversation with ${_conversations[_tabController.index]['userName']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      // Auto-scroll to bottom when messages load
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                            _scrollController.position.maxScrollExtent,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isOwn = message['senderId'] ==
                              authService.currentUser!.uid;

                          return _buildMessageBubble(message, isOwn);
                        },
                      );
                    },
                  ),
          ),

          // Message input
          if (_conversations.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText:
                            'Message ${_conversations[_tabController.index]['userName']}...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabLabel(Map<String, dynamic> conversation) {
    final isOnline = conversation['isOnline'] == true;
    final role = conversation['role'] as String;
    final userName = conversation['userName'] as String;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: role == 'teacher'
                  ? Colors.purple
                  : Theme.of(context).primaryColor,
              child: Icon(
                role == 'teacher' ? Icons.school : Icons.admin_panel_settings,
                size: 16,
                color: Colors.white,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userName,
              style: const TextStyle(fontSize: 13),
            ),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 6,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 3),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 9,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isOwn) {
    final content = message['content'] ?? '';
    final timestamp = message['timestamp'] as DateTime?;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isOwn
              ? Theme.of(context).primaryColor.withOpacity(0.9)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isOwn ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                color: isOwn
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown time';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

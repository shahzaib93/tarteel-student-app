import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/webrtc_service.dart';
import '../services/app_config_service.dart';
import '../services/fcm_service.dart';
import '../widgets/modern_stat_card.dart';
import '../widgets/modern_teacher_card.dart';
import 'messages_screen.dart';
import 'call_logs_screen.dart';
import 'settings_screen.dart';
import '../widgets/incoming_call_dialog.dart';
import '../widgets/video_call_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isShowingDialog = false;
  bool _isNavigatingToCall = false;

  // Create screens once, not on every build
  late final List<Widget> _screens = [
    const TeachersListScreen(),
    const MessagesScreen(),
    const CallLogsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  void _initializeWebRTC() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    final appConfigService = Provider.of<AppConfigService>(context, listen: false);
    final fcmService = Provider.of<FCMService>(context, listen: false);

    if (authService.currentUser != null) {
      // Initialize FCM for push notifications
      fcmService.initialize(authService.currentUser!.uid);

      // 🎥 REQUEST CAMERA & MIC PERMISSIONS EARLY (like FCM)
      // This prevents crashes during call acceptance
      await _requestMediaPermissionsEarly();

      // Get socket URL from Firestore config
      final socketUrl = appConfigService.getSocketUrl();

      debugPrint('🔌 Connecting to socket: $socketUrl');

      webrtcService.connect(
        authService.currentUser!.uid,
        authService.userName,
        socketUrl: socketUrl,
      );

      // Set user online
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      firestoreService.setOnlineStatus(authService.currentUser!.uid, true);
    }

    // Listen for incoming calls
    webrtcService.addListener(_handleWebRTCChanges);
  }

  /// Request camera and microphone permissions early (on app startup)
  /// This is similar to how we initialize FCM early
  Future<void> _requestMediaPermissionsEarly() async {
    try {
      debugPrint('🎥 Requesting camera/mic permissions early...');

      // Request permissions
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      debugPrint('📸 Camera permission: $cameraStatus');
      debugPrint('🎤 Microphone permission: $micStatus');

      if (cameraStatus.isGranted && micStatus.isGranted) {
        debugPrint('✅ Media permissions granted!');
      } else if (cameraStatus.isDenied || micStatus.isDenied) {
        debugPrint('⚠️ Media permissions denied - user can grant later');
      } else if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        debugPrint('❌ Media permissions permanently denied');
        // Show one-time alert to guide user to settings
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera/Microphone access denied. Enable in Settings to make video calls.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting early permissions: $e');
      // Non-critical error - user can still try when call arrives
    }
  }

  void _handleWebRTCChanges() {
    if (!mounted) return;

    final webrtcService = Provider.of<WebRTCService>(context, listen: false);

    // Show incoming call dialog when call arrives (ONLY ONCE)
    if (webrtcService.callerInfo != null && !webrtcService.isInCall && !_isShowingDialog) {
      _showIncomingCallDialog();
    }
  }

  void _showIncomingCallDialog() {
    _isShowingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        onAccept: _handleAcceptCall,
        onReject: _handleRejectCall,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
        });
      }
    });
  }

  /// Handle call acceptance - does ALL the work (like React App.jsx)
  /// Permissions, answering call, navigation - everything happens here
  Future<void> _handleAcceptCall() async {
    if (_isNavigatingToCall) return; // Prevent double-tap
    if (!mounted) return; // Safety check

    debugPrint('📞 Dashboard: Starting call acceptance flow...');

    // Get WebRTCService reference BEFORE any async operations
    WebRTCService? webrtcService;
    try {
      webrtcService = Provider.of<WebRTCService>(context, listen: false);
    } catch (e) {
      debugPrint('❌ Dashboard: Failed to get WebRTCService: $e');
      return;
    }

    try {
      // Answer the call (this handles permissions internally)
      debugPrint('📞 Dashboard: Calling answerCall()...');
      await webrtcService.answerCall();
      debugPrint('📞 Dashboard: answerCall() completed, isInCall=${webrtcService.isInCall}');
      debugPrint('📞 Dashboard: localStream exists: ${webrtcService.localStream != null}');
      debugPrint('📞 Dashboard: remoteStream exists: ${webrtcService.remoteStream != null}');

      // Safety check after async operation
      if (!mounted) {
        debugPrint('⚠️ Dashboard: Widget unmounted after answerCall()');
        return;
      }

      // Check if call was actually established
      if (!webrtcService.isInCall) {
        debugPrint('❌ Dashboard: Call not established after answerCall()');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect call'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // IMPORTANT: Check if localStream is ready
      if (webrtcService.localStream == null) {
        debugPrint('❌ Dashboard: Local stream not ready after answerCall()');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize camera/microphone'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Navigate to call screen
      debugPrint('📞 Dashboard: All checks passed, navigating to VideoCallScreen...');
      _navigateToCallScreen();
      debugPrint('✅ Dashboard: Call acceptance flow completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Dashboard: Error in call acceptance: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to answer call: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Handle call rejection
  void _handleRejectCall() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    debugPrint('📞 Dashboard: Rejecting call');
    webrtcService.rejectCall();
  }

  void _navigateToCallScreen() {
    _isNavigatingToCall = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VideoCallScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isNavigatingToCall = false;
        });
      }
    });
  }

  @override
  void dispose() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    webrtcService.removeListener(_handleWebRTCChanges);

    // Set user offline
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (authService.currentUser != null) {
      firestoreService.setOnlineStatus(authService.currentUser!.uid, false);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF76a6f6),
                Color(0xFF5a8edb),
              ],
            ),
          ),
          child: SafeArea(
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    width: 40,
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      'Tarteel-e-Quran',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Home Dashboard Tab
class TeachersListScreen extends StatefulWidget {
  const TeachersListScreen({super.key});

  @override
  State<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends State<TeachersListScreen> with AutomaticKeepAliveClientMixin {
  String? _assignedTeacherId;
  int _totalClasses = 0;
  int _classesThisWeek = 0;
  int _classesThisMonth = 0;
  int _newMessages = 0;
  int _successRate = 0;
  bool _isLoading = true;
  bool _isCacheLoaded = false; // Cache flag

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Skip loading if data is already cached
    if (_isCacheLoaded) {
      debugPrint('📦 Using cached dashboard data');
      return;
    }

    setState(() => _isLoading = true);
    await Future.wait([
      _loadTeacherInfo(),
      _loadCallStats(),
      _loadMessageCount(),
    ]);
    setState(() {
      _isLoading = false;
      _isCacheLoaded = true; // Mark data as cached
    });
    debugPrint('💾 Dashboard data cached successfully');
  }

  Future<void> _loadTeacherInfo() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser != null) {
      // Get student info to find their assigned teacher
      final studentDoc = await firestoreService.getStudentById(authService.currentUser!.uid);
      if (studentDoc != null && studentDoc['assignedTeacher'] != null) {
        if (mounted) {
          setState(() => _assignedTeacherId = studentDoc['assignedTeacher']);
        }
      }
    }
  }

  Future<void> _loadCallStats() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser != null) {
      final calls = await firestoreService.getCallLogsAsList(authService.currentUser!.uid);

      final now = DateTime.now();

      // Calculate start of week (Monday)
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1), // Monday is day 1
        0, 0, 0,
      );

      // Calculate start of month
      final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);

      int totalCalls = calls.length;
      int weekCalls = 0;
      int monthCalls = 0;
      int completedCalls = 0;

      for (var call in calls) {
        final callDate = call['startTime'] as DateTime?;
        if (callDate != null) {
          if (callDate.isAfter(weekStart) || callDate.isAtSameMomentAs(weekStart)) {
            weekCalls++;
          }
          if (callDate.isAfter(monthStart) || callDate.isAtSameMomentAs(monthStart)) {
            monthCalls++;
          }
        }

        // Success rate: calls with status 'completed' or 'ended'
        final status = call['status'] as String?;
        if (status == 'completed' || status == 'ended') {
          completedCalls++;
        }
      }

      if (mounted) {
        setState(() {
          _totalClasses = totalCalls;
          _classesThisWeek = weekCalls;
          _classesThisMonth = monthCalls;
          _successRate = totalCalls > 0 ? ((completedCalls / totalCalls * 100).round()) : 0;
        });
      }
    }
  }

  Future<void> _loadMessageCount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser != null) {
      final unreadCount = await firestoreService.getUnreadMessageCount(authService.currentUser!.uid);
      if (mounted) {
        setState(() => _newMessages = unreadCount);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authService = Provider.of<AuthService>(context);
    final userName = authService.userName;
    final greeting = _getGreeting();

    return RefreshIndicator(
        onRefresh: () async {
          setState(() => _isCacheLoaded = false); // Clear cache flag
          await _loadDashboardData();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Greeting Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.1),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getGreetingIcon(),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting, $userName!',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ready for today\'s learning session?',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistics Cards
                    _buildStatisticsSection(),

                    const SizedBox(height: 16),

                    // Teacher Info Card
                    if (_assignedTeacherId != null) _buildTeacherCard(),

                    const SizedBox(height: 12),

                    // Today's Schedule
                    _buildScheduleCard(),
                  ],
                ),
              ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny; // Morning
    if (hour < 17) return Icons.light_mode; // Afternoon
    return Icons.nights_stay; // Evening
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Statistics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 160,
                child: ModernStatCard(
                  title: 'Total Classes',
                  value: (_totalClasses ?? 0).toString(),
                  icon: Icons.video_library,
                  color: const Color(0xFF6366F1),
                  subtitle: '${_classesThisMonth ?? 0} this month',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: ModernStatCard(
                  title: 'This Week',
                  value: (_classesThisWeek ?? 0).toString(),
                  icon: Icons.calendar_today,
                  color: const Color(0xFF8B5CF6),
                  subtitle: 'Classes attended',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: ModernStatCard(
                  title: 'Success Rate',
                  value: '${_successRate ?? 0}%',
                  icon: Icons.trending_up,
                  color: const Color(0xFF10B981),
                  subtitle: 'Call completion',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildTeacherCard() {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: firestoreService.getTeacherStream(_assignedTeacherId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.08),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.12),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final teacherInfo = snapshot.data!;
        final isOnline = teacherInfo['isOnline'] == true;
        final teacherName = teacherInfo['username'] ?? 'Teacher';

        // Get recent message preview (you can add this to the StreamBuilder if needed)
        // For now, we'll leave it null
        const String? recentMessage = null;

        return ModernTeacherCard(
          teacherName: teacherName,
          isOnline: isOnline,
          unreadCount: _newMessages,
          recentMessage: recentMessage,
          onMessage: () {
            // Navigate to messages tab (index 1)
            final dashboardState = context.findAncestorStateOfType<_DashboardScreenState>();
            dashboardState?.setState(() {
              dashboardState._selectedIndex = 1;
            });
          },
        );
      },
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.08),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Schedule",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    // View full schedule
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getTodaySchedule(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final classes = snapshot.data ?? [];

                if (classes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No classes scheduled for today',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: classes.take(3).map((classItem) {
                    final time = _formatTime(classItem['scheduledTime']);
                    final subject = classItem['subject'] ?? 'Quran Class';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.1),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getTodaySchedule() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser != null) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return firestoreService.getScheduledClasses(
        authService.currentUser!.uid,
        startOfDay,
        endOfDay,
      );
    }

    return Stream.value([]);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Not scheduled';

    try {
      final dateTime = (timestamp as dynamic).toDate() as DateTime;
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$displayHour:$minute $period';
    } catch (e) {
      return 'Invalid time';
    }
  }
}

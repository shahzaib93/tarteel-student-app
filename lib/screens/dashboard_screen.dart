import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/webrtc_service.dart';
import '../services/app_config_service.dart';
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

  late final List<Widget> _screens = [
    const TeachersListScreen(),
    const MessagesScreen(),
    const CallLogsScreen(),
    const SettingsScreen(),
  ];

  AuthService? _authService;
  FirestoreService? _firestoreService;
  WebRTCService? _webrtcService;
  AppConfigService? _appConfigService;

  bool _webRtcInitialized = false;
  bool _isVideoCallScreenOpen = false;
  bool _isIncomingCallDialogVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService ??= Provider.of<AuthService>(context, listen: false);
    _firestoreService ??= Provider.of<FirestoreService>(context, listen: false);
    _webrtcService ??= Provider.of<WebRTCService>(context, listen: false);
    _appConfigService ??= Provider.of<AppConfigService>(context, listen: false);

    if (!_webRtcInitialized) {
      _webRtcInitialized = true;
      _initializeWebRTC();
    }
  }

  void _initializeWebRTC() {
    final authService = _authService;
    final webrtcService = _webrtcService;
    final appConfigService = _appConfigService;
    final firestoreService = _firestoreService;

    if (authService == null || webrtcService == null || appConfigService == null) {
      return;
    }

    if (authService.currentUser != null) {
      final socketUrl = appConfigService.getSocketUrl();

      debugPrint('🔌 Connecting to socket: $socketUrl');

      webrtcService.connect(
        authService.currentUser!.uid,
        authService.userName,
        socketUrl: socketUrl,
      );

      firestoreService?.setOnlineStatus(authService.currentUser!.uid, true);
    }

    webrtcService.addListener(_handleWebRTCChanges);
  }

  void _handleWebRTCChanges() {
    final webrtcService = _webrtcService;
    if (webrtcService == null) {
      return;
    }

    final hasIncomingCall = webrtcService.callerInfo != null && !webrtcService.isInCall;
    if (hasIncomingCall && !_isIncomingCallDialogVisible) {
      _showIncomingCallDialog();
    } else if (!hasIncomingCall && _isIncomingCallDialogVisible) {
      _dismissIncomingCallDialog();
    }

    if (webrtcService.isInCall && !_isVideoCallScreenOpen) {
      _isVideoCallScreenOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const VideoCallScreen(),
                fullscreenDialog: true,
              ),
            )
            .whenComplete(() {
          _isVideoCallScreenOpen = false;
        });
      });
    } else if (!webrtcService.isInCall && _isVideoCallScreenOpen) {
      _isVideoCallScreenOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _showIncomingCallDialog() {
    if (_isIncomingCallDialogVisible) {
      return;
    }
    _isIncomingCallDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const IncomingCallDialog(),
    ).whenComplete(() {
      _isIncomingCallDialogVisible = false;
    });
  }

  void _dismissIncomingCallDialog() {
    if (!_isIncomingCallDialogVisible) {
      return;
    }
    Navigator.of(context, rootNavigator: true).maybePop();
    _isIncomingCallDialogVisible = false;
  }

  @override
  void dispose() {
    _webrtcService?.removeListener(_handleWebRTCChanges);

    final authService = _authService;
    final firestoreService = _firestoreService;
    if (authService?.currentUser != null && firestoreService != null) {
      firestoreService.setOnlineStatus(authService!.currentUser!.uid, false);
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

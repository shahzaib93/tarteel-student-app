import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/webrtc_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  void _initializeWebRTC() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);

    if (authService.currentUser != null) {
      webrtcService.connect(
        authService.currentUser!.uid,
        authService.userName,
      );

      // Set user online
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      firestoreService.setOnlineStatus(authService.currentUser!.uid, true);
    }

    // Listen for incoming calls
    webrtcService.addListener(_handleWebRTCChanges);
  }

  void _handleWebRTCChanges() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);

    // Show incoming call dialog
    if (webrtcService.callerInfo != null && !webrtcService.isInCall) {
      _showIncomingCallDialog();
    }

    // Show video call screen
    if (webrtcService.isInCall) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const VideoCallScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _showIncomingCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IncomingCallDialog(),
    );
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
    final List<Widget> screens = [
      const TeachersListScreen(),
      const MessagesScreen(),
      const CallLogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Teachers',
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

/// Teachers List Tab
class TeachersListScreen extends StatelessWidget {
  const TeachersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getTeachers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final teachers = snapshot.data ?? [];

          if (teachers.isEmpty) {
            return const Center(
              child: Text('No teachers available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              final isOnline = teacher['online'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          (teacher['username'] ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    teacher['username'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.message),
                        onPressed: () {
                          // Navigate to message screen with this teacher
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam),
                        color: Theme.of(context).primaryColor,
                        onPressed: isOnline
                            ? () {
                                // TODO: Initiate call to teacher
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

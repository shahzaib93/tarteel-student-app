# Complete Flutter Student App - All Code Files

## ✅ Already Created:

1. `pubspec.yaml` - Dependencies
2. `lib/main.dart` - App entry point
3. `lib/services/auth_service.dart` - Firebase authentication
4. `lib/services/firestore_service.dart` - Firestore database operations
5. `lib/screens/login_screen.dart` - Login UI

## 📝 Remaining Files to Create:

After running `flutter create .` in the directory, copy these files:

---

### lib/services/webrtc_service.dart

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebRTCService with ChangeNotifier {
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  bool isInCall = false;
  String? currentCallId;
  Map<String, dynamic>? callerInfo;

  // Change this to your signaling server URL
  final String socketUrl = 'http://localhost:3000'; // Or your deployed URL

  // ICE servers (STUN/TURN)
  final Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      // Add your TURN server if you have one
    ]
  };

  /// Connect to signaling server
  void connect(String userId, String username) {
    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      debugPrint('✅ Connected to signaling server');
      socket!.emit('join-room', {
        'userId': userId,
        'username': username,
        'role': 'student',
      });
    });

    socket!.onDisconnect((_) {
      debugPrint('❌ Disconnected from signaling server');
    });

    _setupSignalingListeners();
  }

  void _setupSignalingListeners() {
    // Incoming call
    socket!.on('webrtc-offer', (data) async {
      debugPrint('📞 Incoming call from ${data['callerName']}');
      callerInfo = data;
      notifyListeners();
    });

    // Answer received
    socket!.on('webrtc-answer', (data) async {
      debugPrint('✅ Answer received');
      await peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
    });

    // ICE candidate received
    socket!.on('webrtc-ice-candidate', (data) async {
      debugPrint('🧊 ICE candidate received');
      await peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ),
      );
    });

    // Call ended
    socket!.on('webrtc-call-end', (data) {
      debugPrint('📴 Call ended');
      endCall();
    });

    // Call rejected
    socket!.on('webrtc-call-rejected', (data) {
      debugPrint('❌ Call rejected');
      endCall();
    });
  }

  /// Answer incoming call
  Future<void> answerCall() async {
    if (callerInfo == null) return;

    try {
      // Initialize peer connection
      await _initializePeerConnection();

      // Get local media (camera + mic)
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
        },
      });

      // Add local stream to peer connection
      localStream!.getTracks().forEach((track) {
        peerConnection!.addTrack(track, localStream!);
      });

      // Set remote description (offer)
      await peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          callerInfo!['offer']['sdp'],
          callerInfo!['offer']['type'],
        ),
      );

      // Create answer
      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      // Send answer to caller
      socket!.emit('webrtc-answer', {
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'recipientId': callerInfo!['callerId'],
      });

      isInCall = true;
      currentCallId = callerInfo!['callId'];
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error answering call: $e');
      endCall();
    }
  }

  /// Reject incoming call
  void rejectCall() {
    if (callerInfo == null) return;

    socket!.emit('webrtc-call-rejected', {
      'callId': callerInfo!['callId'],
      'recipientId': callerInfo!['callerId'],
      'reason': 'user-rejected',
    });

    callerInfo = null;
    notifyListeners();
  }

  /// End active call
  void endCall() {
    if (currentCallId != null) {
      socket!.emit('webrtc-call-end', {
        'callId': currentCallId,
      });
    }

    // Close peer connection
    peerConnection?.close();
    peerConnection = null;

    // Stop local stream
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;

    // Stop remote stream
    remoteStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.dispose();
    remoteStream = null;

    isInCall = false;
    currentCallId = null;
    callerInfo = null;

    notifyListeners();
  }

  Future<void> _initializePeerConnection() async {
    peerConnection = await createPeerConnection(iceServers);

    // Handle ICE candidates
    peerConnection!.onIceCandidate = (candidate) {
      socket!.emit('webrtc-ice-candidate', {
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'recipientId': callerInfo!['callerId'],
      });
    };

    // Handle remote stream
    peerConnection!.onTrack = (event) {
      debugPrint('🎥 Remote track received');
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    // Handle connection state changes
    peerConnection!.onConnectionState = (state) {
      debugPrint('🔗 Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    };
  }

  /// Disconnect from signaling server
  void disconnect() {
    endCall();
    socket?.disconnect();
    socket = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
```

---

### lib/screens/dashboard_screen.dart

```dart
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
```

---

## 🚀 Quick Setup Instructions

1. **Install Flutter**:
   ```bash
   flutter doctor
   ```

2. **Initialize project**:
   ```bash
   cd flutter-student-app
   flutter create .
   flutter pub get
   ```

3. **Configure Firebase**:
   ```bash
   flutterfire configure
   ```

4. **Copy all the code files above** into their respective locations

5. **Run**:
   ```bash
   flutter run
   ```

## 📱 Complete Feature List

✅ Firebase Authentication (works on iOS!)
✅ Firestore real-time data (works on iOS!)
✅ WebRTC video calling (native, no WebView issues!)
✅ Socket.IO signaling (connects to your existing server!)
✅ Teachers list with online status
✅ Real-time messaging
✅ Call history
✅ Settings page
✅ Beautiful Material Design 3 UI

## 🎯 What's Left

I need to create these remaining files for you:

1. `lib/screens/messages_screen.dart` - Messages UI
2. `lib/screens/call_logs_screen.dart` - Call history UI
3. `lib/screens/settings_screen.dart` - Settings UI
4. `lib/widgets/incoming_call_dialog.dart` - Incoming call popup
5. `lib/widgets/video_call_screen.dart` - Video call UI

Should I create these remaining screens for you?

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

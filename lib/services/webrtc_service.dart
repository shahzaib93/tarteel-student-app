import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'settings_service.dart';

class WebRTCService with ChangeNotifier {
  SettingsService? _settingsService;

  /// Set settings service for video call preferences
  void setSettingsService(SettingsService settingsService) {
    _settingsService = settingsService;
    debugPrint('✅ Settings service linked to WebRTC service');
  }
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  bool isInCall = false;
  String? currentCallId;
  Map<String, dynamic>? callerInfo;

  // Queue for ICE candidates received before peer connection is ready
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  // Dynamic socket URL (will be set from Firestore config)
  String? _socketUrl;

  // Default TURN server config
  static const Map<String, dynamic> _defaultIceServers = {
    'iceServers': [
      {
        'urls': [
          'turn:31.97.188.80:3478',
          'turn:31.97.188.80:3478?transport=tcp',
        ],
        'username': 'coturn_user',
        'credential': 'test123',
      }
    ],
    'iceCandidatePoolSize': 10,
  };

  // ICE servers (STUN/TURN) - will be configured dynamically
  Map<String, dynamic> _iceServers = Map<String, dynamic>.from(_defaultIceServers);

  /// Configure TURN server
  void configureTurnServer(Map<String, dynamic>? turnConfig) {
    if (turnConfig == null) {
      debugPrint('⚠️ No TURN config provided, using defaults');
      return;
    }

    final urls = turnConfig['urls'] as List?;
    final username = turnConfig['username'] as String?;
    final credential = turnConfig['credential'] as String?;

    if (urls == null || urls.isEmpty) {
      debugPrint('⚠️ TURN config missing URLs, using defaults');
      return;
    }

    _iceServers = {
      'iceServers': [
        {
          'urls': urls,
          'username': username,
          'credential': credential,
        }
      ],
      'iceCandidatePoolSize': 10,
    };

    debugPrint('✅ TURN server configured: ${turnConfig['host'] ?? 'custom'}');
  }

  /// Connect to signaling server
  void connect(String userId, String username, {String? socketUrl}) {
    // Use provided socketUrl or fallback to stored one
    final url = socketUrl ?? _socketUrl ?? 'http://192.95.33.150:5003';
    _socketUrl = url;

    debugPrint('🔌 Connecting to signaling server: $url');

    socket = IO.io(url, <String, dynamic>{
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

      try {
        // Extract candidate data safely
        final candidateData = data['candidate'];
        final candidateStr = candidateData['candidate']?.toString();
        final sdpMid = candidateData['sdpMid']?.toString();
        final sdpMLineIndex = candidateData['sdpMLineIndex'] as int?;

        if (candidateStr == null) {
          debugPrint('⚠️ Invalid ICE candidate data: candidate string is null');
          return;
        }

        final candidate = RTCIceCandidate(
          candidateStr,
          sdpMid,
          sdpMLineIndex,
        );

        // If peer connection exists, add candidate immediately
        if (peerConnection != null) {
          try {
            await peerConnection!.addCandidate(candidate);
            debugPrint('✅ ICE candidate added');
          } catch (e) {
            debugPrint('⚠️ Error adding ICE candidate: $e');
          }
        } else {
          // Otherwise, queue it for later
          debugPrint('📦 Queuing ICE candidate (peer connection not ready)');
          _pendingIceCandidates.add(candidate);
        }
      } catch (e) {
        debugPrint('❌ Error processing ICE candidate: $e');
      }
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

      // Get video constraints from settings (HD or Standard quality)
      final videoConstraints = _settingsService?.getVideoConstraints() ?? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      };

      // Enable speakerphone BEFORE getting media (iOS requirement)
      await Helper.setSpeakerphoneOn(true);
      debugPrint('🔊 Speakerphone enabled BEFORE getUserMedia');

      // Get local media (camera + mic)
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        'video': videoConstraints,
      });

      // Ensure speakerphone is still on after getUserMedia
      await Helper.setSpeakerphoneOn(true);
      debugPrint('🔊 Speakerphone enforced AFTER getUserMedia');

      // Apply default microphone and camera settings
      final micDefault = _settingsService?.microphoneDefault ?? true;
      final cameraDefault = _settingsService?.cameraDefault ?? true;

      debugPrint('🎤 Microphone default: $micDefault');
      debugPrint('📹 Camera default: $cameraDefault');

      // Set initial enabled states based on settings
      localStream!.getAudioTracks().forEach((track) {
        track.enabled = micDefault;
      });

      localStream!.getVideoTracks().forEach((track) {
        track.enabled = cameraDefault;
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

      // Process any pending ICE candidates that arrived before peer connection was ready
      if (_pendingIceCandidates.isNotEmpty) {
        debugPrint('📤 Processing ${_pendingIceCandidates.length} pending ICE candidates');
        for (final candidate in _pendingIceCandidates) {
          try {
            await peerConnection!.addCandidate(candidate);
            debugPrint('✅ Pending ICE candidate added');
          } catch (e) {
            debugPrint('⚠️ Error adding pending ICE candidate: $e');
          }
        }
        _pendingIceCandidates.clear();
        debugPrint('🧹 Cleared pending ICE candidates queue');
      }

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

    // Clear any pending ICE candidates
    if (_pendingIceCandidates.isNotEmpty) {
      debugPrint('🧹 Clearing ${_pendingIceCandidates.length} pending ICE candidates on call end');
      _pendingIceCandidates.clear();
    }

    isInCall = false;
    currentCallId = null;
    callerInfo = null;

    notifyListeners();
  }

  Future<void> _initializePeerConnection() async {
    peerConnection = await createPeerConnection(_iceServers);

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

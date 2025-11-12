import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;

  // Store reference to avoid accessing context during dispose
  WebRTCService? _webrtcService;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to WebRTCService for safe disposal
    _webrtcService = Provider.of<WebRTCService>(context, listen: false);
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final webrtcService = Provider.of<WebRTCService>(context, listen: false);

    if (webrtcService.localStream != null) {
      _localRenderer.srcObject = webrtcService.localStream;
    }

    if (webrtcService.remoteStream != null) {
      _remoteRenderer.srcObject = webrtcService.remoteStream;
    }

    webrtcService.addListener(_updateStreams);
  }

  void _updateStreams() {
    if (!mounted) return;

    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    bool needsUpdate = false;

    if (webrtcService.localStream != null && _localRenderer.srcObject == null) {
      _localRenderer.srcObject = webrtcService.localStream;
      debugPrint('📹 Local stream attached to renderer');
      needsUpdate = true;
    }

    if (webrtcService.remoteStream != null && _remoteRenderer.srcObject == null) {
      _remoteRenderer.srcObject = webrtcService.remoteStream;
      debugPrint('🎥 Remote stream attached to renderer');
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }

    if (!webrtcService.isInCall && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Use saved reference instead of accessing context
    _webrtcService?.removeListener(_updateStreams);
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _toggleMute() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    if (webrtcService.localStream != null) {
      final audioTrack = webrtcService.localStream!
          .getAudioTracks()
          .firstOrNull;
      if (audioTrack != null) {
        setState(() {
          _isMuted = !_isMuted;
          audioTrack.enabled = !_isMuted; // enabled when NOT muted
        });
        debugPrint('🎤 Microphone ${_isMuted ? 'muted' : 'unmuted'}');
      }
    }
  }

  void _toggleVideo() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    if (webrtcService.localStream != null) {
      final videoTrack = webrtcService.localStream!
          .getVideoTracks()
          .firstOrNull;
      if (videoTrack != null) {
        setState(() {
          _isVideoOff = !_isVideoOff;
          videoTrack.enabled = !_isVideoOff; // enabled when NOT off
        });
        debugPrint('📹 Camera ${_isVideoOff ? 'off' : 'on'}');
      }
    }
  }

  void _endCall() {
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    webrtcService.endCall();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final webrtcService = Provider.of<WebRTCService>(context);
    final callerName = webrtcService.callerInfo?['callerName'] ?? 'Teacher';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video (Full Screen)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: false,
              ),
            ),

            // Local Video (Picture-in-Picture)
            Positioned(
              top: 16,
              right: 16,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
              ),
            ),

            // Top Bar (Caller Name)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute/Unmute
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted ? Colors.red : Colors.white.withOpacity(0.3),
                  ),

                  // Video On/Off
                  _buildControlButton(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    onPressed: _toggleVideo,
                    backgroundColor: _isVideoOff ? Colors.red : Colors.white.withOpacity(0.3),
                  ),

                  // End Call
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    size: 64,
                  ),

                  // Speaker On/Off
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    onPressed: () async {
                      await Helper.setSpeakerphoneOn(!_isSpeakerOn);
                      setState(() {
                        _isSpeakerOn = !_isSpeakerOn;
                      });
                    },
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),

                  // Switch Camera
                  _buildControlButton(
                    icon: Icons.cameraswitch,
                    onPressed: () async {
                      final webrtcService = Provider.of<WebRTCService>(context, listen: false);
                      if (webrtcService.localStream != null) {
                        await Helper.switchCamera(webrtcService.localStream!.getVideoTracks()[0]);
                      }
                    },
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: size * 0.4,
        onPressed: onPressed,
      ),
    );
  }
}

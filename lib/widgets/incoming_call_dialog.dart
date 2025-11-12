import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/webrtc_service.dart';

class IncomingCallDialog extends StatefulWidget {
  const IncomingCallDialog({super.key});

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  Future<void> _startRinging() async {
    if (_isPlaying) return;

    try {
      _isPlaying = true;
      // Play system notification sound in a loop
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      // Use asset or URL for ringtone - for now using a notification sound
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      debugPrint('🔔 Ringtone started');
    } catch (e) {
      debugPrint('❌ Error playing ringtone: $e');
      // Fallback: try to use system sound if custom sound fails
    }
  }

  Future<void> _stopRinging() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      debugPrint('🔕 Ringtone stopped');
    } catch (e) {
      debugPrint('❌ Error stopping ringtone: $e');
    }
  }

  @override
  void dispose() {
    _stopRinging();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webrtcService = Provider.of<WebRTCService>(context);
    final callerInfo = webrtcService.callerInfo;

    // If caller info is null, stop ringing and dismiss dialog
    if (callerInfo == null) {
      _stopRinging();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Caller Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // Caller Name
            Text(
              callerInfo['callerName'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Incoming Call Text
            const Text(
              'Incoming video call...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject Button
                Column(
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        _stopRinging();
                        webrtcService.rejectCall();
                        Navigator.of(context).pop();
                      },
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Decline',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),

                // Accept Button
                Column(
                  children: [
                    FloatingActionButton(
                      onPressed: () async {
                        _stopRinging();
                        Navigator.of(context).pop();
                        await webrtcService.answerCall();
                      },
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.videocam, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Accept',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

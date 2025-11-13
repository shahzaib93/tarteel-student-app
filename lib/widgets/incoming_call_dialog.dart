import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/webrtc_service.dart';

class IncomingCallDialog extends StatefulWidget {
  const IncomingCallDialog({super.key});

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  Timer? _vibrationTimer;
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  Future<void> _startRinging() async {
    if (_isRinging) return;

    try {
      _isRinging = true;

      // Vibrate immediately
      await _vibrate();
      debugPrint('📳 Started vibrating for incoming call');

      // Vibrate every 1.5 seconds
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
        await _vibrate();
      });

      debugPrint('🔔 Ringtone started (vibration pattern)');
    } catch (e) {
      debugPrint('❌ Error starting ringtone: $e');
    }
  }

  Future<void> _vibrate() async {
    try {
      // Vibration pattern: 200ms on, 100ms off, 200ms on, 100ms off, 200ms on
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('⚠️ Vibration not available: $e');
    }
  }

  Future<void> _stopRinging() async {
    if (!_isRinging) return;

    try {
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _isRinging = false;
      debugPrint('🔕 Ringtone stopped');
    } catch (e) {
      debugPrint('❌ Error stopping ringtone: $e');
    }
  }

  @override
  void dispose() {
    _stopRinging();
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

                        try {
                          await webrtcService.answerCall();
                        } catch (e) {
                          // Show error message if permissions denied or other error
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().contains('permission')
                                      ? 'Camera or microphone permission denied. Please enable in settings.'
                                      : 'Failed to answer call: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: Colors.white,
                                  onPressed: () {},
                                ),
                              ),
                            );
                          }
                        }
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

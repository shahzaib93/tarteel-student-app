import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';

/// Incoming call dialog - PURE UI COMPONENT
/// Does NOT handle permissions, navigation, or call logic
/// Only shows UI and calls callbacks (like React IncomingCallModal)
class IncomingCallDialog extends StatelessWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const IncomingCallDialog({
    super.key,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCService>(
      builder: (context, webrtcService, child) {
        final callerInfo = webrtcService.callerInfo;

        // Auto-dismiss if caller hung up
        if (callerInfo == null) {
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
                            // Close dialog first, THEN reject
                            Navigator.of(context).pop();
                            if (onReject != null) {
                              onReject!();
                            } else {
                              webrtcService.rejectCall();
                            }
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
                          onPressed: () {
                            // Close dialog first, THEN accept (parent handles everything)
                            Navigator.of(context).pop();
                            if (onAccept != null) {
                              onAccept!();
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
      },
    );
  }
}

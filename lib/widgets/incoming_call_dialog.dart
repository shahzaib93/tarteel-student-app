import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';

class IncomingCallDialog extends StatefulWidget {
  const IncomingCallDialog({super.key});

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  bool _isAnswering = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final webrtcService = Provider.of<WebRTCService>(context);
    final callerInfo = webrtcService.callerInfo;

    // If caller info is null, schedule dialog dismissal after build completes
    if (callerInfo == null && !_isAnswering) {
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

            // Status Message
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Loading indicator
            if (_isAnswering)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              ),

            // Action Buttons
            if (!_isAnswering)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject Button
                  Column(
                    children: [
                      FloatingActionButton(
                        onPressed: () {
                          webrtcService.rejectCall();
                          if (context.mounted) {
                            Navigator.of(context).pop();
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
                        onPressed: () async {
                          setState(() {
                            _isAnswering = true;
                            _statusMessage = 'Connecting...';
                          });

                          try {
                            setState(() => _statusMessage = 'Checking permissions...');
                            await Future.delayed(const Duration(milliseconds: 100));

                            await webrtcService.answerCall();

                            setState(() => _statusMessage = 'Call connected!');
                            await Future.delayed(const Duration(milliseconds: 500));

                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _isAnswering = false;
                                _statusMessage = 'Error: ${e.toString()}';
                              });

                              await Future.delayed(const Duration(seconds: 3));

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
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

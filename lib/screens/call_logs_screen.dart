import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _calls = [];
  String _statusFilter = 'all';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 10;
  final Map<String, Map<String, dynamic>> _teacherCache = {};

  // Cache flag - true means data is already loaded
  bool _isCacheLoaded = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs({bool isRefresh = false}) async {
    if (!mounted) return;

    // Skip loading if data is already cached (unless explicitly refreshing)
    if (_isCacheLoaded && !isRefresh) {
      debugPrint('📦 Using cached call logs data');
      return;
    }

    if (isRefresh) {
      debugPrint('🔄 Refreshing call logs from Firestore...');
      setState(() {
        _isLoading = true;
        _calls = [];
        _hasMore = true;
        _teacherCache.clear();
        _isCacheLoaded = false;
      });
    } else {
      setState(() => _isLoading = true);
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      debugPrint('📞 Loading call statistics...');
      // Load stats (only once, not paginated)
      final stats = await firestoreService.getCallStatistics(authService.currentUser!.uid);
      debugPrint('📊 Stats loaded: ${stats['totalCalls']} total calls');

      debugPrint('📞 Loading first $_pageSize call logs...');
      // Load only first page of calls
      final calls = await firestoreService.getCallLogsAsList(
        authService.currentUser!.uid,
        limit: _pageSize,
      );
      debugPrint('📞 Loaded ${calls.length} calls');

      // Check if there are more calls
      final hasMore = calls.length == _pageSize;

      // Fetch teacher details with caching
      final callsWithTeachers = await _loadTeachersForCalls(calls, firestoreService);

      debugPrint('✅ Call logs loaded successfully');

      if (mounted) {
        setState(() {
          _stats = stats;
          _calls = callsWithTeachers;
          _hasMore = hasMore;
          _isLoading = false;
          _isCacheLoaded = true; // Mark data as cached
        });
        debugPrint('💾 Call logs cached successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading call logs: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          // Set empty data on error
          _stats = {
            'totalCalls': 0,
            'successfulCalls': 0,
            'successRate': 0,
            'totalDuration': 0,
            'averageDuration': 0,
          };
          _calls = [];
        });

        // Show error in console instead of SnackBar since we don't have Scaffold
        debugPrint('⚠️ Failed to load call logs. Showing empty state.');
      }
    }
  }

  Future<void> _loadMoreCalls() async {
    if (_isLoadingMore || !_hasMore || !mounted) return;

    setState(() => _isLoadingMore = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    if (authService.currentUser == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    try {
      debugPrint('📞 Loading more call logs (offset: ${_calls.length})...');

      // Load next page of calls
      final calls = await firestoreService.getCallLogsAsList(
        authService.currentUser!.uid,
        limit: _pageSize,
        offset: _calls.length,
      );
      debugPrint('📞 Loaded ${calls.length} more calls');

      // Check if there are more calls
      final hasMore = calls.length == _pageSize;

      // Fetch teacher details with caching
      final callsWithTeachers = await _loadTeachersForCalls(calls, firestoreService);

      if (mounted) {
        setState(() {
          _calls.addAll(callsWithTeachers);
          _hasMore = hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading more calls: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadTeachersForCalls(
    List<Map<String, dynamic>> calls,
    FirestoreService firestoreService,
  ) async {
    final callsWithTeachers = <Map<String, dynamic>>[];

    for (var call in calls) {
      final teacherId = call['teacherId'] as String?;
      Map<String, dynamic>? teacher;

      if (teacherId != null) {
        // Check cache first
        if (_teacherCache.containsKey(teacherId)) {
          teacher = _teacherCache[teacherId];
        } else {
          try {
            teacher = await firestoreService.getTeacherById(teacherId);
            if (teacher != null) {
              _teacherCache[teacherId] = teacher;
              debugPrint('👨‍🏫 Loaded teacher: ${teacher['username']} (cached)');
            }
          } catch (e) {
            debugPrint('⚠️ Error loading teacher $teacherId: $e');
          }
        }
      }

      callsWithTeachers.add({
        ...call,
        'teacher': teacher,
      });
    }

    return callsWithTeachers;
  }

  void _showCallDetails(Map<String, dynamic> call) {
    showDialog(
      context: context,
      builder: (context) => _CallDetailsDialog(call: call),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'N/A';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ended':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'failed':
        return Colors.red;
      case 'accepted':
      case 'connected':
        return Theme.of(context).primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'ended':
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
      case 'failed':
        return Icons.error;
      case 'accepted':
      case 'connected':
        return Icons.videocam;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Call History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'View your past video calls',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadCallLogs(isRefresh: true),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Stats Cards
                        if (_stats != null) ...[
                          _buildStatisticsSection(),
                          const SizedBox(height: 24),
                        ],

                        // Status Filter
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Status Filter',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All')),
                                  DropdownMenuItem(value: 'ended', child: Text('Completed')),
                                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _statusFilter = value);
                                    _loadCallLogs();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Call List
                        if (_calls.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No calls found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your call history will appear here',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              Card(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _calls.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                final call = _calls[index];
                                final teacher = call['teacher'] as Map<String, dynamic>?;
                                final teacherName = teacher?['username'] ?? 'Unknown Teacher';
                                final status = call['status'] as String?;
                                final startTime = call['startTime'] as DateTime?;
                                final duration = call['duration'] as int? ?? 0;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacherName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Chip(
                                        label: Text(
                                          status ?? 'unknown',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        avatar: Icon(
                                          _getStatusIcon(status),
                                          size: 14,
                                          color: _getStatusColor(status),
                                        ),
                                        backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          startTime != null
                                              ? DateFormat('MMM d, HH:mm').format(startTime)
                                              : 'N/A',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onPressed: () => _showCallDetails(call),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                        // Load More Button
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _isLoadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _loadMoreCalls,
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('Load More'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      );
  }

  Widget _buildStatisticsSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            title: 'Total Calls',
            value: _stats!['totalCalls'].toString(),
            subtitle: 'All time',
            icon: Icons.videocam,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            title: 'Successful',
            value: _stats!['successfulCalls'].toString(),
            subtitle: '${_stats!['successRate']}% rate',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            title: 'Duration',
            value: _formatDuration(_stats!['totalDuration']),
            subtitle: 'Avg: ${_formatDuration(_stats!['averageDuration'])}',
            icon: Icons.schedule,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Call Details Dialog
class _CallDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> call;

  const _CallDetailsDialog({required this.call});

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'N/A';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final teacher = call['teacher'] as Map<String, dynamic>?;
    final teacherName = teacher?['username'] ?? 'Unknown Teacher';
    final teacherEmail = teacher?['email'] ?? 'No email available';
    final status = call['status'] as String?;
    final startTime = call['startTime'] as DateTime?;
    final endTime = call['endTime'] as DateTime?;
    final duration = call['duration'] as int? ?? 0;
    final callId = call['id'] ?? 'Unknown';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Call Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Call Information
                    _buildSection(
                      title: 'Call Information',
                      children: [
                        _buildInfoRow('Call ID', callId),
                        _buildInfoRow('Status', status ?? 'Unknown'),
                        _buildInfoRow('Duration', _formatDuration(duration)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Teacher Information
                    _buildSection(
                      title: 'Teacher Information',
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacherName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    teacherEmail,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Timeline
                    _buildSection(
                      title: 'Timeline',
                      children: [
                        if (startTime != null)
                          _buildInfoRow(
                            'Call Started',
                            DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm:ss').format(startTime),
                          ),
                        if (endTime != null)
                          _buildInfoRow(
                            'Call Ended',
                            DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm:ss').format(endTime),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/run_data.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<RunData> _runHistory = [];

  @override
  void initState() {
    super.initState();
    _loadRunHistory();
  }

  // Load user's run history from Firestore
  Future<void> _loadRunHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final history = await firebaseService.getUserRunHistory();

      setState(() {
        _runHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load run history: $e';
        _isLoading = false;
      });
    }
  }

  // Refresh run history
  Future<void> _refreshData() async {
    await _loadRunHistory();
  }

  // Calculate total statistics
  Map<String, dynamic> _calculateTotalStats() {
    if (_runHistory.isEmpty) {
      return {
        'totalRuns': 0,
        'totalDistance': 0.0,
        'totalSteps': 0,
        'totalTime': Duration.zero,
        'averageSpeed': 0.0,
      };
    }

    double totalDistance = _runHistory.fold(0.0, (sum, run) => sum + run.distance);
    int totalSteps = _runHistory.fold(0, (sum, run) => sum + run.steps);
    Duration totalTime = _runHistory.fold(Duration.zero, (sum, run) => sum + run.duration);
    double averageSpeed = totalTime.inSeconds > 0 ? totalDistance / totalTime.inSeconds : 0.0;

    return {
      'totalRuns': _runHistory.length,
      'totalDistance': totalDistance,
      'totalSteps': totalSteps,
      'totalTime': totalTime,
      'averageSpeed': averageSpeed,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your run history...'),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: _runHistory.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            // Statistics Summary
            _buildStatsCard(),

            // Run History List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _runHistory.length,
                itemBuilder: (context, index) {
                  final runData = _runHistory[index];
                  return _buildRunCard(runData, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No runs recorded yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first race to see your history here!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Running'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build statistics summary card
  Widget _buildStatsCard() {
    final stats = _calculateTotalStats();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Your Total Stats',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Runs',
                    '${stats['totalRuns']}',
                    Icons.directions_run,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Distance',
                    _formatDistance(stats['totalDistance']),
                    Icons.straighten,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Steps',
                    _formatNumber(stats['totalSteps']),
                    Icons.directions_walk,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Time',
                    _formatDuration(stats['totalTime']),
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build individual stat item
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build individual run card
  Widget _buildRunCard(RunData runData, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showRunDetails(runData),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and run number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Run #${_runHistory.length - index}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    _formatDate(runData.date),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main stats
              Row(
                children: [
                  Expanded(
                    child: _buildRunStat(
                      Icons.straighten,
                      'Distance',
                      runData.formattedDistance,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildRunStat(
                      Icons.timer,
                      'Time',
                      runData.formattedDuration,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildRunStat(
                      Icons.directions_walk,
                      'Steps',
                      '${runData.steps}',
                      Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _buildRunStat(
                      Icons.speed,
                      'Speed',
                      runData.formattedSpeed,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build run stat item
  Widget _buildRunStat(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Show run details dialog
  void _showRunDetails(RunData runData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Run Details - ${_formatDate(runData.date)}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Distance', runData.formattedDistance),
                _buildDetailRow('Duration', runData.formattedDuration),
                _buildDetailRow('Steps', '${runData.steps}'),
                _buildDetailRow('Average Speed', runData.formattedSpeed),
                _buildDetailRow('Date', runData.date.toString().split('.')[0]),
                if (runData.route.isNotEmpty)
                  _buildDetailRow('Route Points', '${runData.route.length}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Build detail row for dialog
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // Format distance for display
  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)}km';
    }
  }

  // Format number with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      final difference = today.difference(dateToCheck).inDays;
      if (difference < 7) {
        final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return weekdays[date.weekday - 1];
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }
}
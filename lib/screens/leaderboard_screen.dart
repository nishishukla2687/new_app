import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/run_data.dart';
import '../models/user_data.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _distanceLeaderboard = [];
  List<Map<String, dynamic>> _speedLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load leaderboard data from Firestore
  Future<void> _loadLeaderboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final firebaseService = Provider.of<FirebaseService>(context, listen: false);

      // Load both distance and speed leaderboards
      final futures = await Future.wait([
        firebaseService.getLeaderboardByDistance(),
        firebaseService.getLeaderboardBySpeed(),
      ]);

      setState(() {
        _distanceLeaderboard = futures[0];
        _speedLeaderboard = futures[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load leaderboard: $e';
        _isLoading = false;
      });
    }
  }

  // Refresh leaderboard data
  Future<void> _refreshData() async {
    await _loadLeaderboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.straighten),
              text: 'Distance',
            ),
            Tab(
              icon: Icon(Icons.speed),
              text: 'Speed',
            ),
          ],
        ),
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
            Text('Loading leaderboard...'),
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
          : TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardList(_distanceLeaderboard, LeaderboardType.distance),
          _buildLeaderboardList(_speedLeaderboard, LeaderboardType.speed),
        ],
      ),
    );
  }

  // Build leaderboard list widget
  Widget _buildLeaderboardList(List<Map<String, dynamic>> leaderboardData, LeaderboardType type) {
    if (leaderboardData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No races recorded yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to complete a race!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: leaderboardData.length,
        itemBuilder: (context, index) {
          final entry = leaderboardData[index];
          final runData = entry['runData'] as RunData;
          final userData = entry['userData'] as UserData;

          return _buildLeaderboardCard(
            context: context,
            position: index + 1,
            runData: runData,
            userData: userData,
            type: type,
          );
        },
      ),
    );
  }

  // Build individual leaderboard card
  Widget _buildLeaderboardCard({
    required BuildContext context,
    required int position,
    required RunData runData,
    required UserData userData,
    required LeaderboardType type,
  }) {
    // Get current user for highlighting
    final currentUser = Provider.of<FirebaseService>(context, listen: false).user;
    final isCurrentUser = currentUser?.uid == userData.uid;

    // Get medal color for top 3 positions
    Color? medalColor;
    IconData? medalIcon;
    if (position == 1) {
      medalColor = Colors.amber;
      medalIcon = Icons.emoji_events;
    } else if (position == 2) {
      medalColor = Colors.grey.shade400;
      medalIcon = Icons.emoji_events;
    } else if (position == 3) {
      medalColor = Colors.brown.shade400;
      medalIcon = Icons.emoji_events;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrentUser ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentUser
            ? BorderSide(color: Colors.blue.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isCurrentUser
              ? LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Position/Medal
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: medalColor ?? Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: medalIcon != null
                      ? Icon(medalIcon, color: Colors.white, size: 20)
                      : Text(
                    '$position',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: medalColor != null ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // User info and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userData.email.split('@')[0], // Show username part of email
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isCurrentUser ? Colors.blue.shade800 : null,
                            ),
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Primary stat (distance or speed)
                    Row(
                      children: [
                        Icon(
                          type == LeaderboardType.distance ? Icons.straighten : Icons.speed,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type == LeaderboardType.distance
                              ? runData.formattedDistance
                              : runData.formattedSpeed,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    // Secondary stats
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildSecondaryInfo(Icons.timer, runData.formattedDuration),
                        const SizedBox(width: 16),
                        _buildSecondaryInfo(Icons.directions_walk, '${runData.steps} steps'),
                      ],
                    ),

                    // Date
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${_formatDate(runData.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build secondary info widget
  Widget _buildSecondaryInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'today';
    } else if (dateToCheck == yesterday) {
      return 'yesterday';
    } else {
      final difference = today.difference(dateToCheck).inDays;
      if (difference < 7) {
        return '$difference days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }
}

// Enum for leaderboard types
enum LeaderboardType { distance, speed }
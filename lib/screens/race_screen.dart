import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/firebase_service.dart';
import '../services/gps_service.dart';
import '../services/step_service.dart';
import '../models/run_data.dart';

class RaceScreen extends StatefulWidget {
  const RaceScreen({Key? key}) : super(key: key);

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late GPSService _gpsService;
  late StepService _stepService;
  Timer? _timer;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  bool _isTracking = false;
  bool _isInitialized = false;
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _gpsService = GPSService();
    _stepService = StepService();
    _initializeServices();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsService.dispose();
    _stepService.dispose();
    super.dispose();
  }

  // Initialize GPS and Step services
  Future<void> _initializeServices() async {
    try {
      // Initialize GPS service
      bool gpsInitialized = await _gpsService.initialize();
      if (!gpsInitialized) {
        if (mounted) {
          _showErrorDialog('GPS initialization failed: ${_gpsService.errorMessage}');
        }
        return;
      }

      // Initialize Step service
      bool stepInitialized = await _stepService.initialize();
      if (!stepInitialized) {
        // Step counter is not critical, show warning but continue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Step counter unavailable: ${_stepService.errorMessage}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to initialize services: $e');
      }
    }
  }

  // Start race tracking
  Future<void> _startRace() async {
    if (!_isInitialized) return;

    try {
      // Start GPS tracking
      await _gpsService.startTracking();

      // Start step tracking
      await _stepService.startTracking();

      // Start timer
      _startTime = DateTime.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_startTime != null) {
          setState(() {
            _elapsedTime = DateTime.now().difference(_startTime!);
          });
        }
      });

      setState(() {
        _isTracking = true;
      });

      // Listen to GPS updates for map polyline
      _gpsService.addListener(_updateMapPolyline);

    } catch (e) {
      _showErrorDialog('Failed to start tracking: $e');
    }
  }

  // Stop race tracking and save data
  Future<void> _stopRace() async {
    if (!_isTracking) return;

    try {
      // Stop services
      _gpsService.stopTracking();
      _stepService.stopTracking();
      _timer?.cancel();

      // Remove GPS listener
      _gpsService.removeListener(_updateMapPolyline);

      // Calculate final statistics
      double totalDistance = _gpsService.totalDistance;
      int totalSteps = _stepService.sessionSteps;
      double averageSpeed = _gpsService.calculateAverageSpeed(_elapsedTime);
      List<Map<String, double>> route = _gpsService.getRouteCoordinates();

      // Create run data
      RunData runData = RunData(
        userId: Provider.of<FirebaseService>(context, listen: false).user!.uid,
        distance: totalDistance,
        steps: totalSteps,
        duration: _elapsedTime,
        date: _startTime!,
        averageSpeed: averageSpeed,
        route: route,
      );

      // Save to Firestore
      await Provider.of<FirebaseService>(context, listen: false).saveRunData(runData);

      setState(() {
        _isTracking = false;
      });

      // Show completion dialog
      _showCompletionDialog(runData);

    } catch (e) {
      _showErrorDialog('Failed to save run data: $e');
    }
  }

  // Update map polyline with current route
  void _updateMapPolyline() {
    if (_gpsService.positions.length > 1) {
      List<LatLng> points = _gpsService.positions
          .map((position) => LatLng(position.latitude, position.longitude))
          .toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 4,
          ),
        };
      });
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show race completion dialog
  void _showCompletionDialog(RunData runData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Race Completed! 🏁'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${runData.formattedDistance}'),
            Text('Time: ${runData.formattedDuration}'),
            Text('Steps: ${runData.steps}'),
            Text('Average Speed: ${runData.formattedSpeed}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Tracking'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            IconButton(
              onPressed: _stopRace,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop Race',
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing GPS and sensors...'),
          ],
        ),
      )
          : Column(
        children: [
          // Statistics Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                // Timer and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_elapsedTime),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isTracking ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isTracking ? 'TRACKING' : 'STOPPED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Statistics Row
                Consumer2<GPSService, StepService>(
                  builder: (context, gpsService, stepService, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Distance',
                            gpsService.totalDistance < 1000
                                ? '${gpsService.totalDistance.toStringAsFixed(0)}m'
                                : '${(gpsService.totalDistance / 1000).toStringAsFixed(2)}km',
                            Icons.straighten,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Steps',
                            '${stepService.sessionSteps}',
                            Icons.directions_walk,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Speed',
                            '${(gpsService.calculateAverageSpeed(_elapsedTime) * 3.6).toStringAsFixed(1)} km/h',
                            Icons.speed,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Map View
          Expanded(
            child: Consumer<GPSService>(
              builder: (context, gpsService, child) {
                if (gpsService.currentPosition == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Getting your location...'),
                      ],
                    ),
                  );
                }

                return GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      gpsService.currentPosition!.latitude,
                      gpsService.currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polylines: _polylines,
                  markers: {
                    if (gpsService.positions.isNotEmpty)
                      Marker(
                        markerId: const MarkerId('start'),
                        position: LatLng(
                          gpsService.positions.first.latitude,
                          gpsService.positions.first.longitude,
                        ),
                        infoWindow: const InfoWindow(title: 'Start'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                  },
                );
              },
            ),
          ),

          // Control Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking ? _stopRace : _startRace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isTracking ? 'STOP RACE' : 'START RACE',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build statistic card widget
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
            children: [
            Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
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
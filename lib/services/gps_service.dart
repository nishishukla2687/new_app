import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GPSService extends ChangeNotifier {
  Position? _currentPosition;
  final List<Position> _positions = [];
  StreamSubscription<Position>? _positionStream;
  double _totalDistance = 0.0;
  bool _isTracking = false;
  String? _errorMessage;

  // Getters
  Position? get currentPosition => _currentPosition;
  List<Position> get positions => _positions;
  double get totalDistance => _totalDistance;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;

  // GPS settings for accuracy and update frequency
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1, // Update every 1 meter
  );

  // Initialize GPS service and request permissions
  Future<bool> initialize() async {
    try {
      _errorMessage = null;

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable location services.';
        notifyListeners();
        return false;
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permission denied.';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permissions are permanently denied. Please enable in settings.';
        notifyListeners();
        return false;
      }

      // Request additional location permission using permission_handler
      var status = await Permission.location.request();
      if (!status.isGranted) {
        _errorMessage = 'Location permission is required for GPS tracking.';
        notifyListeners();
        return false;
      }

      // Get initial position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize GPS: $e';
      notifyListeners();
      return false;
    }
  }

  // Start GPS tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      _isTracking = true;
      _positions.clear();
      _totalDistance = 0.0;
      _errorMessage = null;

      // Get initial position
      _currentPosition ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

      if (_currentPosition != null) {
        _positions.add(_currentPosition!);
      }

      // Start listening to position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
            (Position position) {
          _updatePosition(position);
        },
        onError: (error) {
          _errorMessage = 'GPS tracking error: $error';
          if (kDebugMode) {
            print('GPS Error: $error');
          }
          notifyListeners();
        },
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start GPS tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  // Update position and calculate distance
  void _updatePosition(Position newPosition) {
    if (_currentPosition != null) {
      // Calculate distance from last position
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      // Only add to total if movement is significant (reduces GPS noise)
      if (distanceInMeters >= 1.0) {
        _totalDistance += distanceInMeters;
        _positions.add(newPosition);
        _currentPosition = newPosition;
        notifyListeners();
      }
    } else {
      _currentPosition = newPosition;
      _positions.add(newPosition);
      notifyListeners();
    }
  }

  // Stop GPS tracking
  void stopTracking() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    notifyListeners();
  }

  // Reset tracking data
  void reset() {
    stopTracking();
    _positions.clear();
    _totalDistance = 0.0;
    _currentPosition = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Calculate average speed in m/s
  double calculateAverageSpeed(Duration duration) {
    if (duration.inSeconds == 0) return 0.0;
    return _totalDistance / duration.inSeconds;
  }

  // Get route coordinates for map display
  List<Map<String, double>> getRouteCoordinates() {
    return _positions.map((position) => {
      'latitude': position.latitude,
      'longitude': position.longitude,
    }).toList();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
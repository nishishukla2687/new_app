import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepService extends ChangeNotifier {
  StreamSubscription<StepCount>? _stepCountStream;
  int _initialStepCount = 0;
  int _currentStepCount = 0;
  int _sessionSteps = 0;
  bool _isTracking = false;
  String? _errorMessage;

  // Getters
  int get currentStepCount => _currentStepCount;
  int get sessionSteps => _sessionSteps;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;

  // Initialize step counter and request permissions
  Future<bool> initialize() async {
    try {
      _errorMessage = null;

      // Request activity recognition permission for Android
      var status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _errorMessage = 'Activity recognition permission is required for step counting.';
        notifyListeners();
        return false;
      }

      // Test if step counter is available by trying to get current step count
      try {
        await for (StepCount stepCount in Pedometer.stepCountStream.take(1)) {
          _currentStepCount = stepCount.steps;
          break;
        }
      } catch (e) {
        _errorMessage = 'Step counter not available on this device.';
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize step counter: $e';
      notifyListeners();
      return false;
    }
  }

  // Start step tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      _errorMessage = null;

      // Get initial step count to calculate session steps
      await for (StepCount stepCount in Pedometer.stepCountStream.take(1)) {
        _initialStepCount = stepCount.steps;
        _currentStepCount = stepCount.steps;
        _sessionSteps = 0;
        break;
      }

      // Start listening to step count updates
      _stepCountStream = Pedometer.stepCountStream.listen(
            (StepCount stepCount) {
          _updateStepCount(stepCount);
        },
        onError: (error) {
          _handleStepCountError(error);
        },
      );

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start step tracking: $e';
      notifyListeners();
    }
  }

  // Update step count and calculate session steps
  void _updateStepCount(StepCount stepCount) {
    _currentStepCount = stepCount.steps;

    // Calculate steps taken in this session
    if (_initialStepCount > 0) {
      _sessionSteps = _currentStepCount - _initialStepCount;

      // Handle edge case where step count might reset (rare but possible)
      if (_sessionSteps < 0) {
        _sessionSteps = _currentStepCount;
        _initialStepCount = 0;
      }
    } else {
      _sessionSteps = 0;
    }

    notifyListeners();
  }

  // Handle step counting errors
  void _handleStepCountError(dynamic error) {
    if (kDebugMode) {
      print('Step count error: $error');
    }

    // Handle different types of errors without relying on PedometerException type check
    String errorString = error.toString().toLowerCase();

    if (errorString.contains('step count not available')) {
      _errorMessage = 'Step counting is not available on this device.';
    } else if (errorString.contains('permission denied')) {
      _errorMessage = 'Permission denied for step counting.';
    } else if (errorString.contains('pedometer')) {
      _errorMessage = 'Step counter error: $error';
    } else {
      _errorMessage = 'Unexpected step counter error: $error';
    }

    notifyListeners();
  }

  // Stop step tracking
  void stopTracking() {
    _isTracking = false;
    _stepCountStream?.cancel();
    _stepCountStream = null;
    notifyListeners();
  }

  // Reset step tracking
  void reset() {
    stopTracking();
    _initialStepCount = 0;
    _currentStepCount = 0;
    _sessionSteps = 0;
    _errorMessage = null;
    notifyListeners();
  }

  // Get steps per minute (if duration is provided)
  double getStepsPerMinute(Duration duration) {
    if (duration.inMinutes == 0) return 0.0;
    return _sessionSteps / duration.inMinutes;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
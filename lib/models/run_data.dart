class RunData {
  final String? id; // Firestore document ID
  final String userId;
  final double distance; // in meters
  final int steps;
  final Duration duration;
  final DateTime date;
  final double averageSpeed; // in m/s
  final List<Map<String, double>> route; // List of lat/lng coordinates

  RunData({
    this.id,
    required this.userId,
    required this.distance,
    required this.steps,
    required this.duration,
    required this.date,
    required this.averageSpeed,
    required this.route,
  });

  // Convert RunData to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'distance': distance,
      'steps': steps,
      'duration': duration.inSeconds,
      'date': date.millisecondsSinceEpoch,
      'averageSpeed': averageSpeed,
      'route': route,
    };
  }

  // Create RunData from Firestore document
  factory RunData.fromMap(Map<String, dynamic> map, String documentId) {
    return RunData(
      id: documentId,
      userId: map['userId'] ?? '',
      distance: (map['distance'] ?? 0.0).toDouble(),
      steps: map['steps'] ?? 0,
      duration: Duration(seconds: map['duration'] ?? 0),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      averageSpeed: (map['averageSpeed'] ?? 0.0).toDouble(),
      route: List<Map<String, double>>.from(
          (map['route'] ?? []).map((point) => Map<String, double>.from(point))
      ),
    );
  }

  // Calculate speed in km/h for display
  double get speedKmh => averageSpeed * 3.6;

  // Format distance for display
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)}km';
    }
  }

  // Format duration for display
  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  // Format speed for display
  String get formattedSpeed => '${speedKmh.toStringAsFixed(2)} km/h';

  @override
  String toString() {
    return 'RunData{id: $id, userId: $userId, distance: $distance, steps: $steps, duration: $duration, date: $date, averageSpeed: $averageSpeed}';
  }
}
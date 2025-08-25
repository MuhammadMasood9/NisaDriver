// Enhanced Location Data Models for Driver App
// This file contains the data models for the enhanced live tracking system



/// Enum representing different phases of a ride
enum RidePhase {
  enRouteToPickup,
  atPickupLocation,
  rideInProgress,
  atDropoffLocation,
  rideCompleted;

  String get value {
    switch (this) {
      case RidePhase.enRouteToPickup:
        return 'enRouteToPickup';
      case RidePhase.atPickupLocation:
        return 'atPickupLocation';
      case RidePhase.rideInProgress:
        return 'rideInProgress';
      case RidePhase.atDropoffLocation:
        return 'atDropoffLocation';
      case RidePhase.rideCompleted:
        return 'rideCompleted';
    }
  }

  static RidePhase fromString(String value) {
    switch (value) {
      case 'enRouteToPickup':
        return RidePhase.enRouteToPickup;
      case 'atPickupLocation':
        return RidePhase.atPickupLocation;
      case 'rideInProgress':
        return RidePhase.rideInProgress;
      case 'atDropoffLocation':
        return RidePhase.atDropoffLocation;
      case 'rideCompleted':
        return RidePhase.rideCompleted;
      default:
        return RidePhase.enRouteToPickup;
    }
  }
}

/// Enum representing network quality levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  offline;

  String get value {
    switch (this) {
      case NetworkQuality.excellent:
        return 'excellent';
      case NetworkQuality.good:
        return 'good';
      case NetworkQuality.fair:
        return 'fair';
      case NetworkQuality.poor:
        return 'poor';
      case NetworkQuality.offline:
        return 'offline';
    }
  }

  static NetworkQuality fromString(String value) {
    switch (value) {
      case 'excellent':
        return NetworkQuality.excellent;
      case 'good':
        return NetworkQuality.good;
      case 'fair':
        return NetworkQuality.fair;
      case 'poor':
        return NetworkQuality.poor;
      case 'offline':
        return NetworkQuality.offline;
      default:
        return NetworkQuality.good;
    }
  }
}

/// Enhanced location data model with comprehensive tracking information
class EnhancedLocationData {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double bearing;
  final double accuracy;
  final String status;
  final RidePhase phase;
  final DateTime timestamp;
  final int sequenceNumber;
  final double batteryLevel;
  final NetworkQuality networkQuality;
  final Map<String, dynamic> metadata;

  const EnhancedLocationData({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.bearing,
    required this.accuracy,
    required this.status,
    required this.phase,
    required this.timestamp,
    required this.sequenceNumber,
    required this.batteryLevel,
    required this.networkQuality,
    this.metadata = const {},
  });

  /// Validates the location data for accuracy and completeness
  bool get isValid {
    // Check coordinate bounds
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    
    // Check for reasonable values
    if (speedKmh < 0 || speedKmh > 300) return false; // Max reasonable speed
    if (bearing < 0 || bearing >= 360) return false;
    if (accuracy < 0 || accuracy > 1000) return false; // Max reasonable accuracy
    if (batteryLevel < 0 || batteryLevel > 100) return false;
    
    // Check timestamp is not too old or in future
    final now = DateTime.now();
    final timeDiff = now.difference(timestamp).abs();
    if (timeDiff.inMinutes > 10) return false; // Max 10 minutes old/future
    
    return true;
  }

  /// Calculates confidence score based on accuracy and data quality
  double get confidenceScore {
    double score = 1.0;
    
    // Reduce confidence based on accuracy (lower accuracy = lower confidence)
    if (accuracy > 50) {
      score *= 0.3; // Very poor accuracy
    } else if (accuracy > 20) {
      score *= 0.6; // Poor accuracy
    } else if (accuracy > 10) {
      score *= 0.8; // Fair accuracy
    } else if (accuracy > 5) {
      score *= 0.9; // Good accuracy
    }
    // Excellent accuracy (<=5m) keeps full score
    
    // Reduce confidence based on network quality
    switch (networkQuality) {
      case NetworkQuality.excellent:
        break; // No reduction
      case NetworkQuality.good:
        score *= 0.95;
        break;
      case NetworkQuality.fair:
        score *= 0.8;
        break;
      case NetworkQuality.poor:
        score *= 0.6;
        break;
      case NetworkQuality.offline:
        score *= 0.3;
        break;
    }
    
    // Reduce confidence for very old data
    final age = DateTime.now().difference(timestamp);
    if (age.inSeconds > 30) {
      score *= 0.7; // Reduce confidence for data older than 30 seconds
    } else if (age.inSeconds > 10) {
      score *= 0.9; // Slight reduction for data older than 10 seconds
    }
    
    return score.clamp(0.0, 1.0);
  }

  /// Converts to Firebase JSON format
  Map<String, dynamic> toFirebaseJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'speedKmh': speedKmh,
      'bearing': bearing,
      'accuracy': accuracy,
      'status': status,
      'phase': phase.value,
      'updatedAt': timestamp.millisecondsSinceEpoch,
      'sequenceNumber': sequenceNumber,
      'batteryLevel': batteryLevel,
      'networkQuality': networkQuality.value,
      'metadata': metadata,
    };
  }

  /// Creates instance from Firebase JSON
  static EnhancedLocationData fromFirebaseJson(Map<String, dynamic> json) {
    // Helper function to safely parse numbers
    double? safeParseDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    int? safeParseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    return EnhancedLocationData(
      latitude: safeParseDouble(json['lat'], 0.0)!,
      longitude: safeParseDouble(json['lng'], 0.0)!,
      speedKmh: safeParseDouble(json['speedKmh'], 0.0)!.clamp(0.0, 300.0),
      bearing: safeParseDouble(json['bearing'], 0.0)!.clamp(0.0, 359.9),
      accuracy: safeParseDouble(json['accuracy'], 10.0)!,
      status: json['status']?.toString() ?? '',
      phase: RidePhase.fromString(json['phase']?.toString() ?? 'enRouteToPickup'),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        safeParseInt(json['updatedAt'], DateTime.now().millisecondsSinceEpoch)!,
      ),
      sequenceNumber: safeParseInt(json['sequenceNumber'], 0)!,
      batteryLevel: safeParseDouble(json['batteryLevel'], 100.0)!.clamp(0.0, 100.0),
      networkQuality: NetworkQuality.fromString(
        json['networkQuality']?.toString() ?? 'good',
      ),
      metadata: json['metadata'] is Map 
          ? Map<String, dynamic>.from(json['metadata'] as Map) 
          : <String, dynamic>{},
    );
  }

  /// Creates a copy with updated values
  EnhancedLocationData copyWith({
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? bearing,
    double? accuracy,
    String? status,
    RidePhase? phase,
    DateTime? timestamp,
    int? sequenceNumber,
    double? batteryLevel,
    NetworkQuality? networkQuality,
    Map<String, dynamic>? metadata,
  }) {
    return EnhancedLocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      bearing: bearing ?? this.bearing,
      accuracy: accuracy ?? this.accuracy,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      timestamp: timestamp ?? this.timestamp,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      networkQuality: networkQuality ?? this.networkQuality,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'EnhancedLocationData(lat: $latitude, lng: $longitude, speed: ${speedKmh.toStringAsFixed(1)}km/h, accuracy: ${accuracy.toStringAsFixed(1)}m, phase: ${phase.value}, confidence: ${confidenceScore.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedLocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.speedKmh == speedKmh &&
        other.bearing == bearing &&
        other.accuracy == accuracy &&
        other.status == status &&
        other.phase == phase &&
        other.timestamp == timestamp &&
        other.sequenceNumber == sequenceNumber &&
        other.batteryLevel == batteryLevel &&
        other.networkQuality == networkQuality;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      speedKmh,
      bearing,
      accuracy,
      status,
      phase,
      timestamp,
      sequenceNumber,
      batteryLevel,
      networkQuality,
    );
  }
}

/// Status information for location tracking
class LocationTrackingStatus {
  final bool isActive;
  final DateTime lastUpdate;
  final double accuracy;
  final String status;
  final List<String> issues;

  const LocationTrackingStatus({
    required this.isActive,
    required this.lastUpdate,
    required this.accuracy,
    required this.status,
    this.issues = const [],
  });

  /// Creates a copy with updated values
  LocationTrackingStatus copyWith({
    bool? isActive,
    DateTime? lastUpdate,
    double? accuracy,
    String? status,
    List<String>? issues,
  }) {
    return LocationTrackingStatus(
      isActive: isActive ?? this.isActive,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      accuracy: accuracy ?? this.accuracy,
      status: status ?? this.status,
      issues: issues ?? this.issues,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'lastUpdate': lastUpdate.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'status': status,
      'issues': issues,
    };
  }

  /// Creates instance from JSON
  static LocationTrackingStatus fromJson(Map<String, dynamic> json) {
    return LocationTrackingStatus(
      isActive: json['isActive'] as bool? ?? false,
      lastUpdate: DateTime.fromMillisecondsSinceEpoch(
        (json['lastUpdate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      issues: List<String>.from(json['issues'] as List? ?? []),
    );
  }

  @override
  String toString() {
    return 'LocationTrackingStatus(active: $isActive, accuracy: ${accuracy.toStringAsFixed(1)}m, status: $status, issues: ${issues.length})';
  }
}

/// Metrics for location tracking performance
class LocationTrackingMetrics {
  final int totalUpdates;
  final double averageAccuracy;
  final Duration averageInterval;
  final int failedUpdates;
  final double batteryUsagePercent;
  final double networkUsageMB;
  final DateTime trackingStartTime;
  final Duration totalTrackingTime;

  const LocationTrackingMetrics({
    required this.totalUpdates,
    required this.averageAccuracy,
    required this.averageInterval,
    required this.failedUpdates,
    required this.batteryUsagePercent,
    required this.networkUsageMB,
    required this.trackingStartTime,
    required this.totalTrackingTime,
  });

  /// Success rate as a percentage
  double get successRate {
    if (totalUpdates == 0) return 0.0;
    return ((totalUpdates - failedUpdates) / totalUpdates) * 100;
  }

  /// Updates per minute
  double get updatesPerMinute {
    if (totalTrackingTime.inMinutes == 0) return 0.0;
    return totalUpdates / totalTrackingTime.inMinutes;
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'totalUpdates': totalUpdates,
      'averageAccuracy': averageAccuracy,
      'averageInterval': averageInterval.inMilliseconds,
      'failedUpdates': failedUpdates,
      'batteryUsagePercent': batteryUsagePercent,
      'networkUsageMB': networkUsageMB,
      'trackingStartTime': trackingStartTime.millisecondsSinceEpoch,
      'totalTrackingTime': totalTrackingTime.inMilliseconds,
    };
  }

  /// Creates instance from JSON
  static LocationTrackingMetrics fromJson(Map<String, dynamic> json) {
    return LocationTrackingMetrics(
      totalUpdates: (json['totalUpdates'] as num?)?.toInt() ?? 0,
      averageAccuracy: (json['averageAccuracy'] as num?)?.toDouble() ?? 0.0,
      averageInterval: Duration(
        milliseconds: (json['averageInterval'] as num?)?.toInt() ?? 0,
      ),
      failedUpdates: (json['failedUpdates'] as num?)?.toInt() ?? 0,
      batteryUsagePercent: (json['batteryUsagePercent'] as num?)?.toDouble() ?? 0.0,
      networkUsageMB: (json['networkUsageMB'] as num?)?.toDouble() ?? 0.0,
      trackingStartTime: DateTime.fromMillisecondsSinceEpoch(
        (json['trackingStartTime'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      totalTrackingTime: Duration(
        milliseconds: (json['totalTrackingTime'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  String toString() {
    return 'LocationTrackingMetrics(updates: $totalUpdates, accuracy: ${averageAccuracy.toStringAsFixed(1)}m, success: ${successRate.toStringAsFixed(1)}%, battery: ${batteryUsagePercent.toStringAsFixed(1)}%)';
  }
}
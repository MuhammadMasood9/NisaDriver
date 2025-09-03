// ETA and Route Tracking Service for Driver App
// Implements real-time ETA updates, route deviation detection, and progress tracking

import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/utils/location_data_converter.dart';

// Define SmoothedLocation locally if not available
class SmoothedLocation {
  final LatLng position;
  final double speed;
  final double bearing;
  final bool isPredicted;
  final double smoothingFactor;
  final bool isSnappedToRoute;
  final double confidence;
  final DateTime timestamp;

  const SmoothedLocation({
    required this.position,
    required this.speed,
    required this.bearing,
    this.isPredicted = false,
    this.smoothingFactor = 1.0,
    this.isSnappedToRoute = false,
    this.confidence = 1.0,
    required this.timestamp,
  });
}

/// Route deviation severity levels
enum DeviationSeverity {
  none,
  minor,
  moderate,
  major;

  String get description {
    switch (this) {
      case DeviationSeverity.none:
        return 'On route';
      case DeviationSeverity.minor:
        return 'Slight deviation';
      case DeviationSeverity.moderate:
        return 'Off route';
      case DeviationSeverity.major:
        return 'Significant deviation';
    }
  }

  double get thresholdMeters {
    switch (this) {
      case DeviationSeverity.none:
        return 0.0;
      case DeviationSeverity.minor:
        return 50.0;
      case DeviationSeverity.moderate:
        return 150.0;
      case DeviationSeverity.major:
        return 300.0;
    }
  }
}

/// ETA calculation method
enum ETACalculationMethod {
  speedBased,
  historicalData,
  trafficAware,
  hybrid;

  String get description {
    switch (this) {
      case ETACalculationMethod.speedBased:
        return 'Based on current speed';
      case ETACalculationMethod.historicalData:
        return 'Based on historical data';
      case ETACalculationMethod.trafficAware:
        return 'Traffic-aware estimate';
      case ETACalculationMethod.hybrid:
        return 'Combined estimate';
    }
  }
}

/// ETA update result
class ETAUpdate {
  final Duration estimatedTime;
  final DateTime estimatedArrival;
  final double confidence;
  final ETACalculationMethod method;
  final String displayText;
  final bool hasChanged;
  final Duration? previousEstimate;

  const ETAUpdate({
    required this.estimatedTime,
    required this.estimatedArrival,
    required this.confidence,
    required this.method,
    required this.displayText,
    required this.hasChanged,
    this.previousEstimate,
  });

  /// Whether the ETA has significantly changed (>1 minute difference)
  bool get hasSignificantChange {
    if (previousEstimate == null) return false;
    final diff = (estimatedTime.inMinutes - previousEstimate!.inMinutes).abs();
    return diff >= 1;
  }

  @override
  String toString() {
    return 'ETAUpdate(time: $displayText, confidence: ${confidence.toStringAsFixed(2)}, method: ${method.description})';
  }
}

/// Route progress information
class RouteProgress {
  final double completionPercentage; // 0.0 to 1.0
  final double distanceCompleted; // in meters
  final double distanceRemaining; // in meters
  final int segmentsCompleted;
  final int totalSegments;
  final LatLng? nextWaypoint;
  final double distanceToNextWaypoint;

  const RouteProgress({
    required this.completionPercentage,
    required this.distanceCompleted,
    required this.distanceRemaining,
    required this.segmentsCompleted,
    required this.totalSegments,
    this.nextWaypoint,
    required this.distanceToNextWaypoint,
  });

  /// Total route distance
  double get totalDistance => distanceCompleted + distanceRemaining;

  /// Whether the route is nearly complete (>90%)
  bool get isNearlyComplete => completionPercentage >= 0.9;

  /// Whether the route is halfway complete
  bool get isHalfwayComplete => completionPercentage >= 0.5;

  @override
  String toString() {
    return 'RouteProgress(${(completionPercentage * 100).toStringAsFixed(1)}% complete, ${(distanceRemaining / 1000).toStringAsFixed(1)}km remaining)';
  }
}

/// Route deviation information
class RouteDeviation {
  final DeviationSeverity severity;
  final double distanceFromRoute; // in meters
  final LatLng deviationPoint;
  final LatLng nearestRoutePoint;
  final Duration deviationDuration;
  final bool isReturningToRoute;
  final String description;

  const RouteDeviation({
    required this.severity,
    required this.distanceFromRoute,
    required this.deviationPoint,
    required this.nearestRoutePoint,
    required this.deviationDuration,
    required this.isReturningToRoute,
    required this.description,
  });

  /// Whether this is a significant deviation that should trigger notifications
  bool get requiresNotification =>
      severity.index >= DeviationSeverity.moderate.index;

  @override
  String toString() {
    return 'RouteDeviation(${severity.description}, ${distanceFromRoute.toStringAsFixed(0)}m from route)';
  }
}

/// Traffic condition estimate
class TrafficCondition {
  final double speedFactor; // 1.0 = normal, <1.0 = slower, >1.0 = faster
  final String description;
  final DateTime lastUpdated;

  const TrafficCondition({
    required this.speedFactor,
    required this.description,
    required this.lastUpdated,
  });

  /// Whether traffic data is fresh (less than 5 minutes old)
  bool get isFresh => DateTime.now().difference(lastUpdated).inMinutes < 5;

  static TrafficCondition normal = TrafficCondition(
    speedFactor: 1.0,
    description: 'Normal traffic',
    lastUpdated: DateTime.now(),
  );

  @override
  String toString() {
    return 'TrafficCondition($description, factor: ${speedFactor.toStringAsFixed(2)})';
  }
}

/// Configuration for ETA and route tracking
class ETARouteConfig {
  final Duration updateInterval;
  final double minSpeedForETA; // km/h
  final double maxReasonableSpeed; // km/h
  final Duration maxETATime;
  final double routeDeviationThreshold; // meters
  final bool enableTrafficAwareness;
  final bool enableRouteOptimization;
  final int speedHistorySize;
  final double etaConfidenceThreshold;

  const ETARouteConfig({
    this.updateInterval = const Duration(seconds: 5),
    this.minSpeedForETA = 5.0,
    this.maxReasonableSpeed = 120.0,
    this.maxETATime = const Duration(hours: 2),
    this.routeDeviationThreshold = 100.0,
    this.enableTrafficAwareness = true,
    this.enableRouteOptimization = false,
    this.speedHistorySize = 20,
    this.etaConfidenceThreshold = 0.6,
  });
}

/// ETA and Route Tracking Service
class ETARouteTrackingService {
  final ETARouteConfig _config;

  // Route data
  List<LatLng> _routePoints = [];
  LatLng? _destination;
  double _totalRouteDistance = 0.0;

  // Current state
  SmoothedLocation? _currentLocation;
  RouteProgress? _currentProgress;
  RouteDeviation? _currentDeviation;
  ETAUpdate? _lastETAUpdate;
  TrafficCondition _trafficCondition = TrafficCondition.normal;

  // History tracking
  final List<double> _speedHistory = [];
  final List<ETAUpdate> _etaHistory = [];
  DateTime? _deviationStartTime;
  Timer? _updateTimer;

  // Stream controllers
  final StreamController<ETAUpdate> _etaController =
      StreamController<ETAUpdate>.broadcast();
  final StreamController<RouteProgress> _progressController =
      StreamController<RouteProgress>.broadcast();
  final StreamController<RouteDeviation> _deviationController =
      StreamController<RouteDeviation>.broadcast();

  ETARouteTrackingService([ETARouteConfig? config])
      : _config = config ?? const ETARouteConfig();

  /// Stream of ETA updates
  Stream<ETAUpdate> get etaUpdates => _etaController.stream;

  /// Stream of route progress updates
  Stream<RouteProgress> get progressUpdates => _progressController.stream;

  /// Stream of route deviation updates
  Stream<RouteDeviation> get deviationUpdates => _deviationController.stream;

  /// Current ETA information
  ETAUpdate? get currentETA => _lastETAUpdate;

  /// Current route progress
  RouteProgress? get currentProgress => _currentProgress;

  /// Current route deviation
  RouteDeviation? get currentDeviation => _currentDeviation;

  /// Configure route for tracking
  void configureRoute({
    required List<LatLng> routePoints,
    required LatLng destination,
  }) {
    _routePoints = List.from(routePoints);
    _destination = destination;
    _totalRouteDistance = _calculateTotalRouteDistance();

    dev.log(
        'ETARouteTrackingService: Route configured with ${_routePoints.length} points, total distance: ${(_totalRouteDistance / 1000).toStringAsFixed(1)}km');

    // Reset state
    _currentProgress = null;
    _currentDeviation = null;
    _lastETAUpdate = null;
    _deviationStartTime = null;

    // Start periodic updates
    _startPeriodicUpdates();
  }

  /// Update current location and recalculate ETA/progress
  void updateLocation(SmoothedLocation location) {
    _currentLocation = location;

    // Add speed to history
    _addSpeedToHistory(location.speed);

    // Calculate route progress
    _updateRouteProgress(location);

    // Check for route deviation
    _checkRouteDeviation(location);

    // Calculate and update ETA
    _updateETA(location);
  }

  /// Update traffic conditions
  void updateTrafficCondition(TrafficCondition condition) {
    _trafficCondition = condition;
    dev.log(
        'ETARouteTrackingService: Traffic condition updated - ${condition.description}');

    // Recalculate ETA with new traffic data
    if (_currentLocation != null) {
      _updateETA(_currentLocation!);
    }
  }

  /// Calculate route progress based on current location
  void _updateRouteProgress(SmoothedLocation location) {
    if (_routePoints.isEmpty || _destination == null) return;

    try {
      // Find closest point on route
      int closestIndex = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < _routePoints.length; i++) {
        final distance = LocationDataConverter.calculateDistanceLatLng(
          location.position,
          _routePoints[i],
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestIndex = i;
        }
      }

      // Calculate distances
      double distanceCompleted = 0.0;
      for (int i = 0; i < closestIndex; i++) {
        if (i + 1 < _routePoints.length) {
          distanceCompleted += LocationDataConverter.calculateDistanceLatLng(
            _routePoints[i],
            _routePoints[i + 1],
          );
        }
      }

      // Add distance from closest route point to current location if reasonable
      if (minDistance < 200) {
        // Only if reasonably close to route
        distanceCompleted += minDistance;
      }

      final distanceRemaining =
          max(0.0, _totalRouteDistance - distanceCompleted);
      final completionPercentage = _totalRouteDistance > 0
          ? (distanceCompleted / _totalRouteDistance).clamp(0.0, 1.0)
          : 0.0;

      // Find next waypoint
      LatLng? nextWaypoint;
      double distanceToNextWaypoint = 0.0;
      if (closestIndex + 1 < _routePoints.length) {
        nextWaypoint = _routePoints[closestIndex + 1];
        distanceToNextWaypoint = LocationDataConverter.calculateDistanceLatLng(
          location.position,
          nextWaypoint,
        );
      }

      _currentProgress = RouteProgress(
        completionPercentage: completionPercentage,
        distanceCompleted: distanceCompleted,
        distanceRemaining: distanceRemaining,
        segmentsCompleted: closestIndex,
        totalSegments: _routePoints.length,
        nextWaypoint: nextWaypoint,
        distanceToNextWaypoint: distanceToNextWaypoint,
      );

      _progressController.add(_currentProgress!);

      dev.log(
          'ETARouteTrackingService: Progress updated - ${(completionPercentage * 100).toStringAsFixed(1)}% complete');
    } catch (e) {
      dev.log('ETARouteTrackingService: Error updating route progress: $e');
    }
  }

  /// Check for route deviation
  void _checkRouteDeviation(SmoothedLocation location) {
    if (_routePoints.isEmpty) return;

    try {
      // Find nearest point on route
      final nearestPoint = LocationDataConverter.snapToPolyline(
        location.position,
        _routePoints,
      );

      final distanceFromRoute = LocationDataConverter.calculateDistanceLatLng(
        location.position,
        nearestPoint,
      );

      // Determine deviation severity
      DeviationSeverity severity = DeviationSeverity.none;
      if (distanceFromRoute > DeviationSeverity.major.thresholdMeters) {
        severity = DeviationSeverity.major;
      } else if (distanceFromRoute >
          DeviationSeverity.moderate.thresholdMeters) {
        severity = DeviationSeverity.moderate;
      } else if (distanceFromRoute > DeviationSeverity.minor.thresholdMeters) {
        severity = DeviationSeverity.minor;
      }

      // Track deviation duration
      Duration deviationDuration = Duration.zero;
      if (severity != DeviationSeverity.none) {
        _deviationStartTime ??= DateTime.now();
        deviationDuration = DateTime.now().difference(_deviationStartTime!);
      } else {
        _deviationStartTime = null;
      }

      // Check if returning to route
      bool isReturningToRoute = false;
      if (_currentDeviation != null &&
          _currentDeviation!.severity != DeviationSeverity.none) {
        isReturningToRoute =
            distanceFromRoute < _currentDeviation!.distanceFromRoute;
      }

      _currentDeviation = RouteDeviation(
        severity: severity,
        distanceFromRoute: distanceFromRoute,
        deviationPoint: location.position,
        nearestRoutePoint: nearestPoint,
        deviationDuration: deviationDuration,
        isReturningToRoute: isReturningToRoute,
        description: _getDeviationDescription(
            severity, distanceFromRoute, isReturningToRoute),
      );

      _deviationController.add(_currentDeviation!);

      if (severity != DeviationSeverity.none) {
        dev.log(
            'ETARouteTrackingService: Route deviation detected - ${severity.description}, ${distanceFromRoute.toStringAsFixed(0)}m from route');
      }
    } catch (e) {
      dev.log('ETARouteTrackingService: Error checking route deviation: $e');
    }
  }

  /// Update ETA calculation
  void _updateETA(SmoothedLocation location) {
    if (_destination == null || _currentProgress == null) return;

    try {
      final previousETA = _lastETAUpdate?.estimatedTime;

      // Calculate ETA using multiple methods
      final speedBasedETA = _calculateSpeedBasedETA(location);
      final historicalETA = _calculateHistoricalETA(location);
      final trafficAwareETA =
          _calculateTrafficAwareETA(location, speedBasedETA);

      // Choose best method based on confidence and data availability
      ETAUpdate bestETA;
      if (_config.enableTrafficAwareness && _trafficCondition.isFresh) {
        bestETA = trafficAwareETA;
      } else if (_speedHistory.length >= 5) {
        bestETA = historicalETA;
      } else {
        bestETA = speedBasedETA;
      }

      // Apply confidence threshold
      if (bestETA.confidence < _config.etaConfidenceThreshold) {
        // Use fallback method
        bestETA = speedBasedETA.copyWith(
          confidence: _config.etaConfidenceThreshold,
          method: ETACalculationMethod.speedBased,
        );
      }

      // Check for significant changes
      final hasChanged = previousETA == null ||
          (bestETA.estimatedTime.inMinutes - previousETA.inMinutes).abs() >= 1;

      final finalETA = bestETA.copyWith(
        hasChanged: hasChanged,
        previousEstimate: previousETA,
      );

      _lastETAUpdate = finalETA;
      _etaHistory.add(finalETA);

      // Keep history limited
      if (_etaHistory.length > 50) {
        _etaHistory.removeAt(0);
      }

      _etaController.add(finalETA);

      dev.log(
          'ETARouteTrackingService: ETA updated - ${finalETA.displayText} (${finalETA.method.description})');
    } catch (e) {
      dev.log('ETARouteTrackingService: Error updating ETA: $e');
    }
  }

  /// Calculate ETA based on current speed
  ETAUpdate _calculateSpeedBasedETA(SmoothedLocation location) {
    final distanceRemaining = _currentProgress!.distanceRemaining;
    final currentSpeed = max(location.speed, _config.minSpeedForETA);

    // Calculate time in hours
    final timeHours = (distanceRemaining / 1000) / currentSpeed;
    final estimatedTime =
        Duration(milliseconds: (timeHours * 3600 * 1000).round());

    // Clamp to reasonable limits
    final clampedTime = Duration(
      milliseconds:
          min(estimatedTime.inMilliseconds, _config.maxETATime.inMilliseconds),
    );

    final estimatedArrival = DateTime.now().add(clampedTime);

    // Calculate confidence based on speed stability
    double confidence = 0.7; // Base confidence
    if (location.speed > _config.minSpeedForETA * 2) {
      confidence += 0.2; // Higher confidence for reasonable speeds
    }
    if (location.confidence > 0.8) {
      confidence += 0.1; // Higher confidence for accurate location
    }

    return ETAUpdate(
      estimatedTime: clampedTime,
      estimatedArrival: estimatedArrival,
      confidence: confidence.clamp(0.0, 1.0),
      method: ETACalculationMethod.speedBased,
      displayText: _formatETATime(clampedTime),
      hasChanged: false, // Will be set by caller
    );
  }

  /// Calculate ETA based on historical speed data
  ETAUpdate _calculateHistoricalETA(SmoothedLocation location) {
    if (_speedHistory.isEmpty) {
      return _calculateSpeedBasedETA(location);
    }

    // Calculate average speed from recent history
    final recentSpeeds = _speedHistory.length > 10
        ? _speedHistory.sublist(_speedHistory.length - 10)
        : _speedHistory;

    final averageSpeed =
        recentSpeeds.reduce((a, b) => a + b) / recentSpeeds.length;
    final adjustedSpeed = max(averageSpeed, _config.minSpeedForETA);

    final distanceRemaining = _currentProgress!.distanceRemaining;
    final timeHours = (distanceRemaining / 1000) / adjustedSpeed;
    final estimatedTime =
        Duration(milliseconds: (timeHours * 3600 * 1000).round());

    final clampedTime = Duration(
      milliseconds:
          min(estimatedTime.inMilliseconds, _config.maxETATime.inMilliseconds),
    );

    final estimatedArrival = DateTime.now().add(clampedTime);

    // Calculate confidence based on speed consistency
    final speedVariance = _calculateSpeedVariance(recentSpeeds, averageSpeed);
    double confidence = 0.8; // Base confidence for historical data

    if (speedVariance < 5.0) {
      confidence += 0.15; // Very consistent speed
    } else if (speedVariance < 10.0) {
      confidence += 0.1; // Moderately consistent speed
    } else if (speedVariance > 20.0) {
      confidence -= 0.2; // Inconsistent speed
    }

    return ETAUpdate(
      estimatedTime: clampedTime,
      estimatedArrival: estimatedArrival,
      confidence: confidence.clamp(0.0, 1.0),
      method: ETACalculationMethod.historicalData,
      displayText: _formatETATime(clampedTime),
      hasChanged: false,
    );
  }

  /// Calculate traffic-aware ETA
  ETAUpdate _calculateTrafficAwareETA(
      SmoothedLocation location, ETAUpdate baseETA) {
    // Apply traffic factor to base ETA
    final adjustedDuration = Duration(
      milliseconds:
          (baseETA.estimatedTime.inMilliseconds / _trafficCondition.speedFactor)
              .round(),
    );

    final clampedTime = Duration(
      milliseconds: min(
          adjustedDuration.inMilliseconds, _config.maxETATime.inMilliseconds),
    );

    final estimatedArrival = DateTime.now().add(clampedTime);

    // Confidence based on traffic data freshness and base confidence
    double confidence =
        baseETA.confidence * 0.9; // Slight reduction for complexity
    if (_trafficCondition.isFresh) {
      confidence += 0.1; // Bonus for fresh traffic data
    }

    return ETAUpdate(
      estimatedTime: clampedTime,
      estimatedArrival: estimatedArrival,
      confidence: confidence.clamp(0.0, 1.0),
      method: ETACalculationMethod.trafficAware,
      displayText: _formatETATime(clampedTime),
      hasChanged: false,
    );
  }

  /// Add speed to history and maintain size limit
  void _addSpeedToHistory(double speed) {
    _speedHistory.add(speed);
    if (_speedHistory.length > _config.speedHistorySize) {
      _speedHistory.removeAt(0);
    }
  }

  /// Calculate total route distance
  double _calculateTotalRouteDistance() {
    if (_routePoints.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += LocationDataConverter.calculateDistanceLatLng(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }
    return totalDistance;
  }

  /// Calculate speed variance for consistency measurement
  double _calculateSpeedVariance(List<double> speeds, double average) {
    if (speeds.length < 2) return 0.0;

    double sumSquaredDiffs = 0.0;
    for (final speed in speeds) {
      final diff = speed - average;
      sumSquaredDiffs += diff * diff;
    }
    return sqrt(sumSquaredDiffs / speeds.length);
  }

  /// Format ETA time for display
  String _formatETATime(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) {
      return 'Less than 1 min';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  /// Get deviation description
  String _getDeviationDescription(
      DeviationSeverity severity, double distance, bool isReturning) {
    switch (severity) {
      case DeviationSeverity.none:
        return 'On route';
      case DeviationSeverity.minor:
        return isReturning ? 'Returning to route' : 'Slightly off route';
      case DeviationSeverity.moderate:
        return isReturning
            ? 'Returning to route'
            : 'Off route (${(distance / 1000).toStringAsFixed(1)}km)';
      case DeviationSeverity.major:
        return isReturning
            ? 'Returning to route'
            : 'Significantly off route (${(distance / 1000).toStringAsFixed(1)}km)';
    }
  }

  /// Start periodic updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_config.updateInterval, (_) {
      if (_currentLocation != null) {
        _updateETA(_currentLocation!);
      }
    });
  }

  /// Stop the service and clean up resources
  void dispose() {
    _updateTimer?.cancel();
    _etaController.close();
    _progressController.close();
    _deviationController.close();

    dev.log('ETARouteTrackingService: Service disposed');
  }
}

/// Extension methods for ETAUpdate
extension ETAUpdateExtension on ETAUpdate {
  ETAUpdate copyWith({
    Duration? estimatedTime,
    DateTime? estimatedArrival,
    double? confidence,
    ETACalculationMethod? method,
    String? displayText,
    bool? hasChanged,
    Duration? previousEstimate,
  }) {
    return ETAUpdate(
      estimatedTime: estimatedTime ?? this.estimatedTime,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      confidence: confidence ?? this.confidence,
      method: method ?? this.method,
      displayText: displayText ?? this.displayText,
      hasChanged: hasChanged ?? this.hasChanged,
      previousEstimate: previousEstimate ?? this.previousEstimate,
    );
  }
}

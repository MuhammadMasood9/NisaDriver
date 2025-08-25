// Adaptive Update Frequency Manager for Enhanced Background Location Service
// This component manages dynamic adjustment of location update frequency based on context

import 'dart:developer' as dev;
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:driver/model/enhanced_location_data.dart';

/// Frequency adjustment event for tracking changes
class FrequencyAdjustmentEvent {
  final DateTime timestamp;
  final Duration oldInterval;
  final Duration newInterval;
  final String reason;
  final Map<String, dynamic> context;

  const FrequencyAdjustmentEvent({
    required this.timestamp,
    required this.oldInterval,
    required this.newInterval,
    required this.reason,
    this.context = const {},
  });

  @override
  String toString() {
    return 'FrequencyAdjustmentEvent(${oldInterval.inSeconds}s -> ${newInterval.inSeconds}s, reason: $reason)';
  }
}

/// Metrics for frequency management
class FrequencyMetrics {
  final Duration currentInterval;
  final int updatesPerMinute;
  final double batteryImpact;
  final double networkUsage;
  final DateTime lastAdjustment;
  final int totalAdjustments;

  const FrequencyMetrics({
    required this.currentInterval,
    required this.updatesPerMinute,
    required this.batteryImpact,
    required this.networkUsage,
    required this.lastAdjustment,
    required this.totalAdjustments,
  });

  @override
  String toString() {
    return 'FrequencyMetrics(interval: ${currentInterval.inSeconds}s, updates/min: $updatesPerMinute, battery: ${batteryImpact.toStringAsFixed(1)}%, network: ${networkUsage.toStringAsFixed(2)}MB)';
  }
}

/// Adaptive Update Frequency Manager
class AdaptiveUpdateFrequencyManager {
  // Current state
  RidePhase _currentPhase = RidePhase.enRouteToPickup;
  NetworkQuality _networkQuality = NetworkQuality.good;
  double _batteryLevel = 100.0;
  double _driverSpeed = 0.0; // km/h
  double _locationAccuracy = 10.0; // meters
  Duration _currentInterval = Duration(seconds: 3);
  
  // Configuration
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _maxInterval = Duration(seconds: 30);
  static const Duration _defaultInterval = Duration(seconds: 3);
  
  // Tracking
  final List<FrequencyAdjustmentEvent> _adjustmentHistory = [];
  DateTime _lastAdjustment = DateTime.now();
  int _totalAdjustments = 0;
  
  // Battery and network impact estimation
  double _estimatedBatteryUsage = 0.0;
  double _estimatedNetworkUsage = 0.0;

  /// Set current ride phase
  void setRidePhase(RidePhase phase) {
    if (_currentPhase != phase) {
      final oldPhase = _currentPhase;
      _currentPhase = phase;
      
      dev.log('AdaptiveUpdateFrequencyManager: Ride phase changed: ${oldPhase.value} -> ${phase.value}');
      _recalculateFrequency('ride_phase_change', {
        'oldPhase': oldPhase.value,
        'newPhase': phase.value,
      });
    }
  }

  /// Set network quality
  void setNetworkQuality(NetworkQuality quality) {
    if (_networkQuality != quality) {
      final oldQuality = _networkQuality;
      _networkQuality = quality;
      
      dev.log('AdaptiveUpdateFrequencyManager: Network quality changed: ${oldQuality.value} -> ${quality.value}');
      _recalculateFrequency('network_quality_change', {
        'oldQuality': oldQuality.value,
        'newQuality': quality.value,
      });
    }
  }

  /// Set battery level
  void setBatteryLevel(double level) {
    final oldLevel = _batteryLevel;
    _batteryLevel = level.clamp(0.0, 100.0);
    
    // Only recalculate on significant changes
    if ((oldLevel - _batteryLevel).abs() > 5.0) {
      dev.log('AdaptiveUpdateFrequencyManager: Battery level changed: ${oldLevel.toStringAsFixed(1)}% -> ${_batteryLevel.toStringAsFixed(1)}%');
      _recalculateFrequency('battery_level_change', {
        'oldLevel': oldLevel,
        'newLevel': _batteryLevel,
      });
    }
  }

  /// Set driver speed
  void setDriverSpeed(double speedKmh) {
    final oldSpeed = _driverSpeed;
    _driverSpeed = speedKmh.clamp(0.0, 200.0);
    
    // Only recalculate on significant speed changes
    if ((oldSpeed - _driverSpeed).abs() > 5.0) {
      dev.log('AdaptiveUpdateFrequencyManager: Driver speed changed: ${oldSpeed.toStringAsFixed(1)} -> ${_driverSpeed.toStringAsFixed(1)} km/h');
      _recalculateFrequency('speed_change', {
        'oldSpeed': oldSpeed,
        'newSpeed': _driverSpeed,
      });
    }
  }

  /// Set location accuracy
  void setLocationAccuracy(double accuracy) {
    final oldAccuracy = _locationAccuracy;
    _locationAccuracy = accuracy.clamp(0.0, 1000.0);
    
    // Only recalculate on significant accuracy changes
    if ((oldAccuracy - _locationAccuracy).abs() > 5.0) {
      dev.log('AdaptiveUpdateFrequencyManager: Location accuracy changed: ${oldAccuracy.toStringAsFixed(1)} -> ${_locationAccuracy.toStringAsFixed(1)}m');
      _recalculateFrequency('accuracy_change', {
        'oldAccuracy': oldAccuracy,
        'newAccuracy': _locationAccuracy,
      });
    }
  }

  /// Calculate optimal update interval
  Duration calculateUpdateInterval() {
    return _currentInterval;
  }

  /// Calculate required location accuracy
  LocationAccuracy calculateRequiredAccuracy() {
    // Base accuracy on ride phase
    switch (_currentPhase) {
      case RidePhase.atPickupLocation:
      case RidePhase.atDropoffLocation:
        return LocationAccuracy.best; // Highest accuracy for critical phases
      case RidePhase.rideInProgress:
        return LocationAccuracy.bestForNavigation; // High accuracy during ride
      case RidePhase.enRouteToPickup:
        return LocationAccuracy.high; // Good accuracy en route
      case RidePhase.rideCompleted:
        return LocationAccuracy.medium; // Lower accuracy when completed
    }
  }

  /// Get current metrics
  FrequencyMetrics get metrics {
    final updatesPerMinute = _currentInterval.inSeconds > 0 
        ? (60 / _currentInterval.inSeconds).round()
        : 0;
    
    return FrequencyMetrics(
      currentInterval: _currentInterval,
      updatesPerMinute: updatesPerMinute,
      batteryImpact: _estimatedBatteryUsage,
      networkUsage: _estimatedNetworkUsage,
      lastAdjustment: _lastAdjustment,
      totalAdjustments: _totalAdjustments,
    );
  }

  /// Get adjustment history
  List<FrequencyAdjustmentEvent> get adjustmentHistory => 
      List.unmodifiable(_adjustmentHistory);

  /// Recalculate frequency based on current conditions
  void _recalculateFrequency(String reason, Map<String, dynamic> context) {
    final oldInterval = _currentInterval;
    final newInterval = _calculateOptimalInterval();
    
    if (oldInterval != newInterval) {
      _currentInterval = newInterval;
      _lastAdjustment = DateTime.now();
      _totalAdjustments++;
      
      // Record adjustment event
      final event = FrequencyAdjustmentEvent(
        timestamp: _lastAdjustment,
        oldInterval: oldInterval,
        newInterval: newInterval,
        reason: reason,
        context: context,
      );
      
      _adjustmentHistory.add(event);
      
      // Keep history manageable
      if (_adjustmentHistory.length > 50) {
        _adjustmentHistory.removeAt(0);
      }
      
      // Update impact estimates
      _updateImpactEstimates();
      
      dev.log('AdaptiveUpdateFrequencyManager: $event');
    }
  }

  /// Calculate optimal update interval based on all factors
  Duration _calculateOptimalInterval() {
    int baseSeconds = _defaultInterval.inSeconds;

    // Phase-based adjustment
    baseSeconds = _adjustForRidePhase(baseSeconds);
    
    // Network quality adjustment
    baseSeconds = _adjustForNetworkQuality(baseSeconds);
    
    // Battery level adjustment
    baseSeconds = _adjustForBatteryLevel(baseSeconds);
    
    // Speed-based adjustment
    baseSeconds = _adjustForSpeed(baseSeconds);
    
    // Accuracy-based adjustment
    baseSeconds = _adjustForAccuracy(baseSeconds);
    
    // Apply bounds
    baseSeconds = baseSeconds.clamp(_minInterval.inSeconds, _maxInterval.inSeconds);
    
    return Duration(seconds: baseSeconds);
  }

  /// Adjust interval based on ride phase
  int _adjustForRidePhase(int baseSeconds) {
    switch (_currentPhase) {
      case RidePhase.enRouteToPickup:
        return (baseSeconds * 1.2).round(); // 20% longer (less frequent)
      case RidePhase.atPickupLocation:
      case RidePhase.atDropoffLocation:
        return max(2, (baseSeconds * 0.7).round()); // 30% shorter (more frequent)
      case RidePhase.rideInProgress:
        return baseSeconds; // Standard frequency
      case RidePhase.rideCompleted:
        return (baseSeconds * 3.0).round(); // Much less frequent
    }
  }

  /// Adjust interval based on network quality
  int _adjustForNetworkQuality(int baseSeconds) {
    switch (_networkQuality) {
      case NetworkQuality.excellent:
        return baseSeconds; // No adjustment
      case NetworkQuality.good:
        return (baseSeconds * 1.1).round(); // Slightly longer
      case NetworkQuality.fair:
        return (baseSeconds * 1.3).round(); // Moderately longer
      case NetworkQuality.poor:
        return (baseSeconds * 1.6).round(); // Significantly longer
      case NetworkQuality.offline:
        return (baseSeconds * 2.5).round(); // Much longer (queue for later)
    }
  }

  /// Adjust interval based on battery level
  int _adjustForBatteryLevel(int baseSeconds) {
    if (_batteryLevel >= 80.0) {
      return baseSeconds; // No adjustment when battery is high
    } else if (_batteryLevel >= 50.0) {
      return (baseSeconds * 1.1).round(); // Slight adjustment
    } else if (_batteryLevel >= 20.0) {
      return (baseSeconds * 1.3).round(); // Moderate adjustment
    } else if (_batteryLevel >= 10.0) {
      return (baseSeconds * 1.6).round(); // Significant adjustment
    } else {
      return (baseSeconds * 2.0).round(); // Major adjustment for critical battery
    }
  }

  /// Adjust interval based on driver speed
  int _adjustForSpeed(int baseSeconds) {
    // Only apply speed adjustments if we have meaningful speed data
    // Default speed of 0.0 should not trigger stationary mode unless explicitly set
    if (_driverSpeed == 0.0) {
      // No speed data available, don't adjust
      return baseSeconds;
    } else if (_driverSpeed < 2.0) {
      // Stationary or very slow - reduce frequency significantly
      return max(baseSeconds, 10);
    } else if (_driverSpeed < 10.0) {
      // Slow movement - slightly reduce frequency
      return (baseSeconds * 1.2).round();
    } else if (_driverSpeed > 80.0) {
      // High speed - increase frequency for better tracking
      return max(2, (baseSeconds * 0.8).round());
    } else if (_driverSpeed > 50.0) {
      // Moderate high speed - slightly increase frequency
      return max(2, (baseSeconds * 0.9).round());
    } else {
      // Normal speed - no adjustment
      return baseSeconds;
    }
  }

  /// Adjust interval based on location accuracy
  int _adjustForAccuracy(int baseSeconds) {
    if (_locationAccuracy > 50.0) {
      // Poor accuracy - increase frequency to get better readings
      return max(2, (baseSeconds * 0.8).round());
    } else if (_locationAccuracy > 20.0) {
      // Fair accuracy - slight increase in frequency
      return max(2, (baseSeconds * 0.9).round());
    } else if (_locationAccuracy <= 5.0) {
      // Excellent accuracy - can afford slightly less frequent updates
      return (baseSeconds * 1.1).round();
    } else {
      // Good accuracy - no adjustment
      return baseSeconds;
    }
  }

  /// Update battery and network impact estimates
  void _updateImpactEstimates() {
    final updatesPerHour = 3600 / _currentInterval.inSeconds;
    
    // Estimate battery impact (rough calculation)
    // GPS + network operations consume approximately 0.1-0.3% per update
    _estimatedBatteryUsage = updatesPerHour * 0.2; // 0.2% per update estimate
    
    // Estimate network usage (rough calculation)
    // Each location update is approximately 0.5KB
    _estimatedNetworkUsage = (updatesPerHour * 0.5) / 1024; // MB per hour
  }

  /// Force recalculation of frequency
  void forceRecalculation(String reason) {
    _recalculateFrequency(reason, {'forced': true});
  }

  /// Reset to default settings
  void reset() {
    dev.log('AdaptiveUpdateFrequencyManager: Resetting to default settings');
    
    _currentPhase = RidePhase.enRouteToPickup;
    _networkQuality = NetworkQuality.good;
    _batteryLevel = 100.0;
    _driverSpeed = 0.0;
    _locationAccuracy = 10.0;
    _currentInterval = _defaultInterval;
    _adjustmentHistory.clear();
    _lastAdjustment = DateTime.now();
    _totalAdjustments = 0;
    _estimatedBatteryUsage = 0.0;
    _estimatedNetworkUsage = 0.0;
  }

  /// Get configuration summary
  Map<String, dynamic> getConfigurationSummary() {
    return {
      'currentPhase': _currentPhase.value,
      'networkQuality': _networkQuality.value,
      'batteryLevel': _batteryLevel,
      'driverSpeed': _driverSpeed,
      'locationAccuracy': _locationAccuracy,
      'currentInterval': _currentInterval.inSeconds,
      'minInterval': _minInterval.inSeconds,
      'maxInterval': _maxInterval.inSeconds,
      'totalAdjustments': _totalAdjustments,
      'lastAdjustment': _lastAdjustment.toIso8601String(),
      'estimatedBatteryUsage': _estimatedBatteryUsage,
      'estimatedNetworkUsage': _estimatedNetworkUsage,
    };
  }
}